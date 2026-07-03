# Paridad Notebook vs App

Este documento describe la paridad funcional entre el notebook de referencia `osemosys_notebook_UPME_OPT_01.ipynb` y la implementación actual de la app (flujo DB-first): cómo carga y transforma los datos cada uno antes de resolver el modelo, cómo se traduce ese flujo a la API/PostgreSQL, y qué tan equivalentes son los resultados.

## Mapeo de secciones del notebook a módulos de la app

| Sección del notebook | Módulo en la app |
|---|---|
| Celdas 4-10 (SAND → sets/CSV + filtros + matrices) | Importación: `app/services/official_import_service.py`; preproceso tipo notebook en BD: `app/services/sand_notebook_preprocess.py`; exportación BD → CSV para simulación: `app/simulation/core/data_processing.py` |
| Celda 3 (Model Definition) | `app/simulation/core/model_definition.py` |
| Celda 21 (DataPortal/`create_instance`) | `app/simulation/core/instance_builder.py` |
| Celda 24 (Solve) | `app/simulation/core/solver.py` |
| Celda 26+ (postproceso/resultados para gráficas) | `app/simulation/core/results_processing.py`; consumo frontend: `frontend/src/pages/ResultDetailPage.tsx` |
| Orquestación de secciones | `app/simulation/osemosys_core.py`, `app/simulation/pipeline.py` |

### Flujo de ejecución en la app

1. Importación Excel (`/official-import/xlsm` o `/scenarios/import-excel`) a `osemosys_param_value`.
2. Preprocesamiento tipo notebook al final de la importación (`run_notebook_preprocess`).
3. La simulación (`/simulations`) ejecuta: `run_data_processing` (BD → CSV temporales), `create_abstract_model`, `build_instance`, `solve_model`, `process_results`.
4. Persistencia del resultado JSON y consumo en el frontend (`ResultDetailPage`).

---

## Tratamiento de datos en el notebook (antes del modelado)

### Origen de los datos

- **Archivo**: Excel SAND (p. ej. `./SAND/SAND_04_02_2026.xlsm` o `SAND_26_03_2025_UPME_almacenamiento.xlsm`).
- **Hoja**: `Parameters`.
- **Variable**: `df_colombia = pd.read_excel(..., sheet_name='Parameters')`.
- **Configuración**: `path_csv = "./CSV/"`, `div` (divisiones temporales, p. ej. 1 o 2; 96/`div` para timeslices).

### Flujo general

```text
Excel SAND (hoja Parameters)
    → SAND_SETS_to_CSV (genera sets + algunos parámetros base)
    → SAND_to_CSV por cada parámetro (genera CSV por parámetro)
    → Filtrado por índices válidos (solo valores que pertenecen a los sets)
    → Completar matrices (InputActivityRatio, OutputActivityRatio, etc.)
    → Procesamiento de emisiones (EmissionActivityRatio con InputActivityRatio)
    → [Opcional] Escenarios (Carbononeutralidad: límites de emisión, UDC, etc.)
    → Reordenar columnas de Activity Ratios
    → DataPortal: data.load(...) de sets y parámetros desde CSV
    → model.create_instance(data) → solver
```

### `SAND_SETS_to_CSV(df, path_csv, div)`

- **Entrada**: `df` = DataFrame de la hoja Parameters.
- **Qué hace**:
  - usa **YearSplit** para inferir años y sets: filtra filas con `index % div == 0` para reducir timeslices;
  - genera CSV de **sets** a partir de columnas no numéricas (REGION, TECHNOLOGY, FUEL, TIMESLICE, etc.) y `YEAR.csv` con los años;
  - a partir de **EmissionActivityRatio** extrae los valores únicos de **EMISSION** y escribe `EMISSION.csv`;
  - a partir de **OutputActivityRatio** vuelve a extraer y escribir sets (TECHNOLOGY, FUEL, etc.);
  - a partir de **CapacityToActivityUnit** (variables "Time independent") extrae sets y escribe TECHNOLOGY, REGION, etc.
