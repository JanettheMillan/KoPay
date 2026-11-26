# Revisión de integración inicial y Pull Requests de acceso (S3-15)

**Tarjeta:** #63 · S3-15 · Sprint 3
**Historias:** HU-30 (registro), HU-31 (iniciar sesión), HU-32 (recuperar acceso), HU-33 (cerrar sesión), HU-34 (proteger mis datos)
**Revisó:** Rubén (RuAbogado) · **Fecha:** 26 de noviembre de 2026 · **Código:** `develop` en `0704677`

## 1. Pull Requests revisados

Todos se revisaron con las pruebas del autor más las de `develop` corridas juntas, y se mergearon con Squash. Cada PR tiene un comentario con lo que se revisó y el resultado.

| Tarjeta | PR | Autor | Qué entrega |
| :--- | :--- | :--- | :--- |
| S3-13 | #158 | RuAbogado | Contrato de acceso y forma de errores `{ error, code, fields? }` |
| S3-14 | #160 | RuAbogado | Reglas de roles y consentimiento del contador |
| S3-05 | #169 | EnriqueLanda2 | Migraciones de usuarios, roles y sesiones |
| S3-07 | #167 | CiscoPaquitoTracer | `POST /api/auth/register` |
| S3-08 | #170 | CiscoPaquitoTracer | Hash de contraseñas con scrypt |
| S3-09 | #172 | CiscoPaquitoTracer | `POST /api/auth/login` y `GET /api/auth/me` |
| S3-10 | #176 | JanettheMillan | Pantalla de registro |
| S3-06 | #177 | EnriqueLanda2 | Relación de autorización usuario–contador |
| S4-01 | #179 | EnriqueLanda2 | Emisión y verificación de JWT |
| S4-07 | #182 | CiscoPaquitoTracer | Cliente Flutter de autenticación (`HttpAuthApi`) |
| S4-02 | #188 | EnriqueLanda2 | Renovación y cierre de sesión |
| S4-08 | #191 | CiscoPaquitoTracer | Conservar y renovar la sesión en Flutter |
| S3-11 | #196 | JanettheMillan | Pantalla de inicio de sesión |
| S3-12 | #201 | JanettheMillan | Entrada a la app según la sesión |

S4-01, S4-02, S4-07 y S4-08 son del Sprint 4, pero se incluyen porque completan el acceso que pide HU-31 a HU-34.

## 2. Recorrido de punta a punta con la API real

API local con PostgreSQL 16, base vacía y `npm run migrate` (001 a 006). El script está en [`evidencias/s3-15/recorrido-api.sh`](evidencias/s3-15/recorrido-api.sh) y la salida completa en [`evidencias/s3-15/recorrido-api.txt`](evidencias/s3-15/recorrido-api.txt).

| # | Paso | Esperado (contrato) | Observado |
| ---: | :--- | :--- | :--- |
| 1 | Registro válido | `201` con `user`, rol `user` | `201` |
| 2 | Registro con correo repetido | `409 EMAIL_TAKEN` | `409 EMAIL_TAKEN` |
| 3 | Registro con datos inválidos | `400 VALIDATION_FAILED` con los tres `fields` | `400`, con `name`, `email` y `password` |
| 4 | JSON roto | `400 INVALID_JSON` | `400 INVALID_JSON` |
| 5 | Login con contraseña incorrecta | `401 INVALID_CREDENTIALS` | `401 INVALID_CREDENTIALS` |
| 6 | Login con correo inexistente | El mismo cuerpo que el paso 5 | Idéntico |
| 7 | Login correcto, correo en mayúsculas | `200` con `accessToken` y `refreshToken` | `200` |
| 8 | `GET /me` con token | `200` | `200` |
| 9 | `GET /me` sin token | `401 UNAUTHENTICATED` | `401 UNAUTHENTICATED` |
| 10 | Crear movimiento con sesión | `201` con dueño de la sesión | `201` |
| 11 | Crear ingreso con sesión | `201` | `201` |
| 12 | Renovar | `200` con tokens nuevos | `200` |
| 13 | Renovar con el mismo refreshToken | `401` | `401` |
| 14 | Token de acceso anterior a la renovación | `401` | `401` |
| 15 | Listar movimientos con el token nuevo | `200` con el movimiento del paso 10 | `200` |
| 16 | Cerrar sesión | `204` | `204` |
| 17 | `GET /me` después de cerrar sesión | `401` | `401` |
| 18 | `/api/clients` sin sesión | `401` | `401` |
| 19 | Ruta inexistente | `404 NOT_FOUND` | `404 NOT_FOUND` |
| 20 | Login correcto después de 10 fallos | `429 TOO_MANY_ATTEMPTS` (S4-13) | `429 TOO_MANY_ATTEMPTS` |
| 21 | Login con la base detenida | `503 UNAVAILABLE`, sin detalles internos | `503 UNAVAILABLE`; `/api/health` responde `data.ok: false` |

**Resultado:** 21 de 21 coinciden con el contrato.

Del lado de la app, el recorrido completo (Splash, acceso, login con error, login correcto, Inicio y cierre de sesión) se probó con `integration_test/s3_12_navegacion_test.dart` en macOS. Ese recorrido usa `FakeAuthApi`. El mismo recorrido con la app contra la API real en un teléfono Android le toca a QA en S3-18 (#66).

## 3. Lo que se corrigió durante la revisión

| Dónde | Qué | Cómo quedó |
| :--- | :--- | :--- |
| Recuperación (#180) | Los 5 intentos del código se podían rebasar con peticiones en paralelo | El intento se reserva antes de comparar (REC-15) |
| Capa de datos | Con la base caída, la API respondía `500` | `503 UNAVAILABLE` (paso 21) |
| Login | No limitaba los intentos | 10 fallos en 15 minutos responden `429` (#202, S4-13) |
| Configuración | `CORS_ORIGIN=*` se aceptaba en producción | Producción no arranca con `*` (#202) |
| Contrato | Choque de numeración de secciones entre dos PRs | Renumerado (3.10 `/api/clients`) |
| Manual (#194) | Dos líneas daban por hecho lo que no existía | Marcadas como pendientes; CORS ya resuelto en #202 |
| Conflictos | #181 y #203 chocaban con `develop` | Resueltos con merge commit en la rama del autor, sin force push |

## 4. Bloqueos y pendientes registrados en sus tarjetas

| Pendiente | Tarjeta | Responsable |
| :--- | :--- | :--- |
| `can()` lanza `TypeError` con roles como `__proto__` | #183 (D-07) | Richi |
| La base SQLite local no es por cuenta: otra cuenta en el mismo teléfono vería los datos de la anterior | Nota en #93 (S5-07), coordinar con #96 | Cisco y Janette |
| Probar registro e inicio de sesión en un teléfono contra la API real | #65 (S3-17), #66 (S3-18) | GleipM |
| API en Railway con https | #189 | Rubén |
| APK de entrega | #102 | Rubén |

## 5. Criterio de aceptación

"Cambios y bloqueos se registran en sus tarjetas": cada PR tiene su comentario de revisión. Las correcciones están en la §3 y cada bloqueo abierto en su tarjeta (§4).
