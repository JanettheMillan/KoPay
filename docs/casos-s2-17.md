# Pruebas de tarjetas, deudas y pagos

**Tarjeta:** S2-17 · [#15](https://github.com/JanettheMillan/KoPay/issues/15). **Historias:** HU-13 a HU-23.

## 1. Resultado por flujo

«Aprobado» significa que las pruebas citadas se ejecutaron y pasaron en `flutter test`. No incluye un recorrido en dispositivo.

| Flujo | Historia | Casos | Resultado | Defecto |
| :--- | :--- | :--- | :--- | :--- |
| Registrar tarjeta | HU-13 | UT-04, TAR-01 a TAR-09, CRE-01, CRE-02, CRE-05 a CRE-08, UI-TAR-01 a UI-TAR-04, FLU-01, FLU-02 | **Aprobado** | — |
| Editar tarjeta | HU-14 | UT-16, TAR-04, CRE-03, CRE-09, UI-TAR-05, FLU-03 | **Aprobado** | — |
| Eliminar tarjeta | HU-15 | CRE-04, UI-TAR-06, UI-PAY-05, DB-PAY-02, FLU-04 | **Aprobado** | — |
| Pagar tarjeta | HU-16 | UT-02 y PAG-01, PAG-02, PAG-05 a PAG-09 (`payments_test.dart`), DB-PAY-01, UI-PAY-01, FLU-05, FLU-10 | **Aprobado** en la repetición. Antes falló al editar un pago | D-09 (corregido) |
| Pago de tarjeta inválido | HU-17 | UT-PAY-01, DB-PAY-01, UI-PAY-02 | **Aprobado** | — |
| Pagos próximos de tarjeta | HU-18 | UT-09, UT-12, UT-23, UT-25, UT-27, UT-66 a UT-69, PRX-01, PRX-02, PRX-05 a PRX-07, FLU-05 | **Aprobado** el cálculo. La pantalla está pendiente | H-01 |
| Registrar deuda | HU-19 | UT-05, DEU-01 a DEU-04, DEU-06 a DEU-10, DPR-01, DPR-02, DPR-07 a DPR-11, UI-DEU-01 a UI-DEU-05, UI-DEU-07, FLU-06 | **Aprobado** | — |
| Pagar deuda | HU-20 | PAG-03, DPR-03, DPR-06, DPR-12, DB-PAY-03, FLU-07, FLU-11 | **Aprobado** en la repetición. Antes falló al editar un pago | D-09 (corregido) |
| Liquidar deuda | HU-21 | UT-17, UT-65, DEU-05, PAG-04, PAG-09, DPR-04, DPR-05, UI-DEU-06, UI-PAY-03, FLU-07 | **Aprobado** | — |
| Pago de deuda inválido | HU-22 | UI-07, UT-PAY-02, UI-PAY-04, FLU-08 | **Aprobado** | — |
| Compromisos próximos | HU-23 | UT-06 a UT-08, UT-10, UT-11, UT-22, UT-24, UT-26, UT-28, UT-64, UT-65, PRX-03, PRX-04, FLU-09 | **Aprobado** el cálculo. La pantalla está pendiente | H-01 |

D-09 se origina al editar desde Movimientos (HU-05) y afecta a los pagos de HU-16 y HU-20.

## 2. Casos nuevos

Las pruebas anteriores comprueban cada capa; las de pantalla usan una base simulada en memoria. Estos casos van de la pantalla a SQLite real (`sqflite_common_ffi`, en memoria). Están en `test/cards_debts_payments_flows_test.dart`.

| Caso | Historia | Qué se hace | Resultado esperado | Resultado |
| :--- | :--- | :--- | :--- | :--- |
| FLU-01 | HU-13 | Registrar desde Inicio: límite 1000 y usado 250.50 | Se guarda; disponible 749.50 | Aprobado |
| FLU-02 | HU-13 | Abrir una tarjeta con usado 1200 y límite 1000 | Disponible 0 | Aprobado |
| FLU-03 | HU-14 | Editar límite, saldo usado y día de pago | Se guarda; disponible 1100 | Aprobado |
| FLU-04 | HU-15 | Eliminar: cancelar y después confirmar | Cancelar conserva; confirmar la quita | Aprobado |
| FLU-05 | HU-16, HU-18 | Pagar 120 de una tarjeta que vence hoy | Usado 80; cuenta como pago, no como gasto; vencimiento cubierto | Aprobado |
| FLU-06 | HU-19 | Registrar una deuda desde Inicio | Se guarda como pendiente | Aprobado |
| FLU-07 | HU-20, HU-21 | Pagar 120.10 y después el resto | Quedan 179.90 y luego 0, pagada; sale de próximos | Aprobado |
| FLU-08 | HU-22 | Intentar pagar 0, `abc` y 300.01 de un saldo de 300 | No se guarda nada | Aprobado |
| FLU-09 | HU-23 | Calcular próximos con lo guardado en SQLite | Orden por días y pagado identificado | Aprobado |
| FLU-10 | HU-16, HU-05 | Editar solo la nota de un pago de tarjeta | Sigue como pago de esa tarjeta | **Aprobado** en la repetición; primero falló (D-09) |
| FLU-11 | HU-20, HU-05 | Editar solo la nota de un pago de deuda | Sigue como pago de esa deuda | **Aprobado** en la repetición; primero falló (D-09) |

**UI-07** del plan estaba omitido porque en el Sprint 1 no existían las deudas. Ahora se ejecuta en el mismo archivo con los datos del plan (saldo 300; pagos de 0 y 301): **aprobado**.

## 3. Defectos y hallazgos

### D-09 · Editar un pago lo convierte en un movimiento normal

- **Historias:** HU-16, HU-20 y HU-05.
- **Pasos:** registrar un pago; abrirlo en Movimientos; cambiar solo la nota; guardar.
- **Esperado:** sigue siendo un pago de su tarjeta o deuda.
- **Observado (FLU-10 y FLU-11):** `type` pasa de `payment` a `regular`, y `cardId` o `debtId` quedan en `null`.
- **Efectos comprobados en el pago de tarjeta de 120:** el resumen lo cuenta como gasto (gastos 120, pagos 0), el historial de la tarjeta queda vacío, el saldo usado sigue en 80 y el formulario pasa a ofrecer **Eliminar**.
- **Causa:** `_save` en `lib/widgets/add_movement_sheet.dart` crea el movimiento sin `type`, `cardId` ni `debtId`, y `updateMovement` guarda todos los campos.
- **A considerar al corregir (por lectura del código, no probado):** el formulario permitía cambiar el monto y el tipo de un pago, y `updateMovement` no ajusta el saldo de la tarjeta o deuda.
- **En la primera ejecución:** FLU-10 y FLU-11 fallaron y quedaron con `skip`, sin cambiar el resultado esperado.
- **Corrección:** [#205](https://github.com/JanettheMillan/KoPay/issues/205), en [#206](https://github.com/JanettheMillan/KoPay/pull/206). Al editar un pago se conservan `type`, `cardId` y `debtId`, y el monto y el tipo no se cambian desde esa hoja.
- **Repetición:** sin `skip`, FLU-10 y FLU-11 pasan. **D-09 cerrado.** Anular un pago quedó aparte en [#207](https://github.com/JanettheMillan/KoPay/issues/207) (D-10).

### H-01 · Los pagos próximos no se muestran en la app

- **Historias:** HU-18 y HU-23.
- **Observado (revisión del código):** `computeUpcoming` y `UpcomingPayment` no se usan en ninguna pantalla ni provider. Inicio muestra las tarjetas y las deudas, pero no una lista de próximos pagos con días restantes y estado.
- **Referencia:** `docs/navegacion-usuario-contador.md` indica «Tarjetas y próximos pagos cuando existan» en Inicio.
- **Alcance de lo probado:** el cálculo cumple sus casos. HU-18 y HU-23 tienen prueba de tipo unitaria, que pasa.
- **Estado:** no se registra como defecto nuevo. `docs/manual-del-sistema.md` indica que la pantalla depende de S5-11 ([#97](https://github.com/JanettheMillan/KoPay/issues/97)). Hasta entonces, HU-18 y HU-23 no se pueden comprobar desde la interfaz.

## 4. Ejecución

### Primera ejecución

| Dato | Valor |
| :--- | :--- |
| Fecha | 26 de noviembre de 2026 |
| Responsable | `GleipM` |
| Versión | `develop` en `3b9fc23`, más las pruebas de esta tarjeta |
| Entorno | Windows 11, Flutter 3.50.1, `flutter test` sin dispositivo |

| Ejecución | Resultado |
| :--- | :--- |
| `flutter test test/cards_debts_payments_flows_test.dart` (sobre `efc23cb`) | 10 aprobadas, 2 omitidas (D-09), 0 fallidas |
| `flutter test` con los nueve archivos de tarjetas, deudas y pagos y el nuevo (sobre `efc23cb`) | 132 aprobadas, 2 omitidas, 0 fallidas |
| `flutter test` | 402 aprobadas, 4 omitidas, 0 fallidas |
| `flutter analyze` | 0 errores, 0 advertencias, 58 avisos informativos |

Entre `efc23cb` y `3b9fc23` solo cambió documentación. La suite completa y el análisis se repitieron en `3b9fc23`.

Los nueve archivos son `card_model`, `card_provider`, `card_screens`, `debt_model`, `debt_provider`, `debt_screens`, `payments`, `pay_screens` y `upcoming_payments` (todos terminan en `_test.dart`, en `test/`).

### Repetición con D-09 corregido

| Dato | Valor |
| :--- | :--- |
| Fecha | 26 de noviembre de 2026 |
| Responsable | `GleipM` |
| Versión | `develop` en `2ad4c40` (incluye #206 y S5-07), más las pruebas de esta tarjeta sin `skip` |
| Entorno | Windows 11, Flutter 3.50.1, `flutter test` sin dispositivo |

| Ejecución | Resultado |
| :--- | :--- |
| `flutter test test/cards_debts_payments_flows_test.dart` | 12 aprobadas, 0 omitidas, 0 fallidas |
| `flutter test` con los nueve archivos de tarjetas, deudas y pagos y el nuevo | 134 aprobadas, 0 omitidas, 0 fallidas |
| `flutter test` | 472 aprobadas, 4 omitidas, 0 fallidas |
| `flutter analyze` | 0 errores, 0 advertencias, 70 avisos informativos |

## 5. Sin ejecutar

- Los recorridos `integration_test/s2_13_tarjetas_test.dart`, `s2_14_deudas_test.dart` y `s2_15_pagos_test.dart` necesitan un dispositivo o emulador, que no había en este equipo.
- No se probó en Android ni en iPhone.
- Los flujos FLU no prueban la sincronización ni la conexión con la API (S5).
