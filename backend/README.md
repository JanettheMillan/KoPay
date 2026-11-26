# KoPay API

API Node.js de KoPay (Express 5). Expone la ruta de salud, el registro de cuentas y el inicio de sesión. La sincronización se agrega en tarjetas siguientes.

**Tarjetas:** S3-01 (estructura), S3-02 (ambientes y secretos), S3-03 (esta guía), S3-05 (PostgreSQL y migraciones), S3-07 (registro), S3-08 (credenciales), S3-09 (login), S4-01 (JWT y PostgreSQL en `npm start`), S4-02 (renovar y cerrar sesión), S4-19 (recuperación de acceso).

## 1. Requisitos

- Node.js 20 o más reciente (`node -v`).
- npm, que viene con Node (`npm -v`).
- `npm start` guarda cuentas, sesiones y permisos en PostgreSQL (`DATABASE_URL`, S4-01): ya no se pierden al reiniciar. Antes de arrancar por primera vez, corre `npm run migrate`. Sin base, la API arranca pero responde 503.
- Para `npm run migrate` y `npm run test:db`: PostgreSQL 16 en `DATABASE_URL` (S3-05). Acuerdos en [`docs/base-de-datos.md`](../docs/base-de-datos.md).

### PostgreSQL local con Docker

Una sola vez:

```bash
docker run -d --name kopay-pg -e POSTGRES_USER=kopay -e POSTGRES_PASSWORD=kopay \
  -e POSTGRES_DB=kopay_test -p 5432:5432 postgres:16
docker exec kopay-pg psql -U kopay -d kopay_test -c "CREATE DATABASE kopay;"
```

Después pon en `backend/.env` la línea `DATABASE_URL=postgres://kopay:kopay@localhost:5432/kopay` y crea las tablas:

```bash
npm run migrate      # aplica las migraciones pendientes; correrlo otra vez no hace nada
```

Para usar el branch `dev` de Neon, cambia solo `DATABASE_URL`. La cadena se comparte por mensaje privado, nunca en el repositorio.

## 2. Iniciar el servicio en local

Desde la raíz del repositorio:

```bash
cd backend
npm ci          # instala exactamente las versiones de package-lock.json
npm start       # o `npm run dev` para reiniciar al guardar cambios
```

Debe aparecer:

```
KoPay API (development) en http://localhost:3000
Configuración: {
  env: 'development',
  port: 3000,
  corsOrigin: '*',
  databaseUrl: 'definida',
  jwtSecret: 'definido',
  banxicoToken: 'sin definir'
}
```

Los secretos nunca se muestran: solo dice si están definidos.

Para el tipo de cambio (`GET /api/exchange-rates`, S5-06) necesitas tu propio token de Banxico, que es gratis: pídelo en <https://www.banxico.org.mx/SieAPIRest/service/v1/token> y ponlo en `BANXICO_TOKEN` de tu `.env`. Sin token, esa ruta responde `503` y lo demás funciona igual. No compartas tu token en el grupo ni lo subas.

En desarrollo no hace falta un `.env`. Para cambiar algo, por ejemplo el puerto:

```bash
cp .env.example .env    # .env nunca se sube; git lo ignora
# edita PORT=3001 en .env
npm start
```

También se puede pasar en la misma línea: `PORT=3001 npm start`.

## 3. Comprobar que responde

Con el servicio corriendo, en otra terminal:

```bash
curl -i http://localhost:3000/api/health
```

Respuesta esperada (200):

```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{"status":"ok","service":"kopay-api","version":"0.1.0","environment":"development","data":{"kind":"postgres","ok":true},"timestamp":"2026-11-26T15:00:00.000Z"}
```

Sin `curl`, abre `http://localhost:3000/api/health` en el navegador. Desde un emulador Android, la computadora se ve como `http://10.0.2.2:3000`.

Para detenerlo: `Ctrl + C` en la terminal del servicio.

## 4. Contrato de salud

`GET /api/health`, sin autenticación ni cuerpo.

| Código | Cuándo |
| :--- | :--- |
| `200` | El servicio y la capa de datos responden. |
| `503` | El servicio responde, pero la capa de datos no. |

Cuerpo JSON, igual en los dos casos:

