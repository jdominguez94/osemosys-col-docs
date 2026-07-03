# Variables de entorno

Esta página resume las variables de entorno más relevantes para la primera puesta en marcha del stack Docker (definidas en `.env` en la raíz del repositorio de la aplicación, a partir de `.env.example`). No es un listado exhaustivo de todas las variables internas del backend — solo las que un evaluador o desarrollador nuevo necesita conocer para instalar y acceder a la aplicación.

!!! tip "Ninguna es obligatoria para empezar"
    Todas las variables tienen un valor por defecto razonable. Solo necesitas crear un archivo `.env` si quieres cambiar puertos, credenciales o límites de ejecución.

## Puertos y hosts expuestos

| Variable | Valor por defecto | Propósito |
|----------|--------------------|-----------|
| `API_PORT` | `8010` | Puerto en el host donde queda expuesta la API (contenedor escucha internamente en `8000`). |
| `API_BIND_HOST` | `127.0.0.1` | Interfaz de red donde se publica la API. |
| `FRONTEND_PORT` | `8080` | Puerto en el host donde queda expuesto el frontend (nginx). |
| `FRONTEND_BIND_HOST` | `0.0.0.0` | Interfaz de red donde se publica el frontend. |
| `POSTGRES_PORT` | `55432` | Puerto en el host para conectarse a PostgreSQL directamente (p. ej. con un cliente SQL). |
| `POSTGRES_BIND_HOST` | `127.0.0.1` | Interfaz de red donde se publica PostgreSQL. |
| `REDIS_PORT` | `6379` | Puerto en el host para Redis. |
| `REDIS_BIND_HOST` | `127.0.0.1` | Interfaz de red donde se publica Redis. |

!!! note "Valores en `.env.example`"
    El archivo `.env.example` de referencia trae `POSTGRES_PORT=5433` y `FRONTEND_PORT=80` como sugerencia para ciertos despliegues (p. ej. detrás de un proxy reverso); los valores por defecto que aplica `docker-compose.yml` si no defines nada son los de la tabla anterior (`55432` y `8080` respectivamente). Ajusta estos valores según cómo vayas a exponer el stack.

## Credenciales y base de datos

| Variable | Valor por defecto | Propósito |
|----------|--------------------|-----------|
| `POSTGRES_USER` | `osemosys` | Usuario de PostgreSQL. |
| `POSTGRES_PASSWORD` | `osemosys` | Contraseña de PostgreSQL. |
| `POSTGRES_DB` | `osemosys` | Nombre de la base de datos. |
| `DB_SCHEMA_OSEMOSYS` | `osemosys` | Esquema de PostgreSQL usado por el dominio de simulación. |
| `DATABASE_URL_DOCKER` | `postgresql+psycopg://osemosys:osemosys@db:5432/osemosys` | Cadena de conexión que usa la API/worker **dentro** de la red Docker. |
| `SECRET_KEY` | `replace-me-before-deploy` | Clave usada para firmar tokens de autenticación. **Cámbiala antes de cualquier despliegue real.** |

## Simulación y rendimiento

| Variable | Valor por defecto | Propósito |
|----------|--------------------|-----------|
| `SIM_MAX_CONCURRENCY` | `1` | Número de simulaciones que el worker de Celery ejecuta en paralelo. |
| `SIM_USER_ACTIVE_LIMIT` | `4` (`3` en `.env.example`) | Máximo de simulaciones activas simultáneas por usuario. |
| `SIM_TOTAL_WEIGHT_LIMIT` | `8` | Límite agregado de "peso" de simulaciones en cola (ver pesos abajo). |
| `SIM_WEIGHT_NATIONAL` | `1` | Peso relativo de una simulación en modo nacional. |
| `SIM_WEIGHT_REGIONAL` | `3` | Peso relativo de una simulación en modo regional (más costosa). |
| `SIM_SOLVER_THREADS` | `12` | Hilos asignados al solver HiGHS por simulación. |
| `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS` | `4` | Hilos para las librerías numéricas subyacentes (afectan el rendimiento del solver). |
| `API_WORKERS` | `3` | Número de workers de Uvicorn para la API. |

## Frontend (build-time)

| Variable | Valor por defecto | Propósito |
|----------|--------------------|-----------|
| `VITE_API_BASE_URL` | `/api/v1` | Prefijo base que usa el frontend para llamar a la API. |
| `VITE_APP_ENV` | `production` | Entorno de la build del frontend. |
| `VITE_SIMULATION_MODE` | `api` | Modo de simulación que asume el frontend (contra la API remota). |

## Otras variables

| Variable | Valor por defecto | Propósito |
|----------|--------------------|-----------|
| `DISK_AUDIT_INTERVAL_HOURS` | `6` | Frecuencia de la auditoría local de espacio en disco. |
| `DISK_ALERT_THRESHOLDS_GB` | `60,50,40` | Umbrales (en GB) para generar alertas de espacio en disco. |
| `CORS_ORIGINS` | `http://localhost:8080,http://localhost:5173` | Orígenes permitidos para llamadas cross-origin a la API. |
| `LOG_LEVEL` | `INFO` | Nivel de logging del backend. |

!!! tip "Modo local (SQLite)"
    Si usas el modo local sin Docker (`scripts/setup-local.ps1`), las variables relevantes viven en `backend/.env.local` en lugar de en el `.env` de la raíz, e incluyen `DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db` y `SIMULATION_MODE=sync`. Ver [Instalación](installation.md).

## Siguientes pasos

- [Instalación](installation.md) para el procedimiento completo de puesta en marcha.
- [Primera simulación](first-simulation.md) para el primer recorrido guiado por la interfaz.
