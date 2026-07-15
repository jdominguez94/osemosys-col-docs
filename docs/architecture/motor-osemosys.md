# Motor de simulación OSeMOSYS

Esta página documenta el motor de optimización. Explica cómo está definido el modelo matemático, cómo se resuelve con Pyomo y HiGHS, cómo se manejan la infactibilidad y los errores, y cómo se procesan y visualizan los resultados. Para el mapa de módulos y los flujos operacionales del job (submit, cancelación, contrato de resultado), ver [Visión general (C4)](overview.md).

!!! note "Tipo de modelo"
    Formulación **LP** implementada en Pyomo, inspirada en la estructura OSeMOSYS y extendida por bloques (core, emisiones, reserve margin, RE target, storage, UDC). No replica de forma exacta toda la formulación canónica OSeMOSYS. Prioriza una versión operacional y extensible pensada para un backend productivo.

## Cómo se construyen los datos de entrada

Los datos de entrada salen de consultas SQLAlchemy `select` sobre `parameter_value`, `osemosys_param_value` y los catálogos `parameter`, `technology` y `fuel`.

Después se transforman. Se normalizan los nombres de parámetro a minúsculas alfanuméricas, se agregan por claves multidimensionales y, cuando falta un costo específico, se le asigna un costo de respaldo regional o anual.

Como validación, los valores se convierten a `float` y el loader trunca a no negativos los valores negativos que aparecen en demanda u oferta.

!!! warning "Supuestos implícitos"
    Los parámetros faltantes usan defaults operativos (`1.0`, `0.0` o `inf` según el caso) y varias restricciones avanzadas están aproximadas (proxy), sin expandir completamente la estructura temporal canónica.

## Estructura del modelo

### Sets (actuales)

El modelo actual define tres sets. `SUPPLY` recoge los índices de filas de oferta, `DEMAND_KEY` combina `region` y `year`, y `TECH_KEY` combina `region`, `technology` y `year`. Los tres están definidos en `app/simulation/core/variables.py`.

### Parámetros

Los parámetros se cargan desde dos tablas. `parameter_value` guarda la base legado y los datos de demanda y oferta, mientras que `osemosys_param_value` guarda los parámetros multidimensionales.

Los parámetros usados actualmente (normalizados por nombre) son `ResidualCapacity`, `CapacityFactor`, `AvailabilityFactor`, `CapacityToActivityUnit`, `TotalAnnualMaxCapacity`, `TotalAnnualMaxCapacityInvestment`, `VariableCost`, `CapitalCost`, `FixedCost`, `EmissionActivityRatio`, `AnnualEmissionLimit`, `ReserveMargin`, `REMinProductionTarget`, `RETagTechnology`, `TechnologyToStorage`, `TechnologyFromStorage` y `UDCConstant`.

### Variables de decisión

```
dispatch[s] >= 0
unmet[d] >= 0
new_capacity[t] >= 0
annual_emissions[d] >= 0
reserve_margin_gap[d] >= 0
re_target_gap[d] >= 0
```

### Función objetivo

La función objetivo, implementada en `app/simulation/core/objective.py`, minimiza la suma del costo variable de despacho, el costo de inversión, el costo fijo y las penalizaciones por demanda no servida, por brecha de reserve margin, por brecha de RE target y por emisiones.

### Restricciones principales

El bloque **Core** (`constraints_core.py`) impone la cota por fila de despacho (`DispatchRowCap`), la capacidad por tecnología, año y región, el límite máximo de capacidad total y nueva, y el balance de demanda con su variable de déficit.

El bloque **Emisiones** (`constraints_emissions.py`) define las emisiones anuales y su tope anual.

El bloque **Reserve/RE** (`constraints_reserve_re.py`) cubre el cumplimiento de reserva y el cumplimiento del target renovable, cada uno con su propia variable de brecha.

El bloque **Storage** (`constraints_storage.py`) activa una restricción proxy cuando existen parámetros de storage.

El bloque **UDC** (`constraints_udc.py`) aplica una restricción proxy basada en `UDCConstant`.

### Personalizaciones del modelo

El modelo trae varias personalizaciones. Las penalizaciones explícitas son `unmet_penalty = 1000`, `reserve_gap_penalty = 500` y `re_gap_penalty = 500`. Como simplificación, storage y UDC se implementan con restricciones proxy y las emisiones se agregan por `region`, `technology` y `year`, con una simplificación sobre modos y tipos de emisión. Y como cota numérica de estabilidad, `dispatch` no puede superar `5 * base_value`, lo que evita que el modelo explote numéricamente.

## Solvers soportados por Pyomo

El motor resuelve el modelo LP o MILP a través de Pyomo, que actúa como capa de abstracción sobre varios solvers intercambiables. El catálogo `solver` (ver [Backend](backend.md)) permite elegir, por escenario o simulación, cuál usar.

**HiGHS** (`appsi_highs`) es el solver open source por defecto y no requiere licencia. **Gurobi** es un solver comercial de alto desempeño para instancias LP/MILP grandes. **CPLEX**, de IBM, es una alternativa comercial habitual en optimización energética. **Mosek**, también comercial, rinde bien en problemas cónicos y LP de gran escala.

¿Por qué tener varios solvers? Porque HiGHS cubre el caso por defecto sin costo de licencia, y los solvers comerciales (Gurobi, CPLEX, Mosek) entran cuando el tamaño o la complejidad de la instancia lo justifica, o cuando ya existe una licencia institucional disponible.

Por ahora cada solver corre con su configuración por defecto, sin tuning avanzado explícito en el código. La carga es principalmente de CPU durante el `solve`, y de entrada/salida durante la carga y escritura de datos y artefactos.