- **Salida**: archivos en `path_csv`: `YEAR.csv`, `REGION.csv`, `TECHNOLOGY.csv`, `FUEL.csv`, `TIMESLICE.csv`, `EMISSION.csv`, etc.

### `SAND_to_CSV(df, param, path_csv, div)`

Convierte cada **parámetro** del Excel SAND en un CSV con columnas (sets + YEAR + VALUE).

- **Filtro**: `df_param = df[df["Parameter"] == param].dropna(axis=1)`.
- **Años**: columnas numéricas del DataFrame.
- **Sets**: columnas no numéricas (salvo `Parameter`).

Casos tratados:

1. **"Time indipendent variables"**: una sola columna de valor; se renombra a `VALUE` y se guarda el CSV sin índice temporal explícito por año (o con estructura fija según el parámetro).
2. **Parámetros con TIMESLICE** (dependientes del tiempo intranual):
   - se submuestrea con `df_param.index % div == 0` para agrupar timeslices (reducción de resolución);
   - **CapacityFactor**: se promedian los bloques por grupo (`groupby('index_col').mean()`) y se reasignan por año; luego se genera el producto (sets × year) y se escribe VALUE;
   - **Resto** (p. ej. YearSplit): se eliminan filas con todo cero, se agregan por grupo (`sum`), se asigna por año y se genera el producto (sets × year) → CSV con columnas sets + YEAR + VALUE.
3. **Parámetros sin TIMESLICE**: se indexa por `sets`, se hace el producto cartesiano con `year`, se rellena VALUE desde `df_param_indexed` y se guarda `{param}.csv` con columnas sets + YEAR + VALUE (con `dropna(axis=1)` al final).

- **Salida**: `path_csv/{param}.csv` (p. ej. `CapacityFactor.csv`, `SpecifiedAnnualDemand.csv`).

### Filtrado por índices válidos

Después de generar todos los parámetros:

- para cada parámetro se lee su CSV;
- para cada columna de "set" (REGION, TECHNOLOGY, FUEL, etc., salvo VALUE y REGION2 si aplica) se carga el CSV del set correspondiente (p. ej. `TECHNOLOGY.csv`);
- se filtran las filas del parámetro de modo que cada índice pertenezca al set: `df_prueba[s].isin(df_sets.VALUE.tolist())`;
- se sobrescribe el CSV del parámetro con este DataFrame filtrado.

Con esto se eliminan combinaciones (r, t, f, …) que no pertenecen a los conjuntos definidos en el modelo.

### Completar matrices (relleno de celdas faltantes)

Las matrices de ratios y costos se "completan" para que existan **todas** las combinaciones (REGION, TECHNOLOGY, MODE, …) con VALUE definido (0 donde no había dato):

- **`completar_Matrix_Act_Ratio(variable)`**: para `InputActivityRatio.csv` y `OutputActivityRatio.csv`. Producto cartesiano REGION × TECHNOLOGY × MODE_OF_OPERATION × FUEL × YEAR; merge `how='left'` con el CSV existente, VALUE faltante → 0.
- **`completar_Matrix_Emission(variable)`**: para `EmissionActivityRatio.csv`. Producto REGION × TECHNOLOGY × EMISSION × MODE_OF_OPERATION × YEAR; merge left, `fillna(0)` en VALUE.
- **`completar_Matrix_Storage(variable)`**: solo si `Correr == "Almacenamiento"`. Para `TechnologyFromStorage.csv` y `TechnologyToStorage.csv`. Producto REGION × TECHNOLOGY × STORAGE × MODE_OF_OPERATION.
- **`completar_Matrix_Cost(variable)`**: para `VariableCost.csv`. Producto REGION × TECHNOLOGY × MODE_OF_OPERATION × YEAR.

Así Pyomo recibe parámetros definidos en todos los índices del modelo (evita huecos en los índices).

