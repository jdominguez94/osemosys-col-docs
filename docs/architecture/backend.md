# Backend

Guía técnica del backend OSeMOSYS Colombia (FastAPI + Pyomo + Celery). Para la formulación matemática del motor de optimización, el solver y el procesamiento de resultados, ver [Motor de simulación OSeMOSYS](motor-osemosys.md); para las vistas C4 completas, ver [Visión general](overview.md).

## Descripción general

Este backend implementa un sistema de ejecución de escenarios energéticos centrado en la base de datos para OSEMOSYS. Los insumos del modelo se gestionan en PostgreSQL y las corridas se ejecutan de forma asíncrona a través de una cola.

El problema que resuelve es ejecutar optimizaciones energéticas para varios usuarios a la vez sin bloquear la API, preservando trazabilidad y control operacional. Para lograrlo, el sistema gestiona escenarios e insumos, encola simulaciones, ejecuta el modelo de optimización, persiste artefactos y progreso, y expone los resultados por API. Está pensado para desarrolladores backend, modeladores energéticos, ingenieros de optimización y el equipo de operación on-prem.

## Variables de entorno y artefactos locales

El backend se ejecuta con `backend/.env` (no se usa `backend/.env.example`). Si se viene de una versión anterior con `backend/.env.example`, hay que eliminarlo y dejar únicamente `backend/.env`.

Durante la ejecución local y las simulaciones se generan archivos transitorios que **no deben versionarse**, porque están protegidos por `.gitignore`.

| Ruta | Contenido |
|---|---|
| `backend/tmp/local/` | SQLite local, `simulation_result.json`, `simulation_kpis.csv`, `simulation_events.csv`, `charts/*.png`, `tables/*.csv` |
| `backend/tmp/simulation-results/` | `simulation_job_<id>.json` |
| `backend/tmp/local/parity/` | salidas de paridad CLI vs Docker |
| `backend/tmp/local/comparison_csvs/` | CSV temporales de comparación |

## Arquitectura del sistema

El flujo lógico es este.

1. Cliente solicita `POST /api/v1/simulations`.
2. FastAPI valida permisos y límites de ejecución.
3. Se crea `simulation_job` en BD (`QUEUED`) y se envía la tarea a Celery/Redis.
4. El worker consume la tarea, ejecuta el pipeline OSEMOSYS y escribe el artefacto JSON.
5. La API expone estado (`/simulations/{id}`), logs (`/logs`) y resultados (`/result`).

Los componentes principales son estos. El **backend API** es FastAPI (`app/main.py`, con routers en `app/api/v1`). La **persistencia** vive en PostgreSQL, con los esquemas `osemosys` (modelo energético, jobs, parámetros) y `core` (usuarios y documentos). La **cola y ejecución concurrente** usan Redis como broker y backend de Celery, con un worker dedicado llamado `simulation-worker`. El **motor de optimización** es Pyomo combinado con solvers intercambiables (HiGHS por defecto, Gurobi, CPLEX, Mosek); el detalle completo está en [Motor de simulación OSeMOSYS](motor-osemosys.md).

La separación por capas funciona así. La capa **API** se encarga de la validación HTTP, la serialización y los códigos de error. La capa de **servicio** aplica las reglas de negocio, como permisos, límites por usuario y transición de estados. El **repositorio** maneja el acceso a datos y las consultas SQLAlchemy. Y el **motor de optimización**, en `app/simulation/*`, contiene los bloques matemáticos.

## Flujo de ejecución de un escenario

1. **El usuario crea el escenario**, a través del endpoint `app/api/v1/scenarios.py`, con la regla de negocio en `app/services/scenario_service.py`.
2. **Se almacenan los parámetros.** La base general va a `osemosys.parameter_value`, los parámetros multidimensionales de OSEMOSYS van a `osemosys.osemosys_param_value`, y el modelo ORM vive en `app/models/parameter_value.py` y `app/models/osemosys_param_value.py`.
3. **Se construye el dataset OSEMOSYS.** `app/simulation/core/parameters_loader.py` transforma los registros SQL en estructuras normalizadas (`DemandRow`, `SupplyRow`, mapas de parámetros).
4. **Se genera la estructura del modelo en memoria y se ejecuta el solver.** El detalle completo de sets, variables, restricciones y solver está en [Motor de simulación OSeMOSYS](motor-osemosys.md).
5. **Se parsean y persisten los resultados.** El artefacto JSON queda en `tmp/simulation-results/simulation_job_<id>.json`, con su referencia en `simulation_job.result_ref`, disponible para consulta pública vía `GET /api/v1/simulations/{job_id}/result`.

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

Las tablas relevantes para modelado y ejecución son estas. Las de **escenarios e insumos** viven en `osemosys.scenario`, `osemosys.parameter_value` y `osemosys.osemosys_param_value`. Los **catálogos** son `parameter`, `region`, `technology`, `fuel`, `emission` y `solver`, junto con los sets de OSEMOSYS `timeslice`, `mode_of_operation`, `season`, `daytype`, `dailytimebracket`, `storage_set` y `udc_set`. La **ejecución** se apoya en `osemosys.simulation_job` y `osemosys.simulation_job_event`. Y la **paridad y el benchmark** usan `osemosys.simulation_benchmark`.

En cuanto al mapeo hacia el modelo, `parameter_value` alimenta la demanda y oferta base, `osemosys_param_value` alimenta los parámetros multidimensionales combinando `param_name`, dimensiones y año, y las tablas `simulation_job*` sostienen la orquestación y la observabilidad operacional.

## Concurrencia y control de ejecución

El límite por usuario es `SIM_USER_ACTIVE_LIMIT` (por defecto `1`), validado en el servicio. La concurrencia global de workers es `SIM_MAX_CONCURRENCY` (por defecto `3`), aplicada en el comando Celery del contenedor worker. Un job puede pasar por los estados `QUEUED`, `RUNNING`, `SUCCEEDED`, `FAILED` y `CANCELLED`. La cancelación es cooperativa, mediante la bandera `cancel_requested` y chequeos explícitos entre etapas y subetapas del pipeline.

Para proteger al servidor, la API se desacopla de la carga pesada mediante una cola, se evita la ejecución síncrona en el hilo del request y se persiste el progreso para que el frontend pueda mostrarlo.

## Manejo de errores

Si falla el solver o el pipeline, `simulation_job.status` pasa a `FAILED`, se persiste `error_message` y se agrega un evento `ERROR` en `simulation_job_event`. Si el artefacto no existe, `GET /simulations/{job_id}/result` devuelve un error controlado (`404`). Y si el usuario no tiene acceso al escenario o al job, la respuesta es `403` o `404` según el contexto.

!!! note "Modelo infactible"
    El caso de un modelo infactible (reportado en `solver_status`) se documenta en detalle en [Infactibilidad y manejo de errores](motor-osemosys.md#infactibilidad-y-manejo-de-errores).

## Operación rápida (Docker)

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

Para comprobar que el servicio está sano.

```bash
curl http://localhost:8010/api/v1/health
```

## Operación rápida (sin Docker, SQLite local)

Desde la raíz del repositorio, corre esto.

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Las variables y archivos clave para este modo son estos.

```
backend/.env.local (se crea desde backend/.env.local.example)
DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db
SIMULATION_MODE=sync (ejecución local sin Redis/worker)
```

Para comprobar que el servicio está sano.

```powershell
Invoke-RestMethod http://localhost:8000/api/v1/health
```
