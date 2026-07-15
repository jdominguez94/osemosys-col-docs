# Runbook operativo (Task + logs)

Este runbook define una primera respuesta para incidentes comunes usando `task` (go-task) como interfaz principal sobre el stack de Docker Compose.

## Prerrequisitos

Hace falta el stack levantado con Docker Compose en la raíz del repositorio (ver [Despliegue](deployment.md)) y [`go-task`](https://taskfile.dev/) instalado para ejecutar los comandos `task ...`.

## Comandos base

```bash
# Estado general y healthcheck
task health

# Logs agregados
task logs

# Logs por servicio
task logs:api
task logs:worker
task logs:frontend
task logs:db
task logs:redis

# Filtro de errores de los últimos 15 minutos
task logs:errors

# Ventana configurable de logs recientes
task logs:since MIN=30
```

`task health` ejecuta `docker compose ps` y luego un `curl` contra el healthcheck de la API (`http://localhost:8010/api/v1/health`). `task logs:errors` filtra `ERROR`, `Traceback`, `FAILED` y `Exception` sobre los servicios `api`, `simulation-worker`, `frontend`, `db` y `redis`.

!!! note "Servicios afectados por `logs:<servicio>`"
    Los targets de logs por servicio siguen los nombres definidos en `docker-compose.yml`, que son `api`, `simulation-worker` (worker de simulación), `frontend`, `db` y `redis`.

## Troubleshooting

### 1) API no levanta / health falla

1. Ejecuta `task health`.
2. Si el health falla, revisa `task logs:api`.
3. Busca errores recientes con `task logs:errors MIN=30`.
4. Verifica base y cola con `task logs:db` y `task logs:redis`.

### 2) Worker no consume cola

1. Revisa estado con `task health`.
2. Sigue los logs del worker con `task logs:worker`.
3. Correlaciona con la API usando `task logs:api`.
4. Filtra errores con `task logs:errors MIN=60`.

### 3) Simulación queda en FAILED

1. Revisa los logs del worker con `task logs:worker`.
2. Busca el contexto en la API con `task logs:api`.
3. Ejecuta el filtro global con `task logs:errors MIN=60`.
4. Si hay fallas de persistencia o conexión, revisa `task logs:db`.

### 4) Frontend no conecta con API

1. Revisa el estado general con `task health`.
2. Sigue los logs del frontend con `task logs:frontend`.
3. Correlaciona con la API usando `task logs:api`.
4. Filtra errores de proxy o autenticación con `task logs:errors MIN=30`.

## Checklist de triage (menos de 10 minutos)

1. `task health`
2. `task logs:errors MIN=15`
3. `task logs:<servicio_afectado>`
4. `task logs:since MIN=30`

Con estos cuatro pasos deberías tener una hipótesis de causa raíz inicial.

!!! warning "Comandos destructivos fuera de este runbook"
    Este runbook solo cubre observación (health y logs) y no modifica el stack. Para detener servicios o borrar volúmenes (datos de Postgres/Redis), consulta las tareas `down` y `down:volumes` descritas en [Despliegue](deployment.md), que requieren confirmación explícita por su naturaleza irreversible.

## Referencias relacionadas

Revisa [Despliegue](deployment.md) para levantar o reiniciar el stack completo, y [CI/CD](ci-cd.md) para el contexto de despliegue automatizado.
