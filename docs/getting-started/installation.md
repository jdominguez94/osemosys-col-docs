# Instalación

Esta página explica cómo levantar OSeMOSYS UPME por primera vez, ya sea para evaluar la aplicación o para empezar a desarrollar sobre ella. Hay dos caminos: el stack completo con Docker (recomendado) o un modo local sin Docker basado en SQLite.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) y Docker Compose (para el camino recomendado).
- Windows con PowerShell (para el modo local sin Docker).
- Node.js 18+ y npm (solo si vas a trabajar en el frontend con recarga en caliente).

## Opción 1: Stack completo con Docker (recomendado)

Este es el camino recomendado tanto para evaluar la aplicación como para un primer contacto de desarrollo, ya que levanta los cuatro servicios (base de datos, caché/broker, API y frontend) exactamente como en producción.

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py
```

El primer comando construye y levanta en segundo plano los servicios definidos en `docker-compose.yml`: PostgreSQL, Redis, la API (FastAPI) y el frontend (React servido por nginx). El segundo aplica las migraciones de base de datos con Alembic. El tercero ejecuta el script de siembra (`scripts/seed.py`), que crea datos iniciales y un usuario de prueba:

!!! tip "Usuario de prueba"
    Tras ejecutar `scripts/seed.py` queda disponible el usuario **`seed`** con contraseña **`seed123`**, listo para iniciar sesión en la interfaz web.

### Verificar que todo quedó arriba

```bash
curl http://localhost:8010/api/v1/health
```

Si la respuesta es exitosa, la API está lista. Luego abre la interfaz web en tu navegador:

- **Frontend:** [http://localhost:8080](http://localhost:8080)
- **API:** [http://localhost:8010](http://localhost:8010)

!!! note "Puertos"
    Los puertos indicados son los valores por defecto (`FRONTEND_PORT=8080`, `API_PORT=8010`). Pueden cambiarse mediante variables de entorno — ver [Variables de entorno](environment-variables.md).

### Apagar el stack

```bash
docker compose down
```

Esto detiene los contenedores. Los datos de PostgreSQL y Redis quedan conservados en volúmenes Docker (se preservan entre reinicios) salvo que elimines explícitamente los volúmenes.

## Opción 2: Modo local sin Docker (SQLite)

Para un entorno de desarrollo rápido en Windows, sin depender de contenedores, la aplicación ofrece scripts de PowerShell que configuran un backend local con SQLite en modo síncrono:

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Este modo usa el archivo de configuración `backend/.env.local`, con una base de datos SQLite (`DATABASE_URL=sqlite:///./tmp/local/osemosys_local.db`) y `SIMULATION_MODE=sync` (las simulaciones corren de forma síncrona, sin Celery/Redis de por medio).

!!! note "Cuándo usar cada modo"
    El modo Docker es el más fiel a producción y el recomendado para evaluar la aplicación o simular escenarios reales. El modo local con SQLite es útil para iterar rápido en el backend sin levantar toda la infraestructura, pero no refleja el pipeline asíncrono completo (Celery + Redis).

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
