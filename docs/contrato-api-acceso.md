# Contrato de la API: registro, inicio de sesión y errores

**Tarjeta:** S3-13 · [#61](https://github.com/JanettheMillan/KoPay/issues/61). **Historias:** HU-30 (crear cuenta) y HU-31 (iniciar sesión).
**Base:** [arquitectura.md](arquitectura.md), sección 6, y [navegacion-usuario-contador.md](navegacion-usuario-contador.md), sección 2.

Este documento fija lo que la API Node.js recibe y responde en el registro y el inicio de sesión, y la forma de **todos** los errores de la API. Node (S3-07, S3-08, S3-09, S4-01, S4-02) lo implementa y Flutter (S3-10, S3-11, S3-12, S4-07, S4-08) lo consume. Si una tarjeta necesita cambiarlo, el cambio se hace primero aquí, en un PR propio, y se avisa a ambos lados.

La forma de los errores (sección 2) ya está implementada en `backend/src/errors.js` y `backend/src/middleware/errors.js`. Las rutas de la sección 3 todavía no existen: las crean las tarjetas indicadas en cada una.

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
| 429 | `TOO_MANY_ATTEMPTS` | Reservado: demasiados intentos de login. Se implementa cuando se autorice la librería. | Muestra `error` y desactiva el botón un momento. |
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

- `accessToken` es **opaco** para Flutter: lo guarda y lo envía, pero no lo lee. En el Sprint 3 puede ser un token de la tabla de sesiones (S3-05); en el Sprint 4 S4-01 lo cambia por un JWT sin cambiar esta respuesta.
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

## 4. Resumen de rutas

| Método y ruta | Sesión | Tarjeta | Éxito | Errores propios |
| :--- | :---: | :--- | :--- | :--- |
| `POST /api/auth/register` | No | S3-07 | `201 { user }` | `VALIDATION_FAILED`, `EMAIL_TAKEN` |
| `POST /api/auth/login` | No | S3-09 | `200 { accessToken, tokenType, expiresIn, user }` | `VALIDATION_FAILED`, `INVALID_CREDENTIALS` |
| `GET /api/auth/me` | Sí | S3-09 | `200 { user }` | `UNAUTHENTICATED` |
| `POST /api/auth/logout` | Sí | S4-02 | `204` | — |
| `POST /api/auth/refresh` | No | S4-02 | `200` igual que login | `UNAUTHENTICATED` |

## 5. Casos de prueba del contrato

Los casos CON-01 a CON-04 ya se ejecutan en `backend/test/contract.test.js`. Los demás los automatiza la tarjeta que crea cada ruta, con el mismo identificador en el nombre de la prueba, y QA los toma en S3-16 y S3-18.

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

## 6. Revisión

El criterio de la tarjeta pide que Flutter y Node revisen el contrato. El PR de S3-13 tiene como revisores a Francisco (Node, S3-07 a S3-09) y Janetthe (Flutter, S3-10 a S3-12). Sus observaciones se atienden en este documento antes de que empiecen esas tarjetas.
