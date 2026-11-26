# Trazabilidad y cierre del Sprint 2

Cierre del Sprint 2 (#18). Relaciona cada tarjeta con su PR, sus historias y sus pruebas. Mismo formato que [trazabilidad-sprint-1.md](trazabilidad-sprint-1.md).

- **Fecha:** 26 de noviembre de 2026, sobre `develop` en `d97124a`.
- **Tablero (Project 3):** Sprint 2 con 30 tarjetas en Done; solo queda esta (#18).
- **S2-01 (#33):** revisión de integración registrada en el comentario de cierre de #33 (sin PR propio).

## Tarjetas, PR, historias y pruebas

| Tarjeta | PR | Historias | Pruebas |
| :--- | :--- | :--- | :--- |
| Probar edición y eliminación (#13) | #186 | HU-05, HU-06 | `test/edit_delete_movements_test.dart` |
| Resumen mensual (#14) | #193 | HU-09 | `test/home_screen_test.dart`, `test/month_summary_test.dart` |
| S2-17 · Pruebas de tarjetas, deudas y pagos (#15) | #215 | HU-13 a HU-23 | `test/cards_debts_payments_flows_test.dart`, `test/ui_forms_navigation_test.dart` |
| S2-18 · Pruebas de ajustes y respaldo (#16) | #195 | HU-24 a HU-28 | `test/delete_data_test.dart` |
| S2-03 · Criterios de respaldo, importación y borrado (#35) | #141 | HU-26 a HU-28 | Documento, sin pruebas |
| S2-02 · Patrón de estado y esquema (#34) | #156 | HU-13 a HU-23 | Documento, sin pruebas |
| S2-04 · Categorías (#36) | #140 | HU-10 a HU-12 | `integration_test/s2_04_categorias_test.dart`, `test/category_picker_sheet_test.dart`, `test/category_provider_test.dart`, `test/unit_models_formats_test.dart` |
| S2-05 · Moneda e idioma (#37) | #142 | HU-24, HU-25 | `integration_test/s2_05_moneda_idioma_test.dart`, `test/settings_provider_test.dart`, `test/settings_screen_test.dart`, `test/unit_models_formats_test.dart` |
| S2-06 · XLSX y CSV (#38) | #143 | HU-26, HU-27 | `test/backup_database_test.dart`, `test/backup_service_test.dart`, `test/settings_backup_test.dart` |
| S2-07 · Tarjetas en SQLite (#39) | #147 | HU-13, HU-14 | `test/card_model_test.dart`, `test/database_schema_test.dart`, `test/delete_data_test.dart` |
| S2-08 · Deudas en SQLite (#40) | #150 | HU-19, HU-21 | `test/database_schema_test.dart`, `test/debt_model_test.dart`, `test/delete_data_test.dart` |
| S2-09 · Pagos en SQLite (#41) | #152 | HU-16, HU-20 | `test/debt_model_test.dart`, `test/models_test.dart`, `test/payments_test.dart` |
| S2-10 · Proveedor de tarjetas (#42) | #151 | HU-13 a HU-15 | `test/card_provider_test.dart` |
| S2-11 · Proveedor de deudas (#43) | #166 | HU-19 a HU-21 | `test/debt_provider_test.dart` |
| S2-12 · Próximos pagos (#44) | #168 | HU-18, HU-23 | `test/upcoming_payments_test.dart` |
| S2-13 · Formulario y detalle de tarjeta (#45) | #161 | HU-13 a HU-15 | `integration_test/s2_13_tarjetas_test.dart`, `test/card_screens_test.dart` |
| S2-14 · Formulario y consulta de deuda (#46) | #171 | HU-19 | `integration_test/s2_14_deudas_test.dart`, `test/debt_screens_test.dart` |
| S2-15 · Formularios de pago (#47) | #187 | HU-16, HU-17, HU-20, HU-22 | `integration_test/s2_15_pagos_test.dart`, `test/pay_screens_test.dart` |
| S2-16 · Pruebas de saldos y próximos pagos (#48) | #178 | HU-18, HU-21, HU-23 | `test/upcoming_payments_test.dart` |
| S2-19 · Maqueta del contador (#49) | #165 | HU-39, HU-40 | `integration_test/s2_19_maqueta_contador_test.dart`, `test/accountant_preview_test.dart` |
| S2-20 · Borrado local (#107) | #144 | HU-28 | `integration_test/s2_20_borrar_datos_test.dart`, `test/delete_data_screen_test.dart`, `test/delete_data_test.dart` |
| D-03 (#130) | #163 | HU-01, HU-02 | `test/unit_models_formats_test.dart` |
| D-05 (#131) | #149 | HU-08, HU-09 | `test/home_screen_test.dart` |
| D-01 (#132) | #148 | HU-01 | Documento, sin pruebas |
| D-02 (#133) | #155 | HU-02 | `test/unit_models_formats_test.dart` |
| D-06 (#153) | #154 | HU-16, HU-20 | `test/payments_test.dart` |
| Bug #185 eliminar movimiento | #190 | HU-06 | `integration_test/bug_185_eliminar_movimiento_test.dart`, `test/delete_records_test.dart`, `test/edit_delete_movements_test.dart` |
| D-09 (#205) | #206 | HU-16 | `test/add_movement_sheet_test.dart` |
| D-10 (#207) | #214 | HU-16 | `integration_test/d_10_anular_pago_test.dart`, `test/pay_screens_test.dart`, `test/payments_test.dart` |

## Resultado

| Comando | Resultado |
| :--- | :--- |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` (suite completa) | **502 aprobadas**, 4 omitidas, 0 fallidas |
| `flutter test --concurrency=1` con los 25 archivos del Sprint 2 | **253 aprobadas**, 0 fallidas |

Resultados por historia: [casos-s2-17.md](casos-s2-17.md) (tarjetas, deudas y pagos), §8.8 del [plan de pruebas](plan-de-pruebas.md) (ajustes y respaldo), [casos-hu-05-06.md](casos-hu-05-06.md) y [casos-hu-09.md](casos-hu-09.md).

## Defectos del sprint

| Id | Issue | Estado |
| :--- | :--- | :--- |
| D-01, D-02, D-03, D-05 | #132, #133, #130, #131 | Corregidos (vienen del Sprint 1) |
| D-06 | #153 | Corregido en #154 (pagos en centavos) |
| Bug | #185 | Corregido en #190 |
| D-09 | #205 | Corregido en #206; FLU-10 y FLU-11 pasan |
| D-10 | #207 | Corregido en #214 (anular pago) |
| D-11 | #216 | **Abierto, baja:** el XLSX no incluye tarjetas ni deudas ni distingue pagos (Leo) |

## Pendientes que pasan a otros sprints

- **D-11 (#216):** hojas `Tarjetas` y `Deudas` en el XLSX.
- **Próximos pagos sin pantalla (HU-18, HU-23):** el cálculo existe y pasa sus pruebas; la pantalla es S5-11 (#97).
- **`PeriodSummary` duplica `MonthSummary`:** está en `lib/data/accountant_sample_data.dart`, solo para la maqueta del contador; se elimina al conectar la vista real (S5-12, #98).
- **Pruebas en teléfono:** los recorridos de `integration_test/` se corrieron en macOS; Android queda para la APK (#102).
