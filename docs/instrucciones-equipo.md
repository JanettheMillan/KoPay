# Instrucciones del equipo: primer entregable del front

**Objetivo:** entregar al profe el primer 5% de la parte visual de KoPay en el repositorio del equipo.
**Reglas generales:** [`CLAUDE.md`](../CLAUDE.md). **Rama de integración:** `develop`.

## Orden de trabajo

| Orden | Tarjeta | Persona | Estado |
| :--- | :--- | :--- | :--- |
| 1 | #3 S1-04 Proyecto Flutter | `RichartM` | Mergeado |
| 2 | #20 S1-05 Tema y navegación | `RichartM` | Mergeado |
| 3 | #21 S1-06 Inicio | `RichartM` | En curso |
| 4 | #22 S1-07 Modelos | `EnriqueLanda2` | Pendiente |
| 5 | #25 S1-10 Provider de movimientos | `CiscoPaquitoTracer` | Pendiente |
| 6 | #28 S1-13 Formulario de gasto | `JanettheMillan` | Pendiente |
| 7 | #29 S1-14 Formulario de ingreso | `JanettheMillan` | Pendiente |
| 8 | #30 S1-15 Historial | `JanettheMillan` | Pendiente |
| 9 | #9 S1-17 Pruebas de interfaz | `GleipM` | Pendiente |

## Cómo trabajar cada tarjeta

1. `git clone https://github.com/JanettheMillan/KoPay.git` (o fork si no tienes escritura) y `git checkout develop`.
2. Crea tu rama desde `develop`.
3. Implementa solo los archivos de tu tarjeta. Si usas la app de referencia, copia únicamente esos archivos y quita lo que no es del Sprint 1 (sesión, red, contador, tarjetas, deudas).
4. `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run` y captura.
5. Commit, push y PR a `develop` con `Closes #N`.
6. Pide revisión a `RuAbogado` y espera. Un PR a la vez.

---

## `RichartM`: #21 S1-06 Inicio

- Rama: `feature/s1-06-inicio`, rebasada sobre `develop` después de que #109 quedó mergeado:
  ```
  git fetch origin
  git checkout feature/s1-06-inicio
  git rebase --onto origin/develop ba4af2b
  git push --force-with-lease
  ```
- Archivos: `lib/screens/home_screen.dart`, `lib/widgets/move_row.dart`, y el cambio en `main.dart` que muestra Inicio.
- Qué incluye: resumen del mes (ingresos, gastos, balance), selector de mes y últimos movimientos, con datos de ejemplo fijos.
- PR a `develop`, `Closes #21`, captura de Inicio.

## `EnriqueLanda2`: #22 S1-07 Modelos de movimiento e ingreso

- Espera a que el PR de Inicio (#21) esté mergeado. Rama: `feature/s1-07-modelos`.
- Archivos: `lib/models/movement_model.dart`, `lib/models/income_model.dart`, `lib/utils/format_utils.dart`.
- Cada modelo: campos, `toMap`, `fromMap`, `copyWith`. Sin campos de sincronización ni de tarjetas o deudas. Formato de monto y fecha en `format_utils.dart`.
- `flutter analyze` sin errores. PR con `Closes #22` y descripción de los campos. No tocar SQLite todavía (#23).

## `CiscoPaquitoTracer`: #25 S1-10 Provider de movimientos

- Espera a que #22 esté mergeado. Rama: `feature/s1-10-provider-movimientos`.
- Archivo: `lib/providers/movement_provider.dart`, registrado en `main.dart` con `ChangeNotifierProvider`.
- `ChangeNotifier` con lista en memoria: alta, edición, borrado y totales del mes. Sin base de datos ni red.
- PR con `Closes #25`. Explica en el PR cómo lo usan las pantallas. Luego sigue #26 (ingresos).

## `JanettheMillan`: #28, #29, #30 y #32

- Espera a #25 en `develop`. Un PR por tarjeta, en este orden:
  1. `feature/s1-13-form-gasto`, `Closes #28`: `lib/widgets/add_movement_sheet.dart`, `category_picker_sheet.dart` y `ui_kit.dart` básico. Monto, categoría, fecha, nota y validaciones visibles.
  2. `feature/s1-14-form-ingreso`, `Closes #29`: `lib/widgets/add_income_sheet.dart`.
  3. `feature/s1-15-historial`, `Closes #30`: `lib/screens/movements_screen.dart` con lista y filas.
  4. `feature/s1-19-navegacion`, `Closes #32`: documento breve en `docs/` con el mapa de pantallas de usuario y contador.
- Captura de pantalla en cada PR.

## `GleipM`: #9 S1-17 Pruebas de interfaz

- Espera a que estén mergeados #28, #29 y #30. Rama: `test/s1-17-ui`.
- Widget tests en `test/`: abrir cada formulario, validar campos vacíos y guardar un registro válido.
- Casos de `docs/plan-de-pruebas.md`. Guarda la salida de `flutter test` y llena el registro de ejecución con fecha, resultado y dispositivo, con capturas reales.
- PR con `Closes #9`. Después sigue #31.

## `RuAbogado`: revisión y control

- Revisa cada PR: que apunte a `develop`, que tenga `Closes #N`, que solo traiga los archivos de la tarjeta, que traiga captura y que `analyze` y `test` pasen.
- Orden de merge: #21, #22, #25, #28, #29, #30, #9.
- Al final del sprint: PR de `develop` a `main`.

## Si te atoras

Comenta en tu issue lo que intentaste y el error exacto. No uses la cuenta ni el token de otra persona.
