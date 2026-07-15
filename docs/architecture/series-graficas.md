# Configuración de series de gráficas

Esta página documenta la parte de desarrollo y administración de la configuración global de series de gráficas. Cubre las tablas involucradas, cómo se relacionan entre sí, el flujo de datos desde la base de datos hasta la gráfica, cómo agregar nuevos tipos de gráfica al sistema, los endpoints de API disponibles y el mapa de archivos clave.

!!! note "Alcance"
    Funcionalidad introducida en los commits `d97ad86` (series globales + plantillas de tablas), `55f23bc` (`is_global` + reordenamiento por arrastre) y `65addb2` (retiro de UI de tablas del informe).

## Tablas involucradas y su estructura

### `osemosys.chart_series_config` (tabla principal)

Tabla que almacena la configuración global de cada serie (nombre, color, orden, visibilidad) por tipo de gráfica y modo de agrupación. Los cambios aquí afectan **todas** las visualizaciones que pasan por `chart_service`, incluidas las gráficas de barras, líneas, tablas y las exportaciones que corren en el servidor.

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | PK, autoincrement | Identificador único |
| `tipo` | String(64), NOT NULL | Clave del tipo de gráfica (ej. `prd_electricidad`, `cap_electricidad`, `emisiones_total`). Debe coincidir con una key en `CONFIGS` o `CONFIGS_COMPARACION` |
| `agrupar_por` | String(32), NOT NULL | Modo de agrupación (`TECNOLOGIA`, `FUEL`, `GROUP`, `SECTOR`, `EMISION`, `REGION`, `H2_PRODUCCION`, `TRANSPORTE_GRUPO`, `YEAR`) |
| `series_code` | String(512), NOT NULL | Código de la serie tal como aparece en la columna `COLOR` del DataFrame en `chart_service.py` (ej. `PWRCOA`, `Gas Natural`, `Transporte`) |
| `display_name` | String(512), NOT NULL | Nombre visible en leyendas, tooltips y tablas |
| `color` | String(32), nullable | Color hex (ej. `#4472c4`). Si es null, se usa el color por defecto de `colors.py` |
| `hidden` | Boolean, default false | Si true, la serie se excluye de la gráfica |
| `is_global` | Boolean, default false | Si true, aplica color/nombre/visibilidad en **cualquier** tipo de gráfica donde aparezca el mismo `series_code` |
| `sort_index` | Integer, default 0 | Orden de apilamiento; menor = primero (abajo en barras apiladas) |
| `group_key` | String(255), nullable | Grupo lógico informativo (ej. familia de tecnología, como "Solar" o "Hidro") |
| `notes` | Text, nullable | Notas internas del administrador |
| `created_at`, `updated_at` | DateTime | Timestamps automáticos |

!!! warning "Restricciones"
    La restricción única es `(tipo, agrupar_por, series_code)`, así que no puede haber dos filas con el mismo código de serie para el mismo par tipo y agrupación. El índice compuesto `(tipo, agrupar_por, sort_index)` acelera las consultas ordenadas.

El modelo ORM vive en `backend/app/models/chart_series_config.py`.

### `osemosys.result_table_template` (plantilla de tabla, backend activo, UI deshabilitada)

Define plantillas de tablas automáticas para la página de resultados. El backend, la API y las migraciones siguen activos, pero **la UI fue removida** en el commit `65addb2` (pestaña "Tablas en resultados" en Reportes y sección "Tablas del informe" en ResultDetail). El componente `ResultTablesAdminTab.tsx` existe pero no está montado en ninguna página.

Estas son las columnas clave.

| Columna | Descripción |
|---|---|
| `name` | Nombre corto en administración |
| `seed_key` | Clave estable para siembra idempotente (Alembic/seed). Null = creado en admin |
| `display_title` | Título sobre la tabla; null → usa título del chart-data |
| `sort_order`, `is_enabled` | Orden y visibilidad para usuarios |
| `tipo`, `un`, `sub_filtro`, `loc`, `variable`, `agrupar_por`, `region`, `timeslice` | Parámetros equivalentes al selector de gráficas |
| `table_period_years`, `table_cumulative` | Opciones de vista tabla |
| `custom_series_order` (JSONB), `y_axis_min`, `y_axis_max` | Presentación adicional |
| `created_by_user_id` | FK a `core.user` |

El modelo ORM vive en `backend/app/models/result_table_template.py`.

Las **semillas iniciales** (`backend/app/result_table_seeds.py`) son cuatro plantillas del sector eléctrico (`default_elec_produccion`, `default_prd_electricidad`, `default_cap_electricidad`, `default_factor_planta`).

### `osemosys.result_table_template_column`

Reglas de presentación por columna (categoría/año) de una plantilla de tabla. Hijo de `result_table_template` vía FK `template_id` (CASCADE on delete).

