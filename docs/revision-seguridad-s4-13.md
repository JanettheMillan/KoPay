# Revisión de seguridad de sesiones y permisos (S4-13)

**Tarjeta:** #79 · S4-13 · Sprint 4
**Historias:** HU-31 (iniciar sesión), HU-32 (recuperar acceso), HU-33 (cerrar sesión), HU-34 (proteger mis datos por cuenta), HU-37 (acceso por rol)
**Revisó:** Rubén (RuAbogado) · **Fecha:** 26 de noviembre de 2026
**Código revisado:** `develop` después de #200 (S5-01). Incluye S4-01 a S4-06, S4-08, S4-09, S4-19, S3-11 y S5-01.

## 1. Alcance

Se revisaron estas partes:

| Área | Archivos |
| :--- | :--- |
| Contraseñas | `backend/src/services/password.service.js` |
| Login y registro | `backend/src/services/auth.service.js`, `backend/src/validators/auth.validator.js` |
| Tokens y sesiones | `backend/src/services/jwt.js`, `backend/src/services/session.service.js`, `backend/src/middleware/authenticate.js` |
| Roles y permisos | `backend/src/middleware/rbac.js`, `backend/src/middleware/client-access.js`, `backend/src/middleware/owner.js`, `backend/src/routes/*.js` |
| Recuperación | `backend/src/services/recovery.service.js` |
| Configuración | `backend/src/config/index.js` |
| App | `lib/providers/session_provider.dart`, `lib/services/http_auth_api.dart`, `lib/utils/route_policy.dart`, `android/app/src/*/AndroidManifest.xml` |

## 2. Amenazas consideradas

| Id | Amenaza | Quién | Qué se pierde |
| :--- | :--- | :--- | :--- |
| A1 | Adivinar la contraseña de una cuenta probando muchas | Cualquiera en internet | Todas las finanzas de la cuenta |
| A2 | Averiguar qué correos tienen cuenta | Cualquiera | Privacidad; facilita A1 y phishing |
| A3 | Falsificar o alterar un token | Cualquiera | Entrar como otra cuenta |
| A4 | Usar un token robado o viejo | Quien obtenga el teléfono o el token | Sesión de la víctima |
| A5 | Leer o cambiar datos de otra cuenta cambiando un id | Una cuenta con sesión | Datos ajenos (DB-04) |
| A6 | Que un contador escriba o vea clientes sin permiso | Contador | Datos de clientes |
| A7 | Subirse de rol desde la app | Una cuenta `user` | Vista y datos de contador |
| A8 | Adivinar el código de recuperación | Cualquiera | Tomar la cuenta |
| A9 | Configurar producción con valores inseguros | El equipo | Secretos débiles u orígenes abiertos |
| A10 | Ver tokens o contraseñas en tránsito o en el teléfono | Red o malware | Sesión |

## 3. Lo que se verificó y está bien