### Procesamiento de emisiones (entrada de combustible)

`process_and_save_emission_ratios(emission_activity_path, input_activity_path, output_path)`:

- lee `EmissionActivityRatio` e `InputActivityRatio`;
- hace merge por REGION, TECHNOLOGY, MODE_OF_OPERATION, YEAR;
- filtra filas con `VALUE_x != 0` y `VALUE_y != 0`;
- calcula `VALUE = VALUE_x * VALUE_y` (emisión por uso de combustible en la entrada);
- agrupa por (REGION, TECHNOLOGY, EMISSION, MODE_OF_OPERATION, YEAR), manteniendo un valor;
- actualiza el DataFrame de EmissionActivityRatio y guarda en `output_path` (típicamente sobrescribe `EmissionActivityRatio.csv`).

Con esto se contabilizan emisiones asociadas al **input** de combustible (no solo a la actividad directa).

### Escenarios opcionales

- **`Escenario == "Carbononeutralidad"`**: se genera una serie lineal de límites de emisión (p. ej. de 90 a 30 entre 2024 y 2050). `emissions_limit(emission_limit_path, df_new)` actualiza el CSV de límite anual (`AnnualEmissionLimit`) con la nueva serie por año. Se crean/actualizan archivos UDC: `UDC.csv`, `UDCMultiplierTotalCapacity`, `UDCMultiplierNewCapacity`, `UDCMultiplierActivity`, `UDCConstant`, `UDCTag`, a partir de `AvailabilityFactor`, `REGION`, `YEAR`, etc.
- **UDC (User Defined Constraints)**: si `usar_UDC == True` se crean los CSV de UDC (listas de UDC, multiplicadores por capacidad/actividad, constante y tag ≤/=).

### Último paso antes de DataPortal

Se reordenan columnas de `InputActivityRatio.csv` y `OutputActivityRatio.csv` a `['REGION', 'TECHNOLOGY', 'FUEL', 'MODE_OF_OPERATION', 'YEAR', 'VALUE']` y se guardan de nuevo. Luego se usa **Pyomo DataPortal**: `data.load(filename=path_csv+..., set=...)` o `param=..., index=[...]` para cargar sets y parámetros desde los CSV ya tratados.

---

## Equivalencia DataPortal (CSV) ↔ API (base de datos)

| DataPortal (script del notebook) | API |
|---|---|
| `DataPortal()` + `data.load(filename=path_csv+"X.csv", set="Y")` | Los conjuntos (REGION, TECHNOLOGY, etc.) vienen de catálogos en BD y de los índices usados en `osemosys_param_value` |
| `data.load(filename=path_csv+"X.csv", param="ParamName", index=[...])` | Filas en `osemosys_param_value` con `param_name = "ParamName"` y columnas región, tecnología, combustible, emisión, timeslice, modo, año, UDC, etc. |
| `model.create_instance(data)` | `load_from_db(db, scenario_id)` construye un diccionario de parámetros; `build_context` + `run_model` arman y resuelven el modelo |

Los **nombres de parámetros** en la API se **normalizan** (minúscula, sin caracteres no alfanuméricos). Por ejemplo: `InputActivityRatio` en CSV → `inputactivityratio` en `ctx.params`. En la BD se guarda el nombre tal cual (p. ej. `InputActivityRatio`); el loader lo normaliza al usarlo.

### Conjuntos (sets)

En el script del notebook se cargan sets desde CSV (EMISSION, FUEL, TIMESLICE, MODE_OF_OPERATION, TECHNOLOGY, YEAR, REGION, STORAGE si aplica, UDC si aplica). En la API:

- los **conjuntos** no se cargan como archivos; se derivan de catálogos globales (`region`, `technology`, `fuel`, `emission`, `timeslice`, `mode_of_operation`, etc.) y de las **claves** que aparecen en `osemosys_param_value` para el escenario (regiones, tecnologías, años, etc. que realmente tienen datos);
- si se usa **Almacenamiento**: las dimensiones de almacenamiento se obtienen de filas con `id_storage_set` en `osemosys_param_value` y del catálogo `storage_set`;
- si se usa **UDC**: el set UDC viene del catálogo `udc_set` y de filas con `id_udc_set` en `osemosys_param_value`.

