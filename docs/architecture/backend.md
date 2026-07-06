# Backend

Guía técnica del backend OSeMOSYS UPME (FastAPI + Pyomo + Celery). Para la formulación matemática del motor de optimización, el solver y el procesamiento de resultados, ver [Motor de simulación OSeMOSYS](motor-osemosys.md); para las vistas C4 completas, ver [Visión general](overview.md).

## Descripción general

Este backend implementa un sistema de ejecución de escenarios energéticos con enfoque **DB-first** para OSEMOSYS, donde los insumos del modelo se gestionan en PostgreSQL y las corridas se ejecutan asíncronamente vía cola.

- **Problema que resuelve**: ejecutar optimizaciones energéticas multiusuario sin bloquear la API, preservando trazabilidad y control operacional.
- **Qué hace el sistema**: gestiona escenarios e insumos; encola simulaciones; ejecuta el modelo de optimización; persiste artefactos y progreso; expone resultados por API.
- **Público objetivo**: desarrolladores backend, modeladores energéticos, ingenieros de optimización y equipo de operación on-prem.

## Variables de entorno y artefactos locales

El backend se ejecuta con `backend/.env` (no se usa `backend/.env.example`). Si se viene de una versión anterior con `backend/.env.example`, hay que eliminarlo y dejar únicamente `backend/.env`.

Durante ejecución local/simulaciones se generan archivos transitorios que **no deben versionarse** (protegidos por `.gitignore`):

| Ruta | Contenido |
|---|---|
| `backend/tmp/local/` | SQLite local, `simulation_result.json`, `simulation_kpis.csv`, `simulation_events.csv`, `charts/*.png`, `tables/*.csv` |
| `backend/tmp/simulation-results/` | `simulation_job_<id>.json` |
| `backend/tmp/local/parity/` | salidas de paridad CLI vs Docker |
| `backend/tmp/local/comparison_csvs/` | CSV temporales de comparación |

## Arquitectura del sistema

Flujo lógico:

1. Cliente solicita `POST /api/v1/simulations`.
2. FastAPI valida permisos y límites de ejecución.
3. Se crea `simulation_job` en BD (`QUEUED`) y se envía la tarea a Celery/Redis.
4. El worker consume la tarea, ejecuta el pipeline OSEMOSYS y escribe el artefacto JSON.
5. La API expone estado (`/simulations/{id}`), logs (`/logs`) y resultados (`/result`).

**Componentes:**

- **Backend API**: FastAPI (`app/main.py`, routers en `app/api/v1`).
- **Persistencia**: PostgreSQL con esquemas `osemosys` (modelo energético, jobs, parámetros) y `core` (usuarios/documentos).
- **Cola y ejecución concurrente**: Redis como broker/backend Celery; worker dedicado `simulation-worker`.
- **Motor de optimización**: Pyomo + solvers intercambiables (HiGHS por defecto, Gurobi, CPLEX, Mosek) — ver [Motor de simulación OSeMOSYS](motor-osemosys.md).

**Separación por capas:**

- **API**: validación HTTP, serialización y códigos de error.
- **Servicio**: reglas de negocio (permisos, límites por usuario, transición de estados).
- **Repositorio**: acceso a datos y consultas SQLAlchemy.
- **Motor de optimización**: `app/simulation/*` con bloques matemáticos.

## Flujo de ejecución de un escenario

1. **Usuario crea escenario**
   - Endpoint: `app/api/v1/scenarios.py`.
   - Regla de negocio: `app/services/scenario_service.py`.
2. **Se almacenan parámetros**
   - Base general: `osemosys.parameter_value`.
   - Parámetros multidimensionales OSEMOSYS: `osemosys.osemosys_param_value`.
   - Modelo ORM: `app/models/parameter_value.py`, `app/models/osemosys_param_value.py`.
3. **Se construye el dataset OSEMOSYS** — `app/simulation/core/parameters_loader.py` transforma registros SQL a estructuras normalizadas (`DemandRow`, `SupplyRow`, mapas de parámetros).
4. **Se genera la estructura del modelo (en memoria)** y **se ejecuta el solver** — ver el detalle completo de sets, variables, restricciones y solver en [Motor de simulación OSeMOSYS](motor-osemosys.md).
5. **Se parsean y persisten los resultados** — artefacto JSON en `tmp/simulation-results/simulation_job_<id>.json`; referencia en `simulation_job.result_ref`; consulta pública vía `GET /api/v1/simulations/{job_id}/result`.

### Dónde modificar cada etapa

| Etapa | Archivo |
|---|---|
| Ingesta/transformación de datos | `app/simulation/core/parameters_loader.py` |
| Sets e índices | `app/simulation/core/sets_and_indices.py` |
| Variables | `app/simulation/core/variables.py` |
| Restricciones | `app/simulation/core/constraints_*.py` |
| Objetivo | `app/simulation/core/objective.py` |
| Progreso/logs/artefactos | `app/simulation/pipeline.py` |

