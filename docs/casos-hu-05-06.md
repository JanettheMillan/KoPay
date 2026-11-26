# Casos de edición y eliminación de movimientos

**Tarjeta:** #13 · Probar edición y eliminación de movimientos.
**Historias:** HU-05 (editar un movimiento) y HU-06 (eliminar un movimiento).
**Base:** `docs/historias-de-usuario.md`, `docs/plan-de-pruebas.md` y `docs/plantilla-registro-pruebas.md`.

El plan de pruebas no tiene un caso formal de eliminación de movimientos. La edición se había ejecutado como `UI-HIS-01` en la sección 8.2 del plan. En esta tarjeta se agregan los casos `EDIT-01`, `DEL-01` y `DEL-02` para cubrir el criterio de la historia.

## 1. Casos

| Caso | Historia | Tipo | Preparación y acción | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- |
| EDIT-01 | HU-05 | Integración | Gasto "Café" de 50 en Comida. Tocar la fila en Movimientos, cambiar a "Desayuno" y 80, guardar. Abrir Inicio. | La lista y el resumen muestran los datos nuevos; la base en memoria recibe descripción, importe y categoría. El registro anterior ya no aparece. |
| EDIT-02 | HU-05 | Integración | Gasto "Café" de 50 en SQLite real. Actualizar a "Desayuno" y 80 con `MovementProvider.update`; releer la base y recargar el proveedor. | La base conserva los datos nuevos y el proveedor los lee otra vez. |
| DEL-01 | HU-06 | Integración | Dos gastos del mes: "Café" de 50 y "Camión" de 30. Borrar "Café" con `MovementProvider.delete`. | "Café" desaparece de Movimientos e Inicio; los gastos bajan a 30 y el balance a −30; la base ya no contiene el registro. "Camión" se conserva. |
| DEL-02 | HU-06 | Interfaz | Abrir "Café" desde Movimientos y usar el control de eliminar. Cancelar y después confirmar. | Cancelar conserva el registro; confirmar pide confirmación, lo elimina y actualiza el resumen. Corregido en #185: ahora se ejecuta. |

## 2. Ejecución

| Campo | Valor |
| :--- | :--- |
| Fecha y hora | 2026-11-26 |
| Responsable | `Leonardo-20233tn223` |
| Versión o commit | `test/s2-hu-05-06-editar-eliminar` sobre `develop` en `9ca8249` |
| Entorno | Flutter 3.47.5 (stable), Windows 11, `flutter test` sin dispositivo |
| Archivo | `test/edit_delete_movements_test.dart` |
| Comando | `flutter test test/edit_delete_movements_test.dart -r expanded` |

Salida real: `00:01 +3 ~1: All tests passed!` (3 aprobadas, 1 omitida).

| Caso | Resultado | Observado |
| :--- | :--- | :--- |
| EDIT-01 | **Aprobado** | Al cambiar "Café"/50 por "Desayuno"/80, el historial y Inicio muestran el dato nuevo, los gastos quedan en `$80` y el balance en `−$80.00`. La base en memoria recibe descripción, importe y categoría. |
| EDIT-02 | **Aprobado** | `MovementProvider.update` cambia "Café"/50 por "Desayuno"/80 en SQLite; `getMovement` y una nueva carga del proveedor devuelven el registro actualizado. |
| DEL-01 | **Aprobado** | Al borrar "Café", desaparece de Movimientos e Inicio; "Camión" se conserva, los gastos quedan en `$30`, el balance en `−$30.00` y `getMovement` devuelve `null`. |
| DEL-02 | **Bloqueado** | No existe botón ni confirmación para borrar un movimiento. Se deja `skip: true` y se abrió el issue [#185](https://github.com/JanettheMillan/KoPay/issues/185). |

## 3. Defecto encontrado

**D-08 · HU-06 · No se puede eliminar un movimiento desde la interfaz.**

- **Qué ocurre:** `MovementProvider.delete` y `DatabaseHelper.deleteMovement` existen y están probados, pero ni el historial ni la hoja "Editar movimiento" ofrecen una acción para borrar. Tampoco hay diálogo de confirmación.
- **Dónde:** `lib/screens/movements_screen.dart`, `lib/widgets/add_movement_sheet.dart`.
- **Efecto:** el usuario no puede corregir un movimiento equivocado desde la app; solo puede editar sus datos.
- **Propuesta:** agregar en la hoja de edición un botón "Eliminar" con confirmación (`¿Eliminar movimiento?`), usar `MovementProvider.delete`, cerrar la hoja, avisar "Movimiento eliminado" y refrescar Inicio y Movimientos.
- **Seguimiento:** [#185](https://github.com/JanettheMillan/KoPay/issues/185) (etiqueta `bug`, asignado a `JanettheMillan`).
- **Corrección (#185):** la hoja "Editar movimiento" y la de "Editar ingreso" tienen **Eliminar**, con confirmación. Cancelar conserva el registro y la hoja sigue abierta. Confirmar lo borra con el provider, cierra la hoja, avisa "Movimiento eliminado" o "Ingreso eliminado", y Inicio y Movimientos se actualizan. Un pago de tarjeta o deuda no ofrece Eliminar aquí; desde D-10 ([#207](https://github.com/JanettheMillan/KoPay/issues/207)) se anula en la lista **Pagos** del detalle de su tarjeta o deuda, que sí devuelve el saldo.

### Reejecución tras corregir D-08

Comando: `flutter test test/edit_delete_movements_test.dart test/delete_records_test.dart`. Resultado: 7 aprobadas, 0 omitidas.

| Caso | Resultado | Observado |
| :--- | :--- | :--- |
| DEL-02 | **Aprobado** | "Eliminar movimiento" abre `¿Eliminar movimiento?`. Cancelar deja "Café" en el historial y en la base; confirmar lo quita y el balance de Inicio vuelve a `$0.00`. |
| DEL-03 | **Aprobado** (nuevo) | Lo mismo con un ingreso: cancelar conserva "Nómina" y confirmar lo borra y avisa "Ingreso eliminado". |
| DEL-04 | **Aprobado** (nuevo) | Un registro nuevo y un pago no muestran Eliminar. |
| DEL-05 | **Aprobado** (nuevo) | En inglés: "Delete income" y "Delete income?". |

**D-08 queda corregido.** La tabla de arriba conserva el resultado de la primera ejecución.

## 4. Pruebas existentes que se conservan

La capa de datos ya tenía cobertura y no se duplicó:

- `test/movement_provider_test.dart`: actualización y borrado del proveedor, con recarga desde SQLite.
- `test/database_operations_test.dart`: `updateMovement` y `deleteMovement` sobre la base real.
- `test/ui_forms_navigation_test.dart`: `UI-HIS-01`, apertura de la edición desde el historial.