### Carga de parámetros

En el script del notebook:

```python
data.load(filename=path_csv+"YearSplit.csv", param="YearSplit", index=["TIMESLICE", "YEAR"])
data.load(filename=path_csv+"InputActivityRatio.csv", param="InputActivityRatio", index=["REGION", "TECHNOLOGY", "FUEL", "MODE_OF_OPERATION", "YEAR"])
# ...
if usar_UDC:
    data.load(filename=path_csv+"UDCMultiplierTotalCapacity.csv", param="UDCMultiplierTotalCapacity", index=["REGION", "TECHNOLOGY", "UDC", "YEAR"])
```

En la API, cada fila de parámetro es un registro en **`osemosys_param_value`** (por escenario):

- `param_name`: nombre del parámetro (ej. `YearSplit`, `InputActivityRatio`, `UDCMultiplierTotalCapacity`);
- dimensiones: `id_region`, `id_technology`, `id_fuel`, `id_emission`, `id_timeslice`, `id_mode_of_operation`, `id_season`, `id_daytype`, `id_dailytimebracket`, `id_storage_set`, `id_udc_set`, `year`;
- `value`: valor numérico.

La **clave** con la que el modelo interno indexa cada valor es la tupla `(id_region, id_technology, id_fuel, id_emission, id_timeslice, id_mode_of_operation, id_season, id_daytype, id_dailytimebracket, id_storage_set, id_udc_set, year)`.

Cómo llegan los datos a la BD:

1. **Importación Excel**: hoja tipo SAND/Parameters (por ejemplo vía `POST /scenarios/import-excel` o importación oficial). El Excel tiene columnas tipo REGION, TECHNOLOGY, FUEL, MODE_OF_OPERATION, YEAR, VALUE (y opcionalmente EMISSION, TIMESLICE, UDC, etc.); el importador escribe en `osemosys_param_value` con el `param_name` que corresponda a cada fila/hoja.
2. **Valores manuales**: crear/editar valores OSeMOSYS desde la UI o con `POST /scenarios/{id}/osemosys-values` (y similares), usando los mismos nombres de parámetro y dimensiones.

No hace falta "adaptar" el script línea por línea a la API: la fuente de verdad son las tablas (y catálogos), y el loader lee de ahí y arma la misma estructura lógica que se usaría con DataPortal.

### Parámetros que usa el modelo actual de la API

Los bloques del modelo (`constraints_core`, `constraints_emissions`, `constraints_reserve_re`, `constraints_udc`, `objective`, etc.) leen **solo** los parámetros que necesitan. Cualquier otro parámetro que exista en `osemosys_param_value` se carga en `params` pero no se usa aún en restricciones/objetivo.

| Parámetro (script) | Nombre normalizado en API | Uso en modelo |
|---|---|---|
| ResidualCapacity | `residualcapacity` | constraints_core, constraints_udc |
| CapacityFactor | `capacityfactor` | constraints_core |
| AvailabilityFactor | `availabilityfactor` | constraints_core |
| CapacityToActivityUnit | `capacitytoactivityunit` | constraints_core |
| TotalAnnualMaxCapacity | `totalannualmaxcapacity` | constraints_core |
| TotalAnnualMaxCapacityInvestment | `totalannualmaxcapacityinvestment` | constraints_core |
| CapitalCost | `capitalcost` | objective |
| FixedCost | `fixedcost` | objective |
| VariableCost | `variablecost` | supply_rows / objetivo |
| EmissionsPenalty | `emissionspenalty` | objective |
| EmissionActivityRatio | `emissionactivityratio` | constraints_emissions |
| AnnualEmissionLimit | `annualemissionlimit` | constraints_emissions |
| ReserveMargin | `reservemargin` | constraints_reserve_re |
| REMinProductionTarget | `reminproductiontarget` | constraints_reserve_re |
| RETagTechnology | `retagtechnology` | constraints_reserve_re |
| UDCMultiplierTotalCapacity | `udcmultipliertotalcapacity` | constraints_udc |
| UDCMultiplierNewCapacity | `udcmultipliernewcapacity` | constraints_udc |
| UDCMultiplierActivity | `udcmultiplieractivity` | constraints_udc |
| UDCConstant | `udcconstant` | constraints_udc |
| UDCTag | `udctag` | constraints_udc |
| InputActivityRatio / OutputActivityRatio | `inputactivityratio`, `outputactivityratio` | supply/demand y lógica de balance (vía supply_rows y parámetros) |

