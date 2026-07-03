# Visualizaciones y reportes

Una vez que una simulación termina exitosamente, sus resultados se exploran mediante un conjunto de gráficas interactivas. Esta página cubre cómo elegir y personalizar una gráfica, cómo comparar varios escenarios entre sí, cómo guardar configuraciones para reutilizarlas, cómo ensamblar y exportar reportes, y cómo personalizar la apariencia de las series (nombres, colores, orden) desde la interfaz.

## Abrir los resultados de una simulación

Desde una simulación finalizada, entra a la página de resultados. Ahí encontrarás un resumen con indicadores clave del escenario resuelto y, debajo, el selector de gráficas.

## Elegir qué visualizar

El selector de gráficas te permite elegir:

- **Qué variable** graficar (producción, capacidad instalada, emisiones, demanda no cubierta, factor de planta, etc.), organizada por módulo/subsector.
- **La unidad** de medida (por ejemplo, PJ, GW, MW, TWh, según la variable).
- **La agrupación** de las series: por tecnología, por combustible, por sector, por grupo de transporte o por región (esta última solo disponible en escenarios simulados en modo regional).
- Para escenarios regionales, un filtro adicional por **región** del Sistema Interconectado Nacional.
- Cuando el resultado tiene más de un timeslice, un selector de **timeslice** específico (por defecto se muestra la agregación anual).

!!! tip "No todas las gráficas admiten todas las opciones"
    Algunas gráficas tienen la agrupación o la unidad fijas (por ejemplo, las de emisiones de contaminantes usan una unidad fija; las de factor de planta se muestran siempre en porcentaje y sin selector de agrupación). Esto es intencional — la aplicación oculta las opciones que no aplican a esa gráfica en particular.

## Tipos de vista

Cada gráfica puede mostrarse en distintos modos de visualización:

| Vista | Descripción |
|-------|-------------|
| **Columnas (barras apiladas)** | Vista por defecto para la mayoría de gráficas; todos los años en el eje X, series apiladas. Soporta orientación vertical u horizontal. |
| **Línea** | Cada serie como una línea a lo largo de los años. Soporta series sintéticas superpuestas (ver más abajo). |
| **Área** | Igual que línea, pero con relleno de área bajo la curva. También soporta series sintéticas. |
| **Pareto** | Barras por categoría junto con una línea de porcentaje acumulado (eje Y secundario). Solo disponible en las gráficas que lo soportan explícitamente. |
| **Tabla** | Matriz de categorías × años en formato de tabla, con opciones de agregación por periodo y valores acumulados. |

## Comparación entre escenarios

Además de ver un escenario a la vez, puedes comparar hasta **10 escenarios simultáneamente**. Existen cuatro modos de comparación:

| Modo | Cómo se organiza |
|------|--------------------|
| **Facetas** (`facet`) | Una gráfica completa e independiente por cada escenario, una junto a otra. |
| **Por año** (`by-year`, modo por defecto) | Un panel por año, con los escenarios como categorías dentro de cada panel. |
| **Por año (alterno)** (`by-year-alt`) | Un panel por escenario, con los años seleccionados como categorías dentro de cada panel. |
| **Líneas totales** (`line-total`) | Una sola línea por escenario, mostrando el total anual sin desglose por serie — útil para comparar magnitudes agregadas de un vistazo. |

!!! tip "Elige el modo según la pregunta que quieras responder"
    Si quieres ver cómo se compone cada escenario internamente, usa facetas o "por año". Si solo te interesa comparar una magnitud total entre escenarios (por ejemplo, costo total o emisiones totales), "líneas totales" suele ser más claro.

## Series sintéticas (superposiciones manuales)

En las vistas de línea y área puedes agregar **series sintéticas**: datos manuales que se superponen a la gráfica, útiles para comparar contra una referencia externa (por ejemplo, series históricas o proyecciones de otra fuente). Cada serie sintética admite nombre, color, estilo de línea, marcador y tipo de trazo (línea, área o columna), y puede activarse/desactivarse individualmente. También se puede pegar un rango de datos copiado desde Excel (un valor, una fila, una columna o una matriz de dos columnas año-valor). Estas series se guardan en tu navegador, asociadas a la combinación específica de gráfica, unidad, filtros y vista.

## Personalizar nombres y colores de series

Las series de cada gráfica (tecnologías, combustibles, sectores, etc.) tienen un nombre y un color por defecto definidos internamente. Si tienes permisos de administración de reportes, puedes sobreescribir esos valores — y también ocultar series o reordenarlas — desde la interfaz, y el cambio aplica globalmente para todos los usuarios que vean esa gráfica.

!!! note "Permisos requeridos"
    Esta funcionalidad requiere el permiso de administrador de reportes (o de gestión de escenarios). El usuario semilla `seed` creado por `scripts/seed.py` cuenta con este permiso en un entorno local recién instalado.

