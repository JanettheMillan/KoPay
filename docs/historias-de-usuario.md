# Historias de usuario de KoPay

**Proyecto:** KoPay — aplicación móvil de finanzas personales  
**Versión del documento:** 3.2

**Actualización:** 27 de octubre de 2026
**Estado:** catálogo de necesidades y criterios propuestos; las pruebas aún no se han ejecutado.

## Alcance y lectura

Las historias HU-01 a HU-29 describen los módulos financieros y de configuración previstos para el repositorio de entrega. Las HU-30 a HU-36 cubren autenticación, servicio externo y sincronización; las HU-37 a HU-42 cubren la vista de contador y el consentimiento de la persona usuaria. Todas forman parte del producto objetivo antes del 15 de diciembre. Su presencia aquí expresa un requisito, no un resultado aprobado.

Los identificadores HU se conservan para no romper las referencias del backlog y de las tarjetas. Las historias se presentan por módulo y por el sprint en que se desarrollan funcionalmente; una misma historia puede continuar en otro sprint.

Cada historia indica el **sprint de desarrollo**, las actividades del [backlog](backlog-desarrollo-desde-cero.md) y sus responsables propuestos. Los nombres reflejan a quienes ya aparecen asignados a esas actividades; no crean una asignación nueva en el tablero. Las actividades de definición, maqueta, revisión y prueba pueden ocurrir en otros sprints. La tabla vertical conserva además los datos solicitados en clase.

**Tipos:** Unitaria comprueba una función o cálculo aislado; Interfaz comprueba
la interacción visible; Integración comprueba varias partes juntas.
El tipo indicado describe cómo se comprobaría el criterio completo; el [plan de pruebas reducido](plan-de-pruebas.md) solo conserva tres casos de interfaz y tres de integración. Las demás historias mantienen sus criterios de aceptación para verificarlos al cerrar sus actividades.

## Orden de trabajo por sprint

| Sprint | Historias que se desarrollan o continúan |
| :--- | :--- |
| 1 | HU-01 a HU-09 y HU-29. |
| 2 | HU-10 a HU-28. |
| 3 | HU-30, HU-31 y HU-34. |
| 4 | HU-31 a HU-34 y HU-37 a HU-42. |
| 5 | HU-01, HU-02, HU-05, HU-06, HU-09, HU-13 a HU-23, HU-35, HU-36 y HU-38 a HU-42. |

Las dependencias indican **qué historia debe estar disponible para completar el criterio**, no una fecha de inicio obligatoria. Los trabajos de interfaz, lógica y datos pueden prepararse en paralelo mientras sus contratos estén acordados. El milestone del Issue indica su sprint en el Project.

## Movimientos e ingresos · base del Sprint 1

### HU-01 · Registrar un gasto

> Como usuario, quiero registrar un gasto para controlar mi dinero.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1 y 5** |
| Actividades del backlog | S1-07, S1-10, S1-13, S5-01, S5-07. |
| Responsables propuestos | Enrique, Francisco, Janetthe. |
| ¿Qué comprueba? | Validación, guardado y actualización de vistas. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Un gasto válido aparece en Inicio y Movimientos; el gasto y saldo del mes se actualizan. |

### HU-02 · Registrar un ingreso

> Como usuario, quiero registrar un ingreso para conocer el dinero recibido.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1 y 5** |
| Actividades del backlog | S1-07, S1-11, S1-14, S5-02, S5-08. |
| Responsables propuestos | Enrique, Francisco, Janetthe. |
| ¿Qué comprueba? | Formulario de ingreso, guardado y resumen. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El ingreso aparece en Inicio y Movimientos; ingresos y saldo del mes se actualizan. |

### HU-03 · Registrar un movimiento positivo

> Como usuario, quiero registrar un movimiento positivo desde el formulario de movimientos.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1** |
| Depende de | HU-01. |
| Actividades del backlog | S1-12, S1-13. |
| Responsables propuestos | Francisco, Janetthe. |
| ¿Qué comprueba? | Cambio de tipo y suma al total de ingresos. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El movimiento se guarda con importe positivo y se incluye una sola vez en el resumen. |

### HU-04 · Evitar registros incompletos