| Id | Control | Cómo se comprobó |
| :--- | :--- | :--- |
| V1 | Contraseñas con scrypt (N=16384, r=8, p=1, sal de 16 bytes) y comparación en tiempo constante. Nunca se guardan ni se responden en texto. | Código y `credentials.test.js` |
| V2 | El login responde igual (`401 INVALID_CREDENTIALS`) si el correo no existe o la contraseña falla, y compara contra un hash de relleno para tardar lo mismo (A2). | `login.test.js` (CON-12, CON-13) |
| V3 | El JWT solo acepta el encabezado exacto `HS256`/`JWT`. `alg: none` u otro algoritmo se rechaza. Firma comparada en tiempo constante. `JWT_SECRET` de 32 o más caracteres y distinto del de ejemplo en producción (A3). | `jwt.test.js`, `config.test.js` |
| V4 | Cada token de acceso tiene su fila en `sessions` (solo el hash). Cerrar sesión, renovar o cambiar la contraseña la cierran, y el token deja de servir aunque su firma siga vigente (A4). | `session-refresh.test.js`, `recovery.test.js` |
| V5 | El refreshToken es aleatorio (32 bytes), se guarda solo su hash y sirve una vez. Con dos renovaciones a la vez solo una gana (A4). | `session-refresh.test.js` |
| V6 | El rol se lee de la base en cada petición, nunca de la app. El registro siempre crea `user`; los contadores se crean fuera de la app (A7). | `rbac.test.js`, `register.test.js` |
| V7 | Rutas financieras: 401 sin sesión, 403 para el contador y dueño siempre tomado de la sesión. Un registro ajeno responde el mismo 404 que uno inexistente (A5). | `finances-guard.test.js` (FIN-01 a FIN-07), `movements.test.js` (MOV-05, MOV-10) |
| V8 | El contador solo lee (`readOnly`) y solo clientes con permiso vigente. Sin permiso, revocado o inexistente responde el mismo 403. Revocar tiene efecto inmediato (A6). | `clients.test.js` |
| V9 | Recuperación: código de 6 dígitos guardado como HMAC, 15 minutos, 5 intentos reservados antes de comparar, 1 correo por minuto y la misma respuesta exista o no la cuenta (A2, A8). | `recovery.test.js` (incluye REC-15, el arreglo de intentos en paralelo) |
| V10 | Si la base no responde, la API da `503 UNAVAILABLE` y no un 500 con detalles. | `pg-store` y pruebas de `503` |
| V11 | En la app, los tokens van en `flutter_secure_storage`. El APK de release no permite http sin cifrar: `usesCleartextTraffic` solo está en `debug`. Producción va por https (`config/prod.json`, CFG-04) (A10). | Código y `api_config_files_test.dart` |
| V12 | Las guardas de Flutter (`RoutePolicy`) no dan privilegios a un rol desconocido y no sustituyen a la API, que vuelve a comprobar todo (A7). | `role_guard_test.dart` (GRD-01 a GRD-11) |
| V13 | En la app, dos renovaciones a la vez se juntan en una (`_refreshing`), así que el 401 de la segunda no cierra la sesión. | `session_provider_test.dart` (SES-14) |

## 4. Hallazgos

| Id | Severidad | Hallazgo | Estado |
| :--- | :--- | :--- | :--- |
| SEG-H1 | **Alta** | **El login no limitaba los intentos.** Con una cuenta registrada, 50 contraseñas incorrectas seguidas respondieron `401` y la 51, la correcta, `200`. Se podía adivinar la contraseña sin freno (A1). | **Corregido en este PR** (§5.1) |
| SEG-H2 | Alta | Los 5 intentos del código de recuperación se podían rebasar con peticiones en paralelo (A8). | Corregido antes, en la revisión de #180 (REC-15) |
| SEG-H3 | Media | `CORS_ORIGIN=*` se aceptaba en producción, aunque el manual decía que no (A9). | **Corregido en este PR** (§5.2) |
| SEG-H4 | Media | `can()` de RBAC lanza `TypeError` con roles como `constructor` o `__proto__`. Hoy responde 500 y no da acceso, pero debe responder 403. | Abierto: #183 (D-07, Richi) |
| SEG-H5 | Baja | Si alguien usa un refreshToken que ya se usó, solo recibe `401`; no se cierran las demás sesiones de la cuenta. Un token robado que el atacante use primero le da una sesión hasta que la víctima cierre sesión o cambie la contraseña. | Riesgo aceptado (§6, D3) |
| SEG-H6 | Baja | El HMAC del código de recuperación usa el mismo `JWT_SECRET` que los tokens. | Riesgo aceptado (§6, D4) |
| SEG-H7 | Baja | La tabla `sessions` no se limpia: las filas vencidas se quedan. No es un fallo de seguridad, pero crece. | Pendiente para después de la entrega |
| SEG-H8 | Informativa | La API no tiene middleware de CORS: no envía encabezados `Access-Control-*`, así que un navegador bloquea cualquier página de otro origen. La app de Android no usa CORS. `CORS_ORIGIN` queda para un cliente web futuro. | Documentado |

## 5. Cambios de este PR

### 5.1 Límite de intentos en el login (SEG-H1)

- `backend/src/services/login-throttle.js` (nuevo, sin librerías):
  - Cuenta los fallos por correo normalizado en una ventana de **15 minutos**.
  - Desde el intento **11**, el login responde `429 TOO_MANY_ATTEMPTS` con `"Demasiados intentos. Espera unos minutos e inténtalo de nuevo."`, **aunque la contraseña sea correcta**, hasta que termine la ventana.
