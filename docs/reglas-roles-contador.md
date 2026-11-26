# Reglas de roles y consentimiento del contador

**Tarjeta:** S3-14 · [#62](https://github.com/JanettheMillan/KoPay/issues/62). **Historias:** HU-37 a HU-42.
**Base:** [navegacion-usuario-contador.md](navegacion-usuario-contador.md) (pantallas) y [contrato-api-acceso.md](contrato-api-acceso.md) (formato de respuestas y errores).

Este documento responde tres preguntas: **quién autoriza**, **qué puede consultar** el contador y **cómo se revoca**. Las reglas valen para el servidor: Flutter oculta lo que no corresponde, pero la API es la que decide en cada petición.

Lo implementan:
- S3-06: el esquema de la relación.
- S4-04: el middleware de roles.
- S4-05: conceder y revocar.
- S4-06: las consultas del contador.
- S4-11, S4-12 y S5-12: las pantallas.

## 1. Roles

| Rol (`user.role`) | Cómo se obtiene | Para qué sirve |
| :--- | :--- | :--- |
| `user` | Al crear una cuenta desde la app (`POST /api/auth/register`). Es el único rol que se obtiene así. | Manejar sus propias finanzas y decidir qué contador las ve. |
| `accountant` | Lo da de alta el equipo con el script de semilla de la base (S3-05/S3-06), nunca desde la app ni desde la API. | Consultar, en solo lectura, las finanzas de quien lo autorizó. |

- Una cuenta tiene **un solo rol** y no cambia. Si una persona necesita ambas cosas, usa dos cuentas con correos distintos.
- El rol se lee **de la base en cada petición**, a partir de la sesión. No se confía en un rol que mande la app.
- Una cuenta `accountant` **no tiene finanzas propias**. Las rutas financieras del usuario (movimientos, ingresos, tarjetas, deudas y pagos) le responden `403 FORBIDDEN`.

## 2. Quién autoriza

1. **Solo la persona dueña de los datos** puede autorizar a un contador sobre sus propias finanzas. Nadie autoriza en nombre de otra cuenta, y el contador no puede solicitarse acceso a sí mismo.
2. La autorización es para **un contador específico**, identificado por su correo. Si el correo no corresponde a una cuenta `accountant`, la API responde `404 NOT_FOUND` ("No hay un contador con ese correo") y no se crea nada.
3. **El consentimiento es explícito.** Flutter muestra el diálogo de la sección "Consentimiento" de la navegación, con quién, qué ve, que es de solo lectura y que se puede revocar. Solo al tocar **Confirmar** se llama a la API. Cancelar no envía nada.
4. Una persona puede autorizar a varios contadores, y un contador puede tener varios clientes.
5. Autorizar a un contador que ya tiene un permiso vigente **no crea un duplicado**: la API responde `200` con el permiso existente.

## 3. Qué puede consultar el contador

Con un permiso vigente, el contador puede **leer** de esa persona, por mes:

| Dato | Puede verlo | Detalle |
| :--- | :---: | :--- |
| Nombre y correo de la persona | Sí | En la lista de clientes, con la fecha de autorización. |
| Resumen del mes: balance, ingresos, gastos y pagos | Sí | Mismos cálculos que Inicio (HU-09, HU-40). |
| Movimientos del mes, incluidos los pagos | Sí | Solo lectura (HU-40). |
| Ingresos del mes | Sí | Solo lectura (HU-40). |
| Tarjetas y deudas (límites, saldos, vencimientos) | No | Fuera del permiso en esta versión. Para agregarlo hay que cambiar este documento y el diálogo de consentimiento. |
| Contraseña, sesiones, ajustes, respaldo, otros contadores autorizados | No | Nunca. |

**Solo lectura (HU-42):**
- El contador no puede crear, modificar ni borrar movimientos, ingresos, tarjetas, deudas o pagos de otra persona.
- Bajo `/api/clients` no hay rutas de escritura. Las rutas financieras del usuario responden `403` a una cuenta `accountant`, aunque mande el identificador de otra persona en la URL o en el cuerpo.

## 4. Cómo se revoca

1. La persona usuaria revoca desde Ajustes, en Contadores autorizados, y confirma en un diálogo (HU-41). Puede hacerlo en cualquier momento y sin dar motivo.
2. La revocación tiene **efecto inmediato**: la siguiente petición del contador sobre esa persona responde `403 FORBIDDEN`. El servidor no guarda en caché el permiso, sino que lo consulta en cada petición.
3. El contador deja de ver a la persona en su lista. Si tenía abierta su pantalla, Flutter muestra el aviso de acceso retirado y regresa a la lista.
4. Revocar **no borra nada** de la persona, ni lo que el contador ya vio antes. Solo detiene las consultas nuevas.
5. Para volver a dar acceso, la persona autoriza otra vez y se crea un permiso nuevo. El revocado se conserva con su fecha, como historial.
6. El contador **no puede revocar** un permiso, pero sí dejar de usarlo. Si la cuenta del contador o la de la persona se elimina, sus permisos quedan revocados.

## 5. Comprobación en el servidor

Cada petición del contador a `/api/clients/:userId/...` pasa por tres pasos, en este orden:

| Paso | Si falla | Tarjeta |
| :--- | :--- | :--- |
| 1. La sesión es válida | `401 UNAUTHENTICATED` | S4-01 |
| 2. El rol de la sesión es `accountant` | `403 FORBIDDEN` | S4-04 |
| 3. Existe un permiso **vigente** entre `:userId` y ese contador | `403 FORBIDDEN` | S4-06 |

- En el paso 3, un `:userId` que no existe responde **igual que uno sin permiso** (`403`, no `404`). Así, cambiar el número en la URL no permite averiguar qué cuentas existen (HU-34).
- Los datos se filtran **siempre** por `owner = :userId` y por el mes pedido. Nunca se arma la consulta con un identificador que venga del cuerpo.
- El mensaje de `403` es el mismo en los dos casos: "No tienes acceso a los datos de esta persona".

## 6. Esquema para S3-06

Tabla `accountant_access` (nombre acordado en [base-de-datos.md](base-de-datos.md), S3-04):

| Columna | Tipo | Regla |
| :--- | :--- | :--- |
| `id` | `uuid`, PK, `gen_random_uuid()` | |
| `user_id` | `uuid`, FK a `users.id`, `ON DELETE CASCADE` | La persona que autoriza. Su rol debe ser `user`. |
| `accountant_id` | `uuid`, FK a `users.id`, `ON DELETE CASCADE` | El contador autorizado. Su rol debe ser `accountant`. |
| `granted_at` | `timestamptz` | Se fija al confirmar. |
| `revoked_at` | `timestamptz`, nula | Nula mientras el permiso está vigente. |

- `CHECK (user_id <> accountant_id)`.
- Índice único parcial sobre `(user_id, accountant_id)` donde `revoked_at IS NULL`: solo puede haber un permiso vigente por pareja.
- "Vigente" significa `revoked_at IS NULL`. Los permisos no vencen solos.
- La comprobación de roles al insertar la hace el servicio de S4-05, porque PostgreSQL no puede expresarla con un `CHECK` entre tablas.

## 7. Rutas propuestas para S4-05 y S4-06

Usan el formato de errores del contrato. Las tarjetas las cierran en [contrato-api-acceso.md](contrato-api-acceso.md) al implementarlas.

| Método y ruta | Rol | Éxito | Errores propios |
| :--- | :--- | :--- | :--- |
| `GET /api/accountants` | `user` | `200 { grants: [{ id, accountant: { id, name, email }, grantedAt }] }`, solo vigentes | — |
| `POST /api/accountants` `{ accountantEmail }` | `user` | `201 { grant }`, o `200` si ya estaba vigente | `400 VALIDATION_FAILED`, `404 NOT_FOUND` |
| `DELETE /api/accountants/:grantId` | `user`, dueño del permiso | `204` | `404 NOT_FOUND` si el permiso no es suyo o ya estaba revocado |
| `GET /api/clients` | `accountant` | `200 { clients: [{ id, name, email, grantedAt }] }`, solo vigentes | — |
| `GET /api/clients/:userId/summary?month=AAAA-MM` | `accountant` con permiso | `200 { month, balance, income, expenses, payments }` | `400` si el mes es inválido, `403` |
| `GET /api/clients/:userId/movements?month=AAAA-MM` | `accountant` con permiso | `200 { movements: [...], incomes: [...] }` | `400`, `403` |

## 8. Casos de prueba

Los automatiza la tarjeta indicada, con el identificador en el nombre de la prueba. QA los toma en S3-16 (casos unitarios), S4-17 (RBAC y aislamiento) y S5-14.

| Caso | Historia | Tarjeta | Qué se hace | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- |
| ROL-01 | HU-37 | S4-04 | Una cuenta `accountant` llama a una ruta financiera del usuario | `403 FORBIDDEN` |
| ROL-02 | HU-37 | S3-07 | Un registro envía `role: "accountant"` | La cuenta queda como `user` (CON-06) |
| ROL-03 | HU-38 | S4-05 | Se autoriza un correo que no es de contador, o que no existe | `404` y no se crea permiso |
| ROL-04 | HU-38 | S4-05 | Se autoriza dos veces al mismo contador | Un solo permiso vigente; la segunda respuesta es `200` |
| ROL-05 | HU-38 | S4-11 | Se cancela el diálogo de consentimiento | No se llama a la API ni se crea el permiso |
| ROL-06 | HU-39 | S4-06 | El contador A pide la lista de clientes | Solo las personas que autorizaron a A y siguen vigentes |
| ROL-07 | HU-40 | S4-06 | El contador pide el resumen y los movimientos de un mes | Solo datos de esa persona y de ese mes |
| ROL-08 | HU-34 | S4-06 | El contador cambia `:userId` por el de una persona que no lo autorizó, o por uno inexistente | `403` en ambos casos, con el mismo cuerpo |
| ROL-09 | HU-41 | S4-05, S4-06 | Se revoca y el contador repite la consulta | `403` y la persona ya no aparece en su lista |
| ROL-10 | HU-41 | S4-05 | Se revoca y se vuelve a autorizar | Hay un permiso nuevo y el revocado conserva su `revoked_at` |
| ROL-11 | HU-42 | S4-04, S4-06 | El contador intenta `POST`, `PUT` o `DELETE` sobre datos de un cliente | `403` o ruta inexistente; los datos no cambian |
| ROL-12 | HU-41 | S4-05 | Una persona intenta revocar el permiso de otra | `404` y el permiso sigue vigente |
| ROL-13 | HU-38 | S3-06 | Insertar en la base dos permisos vigentes para la misma pareja, o `user_id = accountant_id` | La base lo rechaza |