> Como usuario, quiero que KoPay rechace montos inválidos o descripciones vacías.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1** |
| Depende de | HU-01 y HU-02. |
| Actividades del backlog | S1-12, S1-13, S1-14. |
| Responsables propuestos | Francisco, Janetthe. |
| ¿Qué comprueba? | Validaciones visibles de los formularios. |
| Tipo de prueba | Interfaz. |
| Criterio de aprobación | No se guarda un gasto o ingreso sin nombre o descripción ni con monto inválido. |

### HU-05 · Editar un movimiento

> Como usuario, quiero corregir un movimiento para mantener mi historial exacto.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1 y 5** |
| Depende de | HU-01. |
| Actividades del backlog | S1-09, S1-10, S5-01, S5-07. |
| Responsables propuestos | Enrique, Francisco. |
| ¿Qué comprueba? | Edición y persistencia del registro. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La lista y el resumen muestran los nuevos datos después de guardar. |

### HU-06 · Eliminar un movimiento

> Como usuario, quiero eliminar un movimiento incorrecto con confirmación.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1 y 5** |
| Depende de | HU-01. |
| Actividades del backlog | S1-09, S1-10, S5-01, S5-07. |
| Responsables propuestos | Enrique, Francisco. |
| ¿Qué comprueba? | Confirmación, eliminación y actualización de vistas. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Cancelar conserva el registro; confirmar lo elimina y recalcula el resumen. |

### HU-07 · Consultar el historial

> Como usuario, quiero consultar mis ingresos y gastos ordenados por fecha.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1** |
| Depende de | HU-01 y HU-02. |
| Actividades del backlog | S1-05, S1-09, S1-15. |
| Responsables propuestos | Maximiliano, Enrique, Janetthe. |
| ¿Qué comprueba? | Listado y orden de los registros. |
| Tipo de prueba | Interfaz. |
| Criterio de aprobación | Movimientos muestra ingresos y gastos del más reciente al más antiguo. |

### HU-08 · Consultar un mes

> Como usuario, quiero cambiar de mes para revisar la actividad de ese periodo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1** |
| Depende de | HU-07. |
| Actividades del backlog | S1-06. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Selección de periodo y filtrado de datos. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Inicio muestra la actividad y los totales del mes seleccionado. |

### HU-09 · Conocer el balance

> Como usuario, quiero ver el balance mensual para entender cuánto dinero tengo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1 y 5** |
| Depende de | HU-01, HU-02 y HU-08. |
| Actividades del backlog | S1-06, S5-02, S5-08. |
| Responsables propuestos | Maximiliano, Enrique, Francisco. |
| ¿Qué comprueba? | Cálculo de ingresos, gastos, pagos de tarjeta y saldo. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Con datos conocidos, el saldo coincide con ingresos menos gastos y pagos de tarjeta del mes. |

## Persistencia local · base del Sprint 1

### HU-29 · Conservar datos al reabrir

> Como usuario, quiero que mis registros sigan disponibles después de cerrar KoPay.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **1** |
| Depende de | HU-01 y HU-02. |
| Actividades del backlog | S1-08, S1-09. |
| Responsables propuestos | Enrique. |
| ¿Qué comprueba? | Persistencia local en SQLite. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Los registros siguen visibles al reabrir la app en el mismo dispositivo. |

## Categorías · Sprint 2

### HU-10 · Usar categorías

> Como usuario, quiero asignar una categoría a cada gasto para reconocer su propósito.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Depende de | HU-01. |
| Actividades del backlog | S2-04. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Selección y conservación de categoría. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El gasto guardado conserva la categoría elegida. |

### HU-11 · Crear categorías

> Como usuario, quiero añadir una categoría propia para clasificar mis gastos.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Actividades del backlog | S2-04. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Alta y persistencia de categorías. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La categoría nueva aparece en el selector tras volver a abrir KoPay. |

### HU-12 · Administrar categorías

> Como usuario, quiero renombrar o quitar categorías que ya no uso.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Depende de | HU-11. |
| Actividades del backlog | S2-04. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Edición, eliminación y actualización del selector. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El selector refleja el cambio y este permanece al reabrir la app. |

## Tarjetas y deudas

### HU-13 · Registrar una tarjeta

> Como usuario, quiero registrar una tarjeta para conocer mi crédito.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Actividades del backlog | S2-07, S2-10, S2-13, S5-04, S5-10. |
| Responsables propuestos | Enrique, Francisco, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Formulario, guardado y crédito disponible. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La tarjeta aparece y el crédito disponible es el límite menos el saldo usado, con mínimo cero. |

### HU-14 · Editar una tarjeta

