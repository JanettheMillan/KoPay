# Cronograma y trazabilidad de KoPay

**Periodo propuesto:** 8 de octubre al 15 de diciembre de 2026.  
**Repositorio de entrega indicado por el equipo:** [JanettheMillan/KoPay](https://github.com/JanettheMillan/KoPay).  
**Tablero indicado por el equipo:** [KoPay Project 3](https://github.com/users/JanettheMillan/projects/3).  
**Estado:** planificación desde el 8 de octubre; las tarjetas, responsables, cambios y resultados se registran como hechos solo cuando existan en el repositorio de entrega.

## 1. Punto de partida y forma de registrar el trabajo

El objetivo de los sprints es construir los módulos de KoPay en el repositorio de entrega mediante tareas, ramas, revisiones y pruebas verificables. El calendario define resultados previstos; el Project registra su avance conforme se realicen.

Este archivo resume el calendario por persona. El [backlog de 97 actividades](backlog-desarrollo-desde-cero.md) contiene el desglose de cada módulo, incluido el contador desde la definición inicial. Cada tarjeta debe enlazar los cambios y comprobaciones realizados por su responsable.

Cada actividad se convierte en una tarjeta con objetivo, criterio de aceptación, responsable confirmado, sprint, etiqueta y dependencias. Si implica código, su evidencia será una rama y un Pull Request revisado; si implica pruebas, será un registro de ejecución y capturas; si implica documentación, será una versión revisada del archivo correspondiente. El límite WIP es **una tarea activa por desarrollador**.

Las cuentas de GitHub comunicadas en la planificación son: Rubén (`RuAbogado`), Janetthe (`JanettheMillan`), Enrique (`EnriqueLanda2`), Francisco (`CiscoPaquitoTracer`), Luis (`GleipM`) y Maximiliano (`RichartM`). Se confirmó que las seis pueden recibir Issues en el repositorio. Las 97 actividades fueron asignadas como responsables propuestos y sus enlaces aparecen en el [backlog](backlog-desarrollo-desde-cero.md). La disponibilidad y aceptación de cada tarea se revisan en el equipo.

## 2. Objetivos por sprint

| Sprint | Fechas | Resultado que se busca |
| :--- | :--- | :--- |
| 1 | 8–23 oct. | Estructura base, datos locales, movimientos, ingresos, Inicio, alcance de usuario y contador, y primeros casos planificados. |
| 2 | 24 oct.–6 nov. | Tarjetas, deudas, pagos, categorías, ajustes y respaldo documentados e integrados. |
| 3 | 7–20 nov. | Backend Node.js, esquema administrado y primeras rutas de registro e inicio de sesión. |
| 4 | 21 nov.–4 dic. | Sesiones, recuperación de acceso, JWT, roles, permisos de contador y conexión inicial Flutter–Node. |
| 5 | 5–15 dic. | API financiera, vista de contador, sincronización, regresión, APK, demostración y entrega. |

Las fechas de los dos primeros sprints se alinean con los cierres comunicados para el Project; los sprints 3 a 5 siguen las fechas aportadas por el equipo. La capacidad y el número final de tarjetas deben ajustarse a la disponibilidad real de las seis personas.

## 3. Actividades por persona y módulo

### Sprint 1 — Base y finanzas personales

| Responsable | Actividad para tarjeta | Criterio de aceptación |
| :--- | :--- | :--- |
| Rubén | Definir alcance, arquitectura inicial, contratos entre interfaz y estado, y criterios del primer ciclo. | Documentos revisados y tarjetas del ciclo vinculadas a historias y pruebas. |
| Enrique | Preparar modelos y persistencia SQLite de movimientos e ingresos. | Altas y consultas funcionan con datos de prueba; esquema y decisiones quedan documentados. |
| Francisco | Implementar proveedores y validaciones de movimientos e ingresos. | Los formularios guardan registros válidos y rechazan datos incompletos. |
| Janetthe | Construir formularios y lista de movimientos e ingresos en Flutter; diseñar la navegación de usuario y contador. | Se puede capturar y consultar cada tipo; ambas vistas tienen recorridos y pantallas definidos. |
| Maximiliano | Construir Inicio, resumen mensual y navegación por periodo. | Con datos conocidos, el mes seleccionado presenta actividad y totales esperados. |
| Luis | Preparar y ejecutar los casos prioritarios de movimientos, ingresos y resumen. | Casos registrados con fecha, resultado, dispositivo y evidencia real. |

### Sprint 2 — Tarjetas, deudas, ajustes y respaldo

| Responsable | Actividad para tarjeta | Criterio de aceptación |
| :--- | :--- | :--- |
| Rubén | Revisar integración de módulos, arquitectura y criterios de aceptación. | Dependencias y decisiones documentadas; PR del ciclo revisados. |
| Enrique | Preparar modelos y persistencia local de tarjetas, deudas y ajustes. | Los datos sobreviven al reinicio y las relaciones necesarias quedan descritas. |
| Francisco | Implementar lógica de pagos y cálculo de compromisos próximos. | Pagos válidos actualizan saldos y próximos pagos según datos conocidos. |
| Janetthe | Construir formularios y detalles de tarjetas y deudas; maquetar la vista del contador con datos de ejemplo. | Los flujos financieros se recorren y la maqueta del contador queda preparada para su integración posterior. |
| Maximiliano | Construir categorías, idioma, moneda, exportación XLSX, importación CSV y borrado de datos locales con confirmación. | Ajustes persisten; ambas operaciones de archivo funcionan; cancelar el borrado conserva datos y confirmarlo elimina los registros financieros locales. |
| Luis | Ejecutar casos de tarjetas, deudas, ajustes y respaldo. | Resultados y fallos observados quedan registrados con evidencia. |

### Sprint 3 — Backend y acceso

| Responsable | Actividad para tarjeta | Criterio de aceptación |
| :--- | :--- | :--- |
| Maximiliano | Inicializar backend Node.js, estructura, variables de entorno y documentación de ejecución. | El servicio arranca en desarrollo sin secretos en el repositorio y tiene instrucciones reproducibles. |
| Enrique | Diseñar esquema y migraciones para usuarios, roles, sesiones y autorización de contador. | Modelo y migraciones revisados; la tecnología concreta de base administrada queda acordada. |
| Francisco | Implementar endpoints de registro e inicio de sesión. | Se aceptan datos válidos y se rechazan credenciales o registros inválidos. |
| Janetthe | Crear pantallas Flutter de registro e inicio de sesión. | Ambos flujos muestran carga, éxito y error según el contrato acordado. |
| Rubén | Definir contrato API, criterios de aceptación y reglas iniciales de consentimiento para el contador. | Contrato y permisos revisados antes de integrar Flutter y Node. |
| Luis | Preparar casos y datos de prueba de autenticación y autorización. | El plan cubre registro, login, errores y separación de cuentas. |

### Sprint 4 — Sesión, roles y acceso del contador

| Responsable | Actividad para tarjeta | Criterio de aceptación |
| :--- | :--- | :--- |
| Enrique | Implementar JWT, renovación/cierre de sesión y protección de rutas. | Las rutas privadas rechazan sesiones ausentes o vencidas. |
| Maximiliano | Implementar middleware RBAC y permisos de relación usuario–contador. | El contador solo accede a datos autorizados; la revocación bloquea nuevas consultas. |
| Francisco | Integrar autenticación Node con Flutter y manejo seguro de sesión. | Inicio, renovación y cierre de sesión funcionan con errores controlados. |
| Janetthe | Implementar sesión visible, perfil y estructura de la vista de contador. | La navegación distingue roles y muestra estados de carga y error. |
| Rubén | Revisar seguridad, consentimiento, integración y Pull Requests del sprint. | Reglas de acceso y decisiones quedan documentadas y revisadas. |
| Luis | Ejecutar pruebas de registro, login, roles y rutas protegidas. | Cada caso tiene resultado y evidencia; las fallas generan tareas. |

### Sprint 5 — API financiera, contador y entrega

| Responsable | Actividad para tarjeta | Criterio de aceptación |
| :--- | :--- | :--- |
| Enrique | Crear API CRUD de movimientos e ingresos y consultas autorizadas para contador. | Los datos de cada usuario se aíslan; el contador ve solo los autorizados. |
| Maximiliano | Crear API para tarjetas, deudas, pagos próximos y resumen del contador. | La API devuelve datos consistentes con permisos y saldos esperados. |
| Francisco | Integrar movimientos e ingresos remotos en Flutter y conectar autorización del contador. | Las pantallas muestran datos remotos y manejan errores sin perder el control de sesión. |
| Janetthe | Integrar tarjetas, deudas, pagos y vista de contador en Flutter. | El contador consulta el resumen autorizado y la persona conserva su experiencia normal. |
| Luis | Consolidar pruebas finales, casos de contador, regresión y evidencia. | Resultados reales, fallos abiertos y capturas quedan vinculados a la versión final. |
| Rubén | Preparar build APK, revisión final, demostración y documentación de entrega. | El APK se instala, la demo recorre los flujos acordados y los documentos finales están enlazados. |

## 4. Alcance mínimo del módulo de contador

El contador es un módulo de la misma entrega, con vista y comportamiento propios. Esta planificación fija un alcance concreto para llegar al 15 de diciembre:

1. Una cuenta con rol de contador puede iniciar sesión.
2. Una persona usuaria autoriza explícitamente a un contador concreto.
3. El contador consulta un resumen y movimientos **solo de las personas que le dieron acceso**.
4. La persona usuaria puede revocar el acceso; las consultas posteriores se rechazan.
5. Las rutas del servidor aplican permisos, incluso si alguien intenta llamar a la API sin pasar por la interfaz.
6. El módulo se define en Sprint 1, prepara datos y contratos en Sprint 3, desarrolla permisos y pantallas en Sprint 4 y concluye integración y pruebas en Sprint 5.

No se asume que el contador pueda editar movimientos, pagos o tarjetas. Si el profesor exige escritura, informes descargables o varias relaciones por usuario, deben añadirse historias, pruebas y capacidad al cronograma. El plazo del Sprint 5 tiene riesgo por reunir API financiera, interfaz, contador y entrega; el equipo deberá revisar alcance y capacidad antes de comprometerlo.

## 5. Relación entre tarjeta, prueba y evidencia

Cada tarjeta cita historias (`HU-xx`) y debe enlazar el caso de prueba aplicable (`UT`, `UI`, `INT` o `FUT`) cuando se ejecute. El Pull Request debe referenciar el Issue. Al cerrar la tarea se registra el resultado real y se adjunta evidencia según [guia-de-evidencias.md](guia-de-evidencias.md). Los 97 Issues ya existen en el [Project 3](https://github.com/users/JanettheMillan/projects/3); el tablero es la fuente del estado. Esta tabla no acredita que las tareas hayan sido ejecutadas o aprobadas.