## Base de datos

**Tablas relevantes para modelado y ejecución:**

- **Escenarios e insumos**: `osemosys.scenario`, `osemosys.parameter_value`, `osemosys.osemosys_param_value`.
- **Catálogos**: `parameter`, `region`, `technology`, `fuel`, `emission`, `solver`; sets OSEMOSYS: `timeslice`, `mode_of_operation`, `season`, `daytype`, `dailytimebracket`, `storage_set`, `udc_set`.
- **Ejecución**: `osemosys.simulation_job`, `osemosys.simulation_job_event`.
- **Paridad/benchmark**: `osemosys.simulation_benchmark`.

**Mapeo al modelo:**

- `parameter_value` alimenta demanda/oferta base.
- `osemosys_param_value` alimenta parámetros multidimensionales por `param_name` + dimensiones + año.
- `simulation_job*` soporta orquestación y observabilidad operacional.

## Concurrencia y control de ejecución

- Límite por usuario: `SIM_USER_ACTIVE_LIMIT` (default `1`), validado en servicio.
- Concurrencia global de workers: `SIM_MAX_CONCURRENCY` (default `3`), aplicada en el comando Celery del contenedor worker.
- Estados de job: `QUEUED`, `RUNNING`, `SUCCEEDED`, `FAILED`, `CANCELLED`.
- Cancelación cooperativa: bandera `cancel_requested`; chequeos explícitos entre etapas y sub-etapas del pipeline.

Protección del servidor: desacoplar la API de la carga pesada mediante cola; evitar ejecución síncrona en el request thread; persistir progreso para visibilidad del frontend.

## Manejo de errores

- Si falla el solver o el pipeline: `simulation_job.status = FAILED`, se persiste `error_message` y se agrega un evento `ERROR` en `simulation_job_event`.
- Si el artefacto no existe: `GET /simulations/{job_id}/result` devuelve un error controlado (`404`).
- Si el usuario no tiene acceso al escenario/job: `403` o `404` según el contexto.