> Como usuario, quiero actualizar los datos de mi tarjeta cuando cambien.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-13. |
| Actividades del backlog | S2-07, S2-10, S2-13, S5-04, S5-10. |
| Responsables propuestos | Enrique, Francisco, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Edición de límite, saldo y fechas. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Los cambios persisten y el crédito disponible se recalcula. |

### HU-15 · Eliminar una tarjeta

> Como usuario, quiero eliminar una tarjeta que ya no utilizo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-13. |
| Actividades del backlog | S2-10, S2-13, S5-04, S5-10. |
| Responsables propuestos | Francisco, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Confirmación y eliminación. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Cancelar la conserva; confirmar la quita de la lista. |

### HU-16 · Registrar un pago de tarjeta

> Como usuario, quiero registrar un pago para reducir el saldo usado de mi tarjeta.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-01 y HU-13. |
| Actividades del backlog | S2-09, S2-15, S5-05, S5-11. |
| Responsables propuestos | Enrique, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Actualización de tarjeta y creación del movimiento de pago. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El saldo usado baja por el pago, sube el crédito disponible y el pago aparece en Movimientos. |

### HU-17 · Evitar pagos de tarjeta inválidos

> Como usuario, quiero evitar un pago mayor que el saldo usado.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-16. |
| Actividades del backlog | S2-15, S5-10. |
| Responsables propuestos | Janetthe. |
| ¿Qué comprueba? | Validación del monto a pagar. |
| Tipo de prueba | Interfaz. |
| Criterio de aprobación | Un monto cero, no numérico o mayor que el saldo usado no se guarda. |

### HU-18 · Ver pagos próximos de tarjeta

> Como usuario, quiero ver cuándo vence mi tarjeta para organizarme.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-13. |
| Actividades del backlog | S2-12, S5-10. |
| Responsables propuestos | Francisco, Janetthe. |
| ¿Qué comprueba? | Cálculo de fecha y estado de pago. |
| Tipo de prueba | Unitaria. |
| Criterio de aprobación | Con fechas y pagos conocidos, la tarjeta aparece con los días restantes y estado esperado. |

### HU-19 · Registrar una deuda

> Como usuario, quiero registrar una deuda para dar seguimiento a lo que debo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Actividades del backlog | S2-08, S2-11, S2-14, S5-04, S5-10. |
| Responsables propuestos | Enrique, Francisco, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Formulario y persistencia de deuda. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La deuda aparece con nombre, mensualidad, saldo restante y vencimiento. |

### HU-20 · Pagar una deuda

> Como usuario, quiero registrar pagos de deuda para reducir el saldo pendiente.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-01 y HU-19. |
| Actividades del backlog | S2-09, S2-11, S2-15, S5-05, S5-11. |
| Responsables propuestos | Enrique, Francisco, Janetthe, Maximiliano. |
| ¿Qué comprueba? | Actualización de deuda y creación de movimiento. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El pago aparece en Movimientos y el saldo restante disminuye por su importe. |

### HU-21 · Liquidar una deuda

> Como usuario, quiero identificar cuándo una deuda queda pagada.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-20. |
| Actividades del backlog | S2-08, S2-11, S5-04, S5-10. |
| Responsables propuestos | Enrique, Francisco, Maximiliano, Janetthe. |
| ¿Qué comprueba? | Cálculo del saldo y cambio de estado. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Un pago por el saldo restante deja la deuda en cero y estado pagada. |

### HU-22 · Evitar pagos de deuda inválidos

> Como usuario, quiero evitar pagar más de lo que debo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-20. |
| Actividades del backlog | S2-15, S5-10. |
| Responsables propuestos | Janetthe. |
| ¿Qué comprueba? | Validación del monto del pago. |
| Tipo de prueba | Interfaz. |
| Criterio de aprobación | Un monto cero, no numérico o superior al saldo restante no se guarda. |

### HU-23 · Ver compromisos próximos

> Como usuario, quiero consultar mis pagos próximos para organizar mis fechas.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2 y 5** |
| Depende de | HU-18 y HU-19. |
| Actividades del backlog | S2-12, S5-05, S5-11. |
| Responsables propuestos | Francisco, Maximiliano, Janetthe. |
| ¿Qué comprueba? | Cálculo y orden de compromisos de tarjetas y deudas. |
| Tipo de prueba | Unitaria. |
| Criterio de aprobación | Los compromisos vigentes se ordenan por días restantes; los ya pagados se identifican. |

