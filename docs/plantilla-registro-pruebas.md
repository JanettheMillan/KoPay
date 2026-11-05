# Plantilla de registro de pruebas

Usar esta plantilla al ejecutar un caso del [plan de pruebas](plan-de-pruebas.md) y pegarla en el Issue de la prueba o en la sección 8 del plan. Mantener **Pendiente** mientras el caso no se haya ejecutado. Las reglas de evidencia están en la [guía de evidencias](guia-de-evidencias.md).

## Ficha por caso

| Campo | Valor |
| :--- | :--- |
| Caso | Identificador del plan, por ejemplo `UT-03` o `UI-02` |
| Historia de usuario | Por ejemplo `HU-02` |
| Tarjeta / Issue | Por ejemplo `S1-17 · #9` |
| Tipo | Unitaria / Interfaz / Integración |
| Fecha y hora | `AAAA-MM-DD HH:MM` |
| Responsable | Usuario de GitHub de quien ejecuta |
| Versión o commit | Rama y commit probado, por ejemplo `develop` en `abc1234` |
| Entorno | Versión de Flutter, sistema operativo y dispositivo o `flutter test` |
| Datos usados | Valores concretos, sin datos financieros reales |
| Comando | Comando exacto ejecutado, si aplica |

## Pasos y resultado

| Campo | Valor |
| :--- | :--- |
| Pasos realizados | Lista numerada de acciones |
| Resultado esperado | Lo que dice el plan para este caso |
| Resultado observado | Lo que realmente ocurrió |
| Estado | Pendiente / Aprobado / Fallido / Bloqueado |
| Evidencia | Nombre del archivo, enlace o salida de la consola |
| Defecto | Identificador y Issue, si aplica. Si no hay, escribir `Ninguno` |

## Ejemplo

| Campo | Valor |
| :--- | :--- |
| Caso | UI-ING-02 · Ingreso válido |
| Historia de usuario | HU-02 |
| Tarjeta / Issue | S1-17 · #9 |
| Tipo | Interfaz |
| Fecha y hora | 2026-11-05 18:30 |
| Responsable | `GleipM` |
| Versión o commit | `develop` en `2c107e0` |
| Entorno | Flutter 3.47.6, `flutter test`, superficie 600 x 844 |
| Datos usados | "Nómina", `500`, fecha de hoy |
| Comando | `flutter test test/ui_forms_navigation_test.dart -r expanded` |
| Pasos realizados | 1. Abrir el botón + 2. Elegir Ingreso 3. Llenar nombre y monto 4. Guardar |
| Resultado esperado | Muestra "Ingreso guardado" y el registro aparece en Movimientos |
| Resultado observado | Muestra "Ingreso guardado" y "Nómina" aparece con `+$500.00` |
| Estado | Aprobado |
| Evidencia | Salida de `flutter test` |
| Defecto | Ninguno |

## Reglas

- No marcar **Aprobado** sin haber ejecutado el caso.
- Si el resultado observado no coincide con el esperado, marcar **Fallido** y abrir un Issue de defecto.
- Si el caso depende de una historia que todavía no existe, marcar **Bloqueado** y anotar la dependencia.
- Guardar las capturas en `docs/evidencias/` con el nombre del caso, por ejemplo `UI-ING-02-resultado.png`.
- No incluir información financiera personal ni credenciales en capturas o registros.
