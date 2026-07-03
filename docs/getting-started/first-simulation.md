# Primera simulación

Esta guía te lleva paso a paso desde iniciar sesión hasta ver los primeros resultados gráficos de una simulación. Se asume que ya tienes el stack levantado — si no, sigue primero [Instalación](installation.md).

!!! tip "Antes de empezar"
    Necesitas el usuario semilla creado por `scripts/seed.py`: usuario **`seed`**, contraseña **`seed123`**.

## 1. Iniciar sesión

Abre el frontend en tu navegador ([http://localhost:8080](http://localhost:8080) si usas el stack Docker por defecto) e inicia sesión con el usuario `seed` y la contraseña `seed123`.

## 2. Elegir o crear un escenario

Un **escenario** agrupa el conjunto de datos de entrada (demanda, tecnologías, combustibles, restricciones, etc.) sobre el que se ejecuta una simulación. Dirígete a la sección de escenarios:

- Si ya existen escenarios de ejemplo (creados por la siembra inicial), selecciona uno de la lista.
- Si necesitas crear uno nuevo, sigue el procedimiento detallado en [Escenarios y catálogos](../user-guide/escenarios.md).

!!! note "Dos formas de simular"
    Esta guía cubre el flujo principal: simular un escenario ya almacenado en la base de datos. También existe un modo alterno para simular directamente desde un archivo Excel/SAND sin pasar por la base de datos — ver [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md).

## 3. Lanzar la simulación

Desde el escenario elegido, inicia una nueva simulación. Al hacerlo, la aplicación:

1. Registra la solicitud como un nuevo trabajo (job) de simulación.
2. Encola una tarea en segundo plano (un worker de Celery) que ejecuta el pipeline completo: exporta los datos del escenario a CSV, construye el modelo de optimización (Pyomo) y lo resuelve con el solver HiGHS.
3. Persiste los resultados en la base de datos y en un archivo JSON asociado al job.

!!! note "Restricciones definidas por el usuario (UDC)"
    Si el escenario tiene habilitadas restricciones definidas por el usuario (por ejemplo, un margen de reserva personalizado), estas se incorporan automáticamente al modelo antes de resolverlo. Ver [UDC](../user-guide/udc.md).

## 4. Monitorear el estado del trabajo

Una simulación no se resuelve instantáneamente — puede tardar desde segundos hasta varios minutos dependiendo del tamaño del escenario (nacional vs. regional) y de la carga del servidor. En la sección de simulaciones podrás ver el estado del job, que típicamente transita por: en cola → en ejecución → finalizado (o infactible/fallido).

!!! tip "¿Y si el resultado es infactible?"
    Si el solver no encuentra una solución factible, la aplicación no te deja sin respuesta: te muestra un análisis que apunta a las restricciones y parámetros involucrados. Ver [Simulaciones](../user-guide/simulaciones.md#resultados-infactibles) para más detalle.

## 5. Abrir los resultados

Cuando el job termina exitosamente, ábrelo desde la lista de simulaciones para entrar a la página de resultados. Ahí encontrarás:

- Un resumen con indicadores clave del escenario resuelto.
- El selector de gráficas, donde puedes elegir qué variable visualizar (producción, capacidad, emisiones, etc.) y cómo agruparla.
- Distintos tipos de vista: barras apiladas, líneas, área, Pareto o tabla.

Para explorar todas las posibilidades de personalización de gráficas (tipos de vista, comparación entre escenarios, series, plantillas guardadas y exportación), continúa con [Visualizaciones y reportes](../user-guide/visualizaciones.md).

## Resumen del flujo

```text
Iniciar sesión → Elegir/crear escenario → Lanzar simulación → Monitorear job → Abrir resultados → Visualizar y comparar
```

## Siguientes pasos

- [Visión general de la Guía de Usuario](../user-guide/overview.md) para entender el flujo completo de la aplicación.
- [Escenarios y catálogos](../user-guide/escenarios.md) para profundizar en la gestión de escenarios.
- [Simulaciones](../user-guide/simulaciones.md) para el detalle del ciclo de vida de un job.