| Columna | Descripción |
|---|---|
| `template_id` | FK a `result_table_template.id` |
| `category_key` | Valor de categoría (p. ej. año como string `"2030"`) |
| `hidden` | Ocultar columna |
| `sort_order` | Orden manual de columnas |

La restricción única es `(template_id, category_key)`.

El modelo ORM vive en `backend/app/models/result_table_template_column.py`.

!!! note "Nota histórica"
    Existió `result_table_template_series` (reglas por serie a nivel de plantilla). Fue migrada a `chart_series_config` y eliminada en la migración `20260519_0027`. Las series ahora se gestionan de forma unificada en `chart_series_config`.

## Relaciones entre tablas

| Relación | Descripción |
|---|---|
| `chart_series_config.tipo` → `CONFIGS` / `CONFIGS_COMPARACION` | Referencia lógica (sin FK físico) a las claves de los diccionarios de configuración |
| `chart_series_config` ↔ `result_table_template` | **Independientes**. No hay FK entre ellas. Ambas usan `tipo` como clave lógica común |
| `result_table_template` → `result_table_template_column` | Relación uno a muchos, con cascade delete |
| Series en tablas | Provienen de `chart_series_config` vía `build_chart_data`, no de reglas por plantilla |

### Separación de responsabilidades

| Concern | Dónde vive |
|---|---|
| Qué chart mostrar (tipo, un, filtros, agrupación) | `result_table_template` |
| Orden/color/oculto de **series** (filas) | `chart_series_config` (global, aplicado en `build_chart_data`) |
| Orden/oculto de **columnas** (años) | `result_table_template_column` |
| Datos numéricos | `/visualizations/{job_id}/chart-data` |
| Render tabla | `ChartDataTable.tsx` |

## Cómo `chart_series_config` afecta el flujo de datos hacia las gráficas

1. El usuario pide chart-data (`GET /visualizations/{job_id}/chart-data?tipo=X`).
2. `chart_service.build_chart_data()` recibe la petición.
3. Carga datos de `osemosys_output_param_value`.
4. Filtra, agrupa, calcula `COLOR` y `VALUE`.
5. Calcula colores por defecto vía `colors.py`.
6. Llama a `apply_global_series_config(db, tipo, agrupar_por, ...)`.
7. Si hay filas en `chart_series_config` para ese tipo y agrupación, filtra las series ocultas (`hidden=true`), reordena por `sort_index` y aplica el override de color y nombre. Si no hay filas, devuelve el orden y los colores por defecto.
8. Se construye la respuesta `ChartDataResponse` (categories, series con nombre/color aplicado).
9. El frontend renderiza Highcharts / `ChartDataTable` / export.

### Detalle de `apply_global_series_config()`

Vive en `backend/app/services/chart_series_config_service.py` (aproximadamente en la línea 565).

El algoritmo funciona así.

1. Carga filas **locales** para el par `(tipo, agrupar_por)`.
2. Carga filas **globales** (`is_global=true`) indexadas por `series_code` (una entrada por código; gana la primera por `id`).
3. Para cada serie en `orden_color`, la fila local gana sobre la fila global del mismo `series_code`. Si `hidden=true`, la serie se excluye. Si tiene `color`, sobreescribe el color por defecto. Y si tiene `display_name`, sobreescribe la etiqueta, usando `get_label()` como respaldo.
4. Reordena las series. Las que tienen fila de configuración van primero (por `sort_index`, luego por índice original), y el resto mantiene el orden original al final.
5. Retorna `list[tuple[code, color, display_name]]`.

### Puntos de invocación en `chart_service.py`

| Función | Contexto |
|---|---|
| `_build_factor_planta_data()` | Gráfica factor de planta (~línea 864) |
| `build_chart_data()` | Ruta principal single-escenario (~línea 1276) |
| `build_comparison_data()` | Comparación multi-escenario por año (~línea 1549) |

La cobertura indirecta viene de `build_comparison_facet_data()`, que llama a `build_chart_data()` por job y así hereda la config.

!!! warning "Rutas que aún NO aplican `apply_global_series_config`"
    `build_comparison_data_by_year_alt` usa un orden `sorted` sin config admin, y `build_comparison_line_data` trabaja con totales por escenario, sin desglose por serie.

## Cómo agregar nuevas gráficas al sistema

El `tipo` debe existir en **tres capas** para funcionar de punta a punta. Necesita estar en `CONFIGS` (backend) para que funcione el chart-data, en el `MENU` del `ChartSelector` (frontend) para que aparezca en el selector y, opcionalmente, en `chart_series_config` para colores, nombres y orden admin.

### Paso 1. Definir la config en `CONFIGS` (backend)

En `backend/app/visualization/configs.py`, agrega una entrada al diccionario `CONFIGS`, como esta.