!!! note "Parámetros cargados pero no usados aún"
    Parámetros que se cargan en el script pero que **el modelo actual no usa** (por tanto son opcionales en la BD, para futuras extensiones): por ejemplo `YearSplit`, `DiscountRate`, `DepreciationMethod`, `TotalTechnologyAnnualActivityLowerLimit`/`UpperLimit`, `TotalTechnologyModelPeriodActivityLowerLimit`/`UpperLimit`, `ModelPeriodEmissionLimit`, `ModelPeriodExogenousEmission`, `AnnualExogenousEmission`, `SpecifiedDemandProfile`, `ReserveMarginTagFuel`, `RETagFuel`, `ReserveMarginTagTechnology`, `TotalAnnualMinCapacityInvestment`, `TotalAnnualMinCapacity`, etc. Se pueden guardar en `osemosys_param_value` para tener paridad con el Excel/notebook; no rompen nada.

### Columnas InputActivityRatio / OutputActivityRatio

En el script del notebook se reordenan columnas a `REGION, TECHNOLOGY, FUEL, MODE_OF_OPERATION, YEAR, VALUE`. En la API esas dimensiones se mapean a región, tecnología, combustible, modo de operación, año (y opcionalmente timeslice, emisión, etc. si se usan). El **preprocesamiento tipo notebook** (ejecutado al importar Excel) puede completar matrices y ajustar formatos; los nombres de parámetro deben coincidir con los que espera el modelo (p. ej. `InputActivityRatio`, `OutputActivityRatio`).

### Flujo equivalente en la API

1. **Cargar datos del escenario**: importar Excel (SAND/Parameters) o importación oficial, o crear/actualizar valores OSeMOSYS por API.
2. **Ejecutar simulación**: `POST /simulations` (o el endpoint que dispare el job) con `scenario_id`. El worker ejecuta `load_from_db(db, scenario_id)` → `build_context(...)` → `run_model(ctx)` (variables, restricciones, objetivo, solver). Equivale a `model.create_instance(data)` + resolución en el notebook.

No hace falta un "script DataPortal" separado: la instancia del modelo se crea a partir de la BD en cada corrida.

### Procesamiento de la solución del solver (HiGHS / GLPK)

**HiGHS — leer archivo `.sol` y convertir a diccionario/DataFrame (notebook) vs solución en memoria (API)**

| Notebook (HiGHS) | API |
|---|---|
| `read_highs_table_solution("solucion_X.sol")` → DataFrame con Name, Primal | No hay archivo `.sol`; se lee la solución desde el modelo Pyomo en memoria |
| `solution_to_dict_with_sets(instance, df_sol_highs)` → `sol['RateOfActivity']`, etc. | Se extraen variables concretas: `dispatch`, `new_capacity`, `unmet_demand`, `annual_emissions` en listas/dicts con estructura fija |
| `sol_variable_to_df(sol, 'RateOfActivity', dimnames)` → DataFrame | El artefacto del job es JSON con `dispatch`, `new_capacity`, etc.; se puede convertir a DataFrame descargando el JSON |

