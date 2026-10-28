# Backlog de desarrollo desde cero de KoPay

**Periodo de planificación:** 8 de octubre al 15 de diciembre de 2026.  
**Repositorio de entrega indicado:** [JanettheMillan/KoPay](https://github.com/JanettheMillan/KoPay).  
**Tablero indicado:** [KoPay Project 3](https://github.com/users/JanettheMillan/projects/3).  
**Estado:** actividades creadas y vinculadas al Project; consultar allí el estado vigente de cada tarjeta. La creación del Issue no acredita ejecución.

## Cómo usar este backlog

Este es el desglose del desarrollo completo de KoPay, desde la base Flutter hasta la entrega en el repositorio del equipo. Cada tarjeta se cerrará únicamente con trabajo real hecho por su responsable: cambio concreto, revisión o prueba verificable. El Project y los Pull Requests mostrarán el avance de cada módulo.

El módulo de contador es parte del producto objetivo, junto con la vista de usuario. Se define desde el alcance y la arquitectura del primer sprint; su esquema y contrato se preparan en el tercero, su acceso y pantallas en el cuarto, y su consulta funcional con pruebas se completa en el quinto. La persona usuaria autoriza a un contador específico; el contador consulta únicamente datos autorizados y no modifica finanzas ajenas.

Los identificadores S1-01 a S1-19, S2-01 a S2-20, S3-01 a S3-18, S4-01 a S4-20 y S5-01 a S5-20 son **identificadores documentales**. Cada una de las 97 actividades ya tiene un Issue vinculado en el repositorio de Jane y aparece en el Project. Los números de Issue figuran debajo de cada tarjeta. Los responsables propuestos fueron asignados a esos Issues; el estado efectivo del trabajo se actualiza en el tablero conforme avance el equipo.

Cada tarjeta debe tener etiqueta, sprint, responsable, criterio de aceptación, dependencia, historia relacionada y enlace a su PR o resultado de prueba. El equipo toma como máximo una tarea activa por desarrollador; las tareas de una persona dentro de un sprint se trabajan de forma secuencial. Algunas tarjetas anteriores del Project permanecen como actividades de apoyo y se distinguen de las 97 actividades de este plan.

### Cómo registrar la trazabilidad de cada actividad

1. Revisar el objetivo, las dependencias y los criterios de aceptación de la tarjeta.
2. Confirmar responsable y sprint en el Project antes de iniciar el trabajo.
3. Implementar el cambio en una rama y describir en cada commit el trabajo realizado.
4. Vincular el Pull Request con la tarjeta y su historia; revisar el resultado y ejecutar el caso de prueba aplicable.
5. Cerrar la tarjeta únicamente cuando exista evidencia verificable del criterio de aceptación.

Las tarjetas describen el trabajo previsto; el Project y Git mostrarán lo que efectivamente se realice.

## Sprints y actividades

### Sprint 1 · 8 al 23 de octubre · Base Flutter y finanzas

#### S1-01 · Definir objetivo, usuarios y alcance inicial

**Issue en GitHub:** [#2](https://github.com/JanettheMillan/KoPay/issues/2).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** Ninguna.
- **Historias relacionadas:** HU-01 a HU-09, HU-37 a HU-42.
- **Criterio de aceptación:** Alcance de las vistas de usuario y contador, sus permisos y exclusiones revisados por el equipo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-02 · Redactar historias y criterios de movimientos e ingresos

**Issue en GitHub:** [#11](https://github.com/JanettheMillan/KoPay/issues/11).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S1-01.
- **Historias relacionadas:** HU-01 a HU-12.
- **Criterio de aceptación:** Cada historia tiene criterio verificable y prioridad propuesta.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-03 · Definir arquitectura Flutter, Provider y SQLite

**Issue en GitHub:** [#10](https://github.com/JanettheMillan/KoPay/issues/10).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `architecture`.
- **Depende de:** S1-01.
- **Historias relacionadas:** HU-01 a HU-09, HU-37 a HU-42.
- **Criterio de aceptación:** Diagrama y contratos pantalla–proveedor documentados, con ruta prevista de autenticación y vista de contador.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-04 · Crear proyecto Flutter y estructura de carpetas

**Issue en GitHub:** [#3](https://github.com/JanettheMillan/KoPay/issues/3).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-03.
- **Historias relacionadas:** HU-01 a HU-09.
- **Criterio de aceptación:** La aplicación inicia con pantallas, modelos, proveedores y servicios separados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-05 · Crear tema visual y navegación base

**Issue en GitHub:** [#20](https://github.com/JanettheMillan/KoPay/issues/20).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-04.
- **Historias relacionadas:** HU-07.
- **Criterio de aceptación:** Inicio, Movimientos y Ajustes son accesibles con estilo consistente.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-06 · Crear Inicio y estructura de resumen mensual

**Issue en GitHub:** [#21](https://github.com/JanettheMillan/KoPay/issues/21).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-05.
- **Historias relacionadas:** HU-08, HU-09.
- **Criterio de aceptación:** Se muestran ingresos, gastos, saldo y selector de mes con datos de ejemplo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-07 · Crear modelos de movimiento e ingreso

**Issue en GitHub:** [#22](https://github.com/JanettheMillan/KoPay/issues/22).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-03.
- **Historias relacionadas:** HU-01, HU-02.
- **Criterio de aceptación:** Modelos convierten datos a mapas y conservan campos al copiarse.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-08 · Crear esquema SQLite de ingresos, movimientos y ajustes

**Issue en GitHub:** [#23](https://github.com/JanettheMillan/KoPay/issues/23).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S1-07.
- **Historias relacionadas:** HU-01, HU-02, HU-29.
- **Criterio de aceptación:** Las tablas se crean y abren en una instalación de prueba.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-09 · Crear operaciones SQLite de alta, lectura, edición y borrado

**Issue en GitHub:** [#24](https://github.com/JanettheMillan/KoPay/issues/24).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S1-08.
- **Historias relacionadas:** HU-05 a HU-07.
- **Criterio de aceptación:** Cada operación conserva datos y ordena movimientos por fecha.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-10 · Crear proveedor de movimientos

**Issue en GitHub:** [#25](https://github.com/JanettheMillan/KoPay/issues/25).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-09.
- **Historias relacionadas:** HU-01, HU-05, HU-06.
- **Criterio de aceptación:** Alta, actualización y borrado recargan estado y notifican a la interfaz.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-11 · Crear proveedor de ingresos

**Issue en GitHub:** [#26](https://github.com/JanettheMillan/KoPay/issues/26).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-09.
- **Historias relacionadas:** HU-02.
- **Criterio de aceptación:** El ingreso se guarda, se consulta y actualiza suscriptores.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-12 · Implementar validaciones y signo de movimiento

**Issue en GitHub:** [#27](https://github.com/JanettheMillan/KoPay/issues/27).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-10, S1-11.
- **Historias relacionadas:** HU-03, HU-04.
- **Criterio de aceptación:** Monto inválido o descripción vacía se rechazan; gastos quedan negativos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-13 · Crear formulario Flutter de gasto y movimiento

**Issue en GitHub:** [#28](https://github.com/JanettheMillan/KoPay/issues/28).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-05, S1-12.
- **Historias relacionadas:** HU-01, HU-03, HU-04.
- **Criterio de aceptación:** Permite monto, tipo, descripción, categoría y fecha; muestra validación.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-14 · Crear formulario Flutter de ingreso

**Issue en GitHub:** [#29](https://github.com/JanettheMillan/KoPay/issues/29).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-05, S1-11.
- **Historias relacionadas:** HU-02, HU-04.
- **Criterio de aceptación:** Permite nombre, monto y fecha; no guarda entradas incompletas.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-15 · Crear historial de movimientos e ingresos

**Issue en GitHub:** [#30](https://github.com/JanettheMillan/KoPay/issues/30).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-10, S1-11.
- **Historias relacionadas:** HU-07.
- **Criterio de aceptación:** La lista reúne ambos tipos y se ordena por fecha.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-16 · Crear y ejecutar pruebas unitarias de modelos y formatos

**Issue en GitHub:** [#31](https://github.com/JanettheMillan/KoPay/issues/31).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S1-07.
- **Historias relacionadas:** HU-01, HU-02.
- **Criterio de aceptación:** Se registran casos, resultados y defectos encontrados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-17 · Ejecutar pruebas de interfaz de formularios y navegación

**Issue en GitHub:** [#9](https://github.com/JanettheMillan/KoPay/issues/9).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S1-13 a S1-15.
- **Historias relacionadas:** HU-01, HU-02, HU-04.
- **Criterio de aceptación:** Se documentan datos usados, dispositivo y resultado real.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-18 · Ejecutar flujo completo de gasto e ingreso hasta el resumen

**Issue en GitHub:** [#7](https://github.com/JanettheMillan/KoPay/issues/7).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S1-06, S1-13 a S1-15.
- **Historias relacionadas:** HU-01, HU-02, HU-09.
- **Criterio de aceptación:** Movimientos y totales coinciden con importes conocidos; evidencia adjunta.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S1-19 · Diseñar navegación de usuario y contador

**Issue en GitHub:** [#32](https://github.com/JanettheMillan/KoPay/issues/32).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `design`.
- **Depende de:** S1-01, S1-03.
- **Historias relacionadas:** HU-37 a HU-42.
- **Criterio de aceptación:** Quedan definidos los recorridos y pantallas de ambas vistas, incluido consentimiento, lista de clientes, resumen e historial del contador.
- **Evidencia al cerrar:** Issue, boceto o archivo editable revisado y decisión de navegación registrada.

### Sprint 2 · 24 de octubre al 6 de noviembre · Tarjetas, deudas y ajustes

#### S2-01 · Revisar integración de interfaz, proveedores y datos locales

**Issue en GitHub:** [#33](https://github.com/JanettheMillan/KoPay/issues/33).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `architecture`.
- **Depende de:** S1-18.
- **Historias relacionadas:** HU-13 a HU-29.
- **Criterio de aceptación:** Contratos y decisiones de integración quedan actualizados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-02 · Documentar patrón de estado y esquema de datos completo

**Issue en GitHub:** [#34](https://github.com/JanettheMillan/KoPay/issues/34).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S2-01.
- **Historias relacionadas:** HU-13 a HU-23.
- **Criterio de aceptación:** Arquitectura explica Provider, SQLite y los módulos financieros.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-03 · Definir criterios de respaldo, importación y borrado

**Issue en GitHub:** [#35](https://github.com/JanettheMillan/KoPay/issues/35).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S2-02.
- **Historias relacionadas:** HU-26 a HU-28.
- **Criterio de aceptación:** Se distinguen XLSX, CSV y borrado; casos críticos quedan definidos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-04 · Crear administración de categorías

**Issue en GitHub:** [#36](https://github.com/JanettheMillan/KoPay/issues/36).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-13.
- **Historias relacionadas:** HU-10 a HU-12.
- **Criterio de aceptación:** Alta, búsqueda, edición y eliminación aparecen en el selector.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-05 · Crear Ajustes de moneda e idioma

**Issue en GitHub:** [#37](https://github.com/JanettheMillan/KoPay/issues/37).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-05, S1-08.
- **Historias relacionadas:** HU-24, HU-25.
- **Criterio de aceptación:** Los cambios se muestran y persisten al reabrir la app.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-06 · Crear exportación XLSX e importación CSV

**Issue en GitHub:** [#38](https://github.com/JanettheMillan/KoPay/issues/38).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-03, S2-05.
- **Historias relacionadas:** HU-26, HU-27.
- **Criterio de aceptación:** Exportación crea archivo legible; importación confirma reemplazo y informa fallos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-07 · Crear modelo y tabla local de tarjetas

**Issue en GitHub:** [#39](https://github.com/JanettheMillan/KoPay/issues/39).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S1-08.
- **Historias relacionadas:** HU-13, HU-14.
- **Criterio de aceptación:** Se conservan límites, saldo usado y fechas de corte y pago.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-08 · Crear modelo y tabla local de deudas

**Issue en GitHub:** [#40](https://github.com/JanettheMillan/KoPay/issues/40).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S1-08.
- **Historias relacionadas:** HU-19, HU-21.
- **Criterio de aceptación:** Se conservan mensualidad, saldo restante, vencimiento y estado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-09 · Crear persistencia de pagos relacionados con tarjetas y deudas

**Issue en GitHub:** [#41](https://github.com/JanettheMillan/KoPay/issues/41).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S2-07, S2-08.
- **Historias relacionadas:** HU-16, HU-20.
- **Criterio de aceptación:** Los movimientos de pago quedan asociados a su entidad.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-10 · Crear proveedor y cálculo de crédito de tarjetas

**Issue en GitHub:** [#42](https://github.com/JanettheMillan/KoPay/issues/42).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-07.
- **Historias relacionadas:** HU-13 a HU-15.
- **Criterio de aceptación:** Alta, edición y eliminación actualizan el crédito disponible.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-11 · Crear proveedor de deudas y actualización de saldo

**Issue en GitHub:** [#43](https://github.com/JanettheMillan/KoPay/issues/43).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-08, S2-09.
- **Historias relacionadas:** HU-19 a HU-21.
- **Criterio de aceptación:** Los pagos reducen saldo y la liquidación cambia el estado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-12 · Implementar cálculo de próximos pagos

**Issue en GitHub:** [#44](https://github.com/JanettheMillan/KoPay/issues/44).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-09 a S2-11.
- **Historias relacionadas:** HU-18, HU-23.
- **Criterio de aceptación:** Tarjetas y deudas aparecen ordenadas por vencimiento y estado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-13 · Crear formulario y detalle de tarjeta

**Issue en GitHub:** [#45](https://github.com/JanettheMillan/KoPay/issues/45).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-10.
- **Historias relacionadas:** HU-13 a HU-15.
- **Criterio de aceptación:** Se puede agregar, consultar, editar y abrir acciones de tarjeta.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-14 · Crear formulario y consulta de deuda

**Issue en GitHub:** [#46](https://github.com/JanettheMillan/KoPay/issues/46).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-11.
- **Historias relacionadas:** HU-19.
- **Criterio de aceptación:** Se puede registrar y consultar deuda y vencimiento.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-15 · Crear formularios de pago de tarjeta y deuda

**Issue en GitHub:** [#47](https://github.com/JanettheMillan/KoPay/issues/47).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-09 a S2-14.
- **Historias relacionadas:** HU-16, HU-17, HU-20, HU-22.
- **Criterio de aceptación:** Pagos válidos actualizan datos y montos inválidos se rechazan.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-16 · Ejecutar pruebas unitarias de saldos y próximos pagos

**Issue en GitHub:** [#48](https://github.com/JanettheMillan/KoPay/issues/48).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S2-12.
- **Historias relacionadas:** HU-18, HU-21, HU-23.
- **Criterio de aceptación:** Se documentan casos de pago parcial, completo y vencimiento.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-17 · Ejecutar pruebas de tarjetas, deudas y pagos

**Issue en GitHub:** [#15](https://github.com/JanettheMillan/KoPay/issues/15).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S2-13 a S2-15.
- **Historias relacionadas:** HU-13 a HU-23.
- **Criterio de aceptación:** Se guardan resultados y defectos por cada flujo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-18 · Ejecutar pruebas de ajustes y respaldo

**Issue en GitHub:** [#16](https://github.com/JanettheMillan/KoPay/issues/16).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S2-04 a S2-06.
- **Historias relacionadas:** HU-24 a HU-28.
- **Criterio de aceptación:** Se validan moneda, idioma, XLSX, CSV y borrado con datos de prueba.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S2-19 · Maquetar la vista inicial del contador con datos de ejemplo

**Issue en GitHub:** [#49](https://github.com/JanettheMillan/KoPay/issues/49).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S1-19, S2-13.
- **Historias relacionadas:** HU-39, HU-40.
- **Criterio de aceptación:** La maqueta muestra selección de cliente, periodo, resumen e historial de solo lectura; los datos de ejemplo están claramente identificados y no se presentan como conexión real.
- **Evidencia al cerrar:** Issue, PR de interfaz y capturas de la maqueta revisada.

#### S2-20 · Implementar borrado local de datos con confirmación

**Issue en GitHub:** [#107](https://github.com/JanettheMillan/KoPay/issues/107).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-03, S2-05.
- **Historia relacionada:** HU-28.
- **Criterio de aceptación:** Cancelar conserva los registros; confirmar elimina tarjetas, deudas, movimientos e ingresos locales, y la interfaz muestra el estado vacío. Se documenta el efecto sobre datos remotos si la sincronización ya está habilitada.
- **Evidencia al cerrar:** PR, comprobación de ambos caminos con datos de prueba y resultado registrado en S2-18.

### Sprint 3 · 7 al 20 de noviembre · Backend Node y autenticación

#### S3-01 · Crear proyecto Node.js y estructura de API

**Issue en GitHub:** [#19](https://github.com/JanettheMillan/KoPay/issues/19).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S2-18.
- **Historias relacionadas:** HU-30 a HU-36.
- **Criterio de aceptación:** El servidor inicia y separa rutas, servicios, configuración y datos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-02 · Configurar ambientes y secretos

**Issue en GitHub:** [#50](https://github.com/JanettheMillan/KoPay/issues/50).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-01.
- **Historias relacionadas:** HU-30, HU-35.
- **Criterio de aceptación:** Desarrollo y producción usan configuración diferenciada; no se suben secretos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-03 · Documentar ejecución local y contrato de salud de la API

**Issue en GitHub:** [#51](https://github.com/JanettheMillan/KoPay/issues/51).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S3-01, S3-02.
- **Historias relacionadas:** HU-31.
- **Criterio de aceptación:** Otro integrante puede iniciar el servicio y comprobar que responde.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-04 · Elegir y documentar base de datos administrada

**Issue en GitHub:** [#52](https://github.com/JanettheMillan/KoPay/issues/52).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S3-01.
- **Historias relacionadas:** HU-34, HU-36.
- **Criterio de aceptación:** Tecnología, conexión, aislamiento por usuario y migraciones se acuerdan.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-05 · Crear migraciones de usuarios, roles y sesiones

**Issue en GitHub:** [#53](https://github.com/JanettheMillan/KoPay/issues/53).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S3-04.
- **Historias relacionadas:** HU-30 a HU-34.
- **Criterio de aceptación:** Las tablas se crean desde cero en ambiente de prueba.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-06 · Crear relación de autorización usuario–contador

**Issue en GitHub:** [#54](https://github.com/JanettheMillan/KoPay/issues/54).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `database`.
- **Depende de:** S3-05.
- **Historias relacionadas:** HU-37 a HU-42.
- **Criterio de aceptación:** El esquema permite conceder y revocar acceso a un contador concreto.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-07 · Crear endpoint de registro de usuario

**Issue en GitHub:** [#55](https://github.com/JanettheMillan/KoPay/issues/55).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-05.
- **Historias relacionadas:** HU-30.
- **Criterio de aceptación:** Acepta datos válidos; rechaza duplicados y campos inválidos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-08 · Crear almacenamiento seguro de credenciales

**Issue en GitHub:** [#56](https://github.com/JanettheMillan/KoPay/issues/56).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-07.
- **Historias relacionadas:** HU-30, HU-31.
- **Criterio de aceptación:** La contraseña no se conserva en texto plano y se valida al entrar.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-09 · Crear endpoint de inicio de sesión

**Issue en GitHub:** [#57](https://github.com/JanettheMillan/KoPay/issues/57).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-07, S3-08.
- **Historias relacionadas:** HU-31.
- **Criterio de aceptación:** Credenciales válidas abren sesión y las inválidas reciben error controlado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-10 · Crear pantalla Flutter de registro

**Issue en GitHub:** [#58](https://github.com/JanettheMillan/KoPay/issues/58).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S3-07.
- **Historias relacionadas:** HU-30.
- **Criterio de aceptación:** Permite capturar datos, muestra validaciones y estados de envío.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-11 · Crear pantalla Flutter de inicio de sesión

**Issue en GitHub:** [#59](https://github.com/JanettheMillan/KoPay/issues/59).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S3-09.
- **Historias relacionadas:** HU-31.
- **Criterio de aceptación:** Permite ingresar credenciales y muestra errores sin filtrar datos privados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-12 · Conectar navegación inicial con acceso y sesión

**Issue en GitHub:** [#60](https://github.com/JanettheMillan/KoPay/issues/60).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S3-10, S3-11.
- **Historias relacionadas:** HU-31, HU-34.
- **Criterio de aceptación:** Una sesión válida abre la app; sin sesión se muestra el acceso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-13 · Definir contrato API para registro, login y errores

**Issue en GitHub:** [#61](https://github.com/JanettheMillan/KoPay/issues/61).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S3-01, S3-05.
- **Historias relacionadas:** HU-30, HU-31.
- **Criterio de aceptación:** Rutas, campos, respuestas y criterios quedan revisados por Flutter y Node.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-14 · Definir reglas de roles y consentimiento de contador

**Issue en GitHub:** [#62](https://github.com/JanettheMillan/KoPay/issues/62).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S3-06, S3-13.
- **Historias relacionadas:** HU-37 a HU-42.
- **Criterio de aceptación:** Se especifica quién autoriza, qué puede consultar y cómo revocar.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-15 · Revisar integración inicial y Pull Requests de acceso

**Issue en GitHub:** [#63](https://github.com/JanettheMillan/KoPay/issues/63).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `review`.
- **Depende de:** S3-09 a S3-14.
- **Historias relacionadas:** HU-30 a HU-34.
- **Criterio de aceptación:** Cambios y bloqueos se registran en sus tarjetas.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-16 · Preparar casos unitarios de validación y autorización

**Issue en GitHub:** [#64](https://github.com/JanettheMillan/KoPay/issues/64).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S3-13, S3-14.
- **Historias relacionadas:** HU-30, HU-34, HU-37.
- **Criterio de aceptación:** Casos cubren límites, roles y datos inválidos con resultado esperado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-17 · Probar interfaz de registro e inicio de sesión

**Issue en GitHub:** [#65](https://github.com/JanettheMillan/KoPay/issues/65).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S3-10, S3-11.
- **Historias relacionadas:** HU-30, HU-31.
- **Criterio de aceptación:** Se registran resultados reales de carga, error y éxito.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S3-18 · Probar registro y login de punta a punta

**Issue en GitHub:** [#66](https://github.com/JanettheMillan/KoPay/issues/66).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S3-07 a S3-12.
- **Historias relacionadas:** HU-30, HU-31.
- **Criterio de aceptación:** Se comprueba API, base y Flutter con cuentas de prueba.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

### Sprint 4 · 21 de noviembre al 4 de diciembre · Sesiones y permisos

#### S4-01 · Crear emisión y verificación de JWT

**Issue en GitHub:** [#67](https://github.com/JanettheMillan/KoPay/issues/67).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-09.
- **Historias relacionadas:** HU-31, HU-34.
- **Criterio de aceptación:** Las rutas reconocen tokens válidos y rechazan tokens inválidos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-02 · Crear renovación y cierre de sesión

**Issue en GitHub:** [#68](https://github.com/JanettheMillan/KoPay/issues/68).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-01.
- **Historias relacionadas:** HU-33.
- **Criterio de aceptación:** La sesión puede renovarse según contrato y queda invalidada al cerrar.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-03 · Proteger rutas financieras por identidad

**Issue en GitHub:** [#69](https://github.com/JanettheMillan/KoPay/issues/69).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-01, S3-05.
- **Historias relacionadas:** HU-34.
- **Criterio de aceptación:** Cada petición identifica usuario y evita consultar recursos ajenos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-04 · Crear middleware RBAC para usuario y contador

**Issue en GitHub:** [#70](https://github.com/JanettheMillan/KoPay/issues/70).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-06, S4-03.
- **Historias relacionadas:** HU-34, HU-37.
- **Criterio de aceptación:** Cada rol dispone únicamente de operaciones autorizadas.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-05 · Crear endpoints para conceder y revocar acceso del contador

**Issue en GitHub:** [#71](https://github.com/JanettheMillan/KoPay/issues/71).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-04.
- **Historias relacionadas:** HU-38, HU-41.
- **Criterio de aceptación:** La persona usuaria controla el vínculo; revocar bloquea consultas posteriores.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-06 · Crear protección de consultas autorizadas de contador

**Issue en GitHub:** [#72](https://github.com/JanettheMillan/KoPay/issues/72).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-05.
- **Historias relacionadas:** HU-39, HU-40, HU-42.
- **Criterio de aceptación:** Una cuenta de contador solo consulta usuarios vinculados y activos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-07 · Crear cliente Flutter para autenticación Node

**Issue en GitHub:** [#73](https://github.com/JanettheMillan/KoPay/issues/73).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S3-13, S4-01.
- **Historias relacionadas:** HU-31.
- **Criterio de aceptación:** Las solicitudes manejan éxito, error y configuración del ambiente.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-08 · Conservar y renovar sesión en Flutter

**Issue en GitHub:** [#74](https://github.com/JanettheMillan/KoPay/issues/74).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S4-02, S4-07.
- **Historias relacionadas:** HU-31, HU-33.
- **Criterio de aceptación:** La app maneja expiración y retorno a login según contrato.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-09 · Aplicar guardas de navegación por rol

**Issue en GitHub:** [#75](https://github.com/JanettheMillan/KoPay/issues/75).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S4-04, S4-08.
- **Historias relacionadas:** HU-34, HU-37.
- **Criterio de aceptación:** Pantallas privadas no se abren sin sesión o permiso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-10 · Crear perfil y estados de sesión

**Issue en GitHub:** [#76](https://github.com/JanettheMillan/KoPay/issues/76).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S4-08.
- **Historias relacionadas:** HU-31, HU-33.
- **Criterio de aceptación:** La persona ve su rol, carga y errores de sesión.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-11 · Crear interfaz para autorizar y revocar contador

**Issue en GitHub:** [#77](https://github.com/JanettheMillan/KoPay/issues/77).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S4-05.
- **Historias relacionadas:** HU-38, HU-41.
- **Criterio de aceptación:** La persona elige contador y puede retirar acceso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-12 · Crear estructura de vista de contador

**Issue en GitHub:** [#78](https://github.com/JanettheMillan/KoPay/issues/78).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S2-19, S4-06, S4-09.
- **Historias relacionadas:** HU-37, HU-39.
- **Criterio de aceptación:** El rol contador navega a una vista propia sin acceso a edición financiera.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-13 · Revisar seguridad de sesiones y permisos

**Issue en GitHub:** [#79](https://github.com/JanettheMillan/KoPay/issues/79).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `review`.
- **Depende de:** S4-01 a S4-06.
- **Historias relacionadas:** HU-31 a HU-34.
- **Criterio de aceptación:** Se documentan amenazas, fallos y decisiones verificadas.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-14 · Revisar contrato Flutter–Node y estados de error

**Issue en GitHub:** [#80](https://github.com/JanettheMillan/KoPay/issues/80).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `review`.
- **Depende de:** S4-07 a S4-12.
- **Historias relacionadas:** HU-31, HU-37.
- **Criterio de aceptación:** Rutas y errores observados coinciden con el contrato documentado.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-15 · Revisar Pull Requests y dependencias del sprint

**Issue en GitHub:** [#81](https://github.com/JanettheMillan/KoPay/issues/81).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `review`.
- **Depende de:** S4-01 a S4-14.
- **Historias relacionadas:** HU-31 a HU-41.
- **Criterio de aceptación:** Cada tarjeta cerrada tiene evidencia y revisión registrada.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-16 · Ejecutar pruebas de JWT, renovación y cierre

**Issue en GitHub:** [#82](https://github.com/JanettheMillan/KoPay/issues/82).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S4-01 a S4-03.
- **Historias relacionadas:** HU-31, HU-33.
- **Criterio de aceptación:** Resultados incluyen tokens ausentes, inválidos y vencidos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-17 · Ejecutar pruebas RBAC y aislamiento de cuentas

**Issue en GitHub:** [#83](https://github.com/JanettheMillan/KoPay/issues/83).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S4-04 a S4-06.
- **Historias relacionadas:** HU-34, HU-37 a HU-41.
- **Criterio de aceptación:** Se prueban usuario, contador autorizado y contador sin permiso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-18 · Ejecutar pruebas de Flutter autenticado y regresión

**Issue en GitHub:** [#84](https://github.com/JanettheMillan/KoPay/issues/84).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S4-07 a S4-12.
- **Historias relacionadas:** HU-31 a HU-41.
- **Criterio de aceptación:** Pantallas protegidas y errores se prueban con evidencia.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S4-19 · Implementar recuperación segura de acceso

**Issue en GitHub:** [#85](https://github.com/JanettheMillan/KoPay/issues/85).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-09, S4-02.
- **Historias relacionadas:** HU-32.
- **Criterio de aceptación:** El mecanismo acordado permite restablecer el acceso con token o código temporal, rechaza solicitudes vencidas y no expone credenciales.
- **Evidencia al cerrar:** Issue, PR revisado y registro real de recuperación con código válido, inválido y vencido; este flujo no tiene caso formal de integración en el plan reducido.

#### S4-20 · Crear pantalla de recuperación de acceso

**Issue en GitHub:** [#86](https://github.com/JanettheMillan/KoPay/issues/86).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S4-19, S3-11.
- **Historias relacionadas:** HU-32.
- **Criterio de aceptación:** La persona solicita y completa recuperación con estados visibles de éxito, error y expiración.
- **Evidencia al cerrar:** Issue, PR revisado y captura del flujo comprobado.

### Sprint 5 · 5 al 15 de diciembre · API financiera, contador y entrega

#### S5-01 · Crear API CRUD de movimientos

**Issue en GitHub:** [#87](https://github.com/JanettheMillan/KoPay/issues/87).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-03.
- **Historias relacionadas:** HU-01, HU-05, HU-06.
- **Criterio de aceptación:** Cada operación se limita a la cuenta propietaria y valida importes.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-02 · Crear API CRUD de ingresos

**Issue en GitHub:** [#88](https://github.com/JanettheMillan/KoPay/issues/88).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-03.
- **Historias relacionadas:** HU-02, HU-09.
- **Criterio de aceptación:** Cada ingreso pertenece a su cuenta y actualiza consultas del mes.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-03 · Crear consulta financiera autorizada para contador

**Issue en GitHub:** [#89](https://github.com/JanettheMillan/KoPay/issues/89).

- **Responsable propuesto:** Enrique (`EnriqueLanda2`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-06, S5-01, S5-02.
- **Historias relacionadas:** HU-39, HU-40, HU-42.
- **Criterio de aceptación:** Solo devuelve datos de usuarios que concedieron acceso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-04 · Crear API de tarjetas y deudas

**Issue en GitHub:** [#90](https://github.com/JanettheMillan/KoPay/issues/90).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S4-03.
- **Historias relacionadas:** HU-13 a HU-23.
- **Criterio de aceptación:** Altas, cambios y consultas respetan la cuenta propietaria.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-05 · Crear API de pagos y próximos vencimientos

**Issue en GitHub:** [#91](https://github.com/JanettheMillan/KoPay/issues/91).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S5-04.
- **Historias relacionadas:** HU-16, HU-20, HU-23.
- **Criterio de aceptación:** Saldos y compromisos coinciden con registros y permisos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-06 · Integrar servicio externo acordado

**Issue en GitHub:** [#92](https://github.com/JanettheMillan/KoPay/issues/92).

- **Responsable propuesto:** Maximiliano (`RichartM`).
- **Módulo o etiqueta:** `backend`.
- **Depende de:** S3-02, S5-04.
- **Historias relacionadas:** HU-35.
- **Criterio de aceptación:** El contrato responde, maneja tiempo de espera y fallos sin exponer secretos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-07 · Conectar movimientos Flutter con API Node

**Issue en GitHub:** [#93](https://github.com/JanettheMillan/KoPay/issues/93).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-01, S4-08.
- **Historias relacionadas:** HU-01, HU-05, HU-06.
- **Criterio de aceptación:** Alta, edición, borrado y consulta usan sesión y muestran errores.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-08 · Conectar ingresos y resumen Flutter con API Node

**Issue en GitHub:** [#94](https://github.com/JanettheMillan/KoPay/issues/94).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-02, S5-07.
- **Historias relacionadas:** HU-02, HU-09.
- **Criterio de aceptación:** Los datos remotos actualizan Inicio sin duplicados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-09 · Conectar autorización y consultas del contador en Flutter

**Issue en GitHub:** [#95](https://github.com/JanettheMillan/KoPay/issues/95).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-03, S4-09.
- **Historias relacionadas:** HU-39 a HU-41.
- **Criterio de aceptación:** La vista solo solicita datos permitidos y reacciona a la revocación.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-10 · Conectar tarjetas y deudas Flutter con API Node

**Issue en GitHub:** [#96](https://github.com/JanettheMillan/KoPay/issues/96).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-04.
- **Historias relacionadas:** HU-13 a HU-23.
- **Criterio de aceptación:** Formularios y detalles muestran datos remotos y estados de error.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-11 · Conectar pagos y próximos vencimientos Flutter

**Issue en GitHub:** [#97](https://github.com/JanettheMillan/KoPay/issues/97).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-05, S5-10.
- **Historias relacionadas:** HU-16, HU-20, HU-23.
- **Criterio de aceptación:** Movimientos de pago y saldos visibles coinciden con la API.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-12 · Terminar panel de contador y consentimientos

**Issue en GitHub:** [#98](https://github.com/JanettheMillan/KoPay/issues/98).

- **Responsable propuesto:** Janetthe (`JanettheMillan`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-03, S5-09.
- **Historias relacionadas:** HU-38 a HU-41.
- **Criterio de aceptación:** El contador ve resumen autorizado; la persona puede revocar acceso.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-13 · Ejecutar regresión financiera de todos los módulos

**Issue en GitHub:** [#99](https://github.com/JanettheMillan/KoPay/issues/99).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S5-01 a S5-11.
- **Historias relacionadas:** HU-01 a HU-29.
- **Criterio de aceptación:** Se documentan resultados de movimientos, tarjetas, deudas, ajustes y respaldo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-14 · Ejecutar pruebas del módulo de contador y servicio externo

**Issue en GitHub:** [#100](https://github.com/JanettheMillan/KoPay/issues/100).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S5-03, S5-06, S5-12.
- **Historias relacionadas:** HU-35, HU-37 a HU-42.
- **Criterio de aceptación:** Se prueban autorización, revocación, acceso indebido y fallos externos.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-15 · Consolidar evidencias y defectos de la versión candidata

**Issue en GitHub:** [#101](https://github.com/JanettheMillan/KoPay/issues/101).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S5-13, S5-14.
- **Historias relacionadas:** HU-01 a HU-42.
- **Criterio de aceptación:** Casos, capturas e issues abiertos quedan ligados a versión y dispositivo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-16 · Preparar APK de entrega e instalación de prueba

**Issue en GitHub:** [#102](https://github.com/JanettheMillan/KoPay/issues/102).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `release`.
- **Depende de:** S5-12.
- **Historias relacionadas:** HU-01 a HU-42.
- **Criterio de aceptación:** El APK instala y abre en Android; se registra versión y dispositivo.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-17 · Revisar documentación, trazabilidad y Pull Requests finales

**Issue en GitHub:** [#103](https://github.com/JanettheMillan/KoPay/issues/103).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `docs`.
- **Depende de:** S5-15, S5-16, S5-20.
- **Historias relacionadas:** HU-01 a HU-42.
- **Criterio de aceptación:** Cada módulo tiene tarjeta, historia, caso y evidencia de revisión.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-18 · Preparar demostración y cierre de entrega

**Issue en GitHub:** [#104](https://github.com/JanettheMillan/KoPay/issues/104).

- **Responsable propuesto:** Rubén (`RuAbogado`).
- **Módulo o etiqueta:** `release`.
- **Depende de:** S5-16, S5-17.
- **Historias relacionadas:** HU-01 a HU-42.
- **Criterio de aceptación:** La demo recorre usuario, contador y errores clave con resultados registrados.
- **Evidencia al cerrar:** Issue del Project, cambio o documento revisado y caso de prueba con resultado cuando corresponda.

#### S5-19 · Comprobar sincronización entre dispositivos

**Issue en GitHub:** [#105](https://github.com/JanettheMillan/KoPay/issues/105).

- **Responsable propuesto:** Francisco (`CiscoPaquitoTracer`).
- **Módulo o etiqueta:** `feature`.
- **Depende de:** S5-07 a S5-11.
- **Historias relacionadas:** HU-36.
- **Criterio de aceptación:** La misma cuenta consulta desde dos instalaciones los cambios guardados en la base remota, sin duplicados ni datos de otra cuenta.
- **Evidencia al cerrar:** Issue, cambio necesario y verificación documentada con dos dispositivos o emuladores; este flujo no tiene caso formal de integración en el plan reducido.

#### S5-20 · Verificar recuperación y sincronización finales

**Issue en GitHub:** [#106](https://github.com/JanettheMillan/KoPay/issues/106).

- **Responsable propuesto:** Luis (`GleipM`).
- **Módulo o etiqueta:** `test`.
- **Depende de:** S4-19, S4-20, S5-19.
- **Historias relacionadas:** HU-32, HU-36.
- **Criterio de aceptación:** Se registran resultados, datos, dispositivos, fallos y evidencia de ambas historias.
- **Evidencia al cerrar:** Casos ejecutados con fecha y versión, vinculados a sus tarjetas.

## Mapa de trazabilidad por módulo

Los rangos muestran las tarjetas principales. El plan de pruebas conserva 79 casos unitarios y solo tres casos de interfaz y tres de integración. Si una actividad no tiene caso formal en esa selección, su Issue debe registrar igualmente la comprobación del criterio de aceptación y la evidencia real.

| Módulo o vista | Historias | Actividades principales | Casos seleccionados o evidencia |
| :--- | :--- | :--- | :--- |
| Base Flutter, navegación y resumen | HU-07 a HU-09 | S1-01, S1-03 a S1-06 | UT-30 a UT-46; INT-01. |
| Movimientos e ingresos | HU-01 a HU-12 | S1-02, S1-07 a S1-18, S5-01, S5-02, S5-07, S5-08 | UT-01 a UT-03, UT-31 a UT-46; UI-02 e INT-01. |
| Tarjetas, deudas y pagos | HU-13 a HU-23 | S2-07 a S2-17, S5-04, S5-05, S5-10, S5-11 | UT-04 a UT-12, UT-16, UT-17, UT-22 a UT-28, UT-64 a UT-69; UI-07. |
| Ajustes, categorías y archivos | HU-24 a HU-29 | S2-03 a S2-06, S2-18, S2-20 | UT-13, UT-14, UT-20, UT-21, UT-29, UT-59 a UT-63; comprobación de archivos y borrado en el Issue. |
| Cuentas, sesión y seguridad | HU-30 a HU-34 | S3-04 a S3-18, S4-01 a S4-03, S4-07 a S4-20 | UT-47 a UT-49, FUT-01, FUT-13, FUT-14; FUT-03. |
| Servicio de terceros y ambientes | HU-35 | S3-02, S5-06 | FUT-07, FUT-10, FUT-17, FUT-20; respuesta real en el Issue. |
| Datos remotos y sincronización | HU-34, HU-36 | S3-04, S5-01 a S5-11, S5-19, S5-20 | Verificación con dos dispositivos y evidencia en el Issue. |
| Vista de contador y consentimiento | HU-37 a HU-42 | S1-01, S1-03, S1-19, S2-19, S3-06, S3-14, S4-04 a S4-06, S4-09 a S4-12, S5-03, S5-09, S5-12, S5-14 | UT-50 a UT-58, FUT-21, FUT-22; FUT-25 y FUT-30. |
| APK, calidad y evidencia | HU-01 a HU-42 | S1-16 a S1-18, S2-16 a S2-18, S3-16 a S3-18, S4-16 a S4-18, S5-13 a S5-18, S5-20 | Instalación y demostración registradas en el Issue. |

## Reglas de trazabilidad y cierre

1. Crear o relacionar cada tarjeta en el [Project 3](https://github.com/users/JanettheMillan/projects/3) con el sprint correspondiente. Conservar el ID documental en la descripción para localizarla.
2. Para código: abrir rama individual, hacer commits reales y presentar Pull Request vinculado al Issue. Un compañero revisa antes de integrar.
3. Para pruebas: registrar fecha, versión, dispositivo, datos, resultado observado y evidencia. Un caso aún no ejecutado sigue Pendiente.
4. Si cambia el alcance, actualizar primero el criterio de aceptación y las historias; después mover o dividir la tarjeta.
5. El patrón de diseño, ambientes, base administrada, servicio externo y módulo contador tienen tareas concretas en este backlog y se verifican con los documentos de arquitectura y pruebas.

El módulo de contador está comprometido como objetivo del 15 de diciembre por indicación del equipo. Su integración depende de autenticación, autorización y API financiera; el Sprint 5 concentra esas dependencias y requiere revisión temprana de capacidad.
