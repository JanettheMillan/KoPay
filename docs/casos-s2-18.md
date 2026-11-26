# Ejecución de pruebas de ajustes y respaldo (S2-18)

**Tarjeta:** #16 · [S2-18] Ejecutar pruebas de ajustes y respaldo.
**Historias:** HU-24 a HU-28 (moneda, idioma, XLSX, CSV y borrado local).
**Base:** `docs/plan-de-pruebas.md`, `docs/criterios-respaldo-importacion-borrado.md` y `docs/plantilla-registro-pruebas.md`.

## 1. Alcance ejecutado

| Área | Casos | Archivo de pruebas | Resultado |
| :--- | :--- | :--- | :--- |
| Moneda | INT-SET-01, INT-SET-02, INT-SET-04, INT-SET-05, INT-SET-06, UI-SET-01, UI-SET-02, UI-SET-04, UT-29, UT-59 | `test/settings_provider_test.dart`, `test/settings_screen_test.dart` | **Aprobado** |
| Idioma | INT-SET-01, INT-SET-03, UI-SET-03 | `test/settings_provider_test.dart`, `test/settings_screen_test.dart` | **Aprobado** |
| Exportar XLSX | RES-01, RES-02, RES-03, RES-04, UI-RES-01, UI-RES-02 | `test/backup_service_test.dart`, `test/settings_backup_test.dart` | **Aprobado** |
| Importar CSV | IMP-01 a IMP-09, más las variantes de interfaz IMP-01, IMP-03, IMP-04 e IMP-09 | `test/backup_service_test.dart`, `test/backup_database_test.dart`, `test/settings_backup_test.dart` | **Aprobado** |
| Borrar datos | BOR-01, BOR-02, BOR-03, BOR-04, UI-BOR | `test/delete_data_test.dart`, `test/delete_data_screen_test.dart` | **Aprobado** |

Se conservan categorías, moneda e idioma después del borrado; los dos caminos de importación (confirmar y cancelar) y los errores de archivo siguen cubiertos.

## 2. Refuerzo de BOR-03

`BOR-03` solo comprobaba la lista estática `DatabaseHelper.financialTables`. Se agregó una prueba con **datos reales**:

1. Inserta un movimiento, un ingreso, una tarjeta (`Oro`, límite 1000, usado 200) y una deuda (`Préstamo auto`, saldo 300).
2. Ejecuta `deleteFinancialData()`.
3. Comprueba que las cuatro tablas quedan vacías.
4. Cierra y reabre la base para confirmar que el borrado persiste.

Resultado: **Aprobado**.

## 3. Ejecución

| Campo | Valor |
| :--- | :--- |
| Fecha | 2026-11-26 |
| Responsable | `Leonardo-20233tn223` |
| Versión o commit | `test/s2-18-ajustes-respaldo` sobre `develop` en `3b9fc23` |
| Entorno | Flutter 3.47.5 (stable), Windows 11, `flutter test` sin dispositivo |
| Comando del bloque | `flutter test --no-pub --concurrency=1 test/settings_provider_test.dart test/settings_screen_test.dart test/backup_service_test.dart test/backup_database_test.dart test/settings_backup_test.dart test/delete_data_test.dart test/delete_data_screen_test.dart -r expanded` |
| Salida del bloque | `00:11 +50: All tests passed!` (50 aprobadas) |
| Comando de la suite | `flutter test --no-pub` |
| Salida de la suite | `00:27 +393 ~3: All tests passed!` (393 aprobadas, 3 omitidas, 0 fallidas) |
| Análisis | `flutter analyze --no-pub` → `No issues found!` |

Se usó `--concurrency=1` porque al cargar en paralelo varios archivos que dependen de los assets nativos de SQLite, el runner de Flutter falló al cargar cuatro archivos. Con una sola instancia pasan los 50 casos; no es un fallo de la aplicación.

## 4. Defectos

No se encontraron defectos nuevos en moneda, idioma, XLSX, CSV ni borrado. Los defectos históricos D-01 a D-08 conservan su seguimiento en el plan y en sus issues.

## 5. Evidencia

- `test/delete_data_test.dart` · `BOR-03 · HU-28 · Confirmar borra también tarjetas y deudas reales`.
- `docs/plan-de-pruebas.md` · sección 8.8.
- Salida de consola de los comandos anteriores.