## Ajustes y datos

### HU-24 · Elegir moneda

> Como usuario, quiero elegir la moneda con la que se muestran mis importes.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Actividades del backlog | S2-05. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Formato y persistencia de moneda. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La moneda seleccionada cambia el símbolo visible y se conserva al reabrir la app. |

### HU-25 · Elegir idioma

> Como usuario, quiero elegir español o inglés para usar la app.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Actividades del backlog | S2-05. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Cambio y persistencia del idioma. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Los textos traducidos cambian al idioma elegido y la selección se conserva. |

### HU-26 · Exportar respaldo Excel

> Como usuario, quiero exportar una copia de mis datos en Excel.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Depende de | HU-29. |
| Actividades del backlog | S2-06. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Generación y opción de compartir un archivo XLSX. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La exportación crea un archivo XLSX que contiene los registros disponibles. |

### HU-27 · Importar respaldo CSV

> Como usuario, quiero importar un respaldo CSV compatible para recuperar datos.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Depende de | HU-29. |
| Actividades del backlog | S2-06. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Confirmación, lectura y reemplazo de registros. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Un CSV válido se importa y sus registros aparecen; cancelar conserva los datos actuales. |

### HU-28 · Borrar los datos locales

> Como usuario, quiero borrar mis datos del dispositivo cuando lo decida.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **2** |
| Depende de | HU-29. |
| Actividades del backlog | S2-03, S2-20, S2-18. |
| Responsables propuestos | Maximiliano implementa; Rubén define criterios y Luis prepara la prueba. |
| ¿Qué comprueba? | Confirmación y eliminación local. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Cancelar conserva los registros; confirmar borra tarjetas, deudas, movimientos e ingresos. |

## Cuentas, servicios y sincronización · desarrollo planificado

### HU-30 · Crear una cuenta

> Como usuario, quiero crear una cuenta para acceder a mis datos con credenciales.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **3** |
| Actividades del backlog | S3-05, S3-07, S3-10. |
| Responsables propuestos | Enrique, Francisco, Janetthe. |
| ¿Qué comprueba? | Registro y rechazo de datos inválidos. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, una cuenta válida se crea y una duplicada se rechaza sin crear otra. |

### HU-31 · Iniciar sesión

> Como usuario, quiero iniciar sesión para acceder a mi cuenta.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **3 y 4** |
| Depende de | HU-30. |
| Actividades del backlog | S3-08, S3-09, S3-11, S4-01, S4-07, S4-08, S4-10. |
| Responsables propuestos | Francisco, Janetthe, Enrique. |
| ¿Qué comprueba? | Autenticación y apertura de sesión. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, credenciales válidas abren la sesión y las inválidas no permiten entrar. |

### HU-32 · Recuperar acceso

> Como usuario, quiero recuperar mi acceso si olvido la contraseña.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4** |
| Depende de | HU-30. |
| Actividades del backlog | S4-19, S4-20. |
| Responsables propuestos | Francisco, Janetthe. |
| ¿Qué comprueba? | Solicitud y validación del proceso de recuperación. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, el proceso permite restablecer el acceso sin exponer la contraseña. |

### HU-33 · Cerrar sesión

> Como usuario, quiero cerrar sesión al terminar de usar KoPay.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4** |
| Depende de | HU-31. |
| Actividades del backlog | S4-02, S4-08, S4-10. |
| Responsables propuestos | Enrique, Francisco, Janetthe. |
| ¿Qué comprueba? | Cierre de sesión y retorno a acceso. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, cerrar sesión impide consultar datos privados hasta iniciar de nuevo. |

### HU-34 · Proteger mis datos por cuenta

> Como usuario, quiero que otra cuenta no vea mis registros.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **3 y 4** |
| Depende de | HU-30 y HU-31. |
| Actividades del backlog | S3-05, S4-03, S4-04, S4-09. |
| Responsables propuestos | Enrique, Maximiliano, Francisco. |
| ¿Qué comprueba? | Separación de datos y control de acceso. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, cada cuenta solo puede consultar y modificar sus propios datos. |

### HU-35 · Usar un servicio externo

> Como usuario, quiero consultar información de un servicio externo útil para mis finanzas.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **5** |
| Actividades del backlog | S3-02, S5-06. |
| Responsables propuestos | Maximiliano. |
| ¿Qué comprueba? | Respuesta válida y manejo de fallos de la API elegida. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras elegir e implementar la API, se muestra la respuesta correcta y se informa si falla. |