### Desde la sección de Reportes (configuración general)

1. Entra a la sección **Reportes** y abre la pestaña de configuración de **series por gráfica**.
2. Selecciona el tipo de gráfica que quieres ajustar (por ejemplo, producción eléctrica).
3. Selecciona la agrupación correspondiente (por tecnología, por combustible, etc.).
4. Si es la primera vez que configuras esa combinación, usa la opción de **poblar desde catálogo** para generar automáticamente una fila por cada serie disponible, con sus valores por defecto.

Por cada serie podrás:

| Acción | Efecto |
|--------|--------|
| Arrastrar la fila | Reordena la serie (afecta el orden de apilamiento: la primera queda abajo en las barras apiladas). |
| Editar el nombre visible | Cambia la etiqueta que aparece en leyendas, tooltips y tablas. |
| Elegir un color | Sobreescribe el color por defecto de esa serie. |
| Marcar como oculta | Excluye la serie de la gráfica, la tabla y las exportaciones. |
| Marcar como global | Aplica ese nombre/color/visibilidad en **cualquier** gráfica donde aparezca esa misma serie, no solo en la combinación tipo+agrupación actual. |
| Quitar la fila | Elimina la personalización; la serie vuelve a sus valores por defecto. |

!!! tip "Local vs. global"
    Si una serie tiene una personalización específica para una gráfica en particular (local) y además una personalización marcada como global, la personalización **local** siempre gana sobre la global para esa gráfica puntual.

### Desde la página de resultados (por gráfica específica)

Si estás viendo una gráfica concreta y tienes permisos de administrador, puedes ajustar sus series sin salir de la página de resultados: busca la opción de **configurar series** en la barra de controles de la gráfica (no disponible en la vista de tabla). Se abrirá un panel ya preconfigurado con el tipo y la agrupación de la gráfica actual; al guardar, la gráfica se actualiza automáticamente con los cambios.

### Agregar una serie que no aparece poblada

Si una serie existe en los datos de la simulación pero no fue incluida al poblar desde el catálogo, puedes añadirla manualmente escribiendo su código exacto (tal como aparece en los datos) en el campo correspondiente — la interfaz sugiere coincidencias mientras escribes. El código debe coincidir exactamente con el identificador interno de la serie; si no aparece en las sugerencias, puedes obtenerlo del explorador de datos de resultados o de una exportación en CSV.

## Plantillas de gráficas guardadas

Puedes guardar la configuración actual de una gráfica (tipo, unidad, filtros, agrupación, vista, modo de comparación, series sintéticas, etc.) como una plantilla reutilizable, en lugar de tener que reconfigurarla cada vez.

1. Configura la gráfica como la necesitas y usa la opción de **guardar gráfica**.
2. La plantilla queda disponible en tu lista personal de gráficas guardadas (y, si la marcas como pública, visible para otros usuarios).
3. Puedes editarla, marcarla como favorita, duplicarla o eliminarla más adelante.

## Reportes

Un reporte es una colección ordenada de plantillas de gráficas guardadas, cada una asociada a uno o varios escenarios, pensada para exportarse como un conjunto.

1. Desde la sección de **Reportes**, en el generador de reportes, selecciona las plantillas de gráfica que quieres incluir.
2. Asigna qué escenario (o escenarios) corresponde a cada plantilla.
3. Previsualiza cada gráfica antes de exportar.
4. Exporta el conjunto como un archivo comprimido (PNG o SVG, una imagen por gráfica).
5. Opcionalmente, guarda el reporte ensamblado como una plantilla de reporte para reutilizarlo más adelante.

!!! tip "Organización por categorías"
    Puedes organizar las gráficas de un reporte en categorías y subcategorías; al exportar, el archivo comprimido conserva esa misma estructura de carpetas.

## Exportar una gráfica individual

Además de los reportes completos, cualquier gráfica individual puede exportarse por separado como imagen (PNG/SVG), CSV o Excel, directamente desde su propia barra de controles.

## Explorador de datos de resultados

Para quienes necesitan revisar los datos crudos de una simulación (no solo las gráficas preconfiguradas), la aplicación ofrece una vista de tabla de formato ancho con filtrado por ocho dimensiones (variable, región, tecnología, combustible, emisión, timeslice, modo, almacenamiento), navegación por categorías, control de columnas visibles, reglas de inclusión/exclusión de años, paginación configurable y exportación a Excel.

## Siguientes pasos

- [Simulaciones](simulaciones.md) para entender el ciclo de vida del job cuyo resultado estás visualizando.
- [UDC](udc.md) si tu escenario incluye restricciones personalizadas que afectan los resultados.
- [Arquitectura](../architecture/overview.md) para el detalle técnico del motor de gráficas (`chart_service`, catálogos de configuración, etc.).
