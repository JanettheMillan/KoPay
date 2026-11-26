# KoPay API

API Node.js de KoPay (Express 5). Por ahora solo expone la ruta de salud. Las cuentas, la sesión y la sincronización se agregan en las siguientes tarjetas del Sprint 3.

**Tarjetas:** S3-01 (estructura), S3-02 (ambientes y secretos), S3-03 (esta guía).

## 1. Requisitos

- Node.js 20 o más reciente (`node -v`).
- npm, que viene con Node (`npm -v`).
- No necesita base de datos todavía: la capa de datos guarda en memoria.

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
  jwtSecret: 'definido'
}
```

Los secretos nunca se muestran: solo dice si están definidos.

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

{"status":"ok","service":"kopay-api","version":"0.1.0","environment":"development","data":{"kind":"memory","ok":true},"timestamp":"2026-11-26T15:00:00.000Z"}
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
| `data.kind` | texto | Tipo de capa de datos; hoy `"memory"`. |
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

## 5. Ambientes

| `NODE_ENV` | Para qué | Necesita `.env` |
| :--- | :--- | :--- |
| `development` (por defecto) | Trabajar en la computadora | No |
| `test` | Pruebas automáticas | No |
| `production` | Servidor real | Sí: `DATABASE_URL`, `JWT_SECRET` (32 caracteres o más, distinto del ejemplo) y `CORS_ORIGIN` |

En producción, si falta algo, el servicio no arranca y dice qué falta:

```
$ NODE_ENV=production npm start
Configuración de producción incompleta: falta DATABASE_URL; falta JWT_SECRET; falta CORS_ORIGIN.
```

Las variables están explicadas en [`.env.example`](.env.example).

## 6. Pruebas

```bash
cd backend
npm test
```

Corre con Jest y supertest, sin abrir puertos fijos ni necesitar base de datos.

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
│   ├── data/             capa de datos (hoy en memoria)
│   └── middleware/       404 y manejo de errores
├── test/                 pruebas con Jest y supertest
└── .env.example          plantilla de configuración
```