!!! note "Modelo infactible"
    El caso de un modelo infactible (reportado en `solver_status`) se documenta en detalle en [Infactibilidad y manejo de errores](motor-osemosys.md#infactibilidad-y-manejo-de-errores).

## Extensibilidad

- Para nuevas funcionalidades: mantener la separación API/Service/Repository/SimulationCore; agregar el bloque de modelo en `app/simulation/core` en lugar de un monolito.
- Para escalar horizontalmente: escalar `simulation-worker` por réplicas; usar Redis gestionado y ajustar `SIM_MAX_CONCURRENCY`.
- Para desacoplar el motor: extraer `app/simulation` a un microservicio de optimización, manteniendo el contrato por `simulation_job` + artefactos + eventos.

## Buenas prácticas para el equipo futuro

- No modificar directamente los contratos de la API sin versionar schemas.
- Antes de cambiar restricciones: validar unidades, revisar impacto en factibilidad y correr el benchmark de paridad numérica.
- No introducir defaults silenciosos adicionales sin documentarlos.
- Mantener trazabilidad de los cambios de formulación en la documentación técnica.
- Revisar el impacto de los cambios sobre tiempos de solve, consumo de memoria y estabilidad numérica.

## Roadmap técnico sugerido

1. **Paridad matemática completa OSEMOSYS** — reemplazar restricciones proxy de storage/UDC por formulación completa.
2. **Validación robusta** — ampliar benchmarks (2-3 escenarios de referencia adicionales).
3. **Tuning solver** — parametrizar tolerancias, time limits y estrategias por tamaño de instancia.
4. **Observabilidad** — métricas Prometheus (tiempo cola, tiempo solve, fallas por tipo).
5. **Microservicio de optimización** — separar el motor del API para despliegue y escalado independientes.
6. **Gobernanza de datos de entrada** — validadores semánticos por `param_name` y cardinalidad esperada.

## Operación rápida (Docker)

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

Health:

```bash
curl http://localhost:8010/api/v1/health
```

## Operación rápida (sin Docker, SQLite local)

Desde la raíz del repo:

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Variables y archivos clave para este modo:

- `backend/.env.local` (se crea desde `backend/.env.local.example`).
- `DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db`
- `SIMULATION_MODE=sync` (ejecución local sin Redis/worker).

Health:

```powershell
Invoke-RestMethod http://localhost:8000/api/v1/health
```

### Ejecutar modelo local desde `../CSV` (sin BD/UPME)

Este flujo no requiere conexión al servidor UPME ni escenarios en base de datos. Toma directamente los CSV en la carpeta `../CSV`, construye la instancia Pyomo y ejecuta el solver.

1. Activar entorno virtual e instalar dependencias (desde la raíz del repo):

   ```powershell
   cd backend
   ..\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

2. Ejecutar la simulación con HiGHS y guardar el resultado JSON:

   ```powershell
   @'
   import json
   from pathlib import Path
   from app.simulation.osemosys_core import run_osemosys_from_csv_dir

   csv_dir = Path("../CSV").resolve()
   result = run_osemosys_from_csv_dir(csv_dir, solver_name="highs")

   out = Path("tmp/prueba_final_from_csv_result.json")
   out.parent.mkdir(parents=True, exist_ok=True)
   out.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

   print("solver_status:", result.get("solver_status"))
   print("objective_value:", result.get("objective_value"))
   print("coverage_ratio:", result.get("coverage_ratio"))
   print("saved:", out.resolve())
   '@ | python -
   ```

3. Verificar salida: archivo `backend/tmp/prueba_final_from_csv_result.json`, con `solver_status: optimal` esperado.

!!! note "Notas del flujo CSV"
    Este flujo usa el pipeline `CSV -> DataPortal -> Pyomo -> HiGHS`. Los sets y parámetros en `../CSV` deben ser consistentes entre sí (por ejemplo, `YEAR.csv` vs `DaySplit.csv`, `TIMESLICE.csv` vs `Conversionl*.csv`).

Usuario seed: `seed` / `seed123`, con permisos `can_manage_catalogs = true` y `can_import_official_data = true`.

## Importación oficial de Excel

Requiere el permiso `can_import_official_data`:

```bash
curl -X POST "http://localhost:8010/api/v1/official-import/xlsm/sheets" \
  -H "Authorization: Bearer <TOKEN>" \
  -F "file=@C:\Users\SGI SAS\OneDrive - SGI SAS\Documentos\UPME\SAND_04_02_2026.xlsm"
```

Luego se importa una hoja específica:

```bash
curl -X POST "http://localhost:8010/api/v1/official-import/xlsm" \
  -H "Authorization: Bearer <TOKEN>" \
  -F "file=@C:\Users\SGI SAS\OneDrive - SGI SAS\Documentos\UPME\SAND_04_02_2026.xlsm" \
  -F "sheet_name=Parameters"
```

Crear un escenario desde Excel (sin depender del usuario seed):

```bash
curl -X POST "http://localhost:8010/api/v1/scenarios/import-excel" \
  -H "Authorization: Bearer <TOKEN>" \
  -F "file=@C:\Users\SGI SAS\OneDrive - SGI SAS\Documentos\UPME\SAND_04_02_2026.xlsm" \
  -F "sheet_name=Parameters" \
  -F "scenario_name=Escenario 2026 (Excel)" \
  -F "edit_policy=OWNER_ONLY"
```

### Formato esperado del Excel (SAND matriz por año)

El importador soporta hojas tipo **matriz** (por ejemplo `Parameters` / `Hoja1`) donde cada fila describe un parámetro y las columnas de años contienen los valores.

- **Encabezados mínimos**: `Parameter` (obligatorio) y columnas de **años** (ej. `2018`, `2019`, `2020`...).
- **Dimensiones opcionales** (pueden estar vacías según aplique): `REGION`, `TECHNOLOGY`, `FUEL`, `EMISSION`, `TIMESLICE`, `MODE_OF_OPERATION`, `STORAGE`, `Time indipendent variables` (valor "sin año").
- **Normalización**: se ignoran mayúsculas/minúsculas, acentos y espacios (ej. `Región`, `REGION`, `region` funcionan igual).

!!! warning "Reglas importantes de importación"
    - Celdas vacías se interpretan como **0**.
    - Para performance, valores **0** se omiten (no se insertan en BD).
    - Si existen catálogos faltantes (regiones/tecnologías/combustibles/emisiones/timeslices/etc.) se crean automáticamente al importar.

Ejemplo mínimo:

| Parameter | REGION | TECHNOLOGY | FUEL | EMISSION | TIMESLICE | MODE_OF_OPERATION | Time indipendent variables | 2020 | 2021 |
|---|---|---|---|---|---|---|---:|---:|---:|
| Demand | R1 |  |  |  |  |  |  | 100 | 105 |
| CapitalCost | R1 | TECH_A |  |  |  |  |  | 1200 | 1180 |
| VariableCost | R1 | TECH_A |  |  |  |  |  | 12.5 | 12.7 |
| EmissionActivityRatio | R1 | TECH_A |  | CO2 |  |  |  | 0.25 | 0.25 |
| AnnualEmissionLimit | R1 |  |  | CO2 |  |  |  | 5000 | 5000 |
