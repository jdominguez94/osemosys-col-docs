# Pruebas E2E de integración (backend + frontend)

Esta guía deja el entorno listo para probar la integración real entre `frontend` y `backend` (FastAPI) de punta a punta, ejecutando **todo en Docker**.

!!! note "Backend local sin Docker"
    Para un flujo de backend local sin Docker (SQLite, ejecución síncrona), ver [Despliegue — Alternativa local sin Docker](deployment.md#alternativa-local-sin-docker-sqlite).

## 1. Prerrequisitos

- Docker Desktop (o Docker Engine + Docker Compose).

### 1.1 Archivos de entorno (`.env`)

Antes de levantar el stack, verifica que existan estos archivos:

- `.env` (raíz)
- `backend/.env`
- `frontend/.env`

Si tienes archivos antiguos `*.env.example`, elimínalos y usa solo los `.env`.

### 1.2 Artefactos locales que no se suben

Al ejecutar flujos locales o pruebas de paridad se generan archivos temporales que no deben ir al repositorio. Rutas típicas:

- `backend/tmp/local/` (SQLite, JSON, CSV, charts y exportaciones de tablas)
- `backend/tmp/simulation-results/` (artefactos por job)
- `backend/tmp/local/parity/` y `backend/tmp/local/comparison_csvs/` (comparaciones CLI vs Docker/notebook)

Todos estos artefactos están cubiertos por `.gitignore`.

!!! tip "Antes de commitear"
    Valida siempre con `git status` antes de hacer commit para asegurarte de que ningún artefacto temporal se cuele.

## 2. Quickstart PowerShell (todo en Docker)

Desde la raíz del repo:

```powershell
.\scripts\stack-up.ps1
```

Healthcheck rápido:

```powershell
Invoke-RestMethod http://localhost:8010/api/v1/health
```

### 2.1 Quickstart PowerShell sin Docker (SQLite local)

Desde la raíz del repo:

```powershell
.\scripts\setup-local.ps1
.\scripts\init-local-db.ps1
.\scripts\run-local-api.ps1
```

Con este flujo:

- se crea `.venv`;
- se instalan dependencias de `backend/requirements.txt`;
- se genera `backend/.env.local` (si no existe);
- se inicializa SQLite local y seed mínimo (`seed/seed123`);
- la API queda en `http://localhost:8000` (`/docs`).

Notas:

- En modo local sin Docker, la simulación corre en modo síncrono (`SIMULATION_MODE=sync`) y no requiere Redis/Celery worker.
- Si quieres cambiar puerto: `.\scripts\run-local-api.ps1 -Port 8010`.

### 2.2 Simulación solo con CSV (Linux/macOS/WSL)

Este flujo ejecuta el solver OSeMOSYS leyendo un directorio de CSV ya generados y procesados (mismo formato que espera el `DataPortal` del backend: `REGION.csv`, `TECHNOLOGY.csv`, `YEAR.csv`, parámetros, etc.). **No usa Docker, ni base de datos, ni la API**; solo Python y las dependencias del backend.

**Prerrequisitos**

- Python 3.11 o superior (`python3 --version`).
- Directorio de CSV listos para simular (por ejemplo exportados tras el pipeline completo, o generados con la misma lógica que el notebook / `compare_notebook_vs_app`). Si faltan pasos de procesamiento (matrices completas, sets coherentes), la corrida puede fallar o dar resultados inconsistentes.

**Comandos previos (una vez por clon del repositorio)**, desde la raíz del repo:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r backend/requirements.txt
```

**Ejecutar la simulación** con el wrapper (recomendado en Linux/macOS; asegúrate de que el script sea ejecutable: `chmod +x scripts/run-local-csv.sh`):

```bash
./scripts/run-local-csv.sh /ruta/al/directorio_con_csvs --solver glpk -o /ruta/salida
```

Equivalente con HiGHS:

```bash
./scripts/run-local-csv.sh /ruta/al/directorio_con_csvs --solver highs -o /ruta/salida
```

Sin el wrapper (mismo comportamiento; ejecutar con el `python` del venv):

```bash
cd backend
../.venv/bin/python scripts/run_osemosys_cli.py csv /ruta/al/directorio_con_csvs --solver glpk --output-dir /ruta/salida
```

Ayuda integrada del CLI (`csv`):

```bash
cd backend
../.venv/bin/python scripts/run_osemosys_cli.py csv -h
```

Opciones habituales: `--solver` (`glpk` o `highs`), `--output-dir`/`-o` (exporta CSV y `simulation_result.json`; por defecto crea una subcarpeta `run_YYYYMMDD_HHMMSS` dentro de la ruta indicada), `--overwrite` (escribe directamente en `-o` sin subcarpeta con timestamp), `--lp` (genera archivo `.lp` del modelo), `--lp-dir`, `--lp-name`.

Referencia: detalle del módulo de simulación y la API en Python en `backend/app/simulation/README.md`.

## 3. Levantar stack completo (Docker)

Desde la raíz del repo:

```bash
./scripts/stack-up.ps1
```

Verifica salud:

```bash
curl http://localhost:8010/api/v1/health
```

Swagger: `http://localhost:8010/docs`

Abre:

- Frontend: `http://localhost:8080`
- Swagger backend: `http://localhost:8010/docs`

## 4. Usuarios de prueba

### 4.1 Usuario base para login

Creado por `scripts/seed.py`:

- username: `seed`
- email: `seed@example.com`
- password: `seed123`
- `can_manage_catalogs`: `true`

### 4.2 (Opcional) Crear usuario sin permisos de catálogo (para probar 403)

Desde la raíz (o cualquier ruta dentro del repo):

```bash
docker compose exec api python -c "from sqlalchemy import select; from app.db.session import SessionLocal; from app.models import User, DocumentType; from app.core.security import get_password_hash; s=SessionLocal(); dt=s.execute(select(DocumentType).where(DocumentType.code=='CC')).scalar_one(); u=s.execute(select(User).where(User.username=='seed_no_catalog')).scalar_one_or_none(); \
u or s.add(User(email='seed_no_catalog@example.com', username='seed_no_catalog', hashed_password=get_password_hash('seed123'), document_number='9876543210', document_type_id=dt.id, is_active=True, can_manage_catalogs=False)); s.commit(); s.close(); print('ok')"
```

Versión PowerShell (desde `backend`):

```powershell
docker compose exec api python -c "from sqlalchemy import select; from app.db.session import SessionLocal; from app.models import User, DocumentType; from app.core.security import get_password_hash; s=SessionLocal(); dt=s.execute(select(DocumentType).where(DocumentType.code=='CC')).scalar_one(); u=s.execute(select(User).where(User.username=='seed_no_catalog')).scalar_one_or_none(); u or s.add(User(email='seed_no_catalog@example.com', username='seed_no_catalog', hashed_password=get_password_hash('seed123'), document_number='9876543210', document_type_id=dt.id, is_active=True, can_manage_catalogs=False)); s.commit(); s.close(); print('ok')"
```

Usuario creado:

- username: `seed_no_catalog`
- password: `seed123`
- `can_manage_catalogs`: `false`

## 5. Prueba SAND (Excel Parameters)

Para ejecutar la prueba con el Excel SAND (hoja **Parameters**) y dejar el resultado listo para comparar con el notebook Jupyter:

1. Levantar el stack (si no está levantado):

    ```powershell
    .\scripts\stack-up.ps1
    ```

2. Ejecutar la prueba (desde la raíz del repo):

    ```powershell
    .\scripts\run-sand-test.ps1
    ```

    Si el Excel está en otra ruta:

    ```powershell
    .\scripts\run-sand-test.ps1 -ExcelPath "C:\ruta\al\SAND_04_02_2026.xlsm"
    ```

El script copia el Excel al contenedor, importa la hoja Parameters, ejecuta la simulación (solver `glpk`) y copia el resultado al host en `backend/tmp/sand_04_02_2026_result.json`.

**Timeslices**: en la aplicación web, la opción "Agregar/colapsar timeslices" viene activada por defecto (mismo criterio que antes). Si la desactivas al importar desde Excel, se conservan los timeslices del archivo; valida el escenario ejecutando una simulación. En CLI local, `backend/scripts/run_sand_excel_test.py` admite `--preserve-timeslices` para el mismo efecto.

Para comparar con el notebook: usar el mismo Excel, hoja Parameters y solver `glpk` en el notebook; luego comparar métricas (`objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio`) o usar `compare_results.py` como se indica en `backend/docs/OSEMOSYS_PARIDAD.md`.

## 6. Checklist de prueba funcional desde UI

### A. Login

1. Ir a `/login`.
2. Ingresar `seed` / `seed123`.
3. Resultado esperado: entra a la app y no redirige de vuelta a login.

### B. Escenarios

1. Ir a `Escenarios`.
2. Crear escenario nuevo.
3. Resultado esperado: aparece en la tabla.

### C. Valores por escenario

1. Abrir un escenario.
2. Crear un valor (campos `id_parameter`, `id_region`, `id_solver`, `year`, `value`; opcionales según aplique).
3. Editar un valor existente.
4. Resultado esperado: operaciones exitosas y lista actualizada.

### D. Solicitudes de cambio

1. En detalle de escenario, crear una solicitud de cambio sobre un valor.
2. Ir a `Solicitudes de cambio`.
3. Aprobar o rechazar una solicitud pendiente (si tienes permisos).
4. Resultado esperado: cambia estado y, al aprobar, el valor queda aplicado.

### E. Catálogos (usuario manager)

1. Con `seed` (manager), entrar a `Catálogos`.
2. Crear, editar y desactivar un registro.
3. Resultado esperado: operaciones exitosas.

### F. Catálogos (usuario sin permiso)

1. Cerrar sesión.
2. Login con `seed_no_catalog`.
3. Resultado esperado:
    - no aparece menú de `Catálogos`;
    - si navegas manualmente a `/app/catalogs`, redirige a escenarios;
    - backend responde `403` para create/update/delete de catálogos.

### G. Simulaciones OSeMOSYS (real)

1. Ir a `Simulación`.
2. Seleccionar escenario y ejecutar.
3. Verificar estado `QUEUED` → `RUNNING` → `SUCCEEDED` (o `FAILED`) y progreso.
4. Abrir logs del job desde la tabla.
5. Ir a `Resultados`, abrir el detalle y verificar KPIs/series.

## 7. Pruebas API rápidas (opcional)

### Login y token

```bash
curl -X POST "http://localhost:8010/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=seed&password=seed123"
```

Guarda `access_token` y prueba:

```bash
curl "http://localhost:8010/api/v1/users/me" \
  -H "Authorization: Bearer <TOKEN>"
```

Versión PowerShell:

```powershell
$login = Invoke-RestMethod -Method Post -Uri "http://localhost:8010/api/v1/auth/login" -ContentType "application/x-www-form-urlencoded" -Body "username=seed&password=seed123"
$token = $login.access_token
Invoke-RestMethod -Method Get -Uri "http://localhost:8010/api/v1/users/me" -Headers @{ Authorization = "Bearer $token" }
```

## 8. Apagar / limpiar entorno

```bash
./scripts/stack-down.ps1
```

!!! danger "Reinicio limpio: borra datos"
    `./scripts/stack-reset.ps1` hace un reinicio limpio que **borra los datos de Postgres/Redis**. Úsalo solo cuando quieras empezar de cero.

    ```bash
    ./scripts/stack-reset.ps1
    ```

### 8.1 Scripts disponibles (PowerShell)

Desde la raíz del repo:

```powershell
# Levantar todo + migraciones + seed
.\scripts\stack-up.ps1

# Levantar sin rebuild
.\scripts\stack-up.ps1 -SkipBuild

# Levantar sin seed
.\scripts\stack-up.ps1 -SkipSeed

# Bajar servicios
.\scripts\stack-down.ps1

# Bajar + borrar volúmenes
.\scripts\stack-down.ps1 -Volumes

# Reset completo (down -v + up)
.\scripts\stack-reset.ps1
```

### Si falla por "port is already allocated" (ej. 5432)

En PowerShell (desde raíz), usa otro puerto para Postgres host:

```powershell
$env:POSTGRES_PORT=5433
.\scripts\stack-up.ps1
```

Frontend y backend siguen igual:

- Frontend: `http://localhost:8080`
- API: `http://localhost:8010`

## 9. Notas de integración actuales

- El frontend corre en Nginx (contenedor `frontend`) y hace proxy de `/api/*` hacia `api:8000`.
- El frontend consume backend real bajo `/api/v1`.
- En Docker, el build del frontend toma variables desde `frontend/.env` y/o `frontend/.env.production` (según Vite).
- Autorización JWT se adjunta automáticamente en todas las requests.
- Si backend responde `401`, la app hace logout y redirecciona a `/login`.
- `Simulación/Resultados` usa endpoints reales (`/simulations`, `/simulations/{id}/logs`, `/simulations/{id}/result`).

## Referencias relacionadas

- [Despliegue](deployment.md) para el procedimiento formal de puesta en marcha del stack.
- [Runbook](runbook.md) para diagnóstico si algo falla durante las pruebas.