| Campo | Tipo | Valor |
| :--- | :--- | :--- |
| `status` | texto | `"ok"` con 200, `"error"` con 503. |
| `service` | texto | Siempre `"kopay-api"`. |
| `version` | texto | Versión de `package.json`, por ejemplo `"0.1.0"`. |
| `environment` | texto | `"development"`, `"test"` o `"production"`. |
| `data.kind` | texto | Tipo de capa de datos: `"postgres"` con `npm start`; `"memory"` en pruebas con configuración manual. |
| `data.ok` | booleano | `true` si la capa de datos respondió. |
| `timestamp` | texto | Fecha y hora del servidor en ISO 8601 (UTC). |

La respuesta nunca incluye secretos, `DATABASE_URL` ni detalles internos. Quien la consuma (la app, un monitor o el servicio de despliegue) debe decidir con el **código HTTP** y con `status`. Los demás campos son informativos y se pueden agregar nuevos sin romper el contrato.

### Otras respuestas generales

| Caso | Código | Cuerpo |
| :--- | :--- | :--- |
| Ruta que no existe | `404` | `{"error":"Ruta no encontrada","code":"NOT_FOUND"}` |
| JSON mal formado | `400` | `{"error":"JSON inválido","code":"INVALID_JSON"}` |
| Cuerpo de más de 100 KB | `413` | `{"error":"Los datos enviados son demasiado grandes","code":"PAYLOAD_TOO_LARGE"}` |
| Error inesperado | `500` | `{"error":"Error interno del servidor","code":"INTERNAL"}` |

Todos los errores tienen la forma `{ error, code, fields? }`. La lista de códigos y las rutas de registro e inicio de sesión están en [`docs/contrato-api-acceso.md`](../docs/contrato-api-acceso.md) (S3-13).

### Registro de cuenta (S3-07)

`POST /api/auth/register` con `{ "name", "email", "password" }`. Responde `201 { user }` sin abrir sesión, `400 VALIDATION_FAILED` con `fields` o `409 EMAIL_TAKEN`. Las reglas están en la sección 3.1 del contrato.

```bash
curl -i -X POST http://localhost:3000/api/auth/register   -H "Content-Type: application/json"   -d '{"name":"Ana López","email":"ana@mail.com","password":"kopay2026"}'
```

Las cuentas se guardan en PostgreSQL y se conservan al reiniciar el servicio. El `accessToken` es un JWT HS256 firmado con `JWT_SECRET` que vence en 15 minutos; cada uno tiene su sesión en la base (solo el hash), así que cerrar sesión (S4-02) lo invalida aunque la firma siga vigente.

La contraseña nunca se guarda en texto plano (S3-08): se guarda su hash con `scrypt`, que viene en Node, con una sal aleatoria por cuenta, en el formato `scrypt$N$r$p$sal$hash` (`src/services/password.service.js`). Al entrar se compara en tiempo constante. Si el correo no existe, también se compara contra un hash de relleno para que la respuesta tarde lo mismo.

### Inicio de sesión (S3-09)

`POST /api/auth/login` con `{ "email", "password" }` responde `200 { accessToken, tokenType, expiresIn, refreshToken, refreshExpiresIn, user }`. Si el correo no existe o la contraseña no coincide, responde siempre lo mismo: `401 INVALID_CREDENTIALS`. Si falta un campo, `400 VALIDATION_FAILED`.

`GET /api/auth/me` con `Authorization: Bearer <accessToken>` responde `200 { user }`, o `401 UNAUTHENTICATED` sin token, con un token inválido o con uno vencido.

```bash
curl -s -X POST http://localhost:3000/api/auth/login   -H "Content-Type: application/json"   -d '{"email":"ana@mail.com","password":"kopay2026"}'
curl -i http://localhost:3000/api/auth/me -H "Authorization: Bearer <accessToken>"
```

El `accessToken` es un JWT HS256 que vence a los 900 segundos (S4-01) y el `refreshToken` es texto aleatorio que vence a los 30 días (S4-02). De los dos solo se guarda el hash SHA-256 (`token_hash` y `refresh_token_hash` de la tabla `sessions`). El middleware `src/middleware/authenticate.js` deja `req.auth.userId` para el control de roles (S4-04).

### Renovar y cerrar sesión (S4-02)

- `POST /api/auth/refresh` con `{ "refreshToken" }` responde `200` igual que el login, con tokens **nuevos**. El `refreshToken` usado y el `accessToken` anterior dejan de servir (rotación). Uno inválido, vencido, ya usado o de una sesión cerrada responde `401 UNAUTHENTICATED`.
- `POST /api/auth/logout` con `Authorization: Bearer <accessToken>` responde `204` y cierra solo esa sesión. Sin token o con uno inválido también responde `204`.