### HU-36 · Sincronizar dispositivos

> Como usuario, quiero consultar mis datos desde otro dispositivo.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **5** |
| Depende de | HU-31 y HU-34. |
| Actividades del backlog | S3-04, S5-19. |
| Responsables propuestos | Enrique, Francisco. |
| ¿Qué comprueba? | Sincronización y consistencia entre sesiones. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras implementarse, los cambios autorizados aparecen en el segundo dispositivo. |

## Vista de contador y autorización · desarrollo planificado

### HU-37 · Acceder como contador

> Como contador, quiero iniciar sesión con mi rol para acceder a una vista de trabajo propia.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4** |
| Depende de | HU-31 y HU-34. |
| Actividades del backlog | S3-06, S4-04, S4-09, S4-12. |
| Responsables propuestos | Enrique, Maximiliano, Francisco, Janetthe. |
| ¿Qué comprueba? | Identificación del rol y navegación a la vista correspondiente. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Una cuenta de contador válida abre su vista; una cuenta de usuario no recibe privilegios de contador. |

### HU-38 · Autorizar a un contador

> Como usuario, quiero autorizar a un contador específico para que consulte mis finanzas.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4 y 5** |
| Depende de | HU-34 y HU-37. |
| Actividades del backlog | S3-06, S4-05, S4-11, S5-12. |
| Responsables propuestos | Enrique, Maximiliano, Janetthe. |
| ¿Qué comprueba? | Selección, consentimiento y registro de la relación de acceso. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Solo el contador elegido puede consultar los datos autorizados después de confirmar el permiso. |

### HU-39 · Consultar clientes autorizados

> Como contador, quiero ver las personas que me autorizaron para elegir cuál consultar.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4 y 5** |
| Depende de | HU-37 y HU-38. |
| Actividades del backlog | S4-06, S4-12, S5-03, S5-09, S5-12. |
| Responsables propuestos | Maximiliano, Janetthe, Enrique, Francisco. |
| ¿Qué comprueba? | Listado filtrado de autorizaciones vigentes. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | La vista solo lista a las personas con autorización vigente para esa cuenta de contador. |

### HU-40 · Revisar resumen y movimientos

> Como contador, quiero consultar el resumen y los movimientos de una persona autorizada para apoyarla en el análisis de sus finanzas.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4 y 5** |
| Depende de | HU-09 y HU-39. |
| Actividades del backlog | S2-19, S4-06, S5-03, S5-09, S5-12. |
| Responsables propuestos | Janetthe, Maximiliano, Enrique, Francisco. |
| ¿Qué comprueba? | Consulta de datos remotos, periodo y presentación en la vista del contador. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El resumen y el historial muestran únicamente los datos de la persona y del periodo seleccionados. |

### HU-41 · Revocar acceso

> Como usuario, quiero retirar el permiso de un contador para detener nuevas consultas.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4 y 5** |
| Depende de | HU-38. |
| Actividades del backlog | S4-05, S4-11, S5-09, S5-12. |
| Responsables propuestos | Maximiliano, Janetthe, Francisco. |
| ¿Qué comprueba? | Revocación y comprobación del permiso en el servidor. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | Tras revocar, el contador deja de ver a la persona y la API rechaza nuevas consultas de sus datos. |

### HU-42 · Impedir modificaciones del contador

> Como usuario, quiero que el contador tenga acceso de solo lectura para conservar el control de mis registros.

| Campo | Descripción |
| :--- | :--- |
| Sprint de desarrollo | **4 y 5** |
| Depende de | HU-34, HU-37 y HU-38. |
| Actividades del backlog | S4-06, S5-03. |
| Responsables propuestos | Maximiliano, Enrique. |
| ¿Qué comprueba? | Permisos de escritura y ausencia de acciones de edición en la vista. |
| Tipo de prueba | Integración. |
| Criterio de aprobación | El contador no puede crear, modificar ni eliminar movimientos, ingresos, tarjetas, deudas o pagos de otra persona, incluso mediante llamadas directas a la API. |

## Revisión del equipo

- [ ] Confirmar con el equipo los sprints y responsables propuestos según su capacidad.
- [ ] Actualizar los criterios cuando cambie el comportamiento real.
- [ ] Registrar los resultados reales en el plan de pruebas.
