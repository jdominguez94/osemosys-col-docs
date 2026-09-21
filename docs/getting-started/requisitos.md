# Requisitos y solvers

Antes de usar OSeMOSYS Colombia conviene distinguir dos perfiles. Quien **usa una instancia ya desplegada** para crear escenarios y correr simulaciones, y quien **instala o aloja la plataforma** para un equipo. Los requisitos son distintos.

## Para usar la plataforma (analistas)

Si ya tienes acceso a una instancia desplegada de OSeMOSYS Colombia (por ejemplo, la de tu institución), solo necesitas:

- Un **navegador web moderno** (Chrome, Edge o Firefox, en sus últimas versiones). No hace falta instalar nada localmente.
- **Excel o LibreOffice Calc**, si vas a preparar o revisar catálogos y escenarios en formato Excel/SAND antes de subirlos. Ver [Carga de datos Excel/SAND](../user-guide/carga-excel-sand.md).
- Conexión estable a la red donde está desplegada la instancia (intranet institucional o internet, según el despliegue).

No necesitas Docker, Python ni conocimientos de programación para este perfil de uso.

## Para instalar o desplegar la plataforma

Este perfil corresponde a quien monta la aplicación para un equipo. El procedimiento completo está en [Instalación](installation.md); en software se resume en Docker + Docker Compose, y opcionalmente `task` y Node.js.

En hardware, la exigencia depende del tamaño y la granularidad de los escenarios que se vayan a simular:

| Escenario | CPU | RAM | Disco |
|---|---|---|---|
| Nacional agregado, 1 timeslice | 2-4 núcleos | 8 GB | 20 GB libres |
| Nacional o regional con timeslices desagregados | 4+ núcleos | 16 GB o más | 40 GB o más |

!!! note "Estos valores son orientativos"
    El tamaño real del problema de optimización depende del número de tecnologías, combustibles, timeslices y años modelados en cada escenario, y de cuántos analistas simulan a la vez. Para escenarios muy grandes o uso concurrente frecuente, conviene dimensionar el servidor por encima de estos mínimos.

## Solvers de optimización

Cada simulación resuelve un problema de programación lineal. La plataforma soporta varios solvers, seleccionables al lanzar la simulación (ver [Primera simulación](first-simulation.md)):

| Solver | Tipo | Licencia | Notas |
|---|---|---|---|
| **HiGHS** | Código abierto | Ninguna | Solver por defecto. No requiere configuración adicional ni licencia. |
| **Gurobi** | Comercial | Requiere licencia propia | Más rápido en problemas grandes; necesita un archivo de licencia configurado en el despliegue. |
| **CPLEX** | Comercial | Requiere licencia propia | Alternativa comercial de IBM; misma consideración de licencia que Gurobi. |
| **Mosek** | Comercial | Requiere licencia propia | Alternativa comercial orientada a problemas de optimización lineal a gran escala. |

!!! tip "¿Cuál solver elegir?"
    Para la mayoría de escenarios, HiGHS es suficiente y es la opción recomendada por defecto. Los solvers comerciales solo aportan una ventaja notable en escenarios muy grandes (alta desagregación regional y/o muchos timeslices), donde el tiempo de resolución con HiGHS se vuelve un cuello de botella, y requieren que el administrador de la instancia haya configurado la licencia correspondiente.

## Siguientes pasos

Si tu perfil es de analista y ya tienes acceso a una instancia, continúa directamente con [Primera simulación](first-simulation.md). Si vas a instalar la plataforma, sigue con [Instalación](installation.md).
