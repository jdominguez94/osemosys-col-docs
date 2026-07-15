# Frontend

Interfaz web para el sistema de planificación energética OSeMOSYS. Consume la API FastAPI del backend (ver [Backend](backend.md)) para gestionar escenarios, ejecutar simulaciones y visualizar resultados.

## Stack tecnológico

El stack usa **React 19** para la interfaz, **Vite 7** como build y dev server, **TypeScript** para el tipado estático, **React Router 7** para el enrutamiento con lazy loading, **Recharts** para las gráficas (despacho, capacidad, emisiones, sectores) y **Axios** como cliente HTTP con interceptor JWT.

!!! note "Librería de gráficas"
    El `README` del frontend lista **Recharts** como librería de gráficas del stack. Otra documentación técnica del backend (el flujo de procesamiento de resultados, ver [Motor de simulación OSeMOSYS](motor-osemosys.md#procesamiento-de-resultados-y-visualizacion)) hace referencia a componentes como `HighchartsChart.tsx` y `CompareChart.tsx` basados en **Highcharts**. Esta página documenta ambas menciones tal como aparecen en las fuentes; conviene revisar el `package.json` vigente del frontend para confirmar la librería efectivamente en uso.

## Requisitos

Hace falta **Node.js >= 20.19** (recomendado para ESLint v10) y npm.

## Instalación y ejecución

```bash
npm install
npm run dev
```

Abre `http://localhost:5173` (o el puerto que indique Vite).

## Variables de entorno

Este proyecto usa archivo `.env` (no `.env.example`).

| Variable | Descripción | Ejemplo |
|---|---|---|
| `VITE_API_BASE_URL` | URL base de la API | `http://localhost:8010/api/v1` (dev) o `/api/v1` (producción con proxy) |
| `VITE_SIMULATION_MODE` | Modo de simulación | `api` (endpoints reales) |

El archivo `.env` es la configuración principal del frontend, `.env.development` es para desarrollo local y `.env.production` es el build para producción.

!!! warning "Archivos que no se deben subir al repositorio"
    No deben subirse `.env.local` ni sus variantes locales con credenciales, `node_modules/`, las carpetas `dist/` y `build/` generadas por la compilación, ni los artefactos de backend local en `backend/tmp/` si se trabaja con ambos proyectos en el mismo repo.

## Scripts disponibles

| Script | Descripción |
|---|---|
| `npm run dev` | Servidor de desarrollo (Vite) |
| `npm run build` | Build de producción (TypeScript + Vite) |
| `npm run preview` | Vista previa del build |
| `npm run typecheck` | Verificación de tipos (`tsc`) |
| `npm run lint` | ESLint |
| `npm run format` | Prettier (formatear) |
| `npm run format:check` | Prettier (solo verificar) |

## Estructura de carpetas

```text
src/
├── app/           # Bootstrap, router, providers (Auth, Toast, CurrentUser)
├── routes/       # Rutas, guards (RequireAuth, RequireCatalogManager, etc.)
├── layouts/      # AppLayout (sidebar + header), AuthLayout
├── pages/        # Páginas (lazy loaded)
├── features/     # Módulos por dominio (auth, scenarios, simulation, etc.)
├── shared/       # Componentes, API, errores, storage, hooks
└── types/        # Tipos de dominio (Scenario, SimulationRun, RunResult, etc.)
```

## Características principales

Entre las características principales, el **lazy loading** carga las páginas bajo demanda (división de código), lo que redujo el bundle principal de unos 606 KB a unos 98 KB. El **router está unificado**, con un solo `AppLayout` compartido para todas las rutas protegidas y un enlace "Inicio" en el sidebar. Hay una **barra de progreso de subida**, el componente `UploadProgress`, para la importación de Excel (carga oficial e importación en escenarios). El **modal se cierra con Escape**, gracias al componente `Modal`. Y en los **tipos de simulación**, `SimulationRun` usa `queued_at` (fecha de encolado) en lugar de `created_at`.

## Integración con el backend

La **opción A**, la recomendada, usa un proxy inverso en Nginx con `/api`. Se configura `VITE_API_BASE_URL=/api/v1` y, en Docker Compose, el frontend (Nginx) proxea `/api/*` hacia el backend.

La **opción B** usa la URL absoluta del backend y solo sirve para desarrollo. Se configura `VITE_API_BASE_URL=http://localhost:8010/api/v1` y hay que configurar CORS en FastAPI.

## Levantar stack completo

```bash
# Backend (API + DB + Redis)
cd ../backend
docker compose up --build

# Frontend (dev contra backend Docker)
cd ../frontend
npm install
npm run dev
```

## Build para producción (sin Docker)

```bash
npm run build
npm run preview
```

## Docker (imagen de producción)

```bash
docker build -t osemosys-frontend .
docker run --rm -p 8080:80 osemosys-frontend
```

Abre `http://localhost:8080`.
