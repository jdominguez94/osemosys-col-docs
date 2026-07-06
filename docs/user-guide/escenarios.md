# Escenarios y catálogos

Un **escenario** es el conjunto de datos de entrada sobre el que se ejecuta una simulación: demanda proyectada, tecnologías disponibles, combustibles, parámetros de costos y disponibilidad, y — opcionalmente — restricciones definidas por el usuario. Este documento cubre el modo de trabajo principal de la aplicación, en el que los escenarios se almacenan y gestionan en la base de datos.

!!! note "Modo alterno"
    Si en cambio quieres simular directamente desde un archivo Excel sin crear un escenario en la base de datos, ver [Carga de datos Excel/SAND](carga-excel-sand.md).

## ¿Qué contiene un escenario?

Un escenario en modo base de datos referencia un conjunto de parámetros del modelo energético (equivalentes a las hojas de un archivo SAND/Excel tradicional): tecnologías, combustibles/recursos, demanda por sector, factores de disponibilidad, costos y límites de capacidad.

Estos datos suelen originarse en un catálogo base (importado desde un archivo Excel oficial u otro escenario existente) y luego ajustarse para representar la variante de política o supuesto que quieres estudiar (por ejemplo, una meta de descarbonización distinta, o una proyección de demanda alternativa).

## Crear un escenario

En la sección de escenarios de la aplicación puedes crear uno nuevo. Generalmente esto implica:

1. Definir los datos básicos del escenario (nombre, descripción y, si aplica, si es de tipo nacional o regional).
2. Vincular o importar el conjunto de parámetros de entrada (a partir de un catálogo existente o de una importación de Excel).
3. Ajustar los parámetros específicos que quieras variar respecto al escenario base.

!!! tip "Escenarios nacional vs. regional"
    La aplicación soporta simulaciones a nivel nacional agregado y también a nivel regional (desagregando el Sistema Interconectado Nacional en sus regiones). El tipo de escenario determina cómo se agrupan y visualizan luego las tecnologías (con prefijo de región en modo regional).

!!! tip "Timeslices: simulación convencional vs. con timeslices"
    Al crear o importar el escenario, deja marcada la opción de **colapsar todo a 1 timeslice** si vas a correr una simulación convencional (esta opción viene activada por defecto). Si en cambio quieres una simulación que sí discrimine por timeslices, **desmarca esa casilla** en la interfaz antes de simular; en ese caso se conservan los timeslices tal como vienen definidos en los datos de entrada.

## Editar y versionar escenarios

Los escenarios existentes pueden ajustarse para explorar variantes: cambia un parámetro puntual (por ejemplo, la disponibilidad de una tecnología o una meta de emisiones) y vuelve a simular, sin perder el escenario original. Esto es lo que permite luego comparar múltiples variantes lado a lado — ver [Comparación entre escenarios](visualizaciones.md#comparacion-entre-escenarios).

## Catálogos

El catálogo es la fuente de tecnologías, combustibles y demás códigos del modelo (por ejemplo, los códigos de tecnología como `PWRCOA`, `PWRHYD`, etc.) que subyace a los escenarios. Los nombres y colores visibles de cada tecnología/combustible en las gráficas provienen de este catálogo — ver [Visualizaciones y reportes](visualizaciones.md#personalizar-nombres-y-colores-de-series) para cómo personalizarlos desde la interfaz.

## Siguientes pasos

- [Simulaciones](simulaciones.md) para lanzar y monitorear la ejecución de un escenario.
- [Primera simulación](../getting-started/first-simulation.md) si es tu primera vez usando la aplicación.
