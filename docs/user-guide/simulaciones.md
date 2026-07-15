# Simulaciones

Una simulación (también llamada "job" o trabajo) es la ejecución del modelo de optimización sobre los datos de un escenario. Esta página explica cómo lanzar una simulación, cómo monitorear su avance, y qué hacer cuando el resultado es infactible.

## Lanzar una simulación

Desde un escenario ya creado (ver [Escenarios y catálogos](escenarios.md)), inicia una nueva simulación. Al confirmar, la aplicación encola la ejecución para que corra en segundo plano. No necesitas mantener la página abierta mientras se resuelve.

## Ciclo de vida de una simulación

Una vez lanzada, la simulación pasa por las siguientes etapas internamente.

1. **En cola.** El trabajo espera a que un worker en segundo plano lo tome (la aplicación limita cuántas simulaciones corren en paralelo y cuántas puede tener activas un mismo usuario a la vez).
2. **En ejecución.** Se preparan los datos de entrada, se construye el modelo matemático y se resuelve con el solver.
3. **Finalizado.** El resultado queda disponible para visualización, y puede terminar en dos estados. En **éxito (factible)** se encontró una solución óptima y los resultados quedan listos para explorar. En **infactible**, no existe ninguna combinación de decisiones que satisfaga todas las restricciones simultáneamente con los datos dados.

!!! tip "Simulaciones nacionales vs. regionales"
    Las simulaciones en modo regional son más exigentes computacionalmente que las nacionales, por lo que pueden tardar más y tienen un peso mayor dentro de los límites de ejecución concurrente de la plataforma.

## Monitorear el avance

Desde la lista de simulaciones puedes ver el estado de cada job en tiempo real. Si necesitas cancelar una ejecución en curso, la opción para hacerlo está disponible en la misma sección desde la fila del job correspondiente.

## Resultados infactibles

Cuando el solver no logra encontrar una solución factible, esto normalmente significa que los datos de entrada del escenario contienen restricciones contradictorias entre sí (por ejemplo, una demanda que ninguna combinación de tecnologías disponibles puede cubrir dentro de los límites de capacidad definidos).

En vez de dejarte solo con un mensaje de "infactible", la aplicación ofrece dos niveles de ayuda.

1. **Diagnóstico básico (automático).** Apenas el solver reporta infactibilidad, la aplicación revisa internamente qué restricciones quedaron violadas y si hay conflictos evidentes entre límites superior e inferior de alguna variable, y guarda ese resumen junto con el resultado del job.
2. **Análisis detallado (bajo demanda).** Desde el reporte de infactibilidad puedes solicitar un análisis más profundo. Este proceso identifica el conjunto mínimo de restricciones que, en conjunto, hacen que el problema sea infactible, y las relaciona con los parámetros del escenario que probablemente estén causando el conflicto (por ejemplo, un límite de capacidad demasiado bajo para una tecnología específica en un año dado). El resultado incluye una lista de "principales sospechosos", los parámetros con mayor probabilidad de ser la causa, para que sepas por dónde empezar a ajustar el escenario.

!!! note "Nivel de detalle"
    El análisis detallado señala qué restricciones y qué parámetros del escenario están involucrados en el conflicto (por ejemplo, "límite de capacidad de la tecnología X en el año Y"), no requiere que entiendas la formulación matemática interna del modelo ni el funcionamiento del solver.

Este análisis puede tardar un poco más que la simulación original, ya que reconstruye el modelo para examinarlo en detalle; puedes cancelarlo si ya no lo necesitas.

## Siguientes pasos

Revisa [Visualizaciones y reportes](visualizaciones.md) para explorar los resultados de una simulación exitosa, o [Escenarios y catálogos](escenarios.md) para ajustar los datos de entrada si tu simulación resultó infactible.
