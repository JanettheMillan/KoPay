# Pruebas de la interfaz de registro e inicio de sesión

**Tarjeta:** S3-17 · [#65](https://github.com/JanettheMillan/KoPay/issues/65). **Historias:** HU-30 y HU-31.

## 1. Resultado por estado

«Aprobado» significa que las pruebas citadas se ejecutaron y pasaron en `flutter test`. No incluye un recorrido en dispositivo ni la API real.

| Pantalla | Estado | Casos | Resultado | Defecto |
| :--- | :--- | :--- | :--- | :--- |
| Registro | Carga | UI-REG-02, UI-AUTH-02 | **Aprobado** | — |
| Registro | Error | UI-REG-01, UI-REG-04 a UI-REG-07, UI-AUTH-04, UI-AUTH-05, UI-AUTH-07 | **Aprobado** | — |
| Registro | Éxito | UI-REG-03, UI-LOG-08, UI-AUTH-01 | **Aprobado** | — |
| Inicio de sesión | Carga | UI-LOG-06, UI-AUTH-03 | **Aprobado** | — |
| Inicio de sesión | Error | UI-LOG-01, UI-LOG-03 a UI-LOG-05, UI-LOG-07, UI-AUTH-05, UI-AUTH-06, UI-AUTH-08, UI-AUTH-09 | **Aprobado** en la repetición. Antes falló el botón después de un 429 | D-12 (corregido) |
| Inicio de sesión | Éxito | UI-LOG-02, UI-AUTH-01 | **Aprobado** | — |

Además pasan UI-REG-08 (mostrar la contraseña), UI-LOG-09 (idioma) y UI-AUTH-10 (pantalla pequeña con teclado).

## 2. Casos nuevos

Las pruebas de S3-10 y S3-11 usan `FakeAuthApi`, que reemplaza al cliente completo. Estos casos usan las pantallas con el cliente real (`HttpAuthApi`) y simulan solo las respuestas HTTP del [contrato](contrato-api-acceso.md). Están en `test/auth_ui_states_test.dart`.

| Caso | Historia | Qué se hace | Resultado esperado | Resultado |
| :--- | :--- | :--- | :--- | :--- |
| UI-AUTH-01 | HU-30, HU-31 | Crear la cuenta (201) y después entrar (200) | Envía lo del contrato; registrar no abre sesión y entrar sí | Aprobado |
| UI-AUTH-02 | HU-30 | Registrar sin recibir respuesta todavía | Progreso; campos, botón y enlace bloqueados; se liberan al responder | Aprobado |
| UI-AUTH-03 | HU-31 | Entrar sin recibir respuesta todavía | Progreso; campos, botón y enlace bloqueados | Aprobado |
| UI-AUTH-04 | HU-30 | Respuestas 400 y 409 | Cada mensaje aparece en su campo | Aprobado |
| UI-AUTH-05 | HU-30, HU-31 | 500 en registro; 500 y 503 en inicio de sesión | Muestra `error`, se borra al editar y permite reintentar | Aprobado (3 ejecuciones) |
| UI-AUTH-06 | HU-31 | La API no responde (límite de 2 s en la prueba) | Quita la carga y avisa que no hay conexión | Aprobado |
| UI-AUTH-07 | HU-30 | 502 con una página HTML | Avisa que no hay conexión, sin mostrar el HTML | Aprobado |
| UI-AUTH-08 | HU-31 | Respuesta 429 | Muestra el mensaje de demasiados intentos | Aprobado |
| UI-AUTH-09 | HU-31 | Revisar el botón después del 429 | Queda desactivado un momento (contrato §2) y luego vuelve | **Aprobado** en la repetición; primero falló (D-12) |
| UI-AUTH-10 | HU-30, HU-31 | 320 × 568, teclado de 260 y errores visibles, en las dos pantallas | Sin desborde y el botón se alcanza | Aprobado (2 ejecuciones) |

## 3. Defecto

### D-12 · Después de un 429 el botón de iniciar sesión sigue activo

- **Historia:** HU-31.
- **Pasos:** intentar iniciar sesión y recibir `429 TOO_MANY_ATTEMPTS`.
- **Esperado:** la pantalla muestra el mensaje y desactiva el botón un momento ([contrato §2](contrato-api-acceso.md)).
- **Observado (UI-AUTH-09):** muestra el mensaje, pero el botón queda activo.
- **Causa (revisión del código):** `_submit` en `lib/screens/login_screen.dart` trata `TOO_MANY_ATTEMPTS` como los demás errores generales. Ningún archivo de `lib/` usa `ApiErrorCode.tooManyAttempts`.
- **Contexto:** el límite del login se agregó en S4-13, después de la pantalla de S3-11. El límite lo aplica la API; el defecto es de la interfaz.
- **A considerar al corregir:** el contrato no dice cuánto es «un momento».
- **En la primera ejecución:** UI-AUTH-09 falló y quedó con `skip`, sin cambiar el resultado esperado.
- **Corrección:** [#220](https://github.com/JanettheMillan/KoPay/issues/220), en [#221](https://github.com/JanettheMillan/KoPay/pull/221). El botón y el envío desde el teclado se desactivan 30 segundos (`loginRetryDelay`), y el contrato §2 ya lo indica.
- **Repetición:** sin `skip`, UI-AUTH-09 pasa. Ahora también comprueba que, al pasar `loginRetryDelay`, el botón vuelve a activarse sin enviar otra petición. Los 29 y 30 segundos y la prueba desde la pantalla de la corrección están en `test/login_screen_test.dart` (#221). **D-12 cerrado.**

## 4. Ejecución

### Primera ejecución

| Dato | Valor |
| :--- | :--- |
| Fecha | 26 de noviembre de 2026 |
| Responsable | `GleipM` |
| Versión | `develop` en `63ecd16`, más las pruebas de esta tarjeta |
| Entorno | Windows 11, Flutter 3.50.1, `flutter test` sin dispositivo |

| Ejecución | Resultado |
| :--- | :--- |
| `flutter test test/auth_ui_states_test.dart` | 12 aprobadas, 1 omitida (D-12), 0 fallidas |
| `flutter test` con `register_screen_test.dart`, `login_screen_test.dart` y el archivo nuevo | 32 aprobadas, 1 omitida, 0 fallidas |
| `flutter test` | 529 aprobadas, 5 omitidas, 0 fallidas |
| `flutter analyze` | 0 errores, 0 advertencias, 73 avisos informativos |

Las 32 incluyen UT-REG-01 a UT-REG-03, que son pruebas unitarias del mismo archivo de registro.

### Repetición con D-12 corregido

| Dato | Valor |
| :--- | :--- |
| Fecha | 26 de noviembre de 2026 |
| Responsable | `GleipM` |
| Versión | `develop` en `e8f392f` (incluye #221), más las pruebas de esta tarjeta sin `skip` |
| Entorno | Windows 11, Flutter 3.50.1, `flutter test` sin dispositivo |

| Ejecución | Resultado |
| :--- | :--- |
| `flutter test test/auth_ui_states_test.dart` | 13 aprobadas, 0 omitidas, 0 fallidas |
| `flutter test` con `register_screen_test.dart`, `login_screen_test.dart` y el archivo nuevo | 34 aprobadas, 0 omitidas, 0 fallidas |
| `flutter test` | 531 aprobadas, 4 omitidas, 0 fallidas |
| `flutter analyze` | 0 errores, 0 advertencias, 73 avisos informativos |

## 5. Sin ejecutar

- Los recorridos `integration_test/s3_10_registro_test.dart` y `s3_11_login_test.dart`: este equipo no tiene emulador ni las herramientas para compilar la app de Android o Windows.
- No se probó en Android ni en iPhone.
- No se probó contra la API y la base reales: corresponde a S3-18 ([#66](https://github.com/JanettheMillan/KoPay/issues/66)).
