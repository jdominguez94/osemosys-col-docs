# Despliegue

Esta página describe cómo poner en marcha el stack completo de OSeMOSYS Colombia con Docker Compose, orientada a quien opera el sistema (no al usuario final de la aplicación web).

## Formas de desplegar

Hay tres formas de poner en marcha (o volver a levantar) el stack, según qué tan cerca de producción necesites estar.

| Forma | Cuándo usarla | Requiere Docker | Base de datos | Simulaciones |
|---|---|---|---|---|
| [`task up`](#atajo-con-task) | Forma recomendada para levantar todo de una vez (dev/staging/producción) | Sí | PostgreSQL | Asíncronas (Celery + Redis) |
| [`docker compose` directo](#levantar-el-stack-completo-docker-compose) | Cuando necesitas control fino paso a paso (build, migraciones y seed por separado), o no tienes `go-task` instalado | Sí | PostgreSQL | Asíncronas (Celery + Redis) |
| [Modo local sin Docker](#alternativa-local-sin-docker-sqlite) | Desarrollo del backend en solitario, sin levantar contenedores | No | SQLite | Síncronas (sin cola) |

=== "task"

    ```bash
    task up
    ```

    Atajo que ejecuta build, migraciones y seed en un solo comando. Ver [detalle](#atajo-con-task).

=== "docker compose"

    ```bash
    docker compose up -d --build
    docker compose exec api alembic upgrade head
    docker compose exec api python scripts/seed.py
    ```

    Los mismos tres pasos que `task up`, explícitos. Ver [detalle](#levantar-el-stack-completo-docker-compose).

=== "Local (sin Docker)"

    ```powershell
    .\scripts\setup-local.ps1
    .\scripts\init-local-db.ps1
    .\scripts\run-local-api.ps1
    ```

    Backend con SQLite y simulaciones síncronas, sin Postgres/Redis/Celery. Ver [detalle](#alternativa-local-sin-docker-sqlite).

## Prerrequisitos

Hace falta Docker Desktop (o Docker Engine más el Docker Compose Plugin) y los archivos de entorno preparados, `.env` en la raíz, `backend/.env` y, si aplica, `frontend/.env`.

!!! note "Archivos `.env` vs `.env.example`"
    El backend se ejecuta con `backend/.env` (no con `backend/.env.example`). Si vienes de una versión anterior que dejó `backend/.env.example` en el árbol, elimínalo y conserva solo el `.env` real. Ver también [Variables de entorno](../getting-started/environment-variables.md).

## Servicios y puertos

El stack (`docker-compose.yml`, proyecto `osemosys`) define los siguientes servicios.

| Servicio | Imagen/build | Puerto host → contenedor | Variables de host |
|---|---|---|---|
| `db` (PostgreSQL 16) | `postgres:16-alpine` | `${POSTGRES_PORT:-55432}` → `5432` | `POSTGRES_BIND_HOST` (default `127.0.0.1`), `POSTGRES_PORT` |
| `redis` (Redis 7) | `redis:7-alpine` | `${REDIS_PORT:-6379}` → `6379` | `REDIS_BIND_HOST`, `REDIS_PORT` |
| `api` (FastAPI/uvicorn) | build `./backend` | `${API_PORT:-8010}` → `8000` | `API_BIND_HOST` (default `127.0.0.1`), `API_PORT` |
| `simulation-worker` (Celery) | build `./backend` | sin puerto expuesto | N/A |
| `frontend` (Nginx + React) | build `./frontend` | `${FRONTEND_PORT:-8080}` → `80` | `FRONTEND_BIND_HOST` (default `0.0.0.0`), `FRONTEND_PORT` |

!!! warning "Exposición por defecto"
    Por defecto solo el `frontend` debería quedar expuesto fuera del host. Deja `API_BIND_HOST`, `POSTGRES_BIND_HOST` y `REDIS_BIND_HOST` en `127.0.0.1` en cualquier ambiente que no sea completamente confiable, y abre en firewall únicamente el puerto del frontend. Ver también [CI/CD, Exposición de servicios](ci-cd.md#exposicion-de-servicios).

El `api` depende de que `db` y `redis` estén healthy; el `frontend` depende de que `api` esté healthy (`condition: service_healthy` en `docker-compose.yml`).

## Levantar el stack completo (Docker Compose)

Desde la raíz del repositorio.

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

1. `docker compose up -d --build` construye las imágenes (`api`, `simulation-worker`, `frontend`) y levanta `db`, `redis`, `api`, `simulation-worker` y `frontend` en segundo plano.
2. `docker compose exec api alembic upgrade head` aplica las migraciones de base de datos pendientes.
3. `docker compose exec api python scripts/seed.py` crea el usuario semilla (ver abajo) y datos mínimos de catálogo.

Verifica el estado del stack.

```bash
docker compose ps
curl -fsS http://localhost:8010/api/v1/health
```

### Atajo con `task`

Si tienes [`go-task`](https://taskfile.dev/) instalado, el `Taskfile.yml` del repo agrupa los mismos tres pasos en una sola tarea.

```bash
task up
```

`task up` ejecuta internamente `docker compose up -d --build --wait`, `docker compose exec api alembic upgrade head` y `docker compose exec api python scripts/seed.py`. Para diagnóstico posterior (logs, health) ver el [Runbook](runbook.md).

## Usuario semilla

`scripts/seed.py` crea un usuario base para login.

| Campo | Valor |
|---|---|
| username | `seed` |
| email | `seed@example.com` |
| password | `seed123` |
| `can_manage_catalogs` | `true` |

!!! danger "Credenciales de ejemplo"
    `seed` / `seed123` es un usuario de conveniencia para ambientes de desarrollo/prueba. No lo dejes activo con esa contraseña en un ambiente expuesto públicamente.

## Detener y reiniciar el stack

```bash
# Detiene y elimina contenedores (DB, Redis y artefactos se conservan)
docker compose down
```

!!! danger "Borrado de volúmenes"
    `docker compose down -v` (o la tarea `task down:volumes`) elimina **todos** los volúmenes, incluyendo los datos de Postgres y la caché de Redis. Es una acción irreversible. Úsala solo cuando de verdad quieras empezar de cero.

Con `task` (ver `Taskfile.yml`).

```bash
task down            # baja contenedores, conserva volúmenes (pide confirmación)
task down:volumes    # baja contenedores y borra volúmenes (pide confirmación, irreversible)
```

## Alternativa local sin Docker (SQLite)

Para desarrollo backend sin levantar todo el stack de contenedores, existe un flujo local con SQLite y ejecución síncrona de simulaciones (sin Redis/Celery).

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Este flujo crea un entorno virtual `.venv` e instala `backend/requirements.txt`, genera `backend/.env.local` (si no existe) con `DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db` y `SIMULATION_MODE=sync`, inicializa SQLite local con un seed mínimo (`seed/seed123`), y deja la API disponible en `http://localhost:8000` (`/docs`); usa `.\scripts\run-local-api.ps1 -Port 8010` para cambiar el puerto.

## Scripts disponibles en `scripts/`

| Script | Propósito |
|---|---|
| `deploy-local.sh` | Despliegue local o manual. Copia `.env`/`backend/.env` desde los `.example` y levanta el stack (usado con `SECRET_KEY` y `APP_PASSWORD` por variable de entorno). |
| `stack-up.ps1` | Levanta el stack completo en Docker (build + migraciones + seed); admite `-SkipBuild` y `-SkipSeed`. |
| `stack-down.ps1` | Baja los servicios del stack; admite `-Volumes` para además borrar volúmenes. |
| `stack-reset.ps1` | Reset completo, equivalente a bajar con `-v` y volver a levantar. |
| `setup-local.ps1` | Prepara el entorno local sin Docker: crea `.venv`, instala dependencias y genera `backend/.env.local`. |
| `init-local-db.ps1` | Inicializa la base SQLite local y aplica un seed mínimo. |
| `run-local-api.ps1` | Levanta la API en modo local (SQLite, `SIMULATION_MODE=sync`); admite `-Port`. |
| `run-local-csv.sh` | Ejecuta el solver OSeMOSYS leyendo un directorio de CSV, sin Docker, sin base de datos y sin la API; admite `--solver` (`glpk`/`highs`) y `-o`/`--output-dir`. |
| `run-sand-test.ps1` | Corre la prueba de integración con el Excel SAND (hoja `Parameters`) contra el stack ya levantado; admite `-ExcelPath`. |

Existen además otros scripts en `scripts/` (`disk_audit.sh`, `local-db.ps1`, `plot-local-results.ps1`, `result_table_template_seed.sql`, `run-local-excel.ps1`) cuyo detalle de uso no está cubierto por esta guía; revisa su contenido en el repositorio antes de usarlos.

## Referencias relacionadas

Revisa [Runbook](runbook.md) para diagnóstico y respuesta a incidentes una vez el stack está arriba, [CI/CD](ci-cd.md) para el despliegue automatizado en `staging` o `production` y las variables esperadas en GitHub Actions, y [Variables de entorno](../getting-started/environment-variables.md) para el detalle de cada variable.