```python
"mi_nueva_grafica": {
    "titulo": "Mi Nueva Gráfica - ProductionByTechnology",
    "figura": "Figura XX",
    "filename": "Fig_XX_MiGrafica",
    "print": "MI NUEVA GRÁFICA",
    "filtro": _filtro_mi_nueva,          # función que filtra el DataFrame
    "msg_sin_datos": "Sin datos para ...",
    "agrupar_por": "TECNOLOGIA",         # o FUEL, SECTOR, EMISION, etc.
    "color_fn": generar_colores_tecnologias,
    "variable_default": "ProductionByTechnology",
}
```

Estas son las opciones adicionales frecuentes.

| Campo | Uso |
|---|---|
| `tiene_sub_filtro`, `label_sub_filtro` | Subfiltros en el selector |
| `es_capacidad` | Títulos dinámicos por variable de capacidad |
| `es_emision`, `es_emision_kt` | Unidades y conversión de emisiones |
| `es_porcentaje` | Eje Y en % |
| `allowedGroupings` (solo frontend) | Restringir agrupaciones en UI |

Si la gráfica necesita registro en el catálogo de BD (admin curador), agregar también en `backend/app/visualization/chart_menu.py` dentro de `MENU`. El startup ejecuta `catalog_sync.sync_catalog()` con INSERT idempotente (no pisa ediciones del curador).

### Paso 2. Agregar al menú del frontend

En `frontend/src/shared/charts/ChartSelector.tsx`, localiza la estructura `MENU` y agrega un `ChartItem` en el módulo o subsector correcto, como este.

```typescript
{ id: 'mi_nueva_grafica', label: 'Mi nueva gráfica', soportaPareto: false },
```

Estas son opciones útiles.

```typescript
allowedGroupings: ['TECNOLOGIA', 'FUEL'],
defaultGrouping: 'TECNOLOGIA',
soportaPareto: true,
soportaTabla: true,
hasSub: true,
subFiltros: ['NGS', 'COA'],
```

!!! note "El menú del frontend es independiente"
    El `MENU` del frontend es **independiente** del `chart_menu.MENU` del backend. Pueden divergir (ej. frontend tiene más variantes eléctricas, módulo `recursos`, upstream con subsectores). Lo crítico es que el `id` del `ChartItem` coincida con la key en `CONFIGS`.

### Paso 3 (opcional). Definir config de comparación

En `backend/app/visualization/configs_comparacion.py`, si se quiere comparar entre escenarios, agrega algo así.

```python
"mi_nueva_grafica": {
    "prefijo": "MITECH",
    "agrupacion_default": "TECNOLOGIA",
    "variable_default": "ProductionByTechnology",
},
```

### Paso 4. Poblar series en `chart_series_config`

Se puede hacer vía API.

```http
POST /api/v1/chart-series-config/populate
Content-Type: application/json

{
  "tipo": "mi_nueva_grafica",
  "agrupar_por": "TECNOLOGIA"
}
```

Para poblar todos los tipos a la vez.

```http
POST /api/v1/chart-series-config/populate-all
```

La población es **no destructiva**. Solo inserta las filas faltantes y no modifica las existentes. (El flujo equivalente desde la interfaz de administración, en la pestaña "Series por gráfica" de Reportes, está documentado para el usuario final en la guía de uso de la aplicación.)

### Reglas de prioridad (local vs global)

```text
1. Fila LOCAL (tipo + agrupar_por + series_code)  →  prioridad máxima
2. Fila GLOBAL (is_global=true, mismo series_code)  →  si no hay local
3. Valores por defecto (colors.py + labels.py)  →  si no hay ninguna fila
```

Por ejemplo, si `PWRCOA` tiene color rojo con `is_global=true` en `cap_electricidad`, ese color aplica también en `prd_electricidad`, **salvo** que exista una fila local específica para `prd_electricidad` + `TECNOLOGIA` + `PWRCOA`.

## API REST disponible

El prefijo es `/api/v1/chart-series-config`.

