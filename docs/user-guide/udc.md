# Restricciones definidas por el usuario (UDC)

Las **UDC** ("User-Defined Constraints") son un mecanismo que permite imponer restricciones lineales adicionales sobre la capacidad o la actividad de las tecnologías del modelo, sin necesidad de modificar la formulación base de OSeMOSYS. Están pensadas para analistas que necesitan imponer una regla de política o de diseño que el modelo estándar no contempla directamente.

## ¿Qué es una restricción UDC?

En términos generales, una restricción UDC combina, para un conjunto de tecnologías, tres magnitudes posibles:

- La **capacidad total instalada** de cada tecnología en un año dado.
- La **capacidad nueva** instalada ese año.
- La **actividad anual** (energía producida/consumida) de la tecnología ese año.

A cada una de estas magnitudes se le puede asignar un coeficiente (multiplicador) distinto por tecnología, región y año. La suma ponderada resultante se compara contra una constante, y la comparación puede ser de tipo "menor o igual que" o "igual a". Si no se configura ninguna restricción para un escenario, este mecanismo simplemente no se activa y el modelo se resuelve igual que sin UDC.

!!! note "No es obligatorio"
    Por defecto, ningún escenario nuevo tiene restricciones UDC habilitadas. Es una funcionalidad opcional que activas explícitamente cuando la necesitas.

## El caso de uso principal: margen de reserva personalizado

El uso más común de UDC en esta aplicación es reemplazar el margen de reserva estándar de OSeMOSYS por una formulación personalizada. La idea del margen de reserva es asegurar que el sistema tenga capacidad instalada suficiente por encima de la demanda pico, considerando que no todas las tecnologías aportan por igual a la confiabilidad del sistema:

- Las tecnologías **despachables** (por ejemplo, térmicas) contribuyen plenamente a la capacidad de respaldo.
- Las tecnologías **no despachables** (por ejemplo, solar o hidráulica de filo de agua) no se consideran como aporte firme al margen de reserva, dado que su disponibilidad no es controlable.
- La tecnología de la red (conexión/interconexión) se pondera con un factor propio que refleja su contribución particular.

Al habilitar esta UDC en un escenario, el modelo exige que la capacidad "efectiva" del sistema (con estas ponderaciones aplicadas) se mantenga por encima de un margen respecto a la demanda máxima esperada.

## Cómo habilitar UDC en un escenario

Desde la configuración del escenario (ver [Escenarios y catálogos](escenarios.md)), activa la opción de restricciones definidas por el usuario y confirma que la configuración quede habilitada antes de lanzar la simulación. Si esta configuración no está presente o no está activada, el modelo se resuelve sin ninguna restricción UDC — el comportamiento por defecto.

!!! tip "UDC y modo Excel/SAND"
    Las restricciones UDC solo aplican al modo de escenarios en base de datos. Cuando simulas directamente desde un archivo Excel/SAND (ver [Carga de datos Excel/SAND](carga-excel-sand.md)), no hay escenario en base de datos al que asociar una configuración UDC, por lo que este mecanismo queda deshabilitado en ese modo.

## Relación con la factibilidad

Como cualquier restricción adicional, una UDC mal calibrada (por ejemplo, un margen de reserva demasiado exigente para la capacidad disponible) puede volver infactible una simulación que de otro modo sería resoluble. Si tu simulación con UDC habilitado resulta infactible, el diagnóstico de infactibilidad de la aplicación puede señalar directamente la restricción UDC como parte del conflicto — ver [Simulaciones: resultados infactibles](simulaciones.md#resultados-infactibles).

## Siguientes pasos

- [Simulaciones](simulaciones.md) para lanzar la simulación una vez configurada la UDC.
- [Escenarios y catálogos](escenarios.md) para el resto de la configuración del escenario.
- [Arquitectura](../architecture/overview.md) si te interesa la formulación matemática completa detrás de UDC.
