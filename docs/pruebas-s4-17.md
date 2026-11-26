# Pruebas de roles y aislamiento de cuentas

**Tarjeta:** S4-17 · [#83](https://github.com/JanettheMillan/KoPay/issues/83). **Historias:** HU-34 y HU-37 a HU-41.
**Base:** [reglas-roles-contador.md](reglas-roles-contador.md).

## 1. Cómo se prueba

Los casos recorren la API completa con registro, inicio de sesión y token reales. Se definen una vez en `backend/test/helpers/rbac-isolation-cases.js` y se ejecutan dos veces:

| Almacén | Archivo | Comando (en `backend/`) |
| :--- | :--- | :--- |
| Memoria | `backend/test/rbac-isolation.test.js` | `npm test` |
| PostgreSQL, el que usa `server.js` | `backend/test/db/rbac-isolation.test.js` | `npm run test:db` |

Cuentas de prueba: Ana y Beto son usuarios. Ana autoriza a la contadora Carla y Beto al contador Dani. Así Dani tiene un cliente, pero no tiene permiso sobre Ana.

## 2. Matriz de acceso (AIS-01 · HU-34, HU-37)

Estado HTTP esperado. En cada celda se comprueba además que el permiso de Ana no cambió; con `401` y `403`, que el error no traiga datos.

| Petición | Sin sesión | Ana (dueña) | Beto (otro usuario) | Carla (con permiso) | Dani (sin permiso) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `GET /api/accountants` | 401 | 200 | 200 | 403 | 403 |
| `DELETE` del permiso de Ana | 401 | FUT-30 | 404 | 403 | 403 |
| `GET /api/clients` | 401 | 403 | 403 | 200 | 200 |
| `GET /api/clients/:ana` | 401 | 403 | 403 | 200 | 403 |
| `POST`, `PUT`, `PATCH` y `DELETE /api/clients/:ana` | 401 | 403 | 403 | 403 | 403 |

Son 39 casos. La revocación que hace Ana, la dueña, se prueba en FUT-30.

## 3. Aislamiento y revocación

| Caso | Historia | Qué se hace | Resultado esperado |
| :--- | :--- | :--- | :--- |
| AIS-02 | HU-39 | Cada contador pide su lista | Solo su cliente, con `id`, `name`, `email` y `grantedAt` |
| AIS-03 | HU-34 | Cada usuario pide sus permisos | Solo los suyos |
| AIS-04 | HU-34 | Se manda el `userId` de otra persona en la consulta y el cuerpo | No cambia la cuenta consultada |
| FUT-22 | HU-38 | Se consulta con la relación vigente, revocada y vuelta a autorizar | Solo la vigente permite consultar |
| FUT-30 | HU-41 | Se revoca y el contador repite la consulta con la misma sesión | `403`; la sesión sigue válida y la lista queda vacía |
| AIS-05 | HU-41 | Se revoca una pareja usuario y contador | Las demás no cambian |

## 4. Casos de las reglas (sección 8)

| Caso | Dónde se prueba |
| :--- | :--- |
| ROL-01 | `rbac.test.js`, con rutas financieras de ejemplo |
| ROL-02 | CON-06 en `register.test.js` |
| ROL-03, ROL-04, ROL-10, ROL-12 | `accountants.test.js` |
| ROL-06, ROL-08 | `clients.test.js` |
| ROL-09 | `accountants.test.js` y `clients.test.js` |
| ROL-11 | `rbac.test.js` y `clients.test.js` |
| ROL-13 | DB-03 en `db/migrations.test.js` |
| ROL-05 | **Sin ejecutar:** es el diálogo de consentimiento (S4-11) |
| ROL-07 | **Sin ejecutar:** las consultas de resumen y movimientos son de S5-03 |

## 5. Resultado

| Dato | Valor |
| :--- | :--- |
| Fecha | 26 de noviembre de 2026 |
| Versión | `develop` en `6212619` (incluye S4-02), más las pruebas de esta tarjeta |
| Equipo | Windows 11, Node 22.20.0, PostgreSQL 17.11 en una base local temporal |

| Ejecución | Resultado |
| :--- | :--- |
| `npx jest test/rbac-isolation.test.js` | 45 aprobadas, 0 fallidas |
| `npx jest --config jest.db.config.js --runInBand test/db/rbac-isolation` | 45 aprobadas, 0 fallidas |
| `npx jest` | 263 aprobadas, 0 fallidas. Incluye los 4 fallos conocidos de AUT-03 (D-07, [#183](https://github.com/JanettheMillan/KoPay/issues/183)) |
| `npx jest --config jest.db.config.js --runInBand` (con `NODE_ENV=test`) | 73 aprobadas, 0 fallidas |
| `flutter test` | 345 aprobadas, 0 fallidas, 4 omitidas |
| `flutter analyze` | 0 errores, 0 advertencias, 54 avisos informativos |

El README del backend indica PostgreSQL 16; esta ejecución usó la 17.

### Comprobación de que las pruebas detectan fallos

Se introdujo cada defecto de forma temporal, se ejecutaron los 45 casos y se restauró el código. Esta comprobación se hizo sobre `9ca8249`, antes de integrar S4-02.

| Defecto introducido | Almacén | Casos que fallaron |
| :--- | :--- | :---: |
| La consulta del permiso no descarta los revocados | PostgreSQL | 3 |
| La consulta del permiso no compara el contador | PostgreSQL | 3 |
| Sin protección de solo lectura, y el permiso solo se revisa en `GET` | Memoria | 8 |

No se encontraron defectos nuevos.

## 6. Fuera del alcance actual

- **Datos financieros:** `develop` no tiene todavía rutas de movimientos, ingresos, tarjetas, deudas ni pagos (S4-03 y S5). El aislamiento de esos datos queda pendiente.
- **Pantallas:** no se probó la navegación por rol ni el consentimiento en Flutter.
