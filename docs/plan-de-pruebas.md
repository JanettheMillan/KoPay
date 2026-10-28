# Plan de pruebas de KoPay

> **KoPay · Aplicación móvil de finanzas personales**
>
> Versión 3.1 · 9 de octubre de 2026 · Estado: planificación

El plan prioriza la lógica aislada para mantener la ejecución manejable: **85 casos propuestos**, de los cuales **79 son unitarios**, **3 de interfaz** y **3 de integración**. Ningún caso se presenta como aprobado sin evidencia de ejecución.

## Contenido

1. [Alcance y decisión del equipo](#1-alcance-y-decisión-del-equipo)
2. [Tipos de prueba](#2-tipos-de-prueba)
3. [Preparación](#3-preparación)
4. [Casos unitarios](#4-casos-unitarios)
5. [Casos de interfaz](#5-casos-de-interfaz)
6. [Casos de integración](#6-casos-de-integración)
7. [Cobertura por módulo](#7-cobertura-por-módulo)
8. [Registro y evidencia](#8-registro-y-evidencia)

---

## 1. Alcance y decisión del equipo

Se eligió un catálogo **principalmente unitario** para comprobar modelos, cálculos, fechas, permisos y transformación de datos sin depender de un dispositivo o servidor. Se conservaron solo tres casos de interfaz y tres de integración como muestra de los recorridos más importantes. Esta selección no comprueba por sí sola todos los criterios de aceptación de las 42 historias.

El identificador **FUT** vincula los casos de cuentas, servicios y contador con las actividades del backlog. Los casos UT-31 a UT-70 especifican comportamientos que deberán implementarse como pruebas automatizadas y ejecutarse durante el desarrollo. Un caso documentado no equivale a una ejecución aprobada.

**Respaldos:** Exportar produce XLSX; Importar acepta CSV compatible. Son rutas distintas y se comprueban por separado.

## 2. Tipos de prueba

- **Unitaria:** comprueba una función, un modelo o un cálculo aislado con datos conocidos.
- **Interfaz:** comprueba controles, mensajes o navegación visibles sin afirmar que otra capa funcionó.
- **Integración:** comprueba el resultado de varias partes juntas, por ejemplo formulario, almacenamiento y resumen.

Un flujo completo no se etiqueta como unitario para aumentar la cantidad de esa categoría. Cada ficha tiene un solo tipo principal.

## 3. Preparación

1. Anotar fecha, responsable y versión o commit al ejecutar cada caso.
2. Usar datos ficticios y fechas conocidas. Para fechas relativas, fijar el reloj del entorno de prueba cuando sea posible.
3. Elegir dispositivo o emulador solo para interfaz e integración; las unitarias pueden ejecutarse sin UI.
4. Registrar resultado observado y evidencia. Hasta entonces, el estado es **pendiente**.

**Datos sugeridos:** ingreso de 500, gasto de 50, tarjeta con límite de 1000 y deuda con saldo de 300. Ajustar fechas al mes que se esté evaluando.

## 4. Casos unitarios

Se ordenan primero porque representan la mayor parte del plan. Los identificadores FUT en este bloque son casos unitarios de funciones de cuentas, configuración o contador.

### 4.1 Modelos, cálculos y formatos

#### UT-01 · Copia de movimiento

**HU-05** · Unitaria · Prioridad alta

- **Preparación:** Un MovementModel con fecha, monto y categoría conocidos.
- **Acción:** Aplicar copyWith cambiando solo monto y descripción.

> **Resultado esperado:** La copia contiene los valores nuevos y conserva los demás; el original no cambia.

#### UT-02 · Conversión de movimiento a mapa

**HU-01** · Unitaria · Prioridad media

- **Preparación:** Un MovementModel con todos sus campos.
- **Acción:** Convertir a mapa y reconstruir el modelo.

> **Resultado esperado:** Fecha, importe, tipo, categoría y descripción conservan sus valores.

#### UT-03 · Ingreso representado como movimiento

**HU-02** · Unitaria · Prioridad alta

- **Preparación:** IncomeModel: nombre Nómina, monto 500, fecha conocida.
- **Acción:** Aplicar toMovement().

> **Resultado esperado:** Se obtiene un movimiento positivo con nombre, fecha, categoría Ingreso y tipo legacy_income.

#### UT-04 · Conversión de tarjeta a mapa

**HU-13** · Unitaria · Prioridad media

- **Preparación:** CardModel con límite 1000 y saldo usado 200.
- **Acción:** Convertir a mapa y reconstruir el modelo.

> **Resultado esperado:** Se conservan límite, usado, disponible y días de corte y pago.

#### UT-05 · Conversión de deuda a mapa

**HU-19** · Unitaria · Prioridad media

- **Preparación:** DebtModel con saldo, mensualidad, fecha y estado conocidos.
- **Acción:** Convertir a mapa y reconstruir el modelo.

> **Resultado esperado:** Todos los campos mantienen sus valores.

#### UT-06 · Urgencia de pago próximo

**HU-23** · Unitaria · Prioridad media

- **Preparación:** UpcomingPayment no pagado con 5 y 6 días restantes.
- **Acción:** Consultar isUrgent para ambos y para uno pagado.

> **Resultado esperado:** A 5 días es urgente; a 6 o ya pagado no lo es.

#### UT-07 · Importe visible de pago próximo

**HU-23** · Unitaria · Prioridad media

- **Preparación:** UpcomingPayment con importe 300, pagado 100 y estado pagado o pendiente.
- **Acción:** Consultar displayAmount en ambos estados.

> **Resultado esperado:** Muestra 100 si está pagado y tiene pago registrado; en otro caso muestra 300.

#### UT-08 · Orden de compromisos

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Dos tarjetas o deudas con vencimientos a 3 y 10 días.
- **Acción:** Invocar computeUpcoming con fecha de referencia controlada por el entorno de prueba.

> **Resultado esperado:** El compromiso a 3 días aparece primero.

#### UT-09 · Tarjeta con pago cubierto

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta con pago mínimo 100 y movimiento de pago 100 del periodo vigente.
- **Acción:** Invocar computeUpcoming con la tarjeta y el movimiento.

> **Resultado esperado:** La tarjeta se marca cubierta y registra el importe pagado.

#### UT-10 · Deuda con pago cubierto

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Deuda con mensualidad 100 y movimiento de pago 100 del periodo vigente.
- **Acción:** Invocar computeUpcoming con la deuda y el movimiento.

> **Resultado esperado:** El compromiso se marca cubierto y registra el pago.

#### UT-11 · Deuda pagada o vencida

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Una deuda pagada y otra con fecha vencida.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** Ninguna se incluye en los compromisos próximos.

#### UT-12 · Cambio de mes en vencimiento de tarjeta

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta cuyo día de pago de este mes ya pasó.
- **Acción:** Invocar computeUpcoming con fecha de referencia controlada.

> **Resultado esperado:** El siguiente vencimiento corresponde al próximo mes.

#### UT-13 · Texto de días restantes

**HU-23** · Unitaria · Prioridad baja

- **Preparación:** Valores de 0, 1 y 3 días, en español e inglés.
- **Acción:** Invocar formatDaysLeft.

> **Resultado esperado:** Se obtiene hoy, en 1 día o en 3 días; en inglés se obtienen sus equivalentes.

#### UT-14 · Formato de importe

**HU-24** · Unitaria · Prioridad media

- **Preparación:** Importe 1234.5 y monedas MXN, USD y EUR.
- **Acción:** Invocar fmtCurrency con la configuración correspondiente.

> **Resultado esperado:** El símbolo y dos decimales corresponden a la moneda seleccionada.

#### UT-15 · Formato de fecha ISO

**HU-08** · Unitaria · Prioridad baja

- **Preparación:** Fecha fija 2026-10-08.
- **Acción:** Invocar dateToIso y fmtDate.

> **Resultado esperado:** dateToIso devuelve 2026-10-08 y fmtDate presenta día y mes según el idioma.

#### UT-16 · Copia parcial de tarjeta

**HU-14** · Unitaria · Prioridad media

- **Preparación:** Tarjeta con límite y saldo conocidos.
- **Acción:** Aplicar copyWith modificando solo usedBalance.

> **Resultado esperado:** La copia cambia el campo pedido y conserva nombre, banco, límite y fechas.

#### UT-17 · Copia parcial de deuda

**HU-21** · Unitaria · Prioridad media

- **Preparación:** Deuda pendiente con saldo 300.
- **Acción:** Aplicar copyWith con saldo 0 y estado paid.

> **Resultado esperado:** La copia refleja ambos cambios y la instancia original conserva sus valores.

#### UT-18 · Copia parcial de ingreso

**HU-02** · Unitaria · Prioridad media

- **Preparación:** Ingreso con nombre, monto y fecha.
- **Acción:** Aplicar copyWith modificando solo amount.

> **Resultado esperado:** La copia contiene el nuevo importe y mantiene nombre y fecha.

#### UT-19 · Conversión de ingreso a mapa

**HU-02** · Unitaria · Prioridad media

- **Preparación:** IncomeModel con datos conocidos.
- **Acción:** Convertir a mapa y reconstruir el modelo.

> **Resultado esperado:** Nombre, importe, fecha e identificador se conservan.

#### UT-20 · Emoji de categoría conocida

**HU-10** · Unitaria · Prioridad baja

- **Preparación:** Categorías Comida, Transporte e Ingreso.
- **Acción:** Invocar categoryEmoji con espacios y diferencias de mayúsculas.

> **Resultado esperado:** Se devuelve el emoji correspondiente tras normalizar el texto.

#### UT-21 · Emoji de categoría desconocida

**HU-10** · Unitaria · Prioridad baja

- **Preparación:** Categoría nueva sin coincidencia conocida.
- **Acción:** Invocar categoryEmoji.

> **Resultado esperado:** Se devuelve el emoji genérico de etiqueta.

#### UT-22 · Sin compromisos próximos

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Listas vacías de tarjetas, deudas y movimientos.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** La lista resultante está vacía.

#### UT-23 · Tarjeta que vence hoy

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta cuyo día de pago coincide con la fecha de ejecución.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** Los días restantes son cero y el compromiso aparece entre los próximos.

#### UT-24 · Deuda que vence hoy

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Deuda pendiente con fecha de vencimiento de hoy.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El compromiso aparece con cero días restantes.

#### UT-25 · Pago parcial de tarjeta

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta con mínimo 100 y pago vigente de 60.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El importe pagado es 60 y el compromiso todavía no aparece cubierto.

#### UT-26 · Pago parcial de deuda

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Deuda con mensualidad 100 y pago vigente de 60.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El importe pagado es 60 y el compromiso todavía no aparece cubierto.

#### UT-27 · Pago de otra tarjeta

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Dos tarjetas y un pago asociado solo a la primera.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El pago no cambia el estado de la segunda tarjeta.

#### UT-28 · Pago de otra deuda

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Dos deudas y un pago asociado solo a la primera.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El pago no cambia el estado de la segunda deuda.

#### UT-29 · Formato compacto del importe

**HU-24** · Unitaria · Prioridad baja

- **Preparación:** Importe 1234.5 y configuración de moneda conocida.
- **Acción:** Invocar fmtCompact.

> **Resultado esperado:** El resultado usa el símbolo configurado y no muestra decimales.

#### UT-30 · Fecha relativa de hoy y ayer

**HU-07** · Unitaria · Prioridad baja

- **Preparación:** Fechas calculadas a partir del día de ejecución.
- **Acción:** Invocar fmtRelative para hoy y ayer.

> **Resultado esperado:** Devuelve las etiquetas relativas correspondientes al idioma activo.

### 4.2 Resumen mensual, permisos y casos límite

#### UT-31 · Fecha dentro del mes

**HU-08** · Unitaria · Prioridad alta

- **Preparación:** Fecha 2026-10-09 y mes octubre 2026.
- **Acción:** Invocar isInMonth.

> **Resultado esperado:** Devuelve verdadero.

#### UT-32 · Mismo mes de otro año

**HU-08** · Unitaria · Prioridad alta

- **Preparación:** Fecha 2025-10-09 y mes octubre 2026.
- **Acción:** Invocar isInMonth.

> **Resultado esperado:** Devuelve falso; también compara el año.

#### UT-33 · Fecha mal formada

**HU-08** · Unitaria · Prioridad media

- **Preparación:** Cadena de fecha inválida.
- **Acción:** Invocar isInMonth.

> **Resultado esperado:** Devuelve falso sin lanzar una excepción.

#### UT-34 · Resumen mensual vacío

**HU-09** · Unitaria · Prioridad alta

- **Preparación:** Listas vacías de ingresos y movimientos.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** Ingresos, gastos, pagos y balance son cero.

#### UT-35 · Ingreso de la tabla de ingresos

**HU-02** · Unitaria · Prioridad alta

- **Preparación:** Ingreso de 500 dentro del mes elegido.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** El total de ingresos aumenta en 500.

#### UT-36 · Gasto ordinario en resumen

**HU-01** · Unitaria · Prioridad alta

- **Preparación:** Movimiento de compra por -50 en el mes elegido.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** Los gastos aumentan en 50 y el balance disminuye en 50.

#### UT-37 · Ingreso como movimiento

**HU-03** · Unitaria · Prioridad alta

- **Preparación:** Movimiento de tipo income por 200.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** El ingreso aumenta en 200 sin sumarse como gasto.

#### UT-38 · Pago de tarjeta separado

**HU-16** · Unitaria · Prioridad alta

- **Preparación:** Movimiento de tipo payment por -100.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** El pago aparece en cardPayments; no se suma a expenses.

#### UT-39 · Gastos por categoría

**HU-10** · Unitaria · Prioridad media

- **Preparación:** Dos compras de Comida por -30 y -20.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** La categoría Comida acumula 50.

#### UT-40 · Orden de categorías

**HU-09** · Unitaria · Prioridad media

- **Preparación:** Gastos de 20 en Salud y 80 en Comida.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** La primera categoría del desglose es Comida.

#### UT-41 · Exclusión de otro mes

**HU-08** · Unitaria · Prioridad alta

- **Preparación:** Ingreso y gasto del mes anterior.
- **Acción:** Calcular MonthSummary.of para el mes actual.

> **Resultado esperado:** Esos registros no alteran los totales del mes actual.

#### UT-42 · Balance del mes

**HU-09** · Unitaria · Prioridad alta

- **Preparación:** Ingresos 500, compras 120 y pagos de tarjeta 30.
- **Acción:** Calcular MonthSummary.of y consultar balance.

> **Resultado esperado:** El balance es 350.

#### UT-43 · Ingreso legado sin doble conteo

**HU-02** · Unitaria · Prioridad alta

- **Preparación:** Ingreso en IncomeModel y su representación legacy_income en movimientos.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** El ingreso se suma una sola vez.

#### UT-44 · Movimiento positivo no clasificado

**HU-09** · Unitaria · Prioridad media

- **Preparación:** Movimiento positivo cuyo tipo no es income.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** No se suma como ingreso ni gasto.

#### UT-45 · Movimiento de monto cero

**HU-09** · Unitaria · Prioridad baja

- **Preparación:** Movimiento de compra con monto cero.
- **Acción:** Calcular MonthSummary.of.

> **Resultado esperado:** No modifica ingresos, gastos ni pagos.

#### UT-46 · Límite entre dos meses

**HU-08** · Unitaria · Prioridad alta

- **Preparación:** Registros del último día de un mes y del primero del siguiente.
- **Acción:** Calcular MonthSummary.of para cada mes.

> **Resultado esperado:** Cada registro afecta solo a su mes.

#### UT-47 · Rol de usuario normal

**HU-37** · Unitaria · Prioridad alta

- **Preparación:** AuthUser con role user.
- **Acción:** Consultar isAccountant.

> **Resultado esperado:** Devuelve falso.

#### UT-48 · Rol de contador

**HU-37** · Unitaria · Prioridad alta

- **Preparación:** AuthUser con role accountant.
- **Acción:** Consultar isAccountant.

> **Resultado esperado:** Devuelve verdadero.

#### UT-49 · Conversión de cuenta

**HU-30** · Unitaria · Prioridad media

- **Preparación:** AuthUser con id, correo, rol y código de contador.
- **Acción:** Convertir con toMap y reconstruir con fromMap.

> **Resultado esperado:** Se conservan todos los campos.

#### UT-50 · Enlace pendiente

**HU-38** · Unitaria · Prioridad media

- **Preparación:** AccountantLink con status pending.
- **Acción:** Consultar isPending, isActive e isOpen.

> **Resultado esperado:** Solo isPending e isOpen son verdaderos.

#### UT-51 · Enlace activo

**HU-38** · Unitaria · Prioridad alta

- **Preparación:** AccountantLink con status active.
- **Acción:** Consultar isPending, isActive e isOpen.

> **Resultado esperado:** Solo isActive e isOpen son verdaderos.

#### UT-52 · Enlace terminado

**HU-41** · Unitaria · Prioridad alta

- **Preparación:** AccountantLink con status ended.
- **Acción:** Consultar isPending, isActive e isOpen.

> **Resultado esperado:** Los tres indicadores son falsos.

#### UT-53 · Datos del enlace

**HU-39** · Unitaria · Prioridad media

- **Preparación:** Respuesta con cliente, contador, permisos y fechas.
- **Acción:** Construir AccountantLink.fromMap.

> **Resultado esperado:** Se conservan identidades, permisos y estado.

#### UT-54 · Revisión marcada

**HU-40** · Unitaria · Prioridad media

- **Preparación:** MovementReview con status flagged.
- **Acción:** Consultar isFlagged.

> **Resultado esperado:** Devuelve verdadero.

#### UT-55 · Revisión aprobada

**HU-40** · Unitaria · Prioridad media

- **Preparación:** MovementReview con status ok.
- **Acción:** Consultar isFlagged.

> **Resultado esperado:** Devuelve falso.

#### UT-56 · Moneda predeterminada del cliente

**HU-40** · Unitaria · Prioridad media

- **Preparación:** Respuesta de cliente sin ajuste currency.
- **Acción:** Construir ClientData.fromMap.

> **Resultado esperado:** La moneda resultante es MXN.

#### UT-57 · Orden de movimientos del contador

**HU-40** · Unitaria · Prioridad media

- **Preparación:** Respuesta con movimientos en fechas desordenadas.
- **Acción:** Construir ClientData.fromMap.

> **Resultado esperado:** Los movimientos quedan del más reciente al más antiguo.

#### UT-58 · Datos no compartidos

**HU-39** · Unitaria · Prioridad alta

- **Preparación:** Respuesta del contador con una lista de recurso en null.
- **Acción:** Construir ClientData.fromMap.

> **Resultado esperado:** La lista permanece null y no se inventan registros.

#### UT-59 · Valor absoluto del importe

**HU-24** · Unitaria · Prioridad media

- **Preparación:** Importe negativo de -123.45.
- **Acción:** Invocar fmtCurrency.

> **Resultado esperado:** El texto muestra el importe absoluto con dos decimales.

#### UT-60 · Moneda explícita del cliente

**HU-40** · Unitaria · Prioridad media

- **Preparación:** Moneda global MXN e importe del cliente en EUR.
- **Acción:** Invocar fmtCurrency con currency EUR.

> **Resultado esperado:** Se muestra el símbolo de EUR sin cambiar la moneda global.

#### UT-61 · Fecha de pantalla inválida

**HU-07** · Unitaria · Prioridad baja

- **Preparación:** Cadena de fecha que no puede interpretarse.
- **Acción:** Invocar fmtDate.

> **Resultado esperado:** Devuelve el texto original.

#### UT-62 · Fecha relativa inválida

**HU-07** · Unitaria · Prioridad baja

- **Preparación:** Cadena de fecha que no puede interpretarse.
- **Acción:** Invocar fmtRelative.

> **Resultado esperado:** Devuelve el texto original.

#### UT-63 · Emoji por coincidencia parcial

**HU-10** · Unitaria · Prioridad baja

- **Preparación:** Texto Compra de comida.
- **Acción:** Invocar categoryEmoji.

> **Resultado esperado:** Devuelve el emoji de comida.

#### UT-64 · Deuda con fecha inválida

**HU-23** · Unitaria · Prioridad media

- **Preparación:** Deuda pendiente con dueDate inválida.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** No genera un vencimiento ficticio.

#### UT-65 · Deuda liquidada fuera de próximos

**HU-21** · Unitaria · Prioridad media

- **Preparación:** Deuda con status paid.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** No aparece entre los compromisos próximos.

#### UT-66 · Tarjeta sin pagos registrados

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta vigente sin movimientos de pago.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** Aparece pendiente y el importe pagado es cero.

#### UT-67 · Movimiento de tipo incorrecto

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta y movimiento asociado cuyo tipo no es payment.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** No se cuenta como abono a la tarjeta.

#### UT-68 · Pago fuera del periodo

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Tarjeta con pago posterior al vencimiento actual.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** El pago no cubre el periodo actual.

#### UT-69 · Identificadores de pagos

**HU-18** · Unitaria · Prioridad media

- **Preparación:** Dos pagos válidos con identificadores conocidos.
- **Acción:** Invocar computeUpcoming.

> **Resultado esperado:** paidMovementIds contiene ambos identificadores.

#### UT-70 · Identificador del ingreso legado

**HU-02** · Unitaria · Prioridad media

- **Preparación:** IncomeModel con id 7.
- **Acción:** Invocar toMovement.

> **Resultado esperado:** El id derivado es negativo y no coincide con el id original.

### 4.3 Lógica de cuentas y servicios

#### FUT-01 · Validar datos de cuenta

**HU-30** · Unitaria · Prioridad media

- **Preparación:** Se definieron reglas de correo y contraseña.
- **Acción:** Probar el validador con datos válidos, vacíos y mal formados.

> **Resultado esperado:** Solo los datos que cumplen la regla se aceptan; no se presume aún una regla concreta.

#### FUT-07 · Mapeo de respuesta externa

**HU-35** · Unitaria · Prioridad baja

- **Preparación:** Se definió proveedor y formato de respuesta.
- **Acción:** Entregar al adaptador una respuesta válida y otra incompleta.

> **Resultado esperado:** La válida se convierte al modelo acordado; la incompleta produce un error controlado.

#### FUT-10 · Configuración por ambiente

**Función técnica futura** · Unitaria · Prioridad media

- **Preparación:** Configuración de desarrollo y producción definida.
- **Acción:** Cargar cada conjunto de configuración de forma aislada.

> **Resultado esperado:** Cada ambiente selecciona sus propios valores requeridos sin mezclar credenciales ni direcciones.

#### FUT-13 · Formato de identificador de cuenta

**HU-30** · Unitaria · Prioridad media

- **Preparación:** Reglas de identificador definidas por el equipo.
- **Acción:** Probar valores válidos, vacíos y mal formados en el validador aislado.

> **Resultado esperado:** Solo los valores permitidos pasan la validación acordada.

#### FUT-14 · Reglas de contraseña

**HU-30** · Unitaria · Prioridad media

- **Preparación:** Política de contraseña definida.
- **Acción:** Probar longitud y caracteres límite en el validador aislado.

> **Resultado esperado:** El resultado coincide con la política documentada.

#### FUT-17 · Respuesta incompleta de la API

**HU-35** · Unitaria · Prioridad baja

- **Preparación:** Contrato de respuesta definido.
- **Acción:** Entregar al adaptador una respuesta con campo requerido ausente.

> **Resultado esperado:** Produce un error controlado según el contrato, sin datos inventados.

#### FUT-20 · Configuración incompleta de ambiente

**HU-35** · Unitaria · Prioridad media

- **Preparación:** Validador de configuración implementado.
- **Acción:** Omitir un valor requerido en ambiente de prueba.

> **Resultado esperado:** La validación detecta el valor faltante antes de usar el servicio.

#### FUT-21 · Rol de contador reconocido

**HU-37** · Unitaria · Prioridad alta

- **Preparación:** Función de permisos con roles usuario y contador.
- **Acción:** Evaluar ambos roles con el mismo permiso de lectura contable.

> **Resultado esperado:** Solo contador recibe ese permiso; usuario no adquiere permisos ajenos.

#### FUT-22 · Autorización vigente

**HU-38** · Unitaria · Prioridad alta

- **Preparación:** Regla de acceso con relaciones activas y revocadas.
- **Acción:** Evaluar una relación vigente y una revocada.

> **Resultado esperado:** Solo la relación vigente permite consultar.

## 5. Casos de interfaz

Se conserva una muestra de tres pantallas: captura de gasto, validación de pago de deuda y entrada a la vista de contador. Las demás pantallas mantienen criterios de aceptación en sus historias, pero no tienen caso de interfaz en este plan reducido.

#### UI-02 · Validación de gasto

**HU-04** · Interfaz · Prioridad alta

- **Preparación:** Formulario de movimiento abierto.
- **Acción:** Intentar guardar con monto vacío, cero y descripción vacía.

> **Resultado esperado:** El formulario permanece abierto y no se añade un gasto inválido.

#### UI-07 · Pago inválido de deuda

**HU-22** · Interfaz · Prioridad alta

- **Preparación:** Deuda con saldo restante 300.
- **Acción:** Intentar pagar 0 y después 301.

> **Resultado esperado:** Se muestra la validación correspondiente y no se registra el pago.

#### FUT-25 · Entrada a vista de contador

**HU-37** · Interfaz · Prioridad alta

- **Preparación:** Dos cuentas de prueba con roles distintos.
- **Acción:** Iniciar sesión con cada cuenta.

> **Resultado esperado:** El contador ve su navegación; el usuario ve la suya.

## 6. Casos de integración

Se conservan tres recorridos entre capas: gasto y resumen, inicio de sesión, y revocación de acceso del contador. Los demás recorridos requieren verificación al cerrar sus Issues, aunque no figuren como casos formales de integración en este plan.

#### INT-01 · Registrar gasto y actualizar resumen

**HU-01** · Integración · Prioridad alta

- **Preparación:** Mes actual y saldos iniciales anotados.
- **Acción:** Guardar gasto Prueba café de 50; abrir Inicio y Movimientos.

> **Resultado esperado:** El gasto aparece en ambas vistas; los gastos suben 50 y el saldo baja 50.

#### FUT-03 · Inicio de sesión

**HU-31** · Integración · Prioridad media

- **Preparación:** Cuenta de prueba existente.
- **Acción:** Ingresar credenciales correctas y después incorrectas.

> **Resultado esperado:** Solo las correctas abren la sesión; el error no revela datos sensibles.

#### FUT-30 · Revocación bloquea API

**HU-41** · Integración · Prioridad alta

- **Preparación:** Contador autorizado y sesión activa.
- **Acción:** Revocar permiso como usuario y repetir consulta como contador.

> **Resultado esperado:** La siguiente petición se rechaza; no usa acceso obsoleto.

## 7. Cobertura por módulo

- **Resumen, fechas y movimientos:** modelos y cálculos UT-01 a UT-03, UT-15, UT-30 a UT-46; UI-02 e INT-01 como muestras visibles.
- **Tarjetas, deudas y pagos:** modelos, pagos próximos y casos límite UT-04 a UT-12, UT-16, UT-17, UT-22 a UT-28, UT-64 a UT-69; UI-07 para un pago inválido.
- **Categorías, moneda e idioma:** UT-13, UT-14, UT-20, UT-21, UT-29, UT-59 a UT-63. La persistencia de ajustes no tiene caso formal de integración en esta versión reducida.
- **Cuentas, acceso y servicio externo:** UT-47 a UT-49, FUT-01, FUT-07, FUT-10, FUT-13, FUT-14, FUT-17 y FUT-20; FUT-03 como muestra de inicio de sesión.
- **Contador y datos compartidos:** UT-50 a UT-58, FUT-21, FUT-22; FUT-25 muestra la vista y FUT-30 la revocación en la API.
- **Respaldo, sincronización, base administrada y APK:** las historias y los Issues conservan sus criterios de aceptación. Este plan reducido no incluye un caso formal de interfaz o integración para esos entregables; la evidencia real de su verificación deberá registrarse al cerrar cada tarea.

La cobertura unitaria es amplia en lógica y modelos, pero las seis pruebas de interfaz e integración son una **muestra**, no una comprobación completa de la aplicación.

## 8. Registro y evidencia

Los **85 casos están pendientes de ejecución**. Al ejecutar uno, usar la ficha de la [guía de evidencias](guia-de-evidencias.md) con caso, fecha, responsable, versión, datos, resultado observado y enlace a captura o registro. Los resultados posibles son **Aprobado**, **Fallido** y **Bloqueado**. Las historias e Issues que no tienen caso formal en este plan también requieren evidencia de aceptación cuando se den por terminados.
