# Motor de simulación OSeMOSYS

Esta página documenta el motor de optimización: cómo está definido el modelo matemático, cómo se resuelve con Pyomo/HiGHS, cómo se manejan la infactibilidad y los errores, y cómo se procesan y visualizan los resultados. Para el mapa de módulos y los flujos operacionales del job (submit, cancelación, contrato de resultado), ver [Visión general (C4)](overview.md).

!!! note "Tipo de modelo"
    Formulación **LP** implementada en Pyomo, inspirada en la estructura OSeMOSYS y extendida por bloques (core, emisiones, reserve margin, RE target, storage, UDC). No se replica 1:1 toda la formulación canónica OSeMOSYS: se prioriza una versión operacional y extensible en backend productivo.

## Cómo se construyen los datos de entrada

Origen:

- SQLAlchemy `select` sobre `parameter_value`, `osemosys_param_value` y catálogos (`parameter`, `technology`, `fuel`).

Transformación:

- Normalización de nombres de parámetro (`lower` alfanumérico).
- Agregación por claves multidimensionales.
- Asignación de costos por fallback regional/anual cuando falta un costo específico.

Validaciones actuales:

- Coerción a `float`.
- Truncado de valores negativos en demanda/oferta a no-negativos en el loader.

!!! warning "Supuestos implícitos"
    Los parámetros faltantes usan defaults operativos (`1.0`, `0.0` o `inf` según el caso) y varias restricciones avanzadas están aproximadas (proxy), sin expandir completamente la estructura temporal canónica.

## Estructura del modelo

### Sets (actuales)

- `SUPPLY` (índices de filas de oferta).
- `DEMAND_KEY` (`region`, `year`).
- `TECH_KEY` (`region`, `technology`, `year`).

Definidos en `app/simulation/core/variables.py`.

### Parámetros

Se cargan desde:

- `parameter_value` (base legado y demanda/oferta).
- `osemosys_param_value` (multidimensional).

Parámetros usados actualmente (normalizados por nombre):

- `ResidualCapacity`
- `CapacityFactor`
- `AvailabilityFactor`
- `CapacityToActivityUnit`
- `TotalAnnualMaxCapacity`
- `TotalAnnualMaxCapacityInvestment`
- `VariableCost`
- `CapitalCost`
- `FixedCost`
- `EmissionActivityRatio`
- `AnnualEmissionLimit`
- `ReserveMargin`
- `REMinProductionTarget`
- `RETagTechnology`
- `TechnologyToStorage`
- `TechnologyFromStorage`
- `UDCConstant`

### Variables de decisión

- `dispatch[s] >= 0`
- `unmet[d] >= 0`
- `new_capacity[t] >= 0`
- `annual_emissions[d] >= 0`
- `reserve_margin_gap[d] >= 0`
- `re_target_gap[d] >= 0`

### Función objetivo

Minimiza (implementada en `app/simulation/core/objective.py`):

- costo variable de despacho;
- costo de inversión;
- costo fijo;
- penalización por demanda no servida;
- penalización por brecha de reserve margin;
- penalización por brecha de RE target;
- penalización de emisiones.

### Restricciones principales

- **Core** (`constraints_core.py`)
  - cota por fila de despacho (`DispatchRowCap`);
  - capacidad por tecnología-año-región;
  - límite máximo de capacidad total y nueva;
  - balance de demanda con variable de déficit.
- **Emisiones** (`constraints_emissions.py`)
  - definición de emisiones anuales;
  - tope anual de emisiones.
- **Reserve/RE** (`constraints_reserve_re.py`)
  - cumplimiento de reserva con variable de brecha;
  - cumplimiento de target renovable con variable de brecha.
- **Storage** (`constraints_storage.py`)
  - restricción proxy activada si existen parámetros de storage.
- **UDC** (`constraints_udc.py`)
  - restricción proxy por `UDCConstant`.

### Personalizaciones del modelo

- **Penalizaciones explícitas**:
  - `unmet_penalty = 1000`
  - `reserve_gap_penalty = 500`
  - `re_gap_penalty = 500`
