# Backend

Guía técnica del backend OSeMOSYS Colombia (FastAPI + Pyomo + Celery). Para la formulación matemática del motor de optimización, el solver y el procesamiento de resultados, ver [Motor de simulación OSeMOSYS](motor-osemosys.md); para las vistas C4 completas, ver [Visión general](overview.md).

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

