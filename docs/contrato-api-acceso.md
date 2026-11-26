# Contrato de la API: registro, inicio de sesión y errores

**Tarjeta:** S3-13 · [#61](https://github.com/JanettheMillan/KoPay/issues/61). **Historias:** HU-30 (crear cuenta) y HU-31 (iniciar sesión).
**Base:** [arquitectura.md](arquitectura.md), sección 6, y [navegacion-usuario-contador.md](navegacion-usuario-contador.md), sección 2.

Este documento fija lo que la API Node.js recibe y responde en el registro y el inicio de sesión, y la forma de **todos** los errores de la API. Node (S3-07, S3-08, S3-09, S4-01, S4-02, S4-19) lo implementa y Flutter (S3-10, S3-11, S3-12, S4-07, S4-08, S4-20) lo consume. Si una tarjeta necesita cambiarlo, el cambio se hace primero aquí, en un PR propio, y se avisa a ambos lados.

La forma de los errores (sección 2) ya está implementada en `backend/src/errors.js` y `backend/src/middleware/errors.js`. `POST /api/auth/register` (S3-07), `POST /api/auth/login` y `GET /api/auth/me` (S3-09), y `POST /api/auth/recover` y `POST /api/auth/reset` (S4-19) ya existen. Las demás rutas de la sección 3 todavía no existen: las crean las tarjetas indicadas en cada una.

## 1. Reglas generales

- Todas las rutas están bajo `/api`. Las de cuenta y sesión, bajo `/api/auth`.
- El cuerpo de petición y de respuesta es JSON (`Content-Type: application/json`), en UTF-8. Un cuerpo de más de 100 kB responde `413`.
- Los nombres de campo van en inglés y `camelCase`. Los mensajes para la persona (`error` y `fields`) van en español.
- Las fechas son texto ISO 8601 en UTC, por ejemplo `2026-11-26T18:30:00.000Z`.
- Los `id` son texto UUID, por ejemplo `"3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f"` (PostgreSQL `gen_random_uuid()`, ver [base-de-datos.md](base-de-datos.md)). Flutter los trata como texto opaco.
- El correo se guarda y se compara **sin espacios al inicio o al final y en minúsculas**. `Ana@Mail.com` y `ana@mail.com` son la misma cuenta.
- La contraseña **nunca** aparece en una respuesta, en un mensaje de error ni en la consola del servidor. Tampoco su hash.
- Las rutas que requieren sesión reciben el token en el encabezado `Authorization: Bearer <accessToken>`.

## 2. Forma de los errores

Cualquier respuesta con estado `4xx` o `5xx` tiene este cuerpo:

```json
{
  "error": "Revisa los datos marcados",
  "code": "VALIDATION_FAILED",
  "fields": {
    "email": "Escribe un correo válido",
    "password": "La contraseña debe tener al menos 8 caracteres"
  }
}
```

| Campo | Siempre | Uso |
| :--- | :---: | :--- |
| `error` | Sí | Mensaje en español que Flutter puede mostrar tal cual. No incluye datos internos ni valores enviados. |
| `code` | Sí | Código estable de la tabla de abajo. **Flutter decide con `code`, nunca comparando el texto de `error`.** |
| `fields` | Solo en `VALIDATION_FAILED` | Un mensaje por campo inválido. Flutter lo muestra debajo de cada campo. |

### Códigos

| Estado | `code` | Cuándo | Qué hace Flutter |
| :---: | :--- | :--- | :--- |
| 400 | `VALIDATION_FAILED` | Falta un campo o no cumple las reglas. | Marca los campos de `fields`. |
| 400 | `INVALID_JSON` | El cuerpo no es JSON válido. | Muestra `error`; es un error de la app, no de la persona. |
| 401 | `INVALID_CREDENTIALS` | Correo o contraseña incorrectos en el login. | Muestra `error` arriba del formulario y limpia la contraseña. |
| 401 | `UNAUTHENTICATED` | Falta el token, no es válido o ya expiró. | Borra la sesión guardada y abre Iniciar sesión. |
| 403 | `FORBIDDEN` | La sesión es válida pero el rol o el permiso no alcanzan (S3-14). | Muestra `error`. En la vista de contador, el aviso de acceso retirado. |
| 404 | `NOT_FOUND` | La ruta o el registro no existe para esa cuenta. | Muestra `error`. |
| 409 | `EMAIL_TAKEN` | Ya hay una cuenta con ese correo. | Marca el campo correo con `error`. |
| 413 | `PAYLOAD_TOO_LARGE` | El cuerpo pasa de 100 kB. | Muestra `error`. |
| 429 | `TOO_MANY_ATTEMPTS` | Código de recuperación con 5 intentos fallidos (sección 3.8). En el login sigue reservado: se implementa cuando se autorice la librería. | Muestra `error` y desactiva el botón un momento. En recuperación, regresa a pedir un código nuevo. |
| 500 | `INTERNAL` | Error inesperado del servidor. | Muestra `error` y permite reintentar. |
| 503 | `UNAVAILABLE` | La base de datos u otro servicio no responde. | Muestra `error` y permite reintentar. |

Si la petición no llega al servidor (sin red, tiempo agotado o respuesta que no es JSON), Flutter muestra **"No se pudo conectar con KoPay. Revisa tu conexión e inténtalo de nuevo."** y no borra la sesión guardada.

Para crear un error en Node se usa `HttpError`; el manejador arma el cuerpo:

```js
throw new HttpError(400, 'Revisa los datos marcados', {
  fields: { email: 'Escribe un correo válido' },
});
throw new HttpError(401, 'Correo o contraseña incorrectos', {
  code: ERROR_CODES.INVALID_CREDENTIALS,
});
```

## 3. Rutas

### 3.1 `POST /api/auth/register` · Crear cuenta (HU-30, S3-07)

Petición:

```json
{ "name": "Ana López", "email": "ana@mail.com", "password": "kopay2026" }
```

| Campo | Regla | Mensaje en `fields` |
| :--- | :--- | :--- |
| `name` | Obligatorio. Sin espacios al inicio o al final, de 1 a 80 caracteres. | `Escribe tu nombre` / `El nombre puede tener hasta 80 caracteres` |
| `email` | Obligatorio. Formato `texto@dominio.ext`, hasta 254 caracteres. Se guarda en minúsculas. | `Escribe un correo válido` |
| `password` | Obligatorio. De 8 a 72 caracteres, con al menos una letra y un número. No se recorta. | `La contraseña debe tener al menos 8 caracteres` / `La contraseña puede tener hasta 72 caracteres` / `La contraseña debe tener al menos una letra y un número` |

- Un campo que no está en la tabla se ignora. En particular, **`role` se ignora**: toda cuenta creada desde la app es `user`. Las cuentas de contador se crean fuera de la app (S3-14).
- Las validaciones se revisan todas a la vez y `fields` trae todos los campos con problema, no solo el primero.
- Flutter aplica las mismas reglas antes de enviar (S3-10), pero la API es la que decide.

Respuesta `201 Created`:

```json
{
  "user": {
    "id": "3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f",
    "name": "Ana López",
    "email": "ana@mail.com",
    "role": "user",
    "createdAt": "2026-11-26T18:30:00.000Z"
  }
}
```

El registro **no abre sesión**: Flutter regresa a Iniciar sesión con el correo ya escrito, como en el diagrama de la navegación.

Errores: `400 VALIDATION_FAILED`, `409 EMAIL_TAKEN` (`"Ya existe una cuenta con ese correo"`), `500`, `503`.

### 3.2 `POST /api/auth/login` · Iniciar sesión (HU-31, S3-09)

Petición:

```json
{ "email": "ana@mail.com", "password": "kopay2026" }
```

- `email` y `password` son obligatorios. Si falta alguno, `400 VALIDATION_FAILED` con `fields`. Aquí **no** se revisan las reglas de longitud del registro.
- Si el correo no existe o la contraseña no coincide, la respuesta es **la misma**: `401 INVALID_CREDENTIALS` con `"Correo o contraseña incorrectos"`. Así no se puede averiguar qué correos tienen cuenta.
- Aunque el correo no exista, el servidor compara la contraseña contra un hash de relleno para que las dos respuestas tarden lo mismo.

Respuesta `200 OK`:

```json
{
  "accessToken": "<texto opaco>",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": "3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f",
    "name": "Ana López",
    "email": "ana@mail.com",
    "role": "user",
    "createdAt": "2026-11-26T18:30:00.000Z"
  }
}
```

- `accessToken` es **opaco** para Flutter: lo guarda y lo envía, pero no lo lee. Desde S4-01 es un JWT HS256 (`sub` = id del usuario, `jti`, `iat`, `exp`) firmado con `JWT_SECRET`, y cada uno tiene su fila en `sessions` (solo el hash). La respuesta no cambió.
- `expiresIn` está en segundos.
- `user.role` es `user` o `accountant`. Flutter abre la vista de usuario o la de contador según este valor (HU-37).
- A partir de S4-02 la respuesta agrega `refreshToken` y `refreshExpiresIn`. Flutter debe aceptar la respuesta con o sin ellos.

Errores: `400 VALIDATION_FAILED`, `401 INVALID_CREDENTIALS`, `429 TOO_MANY_ATTEMPTS` (reservado), `500`, `503`.

### 3.3 `GET /api/auth/me` · Sesión actual (HU-31, HU-34, S3-09)

Requiere `Authorization: Bearer <accessToken>`. Responde `200 OK` con `{ "user": { … } }`, igual que el login.

Flutter la usa en el Splash (S3-12) para saber si la sesión guardada sigue vigente: `200` abre la vista del rol y `401 UNAUTHENTICATED` abre Iniciar sesión.

Errores: `401 UNAUTHENTICATED`, `500`, `503`.

### 3.4 `POST /api/auth/logout` · Cerrar sesión (HU-33, S4-02)

Requiere `Authorization: Bearer <accessToken>`. Invalida la sesión en el servidor y responde `204 No Content` sin cuerpo. Con un token ya inválido también responde `204`: el resultado para la persona es el mismo.

### 3.5 `POST /api/auth/refresh` · Renovar sesión (HU-31, S4-02)

Petición `{ "refreshToken": "<texto opaco>" }`. Responde igual que el login. Si el `refreshToken` no es válido o expiró, `401 UNAUTHENTICATED`. El detalle lo cierra S4-02 en este documento.

### 3.6 `/api/accountants` · Contadores autorizados (HU-38, HU-41, S4-05)

Requiere `Authorization: Bearer <accessToken>` de una cuenta `user`. Las reglas de quién autoriza y cómo se revoca están en [reglas-roles-contador.md](reglas-roles-contador.md), secciones 2 y 4. La cuenta sobre la que se actúa es siempre la de la sesión: un `userId` en el cuerpo se ignora.

| Método y ruta | Éxito | Errores propios |
| :--- | :--- | :--- |
| `GET /api/accountants` | `200 { "grants": [{ "id", "accountant": { "id", "name", "email" }, "grantedAt" }] }`, solo vigentes, del más antiguo al más nuevo | — |
| `POST /api/accountants` `{ "accountantEmail": "carla@conta.mx" }` | `201 { "grant" }`. Si ya había un permiso vigente con ese contador, `200` con el mismo permiso y no se crea otro. | `400 VALIDATION_FAILED` con `fields.accountantEmail`; `404 NOT_FOUND` "No hay un contador con ese correo" |
| `DELETE /api/accountants/:grantId` | `204` sin cuerpo. Efecto inmediato. | `404 NOT_FOUND` "No encontramos ese permiso" si no existe, no es suyo o ya estaba revocado |

- El correo se recorta y se pasa a minúsculas, igual que en el registro.
- El `404` del `POST` es el mismo si el correo no existe o si es de una cuenta `user`, para no revelar qué correos tienen cuenta.
- Sin sesión, `401 UNAUTHENTICATED`. Con una sesión de `accountant`, `403 FORBIDDEN` "No tienes permiso para esta operación": el contador no puede autorizarse ni revocar.
- Revocar no borra el permiso: llena `revokedAt` y se conserva como historial. Autorizar de nuevo crea un permiso con otro `id`.

### 3.7 `POST /api/auth/recover` · Pedir código de recuperación (HU-32, S4-19)

Mecanismo acordado para la HU-32: un **código de 6 dígitos** enviado por correo, que vence a los **15 minutos**, sirve **una sola vez** y admite **5 intentos**. No requiere sesión.

Petición:

```json
{ "email": "ana@mail.com" }
```

| Campo | Regla | Mensaje en `fields` |
| :--- | :--- | :--- |
| `email` | Obligatorio. Mismo formato y normalización que en el registro. | `Escribe un correo válido` |

Respuesta `200 OK`, **la misma exista o no una cuenta con ese correo**:

```json
{ "message": "Si el correo tiene una cuenta, te enviamos un código. Vence en 15 minutos." }
```

- Si la cuenta existe, el servidor genera el código, guarda solo su hash y lo envía por correo. Si no existe, no hace nada más. La respuesta no espera al envío, para que las dos tarden lo mismo.
- Pedir un código nuevo invalida el anterior de esa cuenta, aunque no haya vencido.
- **Un correo por minuto por cuenta.** Si a esa cuenta ya se le envió un código hace menos de 60 segundos, la respuesta es la misma `200`, pero no se genera código nuevo ni se envía correo, y el anterior sigue valiendo. No se responde `429`, para no revelar que la cuenta existe.
- El código nunca aparece en una respuesta. En `development` y `test` el correo no se envía de verdad: el código sale en la consola del servidor. En `production` nunca sale en la consola.
- Si el correo no se puede enviar, la respuesta sigue siendo `200` con el mismo cuerpo. El servidor registra la falla sin el correo ni el código.
- Las cuentas `accountant` también pueden recuperar su acceso.

Errores: `400 VALIDATION_FAILED`, `500`, `503`.

### 3.8 `POST /api/auth/reset` · Cambiar la contraseña con el código (HU-32, S4-19)

Petición:

```json
{ "email": "ana@mail.com", "code": "048213", "password": "nueva2026" }
```

| Campo | Regla | Mensaje en `fields` |
| :--- | :--- | :--- |
| `email` | Obligatorio. Mismo formato y normalización que en el registro. | `Escribe un correo válido` |
| `code` | Obligatorio. Texto de exactamente 6 dígitos; los ceros a la izquierda cuentan. | `Escribe el código de 6 dígitos` |
| `password` | La contraseña nueva. Mismas reglas que en el registro (sección 3.1). | Los mismos mensajes del registro |

Respuesta `204 No Content`, sin cuerpo. **No abre sesión**: Flutter regresa a Iniciar sesión con el correo ya escrito.

Al cambiar la contraseña:

- Se guarda el hash de la contraseña nueva (S3-08); la anterior deja de servir.
- El código queda usado y no sirve otra vez.
- **Se cierran todas las sesiones de la cuenta**: se llena `revoked_at` en `sessions`, así que un token anterior responde `401 UNAUTHENTICATED` en `GET /api/auth/me`.

Errores:

| Estado | `code` | Cuándo | `error` / `fields` |
| :---: | :--- | :--- | :--- |
| 400 | `VALIDATION_FAILED` | Algún campo no cumple su regla. Se revisan todos a la vez. | `fields` con un mensaje por campo |
| 400 | `VALIDATION_FAILED` | El código no coincide, ya venció, ya se usó, se pidió uno más nuevo o el correo no tiene cuenta. La respuesta es la misma en todos los casos. | `fields.code`: `El código no es válido o ya venció` |
| 429 | `TOO_MANY_ATTEMPTS` | El código ya tuvo 5 intentos fallidos. Queda invalidado aunque después se envíe el correcto. | `Demasiados intentos. Pide un código nuevo.` |

- Cada intento con un código incorrecto cuenta, aunque la contraseña nueva no cumpla las reglas. Si solo fallan las reglas de los campos, el intento no cuenta.
- El quinto intento fallido responde `400`; desde el sexto, `429`, hasta que se pide un código nuevo con `POST /api/auth/recover`.

### 3.9 Correo de recuperación y configuración (S4-19)

- Se envía con `nodemailer`, autorizado solo para S4-19.
- En `development` y `test` se usa `jsonTransport`: no sale ningún correo real y las pruebas no necesitan red.
- En `production` se usan `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` y `MAIL_FROM`, definidas en `backend/.env`. Si falta alguna, el servicio no arranca y dice cuál falta, como con `DATABASE_URL` (S3-02). Los valores reales se comparten solo por privado y nunca se suben al repositorio.
- El correo dice el código, que vence en 15 minutos y que, si la persona no lo pidió, puede ignorarlo. No incluye la contraseña ni enlaces con datos de la cuenta.
- Los códigos se guardan en una tabla propia, con el hash del código, el vencimiento, los intentos y la fecha de uso, en una migración nueva de S4-19.

### 3.10 `/api/clients` · Consultas del contador (HU-39, HU-40, HU-42, S4-06)

Requiere `Authorization: Bearer <accessToken>` de una cuenta `accountant`. Cada petición pasa por los tres pasos de [reglas-roles-contador.md](reglas-roles-contador.md), sección 5: sesión (`401`), rol y solo lectura (`403`) y, en las rutas de una persona, permiso vigente (`403`).

| Método y ruta | Éxito | Errores propios |
| :--- | :--- | :--- |
| `GET /api/clients` | `200 { "clients": [{ "id", "name", "email", "grantedAt" }] }`, solo personas con permiso vigente, del permiso más antiguo al más nuevo | — |
| `GET /api/clients/:userId` | `200 { "client": { "id", "name", "email", "grantedAt" } }` | `403 FORBIDDEN` "No tienes acceso a los datos de esta persona" |

- El `403` de `:userId` es el mismo si la persona no autorizó a este contador, si revocó, si no existe o si el id está mal formado (ROL-08).
- El permiso se consulta en cada petición: tras revocar, la siguiente consulta ya responde `403` y la persona sale de la lista.
- Cualquier `POST`, `PUT`, `PATCH` o `DELETE` bajo `/api/clients` responde `403` con el mismo mensaje (HU-42).
- Una cuenta `user` recibe `403` en todas estas rutas.
- S5-03 agrega `GET /api/clients/:userId/summary` y `GET /api/clients/:userId/movements` (sección 7 de las reglas) detrás del mismo guardia.

### 3.11 `GET /api/exchange-rates` · Tipo de cambio (HU-35, S5-06)

Requiere `Authorization: Bearer <accessToken>` de cualquier rol (`user` o `accountant`). No lleva cuerpo ni parámetros.

Devuelve el **tipo de cambio FIX USD/MXN** que publica Banxico (serie SF43718 del SIE). Respuesta `200 OK`:

```json
{ "base": "USD", "quote": "MXN", "rate": 17.2345, "date": "2026-11-25", "source": "Banxico FIX" }
```

| Campo | Tipo | Valor |
| :--- | :--- | :--- |
| `base` | texto | Siempre `"USD"`. |
| `quote` | texto | Siempre `"MXN"`. |
| `rate` | número | Pesos por dólar, tal como lo publica Banxico (hasta 4 decimales). |
| `date` | texto | Día del FIX, `AAAA-MM-DD`. En fin de semana o festivo es el **último publicado**, así que puede ser anterior a hoy. |
| `source` | texto | Siempre `"Banxico FIX"`. Flutter lo muestra como fuente. |

- El servidor guarda la respuesta **una hora** en memoria: el FIX cambia una vez al día y Banxico limita las consultas por token. Dentro de esa hora todas las cuentas reciben el mismo valor sin consultar a Banxico.
- Es **informativo**: no convierte ni guarda montos de la persona.
- Flutter debe mostrar la fecha junto al valor (por ejemplo, "FIX del 25 nov 2026") y, con `503`, un aviso sin bloquear el resto de la pantalla.

Errores:

| Estado | `code` | Cuándo | `error` |
| :---: | :--- | :--- | :--- |
| 401 | `UNAUTHENTICATED` | Sin sesión o con un token inválido o expirado. No se consulta a Banxico. | `Inicia sesión para continuar` |
| 503 | `UNAVAILABLE` | Banxico no respondió en 5 segundos, respondió con error, rechazó el token del servidor, llegó al límite de consultas o mandó una respuesta sin un dato válido. También si el servidor no tiene `BANXICO_TOKEN` (solo posible en `development` y `test`). | `El tipo de cambio no está disponible. Inténtalo más tarde.` |

- El `503` no dice la causa. El servidor anota solo el motivo en la consola (por ejemplo, "Banxico respondió 400" con un token inválido), nunca el token.
- Un fallo no se guarda en caché: la siguiente petición vuelve a intentar.
- `BANXICO_TOKEN` va en `backend/.env` y es obligatorio en `production` (64 caracteres hexadecimales). Cada integrante saca su propio token; no se comparte ni se sube.

## 4. Resumen de rutas

| Método y ruta | Sesión | Tarjeta | Éxito | Errores propios |
| :--- | :---: | :--- | :--- | :--- |
| `POST /api/auth/register` | No | S3-07 | `201 { user }` | `VALIDATION_FAILED`, `EMAIL_TAKEN` |
| `POST /api/auth/login` | No | S3-09 | `200 { accessToken, tokenType, expiresIn, user }` | `VALIDATION_FAILED`, `INVALID_CREDENTIALS` |
| `GET /api/auth/me` | Sí | S3-09 | `200 { user }` | `UNAUTHENTICATED` |
| `POST /api/auth/logout` | Sí | S4-02 | `204` | — |
| `POST /api/auth/refresh` | No | S4-02 | `200` igual que login | `UNAUTHENTICATED` |
| `GET /api/accountants` | Sí, `user` | S4-05 | `200 { grants }` | `FORBIDDEN` |
| `POST /api/accountants` | Sí, `user` | S4-05 | `201 { grant }` o `200` si ya estaba vigente | `VALIDATION_FAILED`, `NOT_FOUND`, `FORBIDDEN` |
| `DELETE /api/accountants/:grantId` | Sí, `user` | S4-05 | `204` | `NOT_FOUND`, `FORBIDDEN` |
| `POST /api/auth/recover` | No | S4-19 | `200 { message }`, igual exista o no la cuenta | `VALIDATION_FAILED` |
| `POST /api/auth/reset` | No | S4-19 | `204` y cierra todas las sesiones | `VALIDATION_FAILED`, `TOO_MANY_ATTEMPTS` |
| `GET /api/clients` | Sí, `accountant` | S4-06 | `200 { clients }` | `FORBIDDEN` |
| `GET /api/clients/:userId` | Sí, `accountant` con permiso | S4-06 | `200 { client }` | `FORBIDDEN` |
| `GET /api/exchange-rates` | Sí, cualquier rol | S5-06 | `200 { base, quote, rate, date, source }` | `UNAVAILABLE` |

## 5. Casos de prueba del contrato

Los casos CON-01 a CON-04 ya se ejecutan en `backend/test/contract.test.js`, CON-05 a CON-09 en `backend/test/register.test.js`, CON-10 en `backend/test/credentials.test.js` CON-11 a CON-14 en `backend/test/login.test.js` y CON-17 a CON-26 y CON-28 en `backend/test/recovery.test.js`. Los demás los automatiza la tarjeta que crea cada ruta, con el mismo identificador en el nombre de la prueba, y QA los toma en S3-16 y S3-18.

| Caso | Historia | Tarjeta | Qué se envía | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- |
| CON-01 | HU-30 | S3-13 | Ruta inexistente, JSON mal formado, cuerpo de más de 100 kB, error inesperado | `{ error, code }` con `NOT_FOUND`, `INVALID_JSON`, `PAYLOAD_TOO_LARGE` e `INTERNAL`; sin detalles internos |
| CON-02 | HU-30 | S3-13 | `HttpError` con y sin `fields` | `fields` solo aparece cuando se envía |
| CON-03 | HU-30 | S3-13 | `HttpError` sin `code` | Código por defecto según el estado |
| CON-04 | HU-30 | S3-13 | Tabla de códigos de este documento | Coincide con `ERROR_CODES` en Node |
| CON-05 | HU-30 | S3-07 | Registro válido | `201`, `role: "user"`, sin `password` en la respuesta |
| CON-06 | HU-30 | S3-07 | Registro con `role: "accountant"` | `201` con `role: "user"` |
| CON-07 | HU-30 | S3-07 | Nombre vacío, correo inválido y contraseña de 7 caracteres a la vez | `400 VALIDATION_FAILED` con los tres campos en `fields` |
| CON-08 | HU-30 | S3-07 | Contraseña de 8 sin números y otra de 73 | `400` con el mensaje de cada regla |
| CON-09 | HU-30 | S3-07 | Mismo correo con mayúsculas y espacios | `409 EMAIL_TAKEN` |
| CON-10 | HU-30 | S3-08 | Revisar la base después de un registro | La contraseña no está en texto plano |
| CON-11 | HU-31 | S3-09 | Login con credenciales correctas | `200` con `accessToken`, `tokenType`, `expiresIn` y `user` |
| CON-12 | HU-31 | S3-09 | Login con correo inexistente y con contraseña incorrecta | Las dos `401 INVALID_CREDENTIALS` con el mismo cuerpo |
| CON-13 | HU-31 | S3-09 | Login sin `password` | `400 VALIDATION_FAILED` con `fields.password` |
| CON-14 | HU-31 | S3-09 | `GET /api/auth/me` con token válido, sin token y con token alterado | `200`, `401`, `401` |
| CON-15 | HU-31 | S3-10, S3-11 | Respuestas `400`, `401`, `409` y sin red en Flutter | Cada una muestra el mensaje de la tabla y ningún dato privado |
| CON-16 | HU-33 | S4-02 | Logout y luego `GET /api/auth/me` con el mismo token | `204` y después `401` |
| CON-17 | HU-32 | S4-19 | `recover` con un correo que tiene cuenta y con uno que no | Las dos `200` con el mismo cuerpo; solo se envía correo a la cuenta que existe |
| CON-18 | HU-32 | S4-19 | `recover` sin correo o con un correo mal formado | `400 VALIDATION_FAILED` con `fields.email` |
| CON-19 | HU-32 | S4-19 | `reset` con el código correcto y luego login con la contraseña nueva y con la anterior | `204`; login nuevo `200`, login anterior `401 INVALID_CREDENTIALS` |
| CON-20 | HU-32, HU-34 | S4-19 | `GET /api/auth/me` con un token abierto antes del `reset` | `401 UNAUTHENTICATED`: todas las sesiones quedaron cerradas |
| CON-21 | HU-32 | S4-19 | El mismo código dos veces | El segundo `400` con `fields.code` |
| CON-22 | HU-32 | S4-19 | El código correcto 15 minutos después de pedirlo | `400` con `fields.code` |
| CON-23 | HU-32 | S4-19 | 5 códigos incorrectos y después el correcto | Los cinco `400`; el sexto `429 TOO_MANY_ATTEMPTS` y la contraseña no cambia |
| CON-24 | HU-32 | S4-19 | Pedir dos códigos y usar el primero | `400` con `fields.code`; el segundo sí funciona |
| CON-25 | HU-32 | S4-19 | `reset` con correo sin cuenta, y con código `12a4` y contraseña de 7 caracteres | El primero `400` igual que un código incorrecto; el segundo `400` con `fields.code` y `fields.password` |
| CON-26 | HU-32 | S4-19 | Revisar respuestas, base y consola después de `recover` y `reset` | El código y la contraseña no aparecen en respuestas; en la base solo hay hashes; en `production` el código no sale en la consola |
| CON-27 | HU-32 | S4-20 | Respuestas `200`, `204`, `400`, `429` y sin red en las pantallas de recuperación de Flutter | Cada una muestra el mensaje de la tabla y ningún dato privado |
| CON-28 | HU-32 | S4-19 | `recover` dos veces en menos de un minuto para la misma cuenta, y otra vez pasado el minuto | Las tres `200` con el mismo cuerpo; solo se envían dos correos; el primer código sigue valiendo hasta que llega el segundo |

## 6. Revisión

El criterio de la tarjeta pide que Flutter y Node revisen el contrato. El PR de S3-13 tiene como revisores a Francisco (Node, S3-07 a S3-09) y Janetthe (Flutter, S3-10 a S3-12). Sus observaciones se atienden en este documento antes de que empiecen esas tarjetas.