En la API, tras `solver.solve(model)`, `model_runner.py` lee los valores con `pyo.value(model.dispatch[i])`, `pyo.value(model.new_capacity[key])`, etc., y arma un diccionario de resultados que se devuelve y persiste.

**Variables que la API extrae y persiste**: `dispatch`, `new_capacity`, `unmet_demand`, `annual_emissions`, más `objective_value`, `solver_status`, `coverage_ratio`, totales; y en `output_parameter_value` los dispatch por parámetro de entrada.

**Diccionario de solución tipo HiGHS** (paridad con el código original): el resultado del job y el artefacto JSON incluyen `sol`, con la misma idea que `solution_to_dict_with_sets`: por cada variable, una lista de `{"index": [region_name, technology_name, fuel_name, year], "value": primal}` (o las dimensiones que correspondan), para las variables `RateOfActivity`, `NewCapacity`, `UnmetDemand`, `AnnualEmissions`. Los índices usan **nombres** (region, technology, fuel) para coincidir con el script original; en Python se puede reconstruir `sol[varname][tuple(index)] = value` a partir de cada lista.

**GLPK — variables intermedias**: en el notebook, con GLPK se calculan variables derivadas con `value(instance.RateOfActivity[...] * instance.OutputActivityRatio[...])`, etc., y `variable_to_dataframe(variable, index_names)` convierte a DataFrame. En la API se calculan variables intermedias tipo GLPK en post-solve y se devuelven en `intermediate_variables`: `TotalCapacityAnnual`, `AccumulatedNewCapacity`, `ProductionByTechnology`, `UseByTechnology`, `RateOfProductionByTechnology`, `RateOfUseByTechnology`. Sin timeslice se usa `YearSplit=1`; los índices son por nombre (region, technology, fuel, year donde aplique), usando `ResidualCapacity`, `OperationalLife` (por defecto 30 si no existe), `InputActivityRatio`, `OutputActivityRatio`.

| Acción en el script del notebook | ¿Existe en la API? |
|---|---|
| Leer solución del solver | Sí; desde Pyomo en memoria (no desde `.sol`) |
| Extraer variables (dispatch, new_capacity, unmet, emissions) | Sí; en el resultado del job y en el artefacto JSON |
| Diccionario genérico `sol[varname][index]` | Parcial; solo variables fijas en formato lista/dict |
| Convertir variable a DataFrame | No en el backend; sí en código propio usando el JSON del job |
| Variables intermedias (ProductionByTechnology, UseByTechnology, etc.) | Sí; calculadas en post-solve en `intermediate_variables` |

**UDC y almacenamiento**: soportados vía `id_udc_set` / `id_storage_set` y catálogos; el bloque UDC y el de storage los usan cuando hay datos.

---

## ¿La app procesa los datos igual que el notebook?

### Resumen ejecutivo

- **Mismo Excel SAND (Parameters) + mismo solver (glpk)**: en las pruebas realizadas, las métricas (`objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio`) coinciden entre app y notebook (comparación con `compare_results.py`).
- La **app no replica** todos los pasos de preprocesamiento del notebook (agregación por `div`, completar matrices con 0, emisiones a la entrada) *en su importación fila a fila*. Usa un **modelo simplificado** y, por defecto, un preprocesamiento adicional tipo notebook (ver más abajo).
- Para el escenario SAND probado los resultados son equivalentes; en otros escenarios (p. ej. con `div` distinto, o donde las emisiones a la entrada sean relevantes) podría haber diferencias si no se alinean los tratamientos.

### Origen de los datos (igual en ambos)

| Aspecto | Notebook | App |
|---|---|---|
| Archivo | Excel SAND (p. ej. `SAND_04_02_2026.xlsm`) | Mismo |
| Hoja | `Parameters` | `Parameters` (vía import oficial o `run_sand_excel_test.py`) |
| Estructura | Columna `Parameter`, columnas de año (2022, 2023, …), columnas de sets (Region, Technology, …) | Misma lectura por filas |