El router vive en `backend/app/api/v1/chart_series_config.py`.

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/chart-types` | Lista tipos disponibles (`CONFIGS` ∪ `CONFIGS_COMPARACION`) |
| GET | `?tipo=X&agrupar_por=Y` | Filas configuradas para un tipo+agrupación |
| POST | `/populate` | Inserta filas faltantes desde catálogo para un tipo |
| POST | `/populate-all` | Inserta filas faltantes para **todos** los tipos → `{ inserted_rows }` |
| POST | `/row` | Crear fila manual (201) |
| PATCH | `/{id}` | Actualizar `display_name`, `color`, `hidden`, `is_global`, `sort_index`, `group_key` |
| DELETE | `/{id}` | Eliminar fila (204) |
| POST | `/reorder` | Reordenar filas (body con `{ "ids": [3, 1, 2, ...] }`) |

Todos los endpoints requieren autenticación + permiso admin reportes.

### API relacionada (plantillas de tabla, backend activo)

El prefijo es `/api/v1/result-table-templates`.

| Método | Ruta | Acceso |
|---|---|---|
| GET | `` | Plantillas habilitadas (todos autenticados) |
| GET | `/manage` | Admin, todas las plantillas |
| GET | `/presentation-options?tipo=&agrupar_por=&variable=` | Admin, candidatos de series y años (usado por autocompletado en `ChartSeriesConfigTab`) |
| POST/PATCH/DELETE | CRUD estándar | Admin |

## Migraciones Alembic relacionadas

| Revisión | Archivo | Operación |
|---|---|---|
| `20260515_0022` | `result_table_template.py` | Crea `result_table_template` |
| `20260516_0023` | `result_table_presentation_relational.py` | Tablas series/column; migra JSONB → relacional |
| `20260517_0024` | `result_table_template_seed_key.py` | `seed_key` + siembra inicial |
| `20260518_0026` | `chart_series_config.py` | **Crea `chart_series_config`** |
| `20260519_0027` | `drop_result_table_series_rules.py` | Migra `result_table_template_series` → `chart_series_config`; elimina tabla legacy |
| `20260519_0028` | `chart_series_config_is_global.py` | **Agrega columna `is_global`** |

Para desplegar.

```bash
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed.py   # plantillas seed + permisos usuario seed
```

## Archivos clave del sistema

### Backend

| Archivo | Rol |
|---|---|
| `backend/app/models/chart_series_config.py` | Modelo SQLAlchemy |
| `backend/app/schemas/chart_series_config.py` | Schemas Pydantic (Public, Create, Update) |
| `backend/app/services/chart_series_config_service.py` | CRUD, población, `apply_global_series_config()` |
| `backend/app/api/v1/chart_series_config.py` | Endpoints REST |
| `backend/app/visualization/chart_service.py` | Invoca `apply_global_series_config()` al construir respuestas |
| `backend/app/visualization/configs.py` | Diccionario `CONFIGS` (~60 gráficas single-escenario) |
| `backend/app/visualization/configs_comparacion.py` | Diccionario `CONFIGS_COMPARACION` |
| `backend/app/visualization/colors.py` | Colores por defecto (familias, sectores, emisiones) |
| `backend/app/visualization/labels.py` | Etiquetas por defecto (`get_label`) |
| `backend/app/visualization/chart_menu.py` | `MENU` para siembra en catálogo BD |
| `backend/app/visualization/catalog_sync.py` | Sync idempotente al startup |
| `backend/app/models/result_table_template.py` | Plantillas de tabla (backend) |
| `backend/app/services/result_table_template_service.py` | CRUD plantillas |
| `backend/app/services/result_table_presentation_options.py` | Candidatos series/años para admin |
| `backend/app/result_table_seeds.py` | Semillas idempotentes |
| `backend/tests/test_chart_series_config.py` | Tests unitarios (local vs global) |

### Frontend

| Archivo | Rol |
|---|---|
| `frontend/src/features/reports/components/ChartSeriesConfigTab.tsx` | UI admin de series (arrastrar y soltar, global, populate) |
| `frontend/src/features/reports/api/chartSeriesConfigApi.ts` | Cliente API |
| `frontend/src/features/reports/api/resultTableTemplatesApi.ts` | Cliente API (presentation-options para autocompletado) |
| `frontend/src/features/reports/components/ResultTablesAdminTab.tsx` | Admin plantillas tablas (**sin montar en UI actual**) |
| `frontend/src/types/domain.ts` | Tipos `ChartSeriesConfigPublic`, `ChartTypeInfo` |
| `frontend/src/pages/ReportsPage.tsx` | Pestaña "Series por gráfica" |
| `frontend/src/pages/ResultDetailPage.tsx` | Botón "Configurar series" + modal |
| `frontend/src/shared/charts/ChartSelector.tsx` | `MENU` del selector (3 niveles) |
| `frontend/src/shared/charts/ChartDataTable.tsx` | Vista tabla (acepta `presentation` para columnas) |

## Estado actual de la UI (post `65addb2`)

| Funcionalidad | Estado |
|---|---|
| Series por gráfica (Reportes) | Activo |
| Configurar series (ResultDetail) | Activo |
| Vista tabla manual (`viewMode=table`) | Activo |
| Arrastrar y soltar + checkbox Global | Activo |
| Tablas en resultados (Reportes) | **Removido de UI** |
| Tablas del informe (ResultDetail) | **Removido de UI** |
| Backend `result_table_templates` | Activo (reactivable) |

Ver también [Motor de simulación OSeMOSYS](motor-osemosys.md) para el resto del pipeline de procesamiento y visualización de resultados, y [Backend](backend.md) para la estructura general del proyecto.