- **Simplificaciones**:
  - storage y UDC implementados como restricciones proxy;
  - emisiones agregadas por (`region`, `technology`, `year`) con simplificación sobre modos/emisiones.
- **Cotas numéricas de estabilidad**:
  - `dispatch <= 5 * base_value` para evitar explosión numérica.

## Resolución con Pyomo — solvers soportados

El motor resuelve el modelo LP/MILP a través de Pyomo, que actúa como capa de abstracción sobre distintos solvers intercambiables. El catálogo `solver` (ver [Backend](backend.md)) permite seleccionar, por escenario/simulación, cuál de estos usar:

- **HiGHS** (`appsi_highs`) — solver open-source por defecto, sin licencia requerida.
- **Gurobi** — solver comercial de alto desempeño para LP/MILP grandes.
- **CPLEX** — solver comercial de IBM, alternativa habitual en optimización energética.
- **Mosek** — solver comercial con buen desempeño en problemas cónicos/LP de gran escala.

Notas generales:

- **Motivación de tener varios solvers**: HiGHS cubre el caso por defecto sin costo de licencia; los solvers comerciales (Gurobi/CPLEX/Mosek) se usan cuando el tamaño/complejidad de la instancia lo justifica o cuando ya se cuenta con licencia institucional.
- **Parámetros actuales**: ejecución por defecto por solver (sin tuning avanzado explícito en código).
- **Naturaleza de la carga**: fuertemente **CPU-bound** durante `solve`; I/O-bound principalmente en la carga/escritura de datos y artefactos.
- **Runner**: `app/simulation/core/model_runner.py` ensambla el modelo, resuelve vía `pyo.SolverFactory(<solver_seleccionado>)` (`appsi_highs`, `gurobi`, `cplex` o `mosek` según configuración) y extrae resultados.

Cómo agregar o cambiar el solver por defecto:

1. Confirmar que el nombre del solver está registrado en el catálogo `solver`.
2. Ajustar `pyo.SolverFactory(...)` en `model_runner.py` si se cambia el default.
3. Asegurar que la licencia/binario del solver comercial (Gurobi/CPLEX/Mosek) esté disponible en el contenedor/host donde corre el worker.
4. Revalidar factibilidad, tiempos y tolerancias numéricas — los resultados pueden variar levemente entre solvers en problemas degenerados.

### Rendimiento y escalabilidad

La complejidad crece con:

- número de filas de oferta (`SUPPLY`);
- años activos;
- tecnologías por región;
- bloques adicionales activados (emisiones, reserve/RE, storage, UDC).

Cuellos de botella típicos:

- solve LP;
- cardinalidad de constraints al aumentar la granularidad temporal.

Impacto esperado: más tecnologías y periodos incrementan el tamaño del problema de forma casi lineal/superlineal según las combinaciones dimensionales; las restricciones proxy actuales evitan un crecimiento explosivo en storage/UDC, pero reducen la fidelidad teórica.

## Infactibilidad y manejo de errores

- Si falla el solver o el pipeline:
  - `simulation_job.status = FAILED`;
  - se persiste `error_message`;
  - se agrega un evento `ERROR` en `simulation_job_event`.
- **Si el modelo es infactible**: se reporta en `solver_status` (terminación del solver) y **debe tratarse como resultado inválido para el negocio** — no como un resultado óptimo degradado.
- Si el artefacto no existe: `GET /simulations/{job_id}/result` devuelve un error controlado (`404`).
- Si el usuario no tiene acceso al escenario/job: `403` o `404` según el contexto.

!!! warning "Infactibilidad ≠ resultado válido"
    Un `solver_status` distinto de éxito no debe interpretarse ni mostrarse como una corrida exitosa parcial. La capa de negocio debe tratar explícitamente ese caso como inválido.

## Riesgos y limitaciones actuales

- No toda la formulación OSeMOSYS canónica está implementada 1:1.
- Storage y UDC están en versión proxy (riesgo de desviación conceptual).
- Los defaults operativos pueden ocultar faltantes de datos.
- El resultado depende de la consistencia semántica de `param_name` en `osemosys_param_value`.
- El tuning del solver aún es básico (sin estrategia avanzada por tamaño de instancia).

