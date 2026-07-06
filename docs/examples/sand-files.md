# Archivos SAND

Un archivo **SAND** es el Excel de entrada que usa OSeMOSYS Colombia para simular: contiene, en una hoja **Parameters**, todos los sets y valores paramétricos del modelo (demanda, tecnologías, combustibles, costos, restricciones, etc.) organizados fila por fila. Es el mismo formato que se usa tanto para importar un escenario a la base de datos (`POST /scenarios/import-excel`) como para simular directamente sin base de datos (ver [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md)).

## Dónde encontrar archivos SAND

- **Carpeta `SAND/` del repositorio**: contiene archivos SAND de referencia/histórico, por ejemplo `SAND_01_04_2025.xlsm`, `SAND_26_08_2025.xlsm`, `SAND_18_11_2025_REF.xlsm`, `SAND_15_12_2025_REF.xlsm`.
- **Raíz del repositorio**: `SAND_integrado_PA_MR_20_04.xlsx`, un archivo SAND consolidado.

Para replicar o partir de una simulación ya construida, usa cualquiera de estos archivos como punto de partida y súbelo por la interfaz (ver [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md)).

## Naturaleza de cada archivo: las tres políticas

Los archivos SAND de escenario siguen la convención de nombre `<PREFIJO>_<timeslices>_<departamentos>_<horizonte>_SAND_<fecha>.xlsx` (por ejemplo `PD_2TS_41D_2055_SAND_03Jun2026.xlsx`). El prefijo indica qué política de largo plazo representa el escenario:

| Prefijo | Política | Qué representa |
|---|---|---|
| **PA** | Políticas Anunciadas | Escenario que incorpora, además de las políticas ya vigentes, los compromisos y metas anunciados oficialmente pero aún no implementados en firme (equivalente al enfoque "Announced Pledges" habitual en la planeación energética internacional). |
| **PD** | Políticas Declaradas | Escenario de línea base: refleja únicamente las políticas y normativa energética actualmente vigentes y en ejecución, sin supuestos adicionales de nuevas metas ("Stated Policies"). |
| **CN** | Carbono Neutralidad | Escenario alineado con la meta de carbono neutralidad de largo plazo: las trayectorias de tecnología, demanda y emisiones se ajustan para converger con esa meta ("Net Zero"). |

!!! note "Convención de nombre"
    `2TS` indica el número de timeslices del escenario, `41D` el número de departamentos/regiones modeladas, y `2055` el año horizonte de la simulación. Estos valores pueden variar entre archivos según el escenario específico.

## Ejemplo de estructura de un SAND

La hoja **Parameters** tiene una fila de encabezado y luego una fila por combinación de parámetro/dimensiones, con una columna por año del horizonte de modelación:

| Parameter | REGION | TECHNOLOGY | EMISSION | FUEL | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|---|---|
| AccumulatedAnnualDemand | RE1 | | | AGFHEA | 40.44 | 41.57 | 44.60 | 46.25 |
| AnnualEmissionLimit | RE1 | | EMIBC | | 1e17 | 1e17 | 1e17 | 1e17 |
| AvailabilityFactor | RE1 | BACKSTOP_1 | | | 1 | 1 | 1 | 1 |
| CapacityFactor | RE1 | BACKSTOP_1 | | | 1 | 1 | 1 | 1 |
| CapitalCost | RE1 | BACKSTOP_1 | | | 9999999 | 9999999 | 9999999 | 9999999 |
| EmissionActivityRatio | RE1 | DEMAGFDSL | EMIBC | | 0.01008 | 0.01008 | 0.01008 | 0.01008 |

!!! tip "Tabla real, recortada"
    Esta tabla es un extracto real de un archivo SAND de referencia (columnas y filas recortadas por espacio) — el archivo completo tiene una columna por cada año del horizonte (hasta 2055) y miles de filas, una por cada combinación de parámetro, región, tecnología, combustible, emisión y/o modo de operación aplicable.

## Siguientes pasos

- [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md) para simular directamente desde un archivo SAND.
- [Escenarios y catálogos](../user-guide/escenarios.md) para importar un SAND como escenario persistente en base de datos.
