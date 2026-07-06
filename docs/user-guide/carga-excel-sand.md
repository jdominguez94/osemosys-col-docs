# Carga de datos Excel/SAND

Además del modo principal de escenarios en base de datos, la aplicación soporta un modo **independiente (standalone)**: simular directamente a partir de un archivo Excel con el formato SAND, sin necesidad de crear ni almacenar un escenario en PostgreSQL.

## ¿Cuándo usar este modo?

- Para validar rápidamente un archivo de datos sin pasar por el proceso de creación de un escenario.
- Para reproducir o comparar una corrida hecha originalmente fuera de la aplicación (por ejemplo, en una hoja de cálculo).
- Para pruebas puntuales donde no necesitas conservar el escenario para uso futuro.

!!! note "Diferencia clave con el modo DB"
    En este modo, los datos de entrada nunca se guardan como un escenario reutilizable en la base de datos — se leen directamente del archivo Excel en el momento de simular. Si luego quieres iterar sobre esos mismos datos, ajustarlos y compararlos con otras variantes de forma persistente, te conviene importarlos como un escenario (ver [Escenarios y catálogos](escenarios.md)).

## Formato del archivo

El archivo debe seguir el formato SAND esperado por la aplicación (una hoja **Parameters** con la estructura de sets y valores que usa el modelo OSeMOSYS). Ver [Ejemplos: Archivos SAND](../examples/sand-files.md) para la ubicación de archivos SAND de referencia y un ejemplo de su estructura.

## Cómo lanzar una simulación desde Excel/SAND

1. En la sección correspondiente de la aplicación, selecciona la opción de simular desde archivo Excel en lugar de desde un escenario existente.
2. Sube el archivo `.xlsx`/`.xlsm` con el formato SAND.
3. Confirma y lanza la simulación. A partir de aquí, el ciclo de vida del job (en cola → en ejecución → finalizado) es el mismo que en el modo de escenarios en base de datos — ver [Simulaciones](simulaciones.md).

## Qué NO está disponible en este modo

- **Persistencia del escenario como reutilizable**: los datos de entrada no quedan guardados como escenario; si necesitas volver a simular con los mismos datos, deberás volver a subir el archivo (o importarlo como escenario en base de datos).

## Visualización de resultados

Una vez que la simulación desde Excel/SAND termina, los resultados se visualizan exactamente igual que los de un escenario en base de datos: mismo selector de gráficas, mismos tipos de vista, mismas opciones de exportación. Ver [Visualizaciones y reportes](visualizaciones.md).

## Comparar contra una corrida externa

Si tu objetivo es verificar que un archivo Excel produce el mismo resultado en la aplicación que en otra herramienta externa (por ejemplo, una hoja de cálculo de referencia), revisa los indicadores clave del resultado (valor de la función objetivo, demanda total, despacho total, demanda no cubierta) y contrástalos con los de la otra ejecución.

## Siguientes pasos

- [Ejemplos: Archivos SAND](../examples/sand-files.md) para ver dónde están los archivos SAND de referencia, las políticas que representan y un ejemplo de su estructura.
- [Visualizaciones y reportes](visualizaciones.md) para explorar los resultados.
- [Escenarios y catálogos](escenarios.md) si luego decides importar estos datos como un escenario persistente.