- Cada intento se **reserva antes de comparar** la contraseña, igual que REC-15. Con 40 peticiones en paralelo se comparan solo 10.
- Un login correcto borra el contador.
- Cuenta igual si el correo no existe, así que el 429 no revela qué correos tienen cuenta (A2).
- El contador vive en memoria, con un tope de 10,000 correos. Se reinicia con la API y vale por instancia; en la entrega hay una sola (#189).
- `docs/contrato-api-acceso.md` §2 y §3.2: el `429` del login deja de estar reservado.
- La app ya lo maneja: `LoginScreen` muestra el `error` arriba del formulario (UI-LOG-05).

Por qué por correo y no por IP: Railway pone un proxy delante y todas las peticiones llegarían con su IP, salvo que se configure `trust proxy`. El límite por correo protege a cada cuenta, que es lo que pide A1.

Riesgo de este cambio: quien conozca el correo de alguien puede bloquearle el login 15 minutos con 10 intentos. Se acepta: la ventana es corta, no se borra nada y la recuperación sigue funcionando.

### 5.2 `CORS_ORIGIN` sin `*` en producción (SEG-H3)

- `backend/src/config/index.js`: en producción, si `CORS_ORIGIN` es `*` o lo incluye en la lista, la API no arranca y avisa `CORS_ORIGIN no puede ser * en producción`.
- En desarrollo y pruebas sigue permitido `*`.
- En Railway (#189) se pone la URL pública de la API, como dice el checklist.

## 6. Decisiones

| Id | Decisión | Por qué |
| :--- | :--- | :--- |
| D1 | El límite del login se implementa sin librería y en memoria. | No hay librería autorizada para el sprint y hay una sola instancia. Si se escala, el contador se mueve a PostgreSQL. |
| D2 | 10 fallos y 15 minutos. | Equilibra adivinar (como máximo 40 intentos por hora por cuenta) y no bloquear a quien se equivoca algunas veces. |
| D3 | No se detecta el reuso de refreshToken (SEG-H5). | Distinguir "ya renovado" de "cerrado con logout" requiere otra columna, y el acceso dura solo 15 minutos. El refreshToken va solo por https y en `flutter_secure_storage`. Cambiar la contraseña cierra todas las sesiones. Se puede agregar después de la entrega, porque la app ya junta las renovaciones a la vez (V13). |
| D4 | El HMAC de recuperación sigue usando `JWT_SECRET` (SEG-H6). | Los mensajes son de tipos distintos (código de 6 dígitos con id de usuario frente a JWT) y no se pueden confundir. Separar el secreto agrega otra variable obligatoria en Railway sin bajar un riesgo real. |
| D5 | Las guardas de Flutter son ayuda de navegación, no seguridad. | La API vuelve a comprobar sesión, rol y permiso en cada petición (V6 a V8). |

## 7. Pruebas

| Caso | Archivo | Qué comprueba | Resultado |
| :--- | :--- | :--- | :--- |
| SEG-01 | `backend/test/login-throttle.test.js` | Después de 10 fallos, `429` aun con la contraseña correcta y sin token | Pasa |
| SEG-02 | mismo | Mayúsculas y espacios en el correo cuentan como el mismo correo | Pasa |
| SEG-03 | mismo | Un correo sin cuenta recibe el mismo `429` | Pasa |
| SEG-04 | mismo | Un login correcto reinicia el contador | Pasa |
| SEG-05 | mismo | Al pasar los 15 minutos se puede entrar | Pasa |
| SEG-06 | mismo | Bloquear un correo no afecta a otra cuenta | Pasa |
| SEG-07 | mismo | 40 intentos en paralelo: exactamente 10 `401` y 30 `429` | Pasa |
| SEG-07b | mismo | El contador no pasa del tope de correos | Pasa |
| SEG-08 | `backend/test/config.test.js` | Producción rechaza `CORS_ORIGIN` con `*` | Pasa |

Reproducción de SEG-H1 antes del arreglo (`develop` en `30c0a68`): 50 intentos con contraseña incorrecta dieron `{"401":50}` y el intento siguiente, con la correcta, `200`.

Resultado en esta rama:

| Comando | Resultado |
| :--- | :--- |
| `cd backend && npm test` | 289 aprobadas, 0 fallidas (9 nuevas) |
| `npm run test:db` (PostgreSQL 16) | 75 aprobadas, 0 fallidas |
| `flutter test` | Sin cambios en la app |

QA repite SEG-01, SEG-03 y SEG-07 en S4-16 (#82).