El runner (`app/simulation/core/model_runner.py`) ensambla el modelo, lo resuelve vía `pyo.SolverFactory(<solver_seleccionado>)` (usando `appsi_highs`, `gurobi`, `cplex` o `mosek` según la configuración) y extrae los resultados.

Cómo agregar o cambiar el solver por defecto

1. Confirmar que el nombre del solver está registrado en el catálogo `solver`.
2. Ajustar `pyo.SolverFactory(...)` en `model_runner.py` si se cambia el default.
3. Asegurar que la licencia o el binario del solver comercial (Gurobi, CPLEX, Mosek) esté disponible en el contenedor o host donde corre el worker.
4. Revalidar factibilidad, tiempos y tolerancias numéricas, porque los resultados pueden variar levemente entre solvers en problemas degenerados.

### Rendimiento y escalabilidad

La complejidad del modelo crece con el número de filas de oferta (`SUPPLY`), los años activos, las tecnologías por región y los bloques adicionales que estén activados (emisiones, reserve o RE, storage, UDC).

Los cuellos de botella típicos son el propio `solve` del LP y la cardinalidad de las constraints cuando aumenta la granularidad temporal.

Más tecnologías y más periodos incrementan el tamaño del problema de forma casi lineal, y a veces superlineal, según cómo se combinen las dimensiones. Las restricciones proxy actuales evitan que storage y UDC exploten en tamaño, aunque a cambio pierden fidelidad teórica.

## Infactibilidad y manejo de errores

Si falla el solver o el pipeline, `simulation_job.status` pasa a `FAILED`, se persiste el `error_message` y se agrega un evento `ERROR` en `simulation_job_event`.

Si el modelo resulta infactible, eso queda reportado en `solver_status` (la terminación del solver) y **debe tratarse como un resultado inválido para el negocio**, nunca como un resultado óptimo degradado.

Si el artefacto no existe, `GET /simulations/{job_id}/result` devuelve un error controlado (`404`). Y si el usuario no tiene acceso al escenario o al job, la respuesta es `403` o `404` según el contexto.

!!! warning "Infactibilidad ≠ resultado válido"
    Un `solver_status` distinto de éxito no debe interpretarse ni mostrarse como una corrida exitosa parcial. La capa de negocio debe tratar explícitamente ese caso como inválido.

## Riesgos y limitaciones actuales

Todavía hay riesgos y limitaciones que vale la pena tener presentes. No toda la formulación canónica de OSeMOSYS está implementada de forma exacta. Storage y UDC siguen en versión proxy, con el riesgo de desviarse conceptualmente del modelo teórico. Los defaults operativos pueden esconder datos faltantes sin que se note. El resultado depende de que `param_name` mantenga consistencia semántica dentro de `osemosys_param_value`. Y el tuning del solver todavía es básico, sin una estrategia avanzada según el tamaño de la instancia.

## Cómo modificar el modelo

**Agregar una nueva tecnología**

1. Crear el registro en el catálogo `technology`.
2. Cargar `parameter_value` y/o `osemosys_param_value` asociados.
3. Verificar que el loader mapea la nueva dimensión correctamente (`parameters_loader.py`).
4. Volver a ejecutar la corrida y validar resultados en `/simulations/{id}/result`.

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

Para comprobar que dos corridas idénticas del mismo escenario dan el mismo resultado (determinismo del pipeline), corre este comando.

```bash
docker compose exec api python scripts/run_parity_test.py
```

Ejecuta dos veces la simulación de un escenario de referencia y compara los resultados. El script sale con código 0 si son idénticos.

## Procesamiento de resultados y visualización

El procesamiento de resultados mueve el peso computacional del cliente (el navegador) al servidor (el backend en Python), en cinco pasos.

1. **Simulación**. Tras resolver el modelo con el solver (HiGHS o GLPK), el sistema guarda los datos crudos en PostgreSQL, incluidas las variables intermedias calculadas y los resultados paramétricos, en la tabla `osemosys_output_param_value`.
2. **Petición del cliente**. El frontend en React usa `simulationApi` para pedir datos a endpoints específicos, por ejemplo `/visualizations/{job_id}/chart-data` o `/visualizations/chart-data/compare`.
3. **Procesamiento en el backend**. `app/visualization/chart_service.py` lee las configuraciones de `configs.py` y, con Pandas, agrupa por tecnologías, combustibles o años (`groupby`), aplica los filtros "Pico", "Valle" o "Acumulado" según el subfiltro elegido, convierte las unidades de forma dinámica (por ejemplo de PJ a otras magnitudes) y asigna la paleta de colores oficial que define `colors.py`, para mantener consistencia regional y tecnológica.
4. **Cache**. El resultado, empaquetado como un objeto Pydantic (`ChartDataResponse`), se guarda en **Redis** para responder de inmediato cuando llega una petición con los mismos parámetros.
5. **Renderizado en el frontend**. React toma la estructura limpia que recibe y la traduce en componentes interactivos de Highcharts. Componentes como `HighchartsChart.tsx` o `CompareChart.tsx` se dedican solo a la capa visual, sin operaciones pesadas sobre el DOM.

### Comparación de escenarios

Cuando se habilita la comparación (`CompareChart.tsx`), el backend extrae en paralelo los escenarios solicitados, concatena y alinea los DataFrames parciales de cada uno, y entrega una estructura `CompareChartResponse` con múltiples subplots que Highcharts dibuja como gráficas de columnas sincronizadas.

### Herramientas de exportación

El dashboard incluye una vía de rescate que comprime toda la selección de gráficas SVG de un escenario a alta calidad vía la librería Matplotlib, generada del lado del servidor. El usuario puede descargarlas empaquetadas en un único `.zip`.

Para la configuración administrable de series (colores, orden, visibilidad) que consume este pipeline, ver [Configuración de series de gráficas](series-graficas.md).