## Cómo modificar el modelo

**Agregar una nueva tecnología**

1. Crear el registro en el catálogo `technology`.
2. Cargar `parameter_value` y/o `osemosys_param_value` asociados.
3. Verificar que el loader mapea la nueva dimensión correctamente (`parameters_loader.py`).
4. Re-ejecutar la corrida y validar resultados en `/simulations/{id}/result`.

**Modificar una restricción**

1. Ubicar el bloque correspondiente en `app/simulation/core/constraints_*.py`.
2. Ajustar la ecuación Pyomo y mantener nombres de constraints descriptivos.
3. Ejecutar el benchmark de paridad (`scripts/validate_simulation_parity.py`).

**Cambiar el horizonte temporal**

1. Ajustar los datos `year` en los insumos del escenario.
2. Verificar la cobertura de parámetros por año requerido.
3. Validar el crecimiento de cardinalidad y el tiempo de solve.

**Agregar una nueva variable**

1. Declarar la variable en `variables.py`.
2. Integrarla en las constraints y en el objetivo (si aplica).
3. Exportarla en `model_runner.py` para observabilidad y artefacto.

**Ajustar la función objetivo**

1. Modificar `objective.py`.
2. Documentar unidades y signo de los nuevos términos.
3. Actualizar benchmarks y tolerancias.

### Prueba de reproducibilidad

Para comprobar que dos corridas idénticas del mismo escenario dan el mismo resultado (determinismo del pipeline):

```bash
docker compose exec api python scripts/run_parity_test.py
```

Ejecuta dos veces la simulación de un escenario de referencia y compara; sale con 0 si los resultados son idénticos.

---

## Procesamiento de resultados y visualización

El procesamiento de resultados mueve el peso computacional del cliente (navegador) al servidor (backend Python):

1. **Simulación**: tras la resolución del modelo por el solver (HiGHS o GLPK), el sistema guarda los datos crudos en PostgreSQL, incluyendo variables intermedias calculadas y resultados paramétricos en la tabla `osemosys_output_param_value`.
2. **Petición del cliente**: el frontend en React interactúa mediante `simulationApi` para solicitar datos en endpoints específicos (ej. `/visualizations/{job_id}/chart-data` o `/visualizations/chart-data/compare`).
3. **Procesamiento backend**: `app/visualization/chart_service.py` lee las configuraciones desde `configs.py`. Mediante Pandas, realiza:
   - agrupación por tecnologías, combustibles o años (`groupby`);
   - filtros por "Pico", "Valle" o "Acumulado" mediante el sub-filtro correspondiente;
   - conversión de unidades dinámicas (ej. de PJ a diferentes magnitudes);
   - asignación de una paleta de colores oficial dictada por `colors.py` para asegurar consistencia regional y tecnológica.
4. **Cache**: el resultado del DataFrame, empaquetado como objeto Pydantic (`ChartDataResponse`), se cachea en **Redis** para responder instantáneamente ante peticiones con los mismos parámetros.
5. **Renderizado frontend**: el frontend (React) toma la estructura limpia enviada y la traduce en componentes interactivos de Highcharts. Componentes como `HighchartsChart.tsx` o `CompareChart.tsx` quedan puramente enfocados a la capa visual, sin operaciones intensivas en el DOM.

### Comparación de escenarios

Cuando se habilita la comparación (`CompareChart.tsx`), el backend extrae en paralelo los escenarios solicitados, concatena y alinea los sub-DataFrames, y entrega una estructura `CompareChartResponse` con múltiples subplots que Highcharts dibuja como gráficas de columnas sincronizadas.

### Herramientas de exportación

El dashboard incluye una vía de rescate que comprime toda la selección de gráficas SVG de un escenario a alta calidad vía la librería Matplotlib, generada del lado del servidor. El usuario puede descargarlas empaquetadas en un único `.zip`.

Para la configuración administrable de series (colores, orden, visibilidad) que consume este pipeline, ver [Configuración de series de gráficas](series-graficas.md).