```bash
curl -s -X POST http://localhost:3000/api/auth/refresh -H "Content-Type: application/json" -d '{"refreshToken":"<refreshToken>"}'
curl -i -X POST http://localhost:3000/api/auth/logout -H "Authorization: Bearer <accessToken>"
```

Después de actualizar `develop`, corre `npm run migrate`: S4-02 agrega la migración `004_session_refresh.sql`.

### Rutas financieras protegidas (S4-03)

`/api/movements`, `/api/incomes`, `/api/cards` y `/api/debts` pasan, en orden, por:

1. Sesión válida: sin token o con uno inválido, `401 UNAUTHENTICATED`.
2. Rol `user` (`rbac.ownFinances()`): una cuenta `accountant` recibe `403 FORBIDDEN`, porque el contador no tiene finanzas propias.
3. `bindOwner` (`src/middleware/owner.js`): deja `req.ownerId` con el id de la sesión y borra cualquier `userId`, `user_id`, `ownerId` u `owner_id` del cuerpo y la consulta. El dueño **nunca** sale de la petición.

Las rutas de cada recurso se agregan en S5-01 a S5-05 con `createApp({ financeRegistrars: { movements: (router) => { … } } })`. Para leer, editar o borrar un registro por id se usa `ensureOwned(row, req.ownerId)`: si no existe o es de otra cuenta responde `404 NOT_FOUND` "No encontramos ese registro", igual en los dos casos. Mientras un recurso no tenga rutas, una cuenta `user` recibe `404`.

### Movimientos (S5-01)

`/api/movements` es la primera ruta financiera, detrás de la protección de S4-03. El detalle está en la sección 3.12 del contrato.

- `GET /api/movements` (opcional `?month=AAAA-MM`), `GET /api/movements/:id`, `POST`, `PUT /:id` y `DELETE /:id`.
- El monto lleva signo: negativo es gasto, positivo es entrada. Se guarda en `numeric(14,2)`.
- `PUT` acepta `version`: si ya cambió en otro dispositivo, responde `409 VERSION_CONFLICT`.
- Un registro de otra cuenta responde `404`, igual que uno que no existe.
- Los pagos se leen aquí, pero se manejan desde su tarjeta o deuda (S5-05).

```bash
curl -s -X POST http://localhost:3000/api/movements -H "Authorization: Bearer <accessToken>" \
  -H "Content-Type: application/json" -d '{"amount":-50,"description":"Café","category":"Comida","date":"2026-11-26"}'
```

Después de actualizar `develop`, corre `npm run migrate`: S5-01 agrega `005_movements.sql`.

### Ingresos (S5-02)

`/api/incomes` sigue el mismo patrón que movimientos. El detalle está en la sección 3.13 del contrato.

- `GET /api/incomes` (opcional `?month=AAAA-MM`), `GET /api/incomes/:id`, `POST`, `PUT /:id` y `DELETE /:id`.
- Un ingreso tiene `name`, `amount` (siempre mayor que cero), `date` y `note`. No lleva categoría.
- `PUT` acepta `version` y responde `409 VERSION_CONFLICT` si ya cambió en otro dispositivo.

```bash
curl -s -X POST http://localhost:3000/api/incomes -H "Authorization: Bearer <accessToken>" \
  -H "Content-Type: application/json" -d '{"name":"Nómina","amount":12500,"date":"2026-11-15"}'
```

Después de actualizar `develop`, corre `npm run migrate`: S5-02 agrega `006_incomes.sql`.

### Consultas del contador (S5-03)

Un contador con permiso vigente lee el mes de quien lo autorizó, solo lectura. Detalle en la sección 3.10 del contrato.

- `GET /api/clients/:userId/summary?month=AAAA-MM`: `{ month, income, expenses, payments, balance }`, con los pagos aparte como en Inicio.
- `GET /api/clients/:userId/movements?month=AAAA-MM`: `{ movements, incomes }` de ese mes.
- Sin permiso, revocado o con un id que no existe: `403` igual. Al revocar, la siguiente consulta ya responde `403`.

No agrega migraciones.

### Límite de intentos del login (S4-13)

