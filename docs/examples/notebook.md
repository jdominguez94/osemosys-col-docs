# Notebook UPME OPT

El repositorio de la aplicación incluye un cuaderno Jupyter, `osemosys_notebook_UPME_OPT.ipynb`, que cumple un rol de **referencia y validación** para el motor de simulación: es el notebook original sobre el que se construyó el modelo OSeMOSYS de esta implementación, y sirve como punto de comparación ("paridad") frente al pipeline de simulación de la aplicación web.

!!! note "No se ejecuta ni se embebe aquí"
    Este documento describe el propósito del notebook de forma narrativa. No se incluye su contenido ni se ejecuta desde este sitio — es un archivo pesado (varios megabytes, en su mayoría salidas de celdas ya ejecutadas) pensado para abrirse y correrse en un entorno Jupyter propio.

## ¿Para qué sirve?

El notebook implementa, en Python/Pyomo, el mismo modelo OSeMOSYS que corre la aplicación: desde la lectura de los datos de entrada (formato SAND/Excel), pasando por la definición del modelo y la construcción de la instancia, hasta la resolución con un solver y el postprocesamiento de resultados. Antes de que la aplicación web existiera, este era el flujo de trabajo original para correr el modelo.

Hoy en día, su función principal es la de **referencia de paridad**: cuando se modifica algo en el pipeline de simulación de la aplicación (procesamiento de datos, definición del modelo, resolución o postprocesamiento), se puede volver a correr el mismo escenario en el notebook y en la aplicación, y comparar indicadores clave del resultado — como el valor de la función objetivo, la demanda total, el despacho total, la demanda no cubierta y la razón de cobertura — para confirmar que ambos caminos producen resultados equivalentes.

## Cómo se relaciona con el pipeline de la aplicación

El repositorio incluye documentación técnica dedicada a este mapeo de paridad (a cargo de otra sección de esta documentación), que traza cada etapa del notebook a su equivalente en el backend de la aplicación: la importación y preprocesamiento de datos, la definición abstracta del modelo, la construcción de la instancia con Pyomo, la resolución con el solver, y el postprocesamiento de resultados hacia las gráficas. Ver [Arquitectura: Paridad Notebook vs App](../architecture/paridad-notebook.md) y [Arquitectura: Comparar resultados](../architecture/comparar-resultados.md) para el detalle técnico completo de esa comparación.

## Cuándo consultarlo

- Si necesitas validar que un cambio en el motor de simulación no alteró los resultados esperados para un escenario conocido.
- Si quieres entender el modelo OSeMOSYS "desde cero", en su forma más directa (celdas de un notebook), antes de adentrarte en la arquitectura de la aplicación web.
- Si tienes un archivo Excel/SAND que ya corriste en el notebook y quieres reproducir esa misma corrida dentro de la aplicación — ver [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md).

## Acceder al notebook

El archivo vive en la raíz del repositorio de la aplicación:

[Ver `osemosys_notebook_UPME_OPT.ipynb` en GitHub](https://github.com/UPME-SubDemanda/Osemosys_UPME/blob/main/osemosys_notebook_UPME_OPT.ipynb)

## Siguientes pasos

- [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md) para simular en la aplicación con el mismo tipo de archivo de entrada que usa el notebook.
- [Arquitectura](../architecture/overview.md) para el resto de la documentación técnica del motor de simulación.