### Qué hace la app en la importación (hoja Parameters)

- **Dónde**: `OfficialImportService._import_sand_matrix_sheet` en `app/services/official_import_service.py`.
- **Qué hace**: recorre el Excel **fila a fila**; por cada fila lee `Parameter`, `Region`, `Technology`, `Fuel`, `Emission`, `Timeslice`, `Mode_of_operation`, `Storage`, columnas de año (cabeceras 1900–2200) y opcionalmente `Time indipendent variables`; crea/obtiene IDs de catálogo (Region, Technology, Fuel, etc.) con `_get_or_create_*` según lo que aparezca en la fila; escribe en `osemosys_param_value` una fila por columna **año** con valor solo si `abs(year_value) > 0` (las celdas en 0 no se guardan), y una fila por **Time indipendent variables** si existe y es no nula.

**Qué no hace la app en la importación (paso a paso del notebook, tal cual):**

| Paso del notebook | ¿Lo hace la app en la importación fila a fila? |
|---|---|
| Reducir timeslices con **div** (submuestreo) | No. Lee todas las filas tal cual. |
| Agregar CapacityFactor (media) o YearSplit (suma) por grupo | No. |
| Filtrar parámetros por pertenencia a sets predefinidos | No. Los sets se construyen al vuelo con lo que aparece en la hoja. |
| **Completar matrices** (rellenar con 0 todas las combinaciones) | No. Solo persiste valores no nulos. |
| **process_and_save_emission_ratios** (emisión por combustible de entrada) | No. EmissionActivityRatio queda como en el Excel. |

### Carga para el modelo (`parameters_loader`)

- **Dónde**: `load_from_db` en `app/simulation/core/parameters_loader.py`.
- **Qué hace**: lee `parameter_value` y `osemosys_param_value` del escenario; construye `demand_rows`, `supply_rows` y un diccionario `params` (nombre de parámetro normalizado → clave → valor); si faltan filas de oferta para (region, technology, year), genera filas "sintéticas" a partir de parámetros como `OutputActivityRatio`, `InputActivityRatio`, `CapacityFactor`, `ResidualCapacity`, etc.; asigna costos variables desde `params["variablecost"]` o un proxy por (region, year).

El modelo de la app es **simplificado** (sets `SUPPLY`, `DEMAND_KEY`, `TECH_KEY`; variables `dispatch`, `unmet`, `new_capacity`, `annual_emissions`), no el OSeMOSYS abstracto completo. Los parámetros se usan en restricciones y objetivo según este esquema reducido.

### Emisiones en la app

- **Dónde**: `constraints_emissions.py`.
- **Qué hace**: agrega `EmissionActivityRatio` por (region, technology, year) tomando el **máximo** sobre los índices (emisión, modo, etc.) y usa ese valor en la restricción de emisiones anuales.

!!! warning "No se aplica el ajuste de emisión a la entrada"
    No se aplica el paso del notebook que mezcla `EmissionActivityRatio` con `InputActivityRatio`; en la app se usa el valor "crudo" del Excel (o de la BD).

### Tabla resumen: ¿paridad de procesamiento?

| Tratamiento | Notebook | App | ¿Puede afectar resultados? |
|---|---|---|---|
| Lectura Excel Parameters | Sí, por parámetro → CSV | Sí, fila a fila → BD | No (misma fuente) |
| div / reducción de timeslices | Sí (96/div) | No | Solo si en el notebook se usa div > 1; entonces el notebook agrega, la app no |
| Filtrado por sets | Sí (solo índices en sets) | No (sets = lo que aparece) | Posible si el Excel tiene filas "fuera de set" que el notebook elimina |
| Completar matrices con 0 | Sí | No | En Pyomo los params suelen tener default 0; puede haber diferencias si el modelo usa explícitamente "solo índices presentes" |
| Emisión a la entrada (Emission × Input) | Sí (`process_and_save_emission_ratios`) | No | Sí, en escenarios donde ese ajuste cambie mucho los factores |
| Modelo | OSeMOSYS completo (DataPortal) | Modelo simplificado (supply/demand, dispatch, capacity, emissions) | La formulación es distinta; para el SAND probado las métricas coinciden |

