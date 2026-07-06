# Instalación

Esta página explica cómo levantar OSeMOSYS Colombia por primera vez, ya sea para evaluar la aplicación o para empezar a desarrollar sobre ella. Hay tres caminos: `task` (recomendado), el stack completo con Docker directo, o un modo local sin Docker basado en SQLite.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) y Docker Compose (para el camino recomendado y para Docker directo).
- [`task`](https://taskfile.dev/) (para el camino recomendado — ver cómo instalarlo abajo).
- Windows con PowerShell (para el modo local sin Docker).
- Node.js 18+ y npm (solo si vas a trabajar en el frontend con recarga en caliente).

## Opción 1: Con `task` (recomendado)

[`task`](https://taskfile.dev/) (go-task) es un runner de tareas que el repo ya trae configurado en `Taskfile.yml`, envolviendo los mismos pasos de Docker Compose en comandos cortos.

### Instalar `task`

=== "macOS"

    ```bash
    brew install go-task
    ```

=== "Linux"

    ```bash
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
    ```

=== "Windows"

    ```powershell
    winget install Task.Task
    ```

Verifica la instalación:

```bash
task --version
```

### Levantar el stack

Desde la raíz del repositorio:

```bash
task up
```

Esto ejecuta build, migraciones y seed en un solo paso (equivalente a los tres comandos de Docker de la Opción 2).

!!! tip "Usuario de prueba"
    Tras `task up` queda disponible el usuario **`seed`** con contraseña **`seed123`**, listo para iniciar sesión en la interfaz web.

Verifica que todo quedó arriba y apaga el stack cuando termines:

```bash
curl http://localhost:8010/api/v1/health
task down            # baja contenedores, conserva volúmenes
```

Luego abre la interfaz web en tu navegador:

- **Frontend:** [http://localhost:8080](http://localhost:8080)
- **API:** [http://localhost:8010](http://localhost:8010)

!!! note "Puertos"
    Los puertos indicados son los valores por defecto (`FRONTEND_PORT=8080`, `API_PORT=8010`). Pueden cambiarse mediante variables de entorno — ver [Variables de entorno](environment-variables.md).

## Opción 2: Stack completo con Docker Compose directo

Si prefieres no instalar `task`, o necesitas ejecutar cada paso por separado (por ejemplo para depurar uno en particular), usa Docker Compose directamente:

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

El primer comando construye y levanta en segundo plano los servicios definidos en `docker-compose.yml`: PostgreSQL, Redis, la API (FastAPI) y el frontend (React servido por nginx). El segundo aplica las migraciones de base de datos con Alembic. El tercero ejecuta el script de siembra (`scripts/seed.py`), que crea datos iniciales y el mismo usuario de prueba (`seed` / `seed123`).

### Verificar que todo quedó arriba

```bash
curl http://localhost:8010/api/v1/health
```

Si la respuesta es exitosa, la API está lista. Abre el frontend en [http://localhost:8080](http://localhost:8080).

### Apagar el stack

```bash
docker compose down
```

Esto detiene los contenedores. Los datos de PostgreSQL y Redis quedan conservados en volúmenes Docker (se preservan entre reinicios) salvo que elimines explícitamente los volúmenes.

## Opción 3: Modo local sin Docker (SQLite)

Para un entorno de desarrollo rápido en Windows, sin depender de contenedores, la aplicación ofrece scripts de PowerShell que configuran un backend local con SQLite en modo síncrono:

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Este modo usa el archivo de configuración `backend/.env.local`, con una base de datos SQLite (`DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db`) y `SIMULATION_MODE=sync` (las simulaciones corren de forma síncrona, sin Celery/Redis de por medio).

!!! note "Cuándo usar cada modo"
    Las opciones con Docker (con `task` o directas) son las más fieles a producción y las recomendadas para evaluar la aplicación o simular escenarios reales. El modo local con SQLite es útil para iterar rápido en el backend sin levantar toda la infraestructura, pero no refleja el pipeline asíncrono completo (Celery + Redis).

## Frontend en modo desarrollo

Si necesitas trabajar sobre la interfaz con recarga en caliente (en lugar de la build de producción servida por nginx dentro de Docker):

```bash
cd frontend
npm install
npm run dev
```

## Siguientes pasos

- Sigue el tutorial [Primera simulación](first-simulation.md) para iniciar sesión, crear un escenario y ver resultados.
- Consulta [Variables de entorno](environment-variables.md) para personalizar puertos, credenciales y parámetros de ejecución.
- Para tareas de desarrollo (tests, linters), revisa [Contribuir](../contributing.md).
