# Instalación

Esta página explica cómo levantar OSeMOSYS Colombia por primera vez, ya sea para evaluar la aplicación o para empezar a desarrollar sobre ella. Hay tres caminos posibles. `task` (recomendado), el stack completo con Docker directo, o un modo local sin Docker basado en SQLite.

!!! tip "¿Solo vas a usar la plataforma?"
    Si tu instituto ya tiene una instancia desplegada, no necesitas nada de esta página. Ver [Requisitos y solvers](requisitos.md) para lo que sí necesitas como analista.

## Requisitos previos

Hacen falta [Docker](https://docs.docker.com/get-docker/) y Docker Compose (para el camino recomendado y para Docker directo), [`task`](https://taskfile.dev/) (para el camino recomendado, ver cómo instalarlo abajo), Windows con PowerShell (para el modo local sin Docker) y Node.js 18+ con npm (solo si vas a trabajar en el frontend con recarga en caliente).

## Opción 1. Con `task` (recomendado)

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

Verifica la instalación.

```bash
task --version
```

### Levantar el stack

Desde la raíz del repositorio.

```bash
task up
```

Esto ejecuta build, migraciones y seed en un solo paso (equivalente a los tres comandos de Docker de la Opción 2).

!!! tip "Usuario de prueba"
    Tras `task up` queda disponible el usuario **`seed`** con contraseña **`seed123`**, listo para iniciar sesión en la interfaz web.

Verifica que todo quedó arriba y apaga el stack cuando termines.

```bash
curl http://localhost:8010/api/v1/health
task down            # baja contenedores, conserva volúmenes
```

Luego abre la interfaz web en tu navegador. El **frontend** está en [http://localhost:8080](http://localhost:8080) y la **API** en [http://localhost:8010](http://localhost:8010).


## Opción 2. Stack completo con Docker Compose directo

Si prefieres no instalar `task`, o necesitas ejecutar cada paso por separado (por ejemplo para depurar uno en particular), usa Docker Compose directamente.

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

El primer comando construye y levanta en segundo plano los servicios definidos en `docker-compose.yml`, es decir PostgreSQL, Redis, la API (FastAPI) y el frontend (React servido por nginx). El segundo aplica las migraciones de base de datos con Alembic. El tercero ejecuta el script de siembra (`scripts/seed.py`), que crea datos iniciales y el mismo usuario de prueba (`seed` / `seed123`).

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

## Siguientes pasos

Sigue el tutorial [Primera simulación](first-simulation.md) para iniciar sesión, crear un escenario y ver resultados. Y para tareas de desarrollo, como tests y linters, revisa [Contribuir](../contributing.md).
