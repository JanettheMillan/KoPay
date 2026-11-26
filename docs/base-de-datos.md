# Base de datos administrada de la API

**Tarjeta:** S3-04 · [#52](https://github.com/JanettheMillan/KoPay/issues/52). **Historias:** HU-34 (proteger mis datos por cuenta) y HU-36 (sincronizar dispositivos).
**Responsable:** Enrique (`EnriqueLanda2`). **Lo usan:** S3-05, S3-06, S3-07 a S3-09, S4-03 a S4-06, S5-01 a S5-05 y S5-19.

Este documento fija cuatro acuerdos: tecnología, conexión, aislamiento por usuario y migraciones. Las tarjetas siguientes los aplican; si alguna necesita cambiarlos, primero se actualiza este documento en su PR.

## 1. Tecnología

| Decisión | Acuerdo | Motivo |
| :--- | :--- | :--- |
| Motor | **PostgreSQL 16** | Ya está en la arquitectura objetivo ([arquitectura.md §6](arquitectura.md)) y en `DATABASE_URL` de S3-02. Tiene transacciones, llaves foráneas, `CHECK` y `numeric` para dinero. |
| Servicio administrado | **Neon** (plan gratuito), región `AWS us-east-1` | No caduca como otros planes gratuitos. Ofrece *branches*, que son copias separadas de la base, una por ambiente, sin pagar otro servidor. Entrega la conexión con TLS y un *pooler* incluido. |
| Alternativa descartada | Supabase | También es PostgreSQL, pero trae su propia autenticación y API REST. KoPay hace eso en Node (S3-07 a S4-06) y no queremos dos fuentes de verdad. |
| Alternativa descartada | Render PostgreSQL | El plan gratuito borra la base a los 30 días; no llega a la entrega del 15 de diciembre. |
| Librería de Node | `pg` (node-postgres) | Se autoriza en S3-05, que es la primera tarjeta que la usa (regla del Sprint 3 en `CLAUDE.md`). Sin ORM: consultas SQL con parámetros (`$1`, `$2`). |

La app Flutter **no** se conecta a PostgreSQL. Habla solo con la API Node. SQLite sigue siendo la base local del teléfono (S1-08).

## 2. Conexión

- La API lee una sola variable: `DATABASE_URL`. La carga `src/config` (S3-02) y nadie más lee `process.env`.
- Formato: `postgres://USUARIO:CONTRASEÑA@HOST/BASE?sslmode=require`. En Neon se usa la cadena **pooled** (el host termina en `-pooler`).
- `DATABASE_URL` es un secreto. Va en `backend/.env` (no se sube) o en las variables del servicio donde se despliegue. En el repositorio solo existe la plantilla `backend/.env.example`.
- El acceso a Neon lo administra el responsable de esta tarjeta. Cada integrante recibe la cadena del branch `dev` por mensaje privado, nunca en un issue, PR ni commit.
- Pool de `pg`: máximo 5 conexiones, `idleTimeoutMillis` 10 s y `connectionTimeoutMillis` 5 s. La capa de datos de PostgreSQL implementa el mismo `ping()` que hoy tiene `createMemoryStore` (`backend/src/data/store.js`). Así, si la base no responde, `GET /api/health` devuelve 503 con `data.ok: false`, sin mostrar la cadena de conexión.

### Un branch por ambiente

| Ambiente (`NODE_ENV`) | Dónde vive la base | Quién la usa |
| :--- | :--- | :--- |
| `development` | PostgreSQL local (`postgres://localhost:5432/kopay`, valor por defecto de S3-02) o branch `dev` de Neon | Cada integrante en su computadora. |
| `test` | PostgreSQL local `kopay_test` (valor por defecto de S3-02) o branch `test` de Neon | `npm test`. Se borra y se vuelve a migrar en cada ejecución. |
| `production` | Branch `main` de Neon | API desplegada y APK de entrega (S5-16). Solo se migra con un PR mergeado. |

Ningún ambiente comparte base con otro. Las pruebas nunca apuntan al branch `main`.

## 3. Aislamiento por usuario (HU-34)

Regla: **cada fila financiera tiene dueño y toda consulta filtra por ese dueño.**

1. Las tablas `movements`, `incomes`, `cards`, `debts`, `payments` y `categories` llevan `user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE`, con un índice que empieza por `user_id`.
2. El `user_id` sale **siempre** de la sesión verificada (JWT, S4-01 y S4-03), nunca del cuerpo, la URL ni la consulta de la petición.
3. Toda consulta de lectura, edición o borrado incluye `WHERE user_id = $1`. Si se pide un id que existe pero es de otra cuenta, la API responde **404**, igual que si no existiera, para no revelar que existe.
4. El contador no es dueño de nada. Solo lee los datos de un cliente si existe una autorización activa en `accountant_access` (S3-06), y solo con `SELECT` (HU-42). Eso se comprueba en el servidor en cada consulta (S4-06), no en Flutter.
5. Los servicios reciben `userId` como primer parámetro (`listMovements(userId, filtros)`). Una función de datos que no lo recibe no puede tocar tablas financieras.

Se descarta por ahora *Row Level Security* de PostgreSQL. Las cinco reglas de arriba se pueden probar con Jest y Supertest. RLS se puede agregar después como segunda barrera sin cambiar el esquema.

### Tablas que crea cada tarjeta

| Tarjeta | Tablas |
| :--- | :--- |
| S3-05 | `users` (correo único, hash de contraseña, rol `user` o `accountant`), `sessions` (refresh token en hash, expiración, revocación). |
| S3-06 | `accountant_access` (usuario, contador, estado `active` o `revoked`, fechas de concesión y revocación). |
| S5-01 a S5-05 | `movements`, `incomes`, `cards`, `debts`, `payments`, `categories`, con las mismas columnas que SQLite ([arquitectura.md §5](arquitectura.md)) más `user_id`, `version` y `updated_at` para la sincronización (HU-36). |

Convenciones: llaves `uuid` con `gen_random_uuid()`; dinero en `numeric(14,2)` con `CHECK (monto >= 0)`; fechas en `timestamptz` guardadas en UTC; nombres en inglés y `snake_case`, igual que SQLite.

## 4. Migraciones

- Viven en `backend/migrations/` como archivos SQL numerados: `001_users_roles_sessions.sql`, `002_accountant_access.sql`, etc.
- Un script `npm run migrate` (S3-05) las aplica en orden, cada una en su propia transacción, y anota el número en la tabla `schema_migrations`. Si una falla, se deshace completa y el script termina con error.
- **Una migración aplicada no se edita.** Para cambiar algo, se agrega una migración nueva.
- Cada migración va en el PR de la tarjeta que la necesita, con su prueba.
- Las pruebas de `npm test` parten de una base vacía: borran el esquema, corren todas las migraciones y después ejecutan los casos.

## 5. Cómo se comprueba

Estos casos se ejecutan en las tarjetas que implementan cada parte. Este documento solo los define.

| Caso | Tarjeta | Qué se hace | Resultado esperado |
| :--- | :--- | :--- | :--- |
| DB-01 · Migración desde cero | S3-05 | En una base `test` vacía, correr `npm run migrate` dos veces. | La primera crea `users`, `sessions` y `schema_migrations`. La segunda no hace nada y no falla. |
| DB-02 · Restricciones | S3-05 | Insertar dos usuarios con el mismo correo y un rol que no existe. | Ambos se rechazan. |
| DB-03 · Conceder y revocar | S3-06 | Conceder acceso a un contador, revocarlo y volver a consultar. | Solo cuenta la autorización activa. |
| DB-04 · Aislamiento | S4-03 y S5-01 | La cuenta A crea un movimiento y la cuenta B lo pide por su id. | B recibe 404 y la fila sigue intacta. |
| DB-05 · Salud sin base | S3-05 | Arrancar la API con una `DATABASE_URL` inalcanzable y pedir `GET /api/health`. | Responde 503 sin mostrar la cadena de conexión. |

## 6. Pendientes fuera del repositorio

- Crear el proyecto de Neon y los branches `dev`, `test` y `main`, y compartir la cadena de `dev`. El responsable lo registra en el issue #52 **sin** pegar la cadena.
- Configurar `DATABASE_URL` de producción en el servicio de despliegue cuando se elija (Sprint 5).