### Paridad exacta implementada en la app

La app aplica **por defecto** (al importar la hoja Parameters/SAND) el preprocesamiento tipo notebook: sets canónicos, filtrado por sets, completar matrices (`InputActivityRatio`, `OutputActivityRatio`, `EmissionActivityRatio`, `VariableCost`) y emisiones a la entrada. Módulo `app/services/sand_notebook_preprocess.py`; opción `notebook_parity=True` en `import_xlsm` y en `POST /official-import/xlsm`. El div/reducción de timeslices **no está implementado**.

- **Para el caso probado (SAND_04_02_2026, glpk)**: sí, en la práctica. Las métricas comparadas (`objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio`) coinciden; la combinación importación + modelo simplificado reproduce bien ese resultado.
- **En general**: con `notebook_parity=True` (por defecto) ya se aplican filtrado por sets, completar matrices y emisiones a la entrada. Si en el notebook se usa **div** > 1 (reducción de timeslices), eso aún no está implementado. Mientras no se use `div`, no se dependa de "filas fuera de set" y las emisiones a la entrada no cambien mucho el `EmissionActivityRatio`, es esperable que los resultados sigan siendo muy parecidos.

!!! tip "Recomendación"
    Seguir usando `compare_results.py` al cambiar de escenario o de Excel para comprobar que las métricas sigan dentro de la tolerancia esperada. Ver [Comparar resultados: app vs notebook](comparar-resultados.md).

---

## Invariantes de paridad implementados

- Timeslice agregado a 1 en el flujo app (equivalente al notebook con `div=1`).
- Filtrado por sets canónicos para evitar dimensiones fuera de corrida.
- Exclusión de años con `YearSplit=0`.
- Corrección de límites lower/upper invertidos por precisión flotante.
- Carga de DataPortal robusta ante CSVs vacíos.
- Dedupe de parámetros por clave de índice antes de crear la instancia.

## Resumen para paridad app vs notebook

Para que la app reproduzca los mismos resultados que el notebook:

1. **Misma fuente**: misma hoja (Parameters) y mismo Excel SAND (o equivalente).
2. **Misma lógica SAND → CSV**: misma identificación de años y sets; mismo `div` y mismo submuestreo (`index % div == 0`) en parámetros con TIMESLICE; misma regla para CapacityFactor (media) vs otros (suma) en agregación por grupo.
3. **Mismo filtrado**: eliminar filas de parámetros cuyos índices no estén en los sets.
4. **Mismas matrices completadas**: `InputActivityRatio`, `OutputActivityRatio`, `EmissionActivityRatio`, `VariableCost` (y Storage si aplica) con producto cartesiano y relleno con 0.
5. **Mismo procesamiento de emisiones**: `process_and_save_emission_ratios` con `InputActivityRatio` para actualizar `EmissionActivityRatio`.
6. **Misma carga en el modelo**: mismos CSV (o mismos datos en memoria) y mismos índices en `data.load(...)`.

## Pruebas recomendadas de paridad

1. Ejecutar la simulación de la app para el/los escenario(s) de prueba.
2. Exportar el JSON de referencia del notebook con `objective_value`, `coverage_ratio`, `total_demand`, `total_dispatch`, `total_unmet`.
3. Comparar:

   ```bash
   python scripts/compare_results.py --ref tmp/referencia_notebook.json --actual tmp/sand_04_02_2026_result.json --tolerance 1e-6
   ```

4. Para comparación de tablas completas entre corridas:

   ```bash
   python scripts/run_parity_test.py --tolerance 1e-6
   ```

Ver también [Comparar resultados: app vs notebook](comparar-resultados.md) para el detalle paso a paso de cómo leer e interpretar esas comparaciones.