Después de 10 intentos fallidos con el mismo correo en 15 minutos, `POST /api/auth/login` responde `429 TOO_MANY_ATTEMPTS`, aunque la contraseña sea correcta, hasta que pase la ventana. Un login correcto reinicia el contador. El contador vive en memoria (`src/services/login-throttle.js`): se reinicia con la API. Revisión completa en `docs/revision-seguridad-s4-13.md`.

### Recuperación de acceso (S4-19)

1. `POST /api/auth/recover` con `{ "email" }` responde siempre `200 { message }`, exista o no la cuenta. Si existe, envía por correo un código de 6 dígitos que vence en 15 minutos. Como máximo un correo por minuto por cuenta: antes de ese minuto responde igual, pero no envía otro.
2. `POST /api/auth/reset` con `{ "email", "code", "password" }` responde `204`. Cambia la contraseña y cierra todas las sesiones de la cuenta. Un código incorrecto, vencido o usado responde `400` con `fields.code`; después de 5 intentos fallidos, `429 TOO_MANY_ATTEMPTS`.

En `development` y `test` no se envía ningún correo: el código sale en la consola del servicio.

```bash
curl -s -X POST http://localhost:3000/api/auth/recover \
  -H "Content-Type: application/json" -d '{"email":"ana@mail.com"}'
# En la consola: [correo de prueba, no se envió] Código de recuperación para ana@mail.com: 048213
curl -i -X POST http://localhost:3000/api/auth/reset \
  -H "Content-Type: application/json" \
  -d '{"email":"ana@mail.com","code":"048213","password":"nueva2026"}'
```

El código se guarda como HMAC-SHA256 con `JWT_SECRET` (tabla `password_resets`, migración `003`). Reglas completas en las secciones 3.7 a 3.9 del contrato.

## 5. Ambientes

| `NODE_ENV` | Para qué | Necesita `.env` |
| :--- | :--- | :--- |
| `development` (por defecto) | Trabajar en la computadora | No |
| `test` | Pruebas automáticas | No |
| `production` | Servidor real | Sí: `DATABASE_URL`, `JWT_SECRET` (32 caracteres o más, distinto del ejemplo), `CORS_ORIGIN`, `BANXICO_TOKEN` (S5-06), y `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` y `MAIL_FROM` para el correo de recuperación |

En producción, si falta algo, el servicio no arranca y dice qué falta:

```
$ NODE_ENV=production npm start
Configuración de producción incompleta: falta DATABASE_URL; falta JWT_SECRET; falta CORS_ORIGIN; falta SMTP_HOST; falta SMTP_PORT; falta SMTP_USER; falta SMTP_PASS; falta MAIL_FROM; falta BANXICO_TOKEN.
```

Las variables están explicadas en [`.env.example`](.env.example).

## 6. Pruebas

```bash
cd backend
npm test
```

Corre con Jest y supertest, sin abrir puertos fijos ni necesitar base de datos.

Las pruebas de migraciones (`test/db/`) sí necesitan PostgreSQL y **borran el esquema** de la base que reciben, así que solo aceptan una base cuyo nombre contenga `test`:

```bash
DATABASE_URL=postgres://kopay:kopay@localhost:5432/kopay_test npm run test:db
```

## 7. Problemas comunes

| Mensaje | Qué hacer |
| :--- | :--- |
| `EADDRINUSE` | El puerto ya está ocupado. Cierra el otro proceso o usa `PORT=3001 npm start`. |
| `PORT inválido` | `PORT` debe ser un número entero de 0 a 65535. Vacío usa 3000. |
| `NODE_ENV inválido` | Usa `development`, `test` o `production`. |
| `Configuración de producción incompleta` | Define las variables que menciona el mensaje (ver sección 5). |
| `Cannot find module 'express'` | Falta instalar: `npm ci` dentro de `backend/`. |

## 8. Estructura

```
backend/
├── src/
│   ├── server.js         abre el puerto
│   ├── app.js            arma la app de Express (sin puerto, para pruebas)
│   ├── config/           variables de entorno por ambiente
│   ├── routes/           rutas bajo /api
│   ├── services/         lógica (hoy, el estado de salud)
│   ├── data/             capa de datos: PostgreSQL, memoria y migraciones
│   └── middleware/       404 y manejo de errores
├── migrations/           migraciones SQL numeradas (NNN_nombre.sql)
├── scripts/migrate.js    `npm run migrate`
├── test/                 pruebas con Jest y supertest (test/db/ necesita PostgreSQL)
└── .env.example          plantilla de configuración
```
