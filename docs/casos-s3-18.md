# Registro e inicio de sesión de punta a punta

**Tarjeta:** S3-18 · [#66](https://github.com/JanettheMillan/KoPay/issues/66). **Historias:** HU-30 y HU-31.

## 1. Qué se unió

App Flutter (`KopayApp`, con `HttpAuthApi`) → API Node en ejecución → PostgreSQL 16. Lo guardado se revisa con `psql`. Las cuentas son de prueba.

La app corre dentro de `flutter test`, sin dispositivo: SQLite va en memoria, el almacén seguro del sistema se simula y el idioma se fija en español.

## 2. Resultado por historia

| Historia | Criterio | Casos | Resultado |
| :--- | :--- | :--- | :--- |
| HU-30 | Una cuenta válida se crea y una duplicada se rechaza sin crear otra | E2E-AUTH-01, E2E-AUTH-03, E2E-AUTH-05 | **Aprobado** |
| HU-31 | Credenciales válidas abren la sesión y las inválidas no permiten entrar | E2E-AUTH-02, E2E-AUTH-04, E2E-AUTH-06 a E2E-AUTH-08 | **Aprobado** |

No se encontraron defectos en este recorrido.

## 3. Casos nuevos

Están en `test/e2e_auth_api_test.dart`.

| Caso | Historia | Qué se hace | Resultado esperado y comprobado | Resultado |
| :--- | :--- | :--- | :--- | :--- |
| E2E-AUTH-01 | HU-30 | Registrar desde la app, con el correo en mayúsculas y con espacios | Una fila en `users`, correo en minúsculas, rol `user`, contraseña como hash `scrypt`; no abre sesión | Aprobado |
| E2E-AUTH-02 | HU-31 | Entrar con la cuenta creada | Abre la vista de usuario; una fila en `sessions`; ningún token en claro en la base | Aprobado |
| E2E-AUTH-03 | HU-30 | Registrar el mismo correo en mayúsculas | Avisa que ya existe y sigue habiendo una cuenta | Aprobado |
| E2E-AUTH-04 | HU-31 | Contraseña incorrecta y correo sin cuenta | El mismo mensaje en la pantalla; no abre sesión ni crea filas | Aprobado |
| E2E-AUTH-05 | HU-30 | Enviar el registro vacío | La app muestra el error y el número de cuentas no cambia | Aprobado |
| E2E-AUTH-06 | HU-31 | Cerrar la app y volver a abrirla | La API confirma la sesión guardada y abre la vista de usuario | Aprobado |
| E2E-AUTH-07 | HU-31 | Revocar la sesión en la base y abrir la app | Regresa a Iniciar sesión, avisa y borra la sesión guardada | Aprobado |
| E2E-AUTH-08 | HU-31 | 10 fallos directos a la API y el intento 11 desde la pantalla con la contraseña correcta | Muestra el mensaje del 429, el botón queda desactivado y no hay sesión | Aprobado |

E2E-AUTH-05 no llega a la API: la app valida antes de enviar. El rechazo de la API se comprueba en las pruebas del backend.

**Control:** con la API apagada, 7 casos fallaron y solo pasó E2E-AUTH-05.

## 4. Ejecución

| Dato | Valor |
| :--- | :--- |
| Fecha | 27 de noviembre de 2026 (backend: 26 de noviembre) |
| Responsable | `GleipM` |
| Versión | `develop` en `243ac20` (incluye S5-19), más las pruebas de esta tarjeta |
| Entorno | Windows 11, Flutter 3.50.1, Node 26.13.1, PostgreSQL 16.16 local |

| Ejecución | Resultado |
| :--- | :--- |
| `flutter test test/e2e_auth_api_test.dart` con la API y la base | 8 aprobadas, 0 fallidas (dos veces seguidas) |
| `flutter test` sin los datos de la API | 537 aprobadas, 12 omitidas (8 son estas), 0 fallidas |
| `flutter analyze` | 0 errores, 0 advertencias, 74 avisos informativos |
| `npx jest` en `backend/` | 306 aprobadas, 0 fallidas |
| `npx jest --config jest.db.config.js --runInBand` en `backend/` | 78 aprobadas, 0 fallidas |

Las dos ejecuciones del backend se hicieron sobre `8e812bc`; `backend/` no cambió entre esa versión y `243ac20`. El control con la API apagada también se hizo sobre `8e812bc`.

## 5. Cómo repetirlo

1. Crear una base vacía para el recorrido, por ejemplo `kopay_e2e`, en PostgreSQL 16.
2. En `backend/`, con `DATABASE_URL` apuntando a esa base: `npm ci`, `npm run migrate` y `npm start`.
3. En la raíz del repositorio, con la API en el puerto 3000:

```
flutter test test/e2e_auth_api_test.dart --dart-define=API_URL=http://127.0.0.1:3000 --dart-define=E2E_DB=postgres://usuario:clave@localhost:5432/kopay_e2e
```

Si `psql` no está en el `PATH`, agregar `--dart-define=PSQL=<ruta de psql>`. Sin `E2E_DB`, las pruebas se omiten. Cada ejecución crea cuentas con correos nuevos. No usar una base con datos reales.

## 6. Sin ejecutar

- No se probó en Android ni en iPhone, ni con la app compilada: este equipo no tiene emulador ni las herramientas para compilarla.
- El guardado en Keystore o Keychain no se probó: el almacén seguro se simula.
- No se probó contra la API desplegada.
- No se probó la recuperación de acceso (HU-32) ni el cierre de sesión desde la interfaz.
