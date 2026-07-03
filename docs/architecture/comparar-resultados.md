# Comparar resultados: app vs notebook

Después de ejecutar la misma simulación (mismo Excel, hoja Parameters, solver glpk) en la **app** y en el **notebook**, esta página explica cómo comparar los resultados.

Para el detalle de por qué (y cuándo) los tratamientos de datos y de modelo de la app y el notebook son equivalentes, ver [Paridad Notebook vs App](paridad-notebook.md).

## Dónde está el resultado de la app

- **En la UI**: Simulaciones → fila de la ejecución (ej. ID 12, Escenario 5) → botón **"Abrir"** en la columna **Resultados**. Ahí se abre o descarga el JSON del resultado.
- **En disco (script SAND)**: si se usó `.\scripts\run-sand-test.ps1`, el mismo resultado se copia a `backend/tmp/sand_04_02_2026_result.json` en el host.
- **En el contenedor (por job)**: el backend guarda cada resultado en `tmp/simulation-results/simulation_job_{id}.json` (ej. job 12 → `simulation_job_12.json`).

!!! note "Mismo resultado, distintas rutas"
    El resultado que se ve al hacer clic en **"Abrir"** (ejecución 12, escenario 5) es el mismo que el de `sand_04_02_2026_result.json` si la corrida fue con el mismo escenario SAND_04_02_2026.

## Qué tiene el resultado de la app

El archivo `backend/tmp/sand_04_02_2026_result.json` (o el que genere `run-sand-test.ps1`) contiene, entre otras cosas:

| Clave | Significado |
|---|---|
| `objective_value` | Valor de la función objetivo del modelo |
| `total_demand` | Demanda total (suma en el horizonte) |
| `total_dispatch` | Despacho total (generación que cubre la demanda) |
| `total_unmet` | Demanda no cubierta |
| `coverage_ratio` | `total_dispatch` / `total_demand` (1.0 = 100 % cubierto) |
| `solver_status` | Estado del solver (p. ej. `"optimal"`) |
| `dispatch` | Tabla detallada por región, año, tecnología (despacho) |
| `new_capacity` | Tabla de nueva capacidad por tecnología y año |
| `unmet_demand` | Tabla de demanda no cubierta por región y año |
| `annual_emissions` | Emisiones anuales por región y año |

## Comparación rápida (métricas principales)

### En el notebook Jupyter

Al terminar de resolver el modelo (solver glpk), en el notebook se suele tener algo como:

- **Función objetivo**: `value(model.OBJ)` o similar.
- **Demanda total**: suma de la demanda en el horizonte.
- **Despacho total**: suma del despacho (producción).
- **Demanda no cubierta**: si el modelo la reporta.

Anotar estos cuatro números (o cinco con `coverage_ratio`): `objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio` (opcional; si no, se puede calcular como `total_dispatch / total_demand`).

### En la app

Abrir `backend/tmp/sand_04_02_2026_result.json` y mirar las mismas claves al inicio del JSON:

```json
{
  "objective_value": 126980.25005481177,
  "total_demand": 63490.12500633663,
  "total_dispatch": 126980.25001267325,
  "total_unmet": 0.0,
  "coverage_ratio": 1.0
}
```

### Comparar a mano

- Si **objective_value**, **total_demand**, **total_dispatch**, **total_unmet** y **coverage_ratio** son iguales (o casi iguales, p. ej. diferencias en decimales por redondeo), los resultados son equivalentes.
- Si hay diferencias grandes, revisar que en ambos se haya usado: mismo archivo Excel, hoja **Parameters**, mismo solver (**glpk**).

## Comparación con el script `compare_last_with_notebook.py` (recomendado)

Desde `backend/` se puede ejecutar:

```powershell
python scripts/compare_last_with_notebook.py
```

- Si **no existe** `tmp/referencia_notebook_sand.json` (ni `referencia_notebook.json`), el script imprime las **métricas del último resultado de la app** para compararlas a mano con el notebook, e indica cómo crear la referencia.
- Si **existe** el archivo de referencia, el script compara automáticamente y devuelve `[OK]` o `[FAIL]`.

El script usa como "último resultado" el más reciente entre `tmp/sand_04_02_2026_result.json`, `tmp/app_result_job*.json` y `tmp/simulation-results/simulation_job_*.json`.

### Paso 1: crear el JSON de referencia desde el notebook

En el notebook, al final (después de resolver), se puede hacer algo así (ajustando los nombres de variables al propio código):

```python
import json
ref = {
    "objective_value": float(value(model.OBJ)),   # o la variable que tenga el objetivo
    "total_demand": float(tu_suma_demanda),       # suma de demanda en el horizonte
    "total_dispatch": float(tu_suma_despacho),    # suma de despacho/producción
    "total_unmet": float(tu_suma_unmet),          # 0 si todo cubierto
    "coverage_ratio": float(tu_suma_despacho / tu_suma_demanda) if tu_suma_demanda else 0.0
}
with open("referencia_notebook.json", "w") as f:
    json.dump(ref, f, indent=2)
```

Guardar ese archivo en `backend/tmp/referencia_notebook_sand.json` (o `referencia_notebook.json`). Así `compare_last_with_notebook.py` lo detectará solo.

### Paso 2: ejecutar la comparación

Desde `backend/`:

```powershell
python scripts/compare_last_with_notebook.py
```

O con rutas explícitas:

```powershell
python scripts/compare_results.py --ref tmp/referencia_notebook_sand.json --actual tmp/sand_04_02_2026_result.json --tolerance 1e-4
```

**Salida esperada:**

- muestra **Métricas de referencia** (las del notebook) y **Métricas actuales** (las de la app);
- si están dentro de la tolerancia: `[OK] Resultados dentro de la tolerancia.`;
- si no: `[FAIL] Alguna métrica supera la tolerancia.`, indicando en qué métricas hay diferencia.

## Comparar tablas (opcional)

Si además de las métricas agregadas se quieren comparar las tablas:

- **dispatch**: despacho por región, año, tecnología.
- **new_capacity**: nueva capacidad por tecnología y año.
- **unmet_demand**: demanda no cubierta por región y año.
- **annual_emissions**: emisiones por región y año.

El script `compare_results.py` solo compara las cinco métricas anteriores. Para comparar tablas habría que:

1. Exportar desde el notebook esas tablas a CSV o JSON (misma estructura que en la app: región, año, tecnología, valor).
2. Comparar a mano o con un script propio (p. ej. con pandas: cargar ambos JSON/CSV, hacer merge por claves y restar valores).

!!! tip "Si las métricas coinciden, las tablas probablemente también"
    Si en el notebook y en la app las **métricas** (`objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio`) coinciden, es muy probable que las tablas también coincidan, porque esas métricas son agregados de esas tablas.

## Resumen

| Qué comparar | Dónde en la app | Cómo |
|---|---|---|
| Métricas principales | Inicio de `sand_04_02_2026_result.json`: `objective_value`, `total_demand`, `total_dispatch`, `total_unmet`, `coverage_ratio` | Anotar los mismos números del notebook y comparar, o usar `compare_results.py` con un JSON de referencia del notebook |
| Tablas detalladas | Arrays `dispatch`, `new_capacity`, `unmet_demand`, `annual_emissions` en el mismo JSON | Exportar desde el notebook a JSON/CSV y comparar por filas (opcional) |

Si las cinco métricas son iguales (o dentro de una tolerancia pequeña, p. ej. 1e-4), se puede considerar que los resultados de la app y del notebook son equivalentes para ese mismo input (Excel Parameters, solver glpk).
