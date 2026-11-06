# Trazabilidad del Sprint 1

Relaciona cada tarjeta del Sprint 1 con su historia de usuario, los archivos de código que la implementan y las pruebas que la cubren. Las historias de usuario no se modifican: aquí solo se enlazan.

- **Historias:** tomadas de `docs/backlog-desarrollo-desde-cero.md` (campo "Historias relacionadas" de cada tarjeta).
- **Código y pruebas:** tomados de los archivos de cada Pull Request mergeado a `develop`.
- **Caso del plan:** solo se anota cuando la prueba cita su identificador del [plan de pruebas](plan-de-pruebas.md). Muchas pruebas de desarrollo se escribieron junto con su código y no citan un caso; se marcan como "sin caso del plan" en lugar de inventar uno.
- Hecho el 6 de noviembre de 2026 sobre `develop`. Las reglas para las tarjetas siguientes están en `CLAUDE.md`.

## Tarjetas de desarrollo

| Tarjeta | Responsable | PR | Historias | Código | Pruebas (archivo · cantidad) | Caso del plan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| S1-04 · Proyecto Flutter y carpetas (#3) | RichartM | #108 | HU-01 a HU-09 | `lib/main.dart` y estructura de `lib/` | Ninguna propia | Sin caso del plan |
| S1-05 · Tema y navegación base (#20) | RichartM | #109 | HU-07 | `lib/utils/app_colors.dart`, `lib/main.dart` | `test/widget_test.dart` · 1 | Sin caso del plan |
| S1-06 · Inicio y resumen mensual (#21) | RichartM | #110 | HU-08, HU-09 | `lib/screens/home_screen.dart`, `lib/widgets/move_row.dart` | Ninguna propia. Ver defecto D-05 (#131) | Sin caso del plan |
| S1-07 · Modelos de movimiento e ingreso (#22) | EnriqueLanda2 | #112 | HU-01, HU-02 | `lib/models/movement_model.dart`, `lib/models/income_model.dart`, `lib/utils/format_utils.dart` | `test/models_test.dart` · 11 | Sin caso del plan |
| S1-08 · Esquema SQLite (#23) | EnriqueLanda2 | #114 | HU-01, HU-02, HU-29 | `lib/database/database_helper.dart` | `test/database_schema_test.dart` · 6 | Sin caso del plan |
| S1-09 · Operaciones SQLite (#24) | EnriqueLanda2 | #115 | HU-05 a HU-07 | `lib/database/database_helper.dart` | `test/database_operations_test.dart` · 12 | Sin caso del plan |
| S1-10 · Proveedor de movimientos (#25) | CiscoPaquitoTracer | #117 | HU-01, HU-05, HU-06 | `lib/providers/movement_provider.dart`, `lib/main.dart` | `test/movement_provider_test.dart` · 7 | Sin caso del plan |
| S1-11 · Proveedor de ingresos (#26) | CiscoPaquitoTracer | #118 | HU-02 | `lib/providers/income_provider.dart`, `lib/main.dart` | `test/income_provider_test.dart` · 7 | Sin caso del plan |
| S1-12 · Validaciones y signo (#27) | CiscoPaquitoTracer | #119 | HU-03, HU-04 | `lib/utils/validators.dart`, `lib/providers/*.dart` | `test/validators_test.dart` · 9 | Sin caso del plan |
| S1-13 · Formulario de gasto y movimiento (#28) | JanettheMillan | #120 | HU-01, HU-03, HU-04 | `lib/widgets/add_movement_sheet.dart`, `lib/widgets/category_picker_sheet.dart`, `lib/widgets/ui_kit.dart` | `test/add_movement_sheet_test.dart` · 7 | Sin caso del plan |
| S1-14 · Formulario de ingreso (#29) | JanettheMillan | #121 | HU-02, HU-04 | `lib/widgets/add_income_sheet.dart`, `lib/main.dart` | `test/add_income_sheet_test.dart` · 6 | Sin caso del plan |
| S1-15 · Historial de movimientos e ingresos (#30) | JanettheMillan | #122 | HU-07 | `lib/screens/movements_screen.dart`, `lib/main.dart` | `test/movements_screen_test.dart` · 7 | Sin caso del plan |
| S1-19 · Navegación de usuario y contador (#32) | JanettheMillan | #116 | HU-37 a HU-42 | Documento `docs/navegacion-usuario-contador.md` (sin código) | No aplica | No aplica |

## Tarjetas de pruebas

| Tarjeta | Responsable | PR | Historias | Pruebas (archivo · cantidad) | Casos del plan | Resultado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| S1-16 · Pruebas unitarias de modelos y formatos (#31) | GleipM | #123 | HU-01, HU-02 | `test/unit_models_formats_test.dart` · 17 (13 aprobadas, 4 omitidas) | UT-01, 02, 03, 14, 15, 18, 19, 20, 21, 29, 30, 31, 32 y 33 | 8 aprobados, 3 fallidos (D-01, D-02, D-03) y 3 bloqueados |
| S1-17 · Pruebas de interfaz (#9) | GleipM | #124 y #126 | HU-01, HU-02, HU-04 | `test/ui_forms_navigation_test.dart` · 9 (7 aprobadas, 2 omitidas); `integration_test/s1_17_recorrido_test.dart` · 2 fases | UI-02, UI-07 y FUT-25 | 7 aprobados y 2 bloqueados; recorrido en macOS, 8 de 8 pasos aprobados |
| S1-18 · Flujo completo hasta el resumen (#7) | GleipM | #129 | HU-01, HU-02, HU-09 | `integration_test/s1_18_flujo_completo_test.dart` · 1 | INT-01 | Fallido por D-05 (#131) |
| Probar registro de un ingreso (#8) | Leonardo-20233tn223 | #134 | HU-02 | `test/registro_ingreso_test.dart` · 1 | Sin caso del plan | Pasa en Movimientos; falta el resultado con la plantilla y el criterio de Inicio (D-05) |

## Otros entregables del sprint

| Entregable | PR o archivo |
| :--- | :--- |
| Plantillas de Issue y de PR (#4) | #125 · `.github/ISSUE_TEMPLATE/tarjeta.md`, `.github/PULL_REQUEST_TEMPLATE.md` |
| Plantilla de registro de pruebas (#6) | #127 · `docs/plantilla-registro-pruebas.md` |
| Reglas del equipo | #111 y #136 · `CLAUDE.md` |
| Alineación con el Manual de Estilo | #135 · sección 9 de `docs/plan-de-pruebas.md` |
| Historias, arquitectura y alcance (S1-01 a S1-03) | `docs/historias-de-usuario.md`, `docs/plan-del-proyecto.md` y demás documentos de `docs/` |

## Defectos del Sprint

| Id | Issue | Severidad | Resumen |
| :--- | :--- | :--- | :--- |
| D-01 | #132 | Baja | `categoryEmoji` no reconoce mayúsculas ni espacios |
| D-02 | #133 | Baja | El plan espera `legacy_income`, que el modelo no tiene |
| D-03 | #130 | Media | `fromMap` acepta fechas imposibles |
| D-04 | Corregido en #124 | Baja | Menú del botón + sin `Material` propio |
| D-05 | #131 | Alta | Inicio no usa los providers |

## Huecos que esta tabla deja ver

- **S1-04 y S1-06 no tienen pruebas propias.** S1-06 es además el origen de D-05.
- **Las pruebas de desarrollo no citan casos del plan.** Solo las de S1-16 a S1-18 enlazan su identificador.
- **Prueba en teléfono:** el recorrido de S1-17 se hizo en macOS, no en iPhone ni Android (casos DISP-01 a DISP-03 del plan, sección 9).
