# Evidencia D-11 · respaldo XLSX con tarjetas, deudas y pagos

Este cambio no modifica la interfaz: exportar desde Ajustes sigue igual. La
evidencia es el libro que se genera y la salida de las pruebas.

El libro de abajo se generó con `BackupService.buildXlsx` y dos movimientos de
ejemplo, un pago de tarjeta, un pago de deuda, una tarjeta y una deuda, y se
volvió a leer con la misma librería `excel`. Se muestran las celdas tal como
quedan en el archivo.

## Hojas y contenido

```text
HOJA Movimientos
[Fecha, Descripción, Categoría, Importe, Nota, Tipo, De]
[2026-11-06T00:00:00.000Z, Pago Préstamo auto, Pago deuda, -3200, , Pago, Préstamo auto]
[2026-11-05T00:00:00.000Z, Pago Oro, Pago tarjeta, -1500, , Pago, Oro]
[2026-11-02T00:00:00.000Z, Súper, Comida, -250.5, , Gasto, ]
HOJA Ingresos
[Fecha, Nombre, Importe, Nota]
[2026-11-01T00:00:00.000Z, Quincena, 12000, ]
HOJA Tarjetas
[Nombre, Banco, Límite, Saldo usado, Día de corte, Día de pago, Pago mínimo]
[Oro, BBVA, 30000, 3500, 15, 5, 900]
HOJA Deudas
[Nombre, Monto, Saldo restante, Fecha, Estado]
[Préstamo auto, 3200, 41800, 2026-12-10T00:00:00.000Z, Pendiente]
HOJA Respaldo
[tipo, fecha, importe, descripcion, categoria, nota]
[movimiento, 2026-11-02, -250.5, Súper, Comida, ]
[ingreso, 2026-11-01, 12000, Quincena, , ]
```

La hoja `Respaldo` no incluye los pagos, como dice
`docs/criterios-respaldo-importacion-borrado.md` (secciones 2 y 3).

## Resultado de las pruebas

```text
flutter analyze  → No issues found!
flutter test     → 520 aprobadas, 4 omitidas, 0 fallidas
flutter test test/backup_service_test.dart test/backup_database_test.dart
                 → 19 aprobadas, 0 fallidas
```

## Nota sobre `flutter run`

La app compila e instala en el emulador (Android 17, API 37). En `develop` la
entrada pasa primero por Iniciar sesión (S3-12), y no había API ni PostgreSQL
locales en esta computadora, así que no se llegó a Ajustes desde la app. La
pantalla de Ajustes no cambia con esta tarjeta; lo que cambia es el libro
generado, que se comprobó con las pruebas y con el volcado de arriba.
