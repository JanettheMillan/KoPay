# Manual del sistema KoPay

**Versión del documento:** 26 de noviembre de 2026, sobre la rama `develop`.
**Para quién es:** el equipo, quien revise la entrega integradora y quien tenga que instalar, probar o continuar el proyecto.
**Base:** este manual resume los documentos de `docs/` y `backend/README.md`. Cuando un tema tiene su propio documento, aquí está el resumen y el enlace. Si algo no coincide, manda el documento original.

> Este manual describe **lo que existe hoy en `develop`** y marca como *pendiente* lo que todavía no está hecho, con su tarjeta. No declara terminado nada que no tenga PR mergeado y pruebas.

## Contenido

1. [Qué es KoPay](#1-qué-es-kopay)
2. [Estado actual](#2-estado-actual)
3. [Arquitectura](#3-arquitectura)
4. [Guía de uso de la app](#4-guía-de-uso-de-la-app)
5. [Reglas de negocio](#5-reglas-de-negocio)
6. [Instalación y ejecución local](#6-instalación-y-ejecución-local)
7. [Ambientes, configuración y secretos](#7-ambientes-configuración-y-secretos)
8. [API Node.js](#8-api-nodejs)
9. [Datos: SQLite y PostgreSQL](#9-datos-sqlite-y-postgresql)
10. [Seguridad](#10-seguridad)
11. [Pruebas y evidencias](#11-pruebas-y-evidencias)
12. [Compilación y entrega del APK](#12-compilación-y-entrega-del-apk)
13. [Forma de trabajo del equipo](#13-forma-de-trabajo-del-equipo)
14. [Problemas comunes](#14-problemas-comunes)
15. [Documentos de referencia](#15-documentos-de-referencia)

---

## 1. Qué es KoPay

KoPay es una app móvil (Flutter) para registrar **gastos, ingresos, tarjetas de crédito, deudas y pagos**, y ver el **balance del mes**. Tiene dos vistas:

| Rol | Qué hace | Qué no puede hacer |
| :--- | :--- | :--- |
| **Usuario** (`user`) | Registra, edita y borra sus movimientos, ingresos, tarjetas y deudas. Autoriza y revoca contadores. | Ver datos de otras cuentas. |
| **Contador** (`accountant`) | Ve la lista de personas que lo autorizaron y consulta el resumen y el historial de una de ellas, por mes, **solo lectura**. | Crear, editar o borrar datos ajenos (HU-42). Ver a quien no lo autorizó o lo revocó. |

El sistema tiene tres partes:

- **App Flutter** (`lib/`): las pantallas. Guarda los datos en el teléfono con SQLite.
- **API Node.js** (`backend/`): cuentas, sesiones, roles, permisos del contador, recuperación de acceso y tipo de cambio.
- **PostgreSQL**: la base de la API. En producción será Neon ([base-de-datos.md](base-de-datos.md)).

Las 42 historias de usuario están en [historias-de-usuario.md](historias-de-usuario.md) y las 97 actividades en el [backlog](backlog-desarrollo-desde-cero.md).

## 2. Estado actual

| Módulo | Historias | Estado en `develop` |
| :--- | :--- | :--- |
| Gastos, entradas, ingresos, historial, resumen del mes | HU-01 a HU-09, HU-29 | ✅ Funciona con SQLite. Eliminar con confirmación en revisión (#185, PR #190). |
| Categorías | HU-10 a HU-12 | ✅ Selector con búsqueda, alta, renombrado y borrado. |
| Tarjetas | HU-13 a HU-17 | ✅ Alta, detalle, edición, borrado y pagos. |
| Deudas | HU-19 a HU-22 | ✅ Alta, detalle, edición, borrado, pagos y liquidación. |
| Próximos pagos | HU-18, HU-23 | ✅ Cálculo (S2-12). La pantalla depende de S5-11. |
| Moneda, idioma, respaldo XLSX, importación CSV, borrar datos | HU-24 a HU-28 | ✅ En Ajustes. |
| Registro de cuenta | HU-30 | ✅ API (S3-07, S3-08) y pantalla Flutter (S3-10). |
| Inicio y cierre de sesión, renovación | HU-31, HU-33 | ✅ API con JWT y renovación (S3-09, S4-01, S4-02). Cliente HTTP en Flutter (S4-07). *Pendiente:* pantalla de login (S3-11) y navegación con sesión (S3-12). |
| Recuperar acceso | HU-32 | ✅ API (S4-19). *Pendiente:* pantalla (S4-20). |
| Protección por cuenta y roles | HU-34, HU-37 | ✅ RBAC en la API (S4-04). *Pendiente:* rutas financieras protegidas (S4-03) y guardas en Flutter (S4-09). |
| Autorizar, revocar y consultar contador | HU-38 a HU-42 | ✅ API (S3-06, S4-05, S4-06). Maqueta Flutter con datos de ejemplo (S2-19). *Pendiente:* pantallas reales (S4-11, S4-12, S5-12) y consulta financiera (S5-03). |
| Servicio externo | HU-35 | ✅ Tipo de cambio FIX de Banxico en la API (S5-06). |
| Sincronizar dispositivos | HU-36 | *Pendiente:* API financiera (S5-01 a S5-05) y conexión Flutter (S5-07 a S5-11, S5-19). |
| APK de entrega | — | *Pendiente:* S5-16 (ver la sección 12). |

## 3. Arquitectura

```mermaid
flowchart LR
    U[Usuario] --> A[App Flutter]
    K[Contador] --> A
    A --> P[Providers]
    P --> D[DatabaseHelper]
    D --> L[(SQLite kopay.db)]
    A -- HTTP + JWT --> API[API Node.js / Express]
    API --> R[Autenticación, roles y permisos]
    API --> PG[(PostgreSQL)]
    API --> BX[Banxico SIE]
    API --> SM[Correo SMTP]
```

### App Flutter

| Capa | Carpeta | Qué hace |
| :--- | :--- | :--- |
| Pantallas | `lib/screens/` | Inicio, Movimientos, Ajustes, detalle de tarjeta y deuda, registro, vista de contador. |
| Componentes | `lib/widgets/` | Formularios en hoja inferior (gasto, ingreso, tarjeta, deuda, pago), secciones de Inicio y kit de UI. |
| Estado | `lib/providers/` | Un `ChangeNotifier` por tema: movimientos, ingresos, tarjetas, deudas, categorías y ajustes. Validan, guardan y avisan a la interfaz. |
| Persistencia | `lib/database/database_helper.dart` | Único punto que habla con SQLite. Tablas, migraciones y transacciones. |
| Servicios | `lib/services/` | Respaldo XLSX y CSV, y el cliente de la API (`AuthApi`, `HttpAuthApi`, `ApiConfig`). |
| Utilidades | `lib/utils/` | Validaciones, formato de moneda y fechas, textos en español e inglés (`AppStrings`), colores. |

Patrón: **Provider**. Una pantalla nunca escribe en SQLite; llama al provider, que valida, guarda, recarga y notifica. Por eso Inicio y Movimientos se actualizan solos ([arquitectura.md](arquitectura.md) §3).

### API Node.js

| Carpeta | Qué hace |
| :--- | :--- |
| `backend/src/config/` | Lee las variables de entorno por ambiente. Nadie más lee `process.env`. |
| `backend/src/routes/` | Rutas bajo `/api`: salud, `auth`, `accountants`, `clients` y `exchange-rates`. |
| `backend/src/services/` | Lógica: cuentas, contraseñas, sesiones y JWT, permisos del contador, recuperación, correo y tipo de cambio. |
| `backend/src/middleware/` | Sesión (`authenticate`), roles (`rbac`), acceso a clientes y errores. |
| `backend/src/data/` | Capa de datos: PostgreSQL (`pg-store.js`), memoria (pruebas) y migraciones. |
| `backend/migrations/` | Migraciones SQL numeradas (`001` a `004`). |

## 4. Guía de uso de la app

### Navegación

La app tiene tres pestañas abajo: **Inicio**, **Movimientos** y **Ajustes**, más el botón verde **+** para registrar.

### Registrar un gasto, una entrada o un ingreso (HU-01 a HU-04)

1. Toca **+** y elige **Gasto o movimiento** o **Ingreso**.
2. Captura el monto, la descripción (o el nombre del ingreso), la categoría y la fecha. La nota es opcional.
3. Toca **Guardar**. Si falta algo o el monto no es válido, el campo se marca en rojo y no se guarda.

### Consultar, editar y eliminar (HU-05 a HU-09)

- **Inicio** muestra el balance del mes elegido (flechas junto al mes), los ingresos, los gastos y los movimientos del mes, además de las secciones **Tarjetas** y **Deudas**.
- **Movimientos** muestra gastos, entradas, pagos e ingresos, del más reciente al más antiguo.
- Toca una fila para **editarla**. En la hoja de edición, **Eliminar** pide confirmación: Cancelar conserva el registro y Eliminar lo borra y recalcula el resumen (#185). Los pagos de tarjeta o deuda no se borran desde aquí.

### Tarjetas (HU-13 a HU-17)

1. En Inicio, sección **Tarjetas**, toca **Agregar tarjeta**: nombre, banco, límite, saldo usado, día de corte, día de pago y pago mínimo.
2. Toca la tarjeta para ver su **crédito disponible** (límite − usado), la barra de uso y sus datos. Arriba están **Editar** y **Eliminar**.
3. **Registrar pago:** captura el monto (o toca **Pagar todo**), la fecha y la nota. No se acepta un monto cero, no numérico o mayor que el saldo usado. El pago baja el saldo usado, sube el disponible y aparece en Movimientos.
4. Al eliminar la tarjeta, sus pagos **se conservan** en Movimientos.

### Deudas (HU-19 a HU-22)

1. Sección **Deudas**, **Agregar deuda**: nombre, mensualidad, saldo restante y próximo vencimiento.
2. La lista va por vencimiento y muestra **Pendiente**, **Vencida** (en rojo) o **Pagada** (en verde).
3. **Registrar pago** funciona igual que en tarjetas. Un pago por el saldo completo deja la deuda en **Pagada** y desactiva el botón.

### Ajustes (HU-10 a HU-12, HU-24 a HU-28)

| Opción | Qué hace |
| :--- | :--- |
| Moneda | MXN, USD o EUR. Cambia el formato de todos los importes. |
| Idioma | Español o inglés. Cambia los textos de la app. |
| Categorías | Desde el selector de categoría de un gasto: buscar, crear, renombrar y borrar. |
| Exportar a Excel | Crea `kopay-respaldo-AAAA-MM-DD.xlsx` con las hojas Movimientos, Ingresos y Respaldo, y abre la hoja de compartir. |
| Importar CSV | Valida todo el archivo y, tras confirmar, **reemplaza** movimientos e ingresos. Formato en [criterios-respaldo-importacion-borrado.md](criterios-respaldo-importacion-borrado.md) §3. |
| Borrar datos | Tras confirmar, elimina movimientos, ingresos, tarjetas y deudas del dispositivo. Conserva categorías y ajustes. |
| Vista de contador (maqueta) | Muestra la vista del contador con **datos de ejemplo** y un aviso fijo de que no está conectada a cuentas reales. |

### Crear cuenta (HU-30)

La pantalla **Crear cuenta** pide nombre, correo y contraseña (8 a 72 caracteres, con al menos una letra y un número). Revisa los tres campos a la vez, bloquea el formulario mientras envía y muestra los errores de la API bajo cada campo o arriba si no hay red. *Pendiente:* su entrada en la app llega con S3-12.

### Vista de contador (HU-39, HU-40, HU-42)

Hoy es una **maqueta** (S2-19): Clientes autorizados → Resumen del mes → Historial de solo lectura. La versión real, con sesión de contador y datos de la API, llega con S4-12, S5-09 y S5-12. Las reglas están en [navegacion-usuario-contador.md](navegacion-usuario-contador.md) y [reglas-roles-contador.md](reglas-roles-contador.md).

## 5. Reglas de negocio

- **Montos:** mayores que cero y como máximo 999,999,999.99, con dos decimales. Las comparaciones y restas de saldos se hacen en **centavos enteros** (D-06).
- **Signo:** en `movements`, los gastos y pagos son negativos y las entradas positivas. Los ingresos se guardan positivos en su propia tabla.
- **Fechas:** se guardan en ISO 8601. Una fecha imposible (`2026-02-30`) se rechaza al leerla (D-03).
- **Pagos:** no pueden ser mayores que el saldo usado de la tarjeta ni que el saldo restante de la deuda. Un pago es un movimiento `type = payment` ligado a su tarjeta o deuda.
- **Estado de deuda:** saldo cero = **Pagada**; mayor que cero = **Pendiente**; pendiente con vencimiento anterior a hoy = **Vencida**.
- **Borrar tarjeta o deuda:** sus pagos se conservan en Movimientos y solo se desligan.
- **Pendientes anotados para el cierre del Sprint 2 (#18):** editar o borrar un pago no devuelve el saldo, y `expensesForMonth` cuenta los pagos como gastos.

## 6. Instalación y ejecución local

### Requisitos

| Herramienta | Para qué |
| :--- | :--- |
| Flutter 3.x con Dart 3.11 o más reciente | La app. |
| Android Studio con un emulador, o un teléfono Android | Correr y probar la app. En web la app **no guarda datos**, porque sqflite no funciona ahí. |
| Node.js 20 o más reciente | La API. |
| Docker (o PostgreSQL 16 instalado) | La base de la API en local. |

### App Flutter

```bash
flutter pub get
flutter run                                         # emulador o teléfono conectado
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

Sin `API_URL`, la app usa `http://10.0.2.2:3000`, que es la computadora vista desde el emulador de Android.

### API Node.js

```bash
# Una sola vez: PostgreSQL local
docker run -d --name kopay-pg -e POSTGRES_USER=kopay -e POSTGRES_PASSWORD=kopay \
  -e POSTGRES_DB=kopay_test -p 5432:5432 postgres:16
docker exec kopay-pg psql -U kopay -d kopay_test -c "CREATE DATABASE kopay;"

cd backend
cp .env.example .env        # y pon DATABASE_URL=postgres://kopay:kopay@localhost:5432/kopay
npm ci
npm run migrate             # crea o actualiza las tablas; otra vez no hace nada
npm start                   # o npm run dev
curl -i http://localhost:3000/api/health
```

`/api/health` responde `200` con `"data":{"kind":"postgres","ok":true}`. Si la base no responde, responde `503`. Más detalle en [backend/README.md](../backend/README.md).

## 7. Ambientes, configuración y secretos

### API (`backend/.env`, nunca se sube)

| Variable | Para qué | En producción |
| :--- | :--- | :--- |
| `NODE_ENV` | `development`, `test` o `production`. | `production` |
| `PORT` | Puerto HTTP (3000 si está vacío). | Lo da el servicio |
| `DATABASE_URL` | Conexión a PostgreSQL. | Obligatoria (Neon, con `sslmode=require`) |
| `JWT_SECRET` | Firma de los tokens. | Obligatoria, de 32 caracteres o más y distinta del ejemplo |
| `CORS_ORIGIN` | Orígenes permitidos. | Obligatoria, sin `*` |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` | Correo de recuperación. | Obligatorias. En dev y test no se envía nada: el código sale en la consola |
| `BANXICO_TOKEN` | Tipo de cambio FIX. | Obligatoria (64 caracteres hexadecimales) |

En producción, si falta algo, la API **no arranca** y dice qué falta. Los valores reales se comparten solo por mensaje privado. La plantilla es `backend/.env.example`.

### App

La URL de la API se elige **al compilar** con `--dart-define=API_URL=…` (`lib/services/api_config.dart`). En producción debe ser `https`. La propuesta de archivos por ambiente (`config/dev.json`, `config/prod.json`) está en la sección 12.

### Bases por ambiente

| Ambiente | Base |
| :--- | :--- |
| `development` | PostgreSQL local `kopay` o branch `dev` de Neon |
| `test` | PostgreSQL local `kopay_test` o branch `test` de Neon; las pruebas la borran y la vuelven a migrar |
| `production` | Branch `main` de Neon; solo se migra con PR mergeado |

## 8. API Node.js

Todas las rutas están bajo `/api`, con JSON en UTF-8. El contrato completo está en [contrato-api-acceso.md](contrato-api-acceso.md).

| Método y ruta | Sesión | Para qué |
| :--- | :---: | :--- |
| `GET /api/health` | No | Estado de la API y de la base |
| `POST /api/auth/register` | No | Crear cuenta (`201`, no abre sesión) |
| `POST /api/auth/login` | No | Iniciar sesión: `accessToken`, `refreshToken` y `user` |
| `GET /api/auth/me` | Sí | Cuenta de la sesión |
| `POST /api/auth/refresh` | No | Renovar con `refreshToken` (rotación) |
| `POST /api/auth/logout` | Sí | Cerrar esa sesión (`204` siempre) |
| `POST /api/auth/recover` | No | Pedir código de recuperación por correo |
| `POST /api/auth/reset` | No | Cambiar la contraseña con el código; cierra todas las sesiones |
| `GET`, `POST /api/accountants`, `DELETE /api/accountants/:grantId` | `user` | Listar, autorizar y revocar contadores |
| `GET /api/clients`, `GET /api/clients/:userId` | `accountant` | Clientes que autorizaron al contador |
| `GET /api/exchange-rates` | Cualquiera | Tipo de cambio FIX USD/MXN de Banxico |

**Errores:** siempre `{ error, code, fields? }`. La app decide con `code`, por ejemplo `VALIDATION_FAILED`, `INVALID_CREDENTIALS`, `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `EMAIL_TAKEN`, `TOO_MANY_ATTEMPTS` o `UNAVAILABLE`.

**Sesión:**
- El `accessToken` es un JWT HS256 que vence en 15 minutos. Se envía como `Authorization: Bearer <accessToken>`.
- El `refreshToken` vence en 30 días y sirve una sola vez.
- *Pendiente:* las rutas financieras (S5-01 a S5-05) detrás de S4-03.

## 9. Datos: SQLite y PostgreSQL

### En el teléfono (`kopay.db`, versión 4)

| Tabla | Contenido |
| :--- | :--- |
| `movements` | Gastos, entradas y pagos (`type`, `card_id`, `debt_id`) |
| `incomes` | Ingresos |
| `cards` | Tarjetas; el disponible se calcula, no se guarda |
| `debts` | Deudas con saldo, vencimiento y estado |
| `settings` | Moneda, idioma y categorías |

Cada cambio de esquema sube la versión y agrega su paso en `onUpgrade`, sin borrar datos ([arquitectura.md](arquitectura.md) §5).

### En la API (PostgreSQL 16)

| Migración | Tablas |
| :--- | :--- |
| `001_users_roles_sessions.sql` | `users` (correo único en minúsculas, hash de contraseña, rol) y `sessions` (hash del token) |
| `002_accountant_access.sql` | `accountant_access`: un permiso vigente por pareja; revocar llena `revoked_at` |
| `003_password_resets.sql` | Códigos de recuperación (solo el hash, 15 minutos, 5 intentos) |
| `004_session_refresh.sql` | Hash y vencimiento del `refreshToken` en `sessions` |

Las tablas financieras remotas (`movements`, `incomes`, `cards`, `debts`, `settings`, cada una con `user_id`) llegan con S5-01 a S5-05. Las reglas de aislamiento están en [base-de-datos.md](base-de-datos.md) §3.

## 10. Seguridad

- **Contraseñas:** solo se guarda su hash (S3-08). Nunca aparecen en respuestas, errores ni consola.
- **Tokens:** de `accessToken`, `refreshToken` y códigos de recuperación solo se guarda el hash.
- **Login:** si el correo no existe o la contraseña no coincide, la respuesta es la misma, para no revelar qué correos tienen cuenta.
- **Roles:** el rol se lee de la base en cada petición, nunca de lo que mande la app (S4-04). El contador solo lee, y solo con un permiso vigente que se revisa en cada consulta (S4-06).
- **Aislamiento:** toda consulta filtra por el `user_id` de la sesión. Un id de otra cuenta responde igual que uno inexistente.
- **Secretos fuera del repo:** `.env`, cadenas de Neon, claves SMTP, token de Banxico y, para el APK, el keystore y `key.properties` (sección 12).

## 11. Pruebas y evidencias

| Qué | Comando | Dónde |
| :--- | :--- | :--- |
| Análisis de Flutter | `flutter analyze` | Todo `lib/` y `test/` |
| Unitarias y de interfaz de Flutter | `flutter test` | `test/` |
| Recorridos en la app | `flutter test integration_test/<archivo> -d <dispositivo>` | `integration_test/`, con capturas en `docs/evidencias/` |
| API sin base | `cd backend && npm test` | `backend/test/` |
| API con PostgreSQL | `DATABASE_URL=…/kopay_test npm run test:db` | `backend/test/db/` (borra la base de pruebas) |

- Cada prueba lleva en su nombre el caso del plan (`UT-xx`, `UI-xx`, `INT-xx`, `CON-xx`, …) y la historia (`HU-xx`).
- El plan y los resultados registrados están en [plan-de-pruebas.md](plan-de-pruebas.md). Cómo guardar la evidencia, en [guia-de-evidencias.md](guia-de-evidencias.md).
- En macOS, los recorridos de `integration_test` necesitan la ventana de la app **al frente**: si queda detrás de otra, la prueba se detiene.

## 12. Compilación y entrega del APK

Responsable: S5-16 (#102). Esta sección resume lo que falta para un release correcto. El detalle paso a paso irá en `docs/manual-release.md`.

| # | Paso | Estado hoy |
| :--- | :--- | :--- |
| 1 | **Versión:** subir `version:` de `pubspec.yaml` en cada entrega (`1.0.0+1` → `1.1.0+2`; el número después de `+` siempre crece) y poner un tag `git tag v1.1.0`. | *Pendiente* |
| 2 | **Identidad:** cambiar `applicationId` y `namespace` de `com.example.kopay` a uno propio (por ejemplo `mx.utez.kopay`) y `android:label` a `KoPay`, **antes** de la primera firma. | *Pendiente* |
| 3 | **Firma:** generar el keystore con `keytool`, crear `android/key.properties` y usar `signingConfigs.release` en `android/app/build.gradle.kts`. Hoy el release se firma con la llave de debug. | *Pendiente* |
| 4 | **Resguardo:** agregar `android/key.properties`, `*.jks` y `*.keystore` al `.gitignore`. Guardar el `.jks` fuera del repo, con respaldo, y las contraseñas en un gestor. Si se pierde la llave, no se pueden publicar actualizaciones. | *Pendiente* |
| 5 | **Ambientes:** `config/dev.json` y `config/prod.json` con `API_URL` y compilar con `--dart-define-from-file`. En producción, `https`. | *Pendiente*: falta la URL pública de la API (despliegue) |
| 6 | **Build de producción:** `flutter build apk --release --dart-define-from-file=config/prod.json --obfuscate --split-debug-info=build/symbols`. Guardar `build/symbols`. | *Pendiente* |
| 7 | **Instalación:** `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Registrar en #102 la versión, el modelo y la versión de Android, con una captura. | *Pendiente* |

**APK o AAB:** el **APK** se instala directo en el teléfono y es lo que pide la entrega. El **AAB** (`flutter build appbundle --release`) solo sirve para Play Store, que genera un APK por dispositivo.

## 13. Forma de trabajo del equipo

Las reglas completas están en [CLAUDE.md](../CLAUDE.md) e [instrucciones-equipo.md](instrucciones-equipo.md).

- **Ramas:** `main` es estable y `develop` es de integración. Hay una rama por tarjeta (`feature/sN-XX-…`, `test/…`, `docs/…`, `fix/…`) y todos los PR van a `develop`. Nadie hace push directo a `main` ni a `develop`.
- **Una tarjeta activa por persona y un PR a la vez.** Antes de empezar, revisa que la tarjeta de la que dependes ya esté mergeada.
- **Cada quien con su cuenta:** cada persona hace sus commits y abre sus PR con su propia cuenta de GitHub, sin coautores de herramientas de IA.
- **PR:**
  - Título `[SN-XX] …` y `Closes #N`. Reviewer: `RuAbogado`. Se mergea con *Squash and merge*.
  - La sección **Pruebas** es obligatoria: historia, archivos, caso del plan, ruta de las pruebas, resultado real y evidencia.
- **Tablero (Project 3):** la tarjeta pasa a *In progress* al empezar y a *In review* al abrir el PR. Pasa a *Done* solo con el PR mergeado y un comentario con las pruebas.
- **Dependencias:** cada sprint autoriza las suyas ([CLAUDE.md](../CLAUDE.md), sección Prohibido).

## 14. Problemas comunes

| Síntoma | Qué hacer |
| :--- | :--- |
| `/api/health` responde 503 | La base no responde: levanta `kopay-pg` y revisa `DATABASE_URL`. |
| La API no arranca en producción | Falta una variable obligatoria: el mensaje dice cuál (sección 7). |
| `Cannot find module …` en el backend | Corre `npm ci` en `backend/` después de actualizar `develop`. |
| Tablas que faltan después de actualizar | Corre `npm run migrate`. |
| `EADDRINUSE` | El puerto está ocupado: usa `PORT=3001 npm start`. |
| La app no guarda nada en el navegador | sqflite no funciona en web: usa un emulador o un teléfono. |
| La app no conecta con la API desde el emulador | Usa `http://10.0.2.2:3000`, no `localhost`. |
| Una prueba de `integration_test` en macOS se queda detenida | Trae la ventana de KoPay al frente. |

## 15. Documentos de referencia

| Documento | Contenido |
| :--- | :--- |
| [plan-del-proyecto.md](plan-del-proyecto.md) | Alcance, módulos y calendario de los cinco sprints |
| [backlog-desarrollo-desde-cero.md](backlog-desarrollo-desde-cero.md) | Las 97 tarjetas con responsable, dependencia y criterio |
| [historias-de-usuario.md](historias-de-usuario.md) | HU-01 a HU-42 |
| [arquitectura.md](arquitectura.md) | Módulos, patrón de estado y esquema local |
| [navegacion-usuario-contador.md](navegacion-usuario-contador.md) | Pantallas y recorridos de cada rol |
| [criterios-respaldo-importacion-borrado.md](criterios-respaldo-importacion-borrado.md) | XLSX, CSV y borrar datos |
| [contrato-api-acceso.md](contrato-api-acceso.md) | Rutas, campos, respuestas y errores de la API |
| [reglas-roles-contador.md](reglas-roles-contador.md) | Roles, consentimiento y revocación |
| [base-de-datos.md](base-de-datos.md) | PostgreSQL, Neon, aislamiento y migraciones |
| [plan-de-pruebas.md](plan-de-pruebas.md) | Casos y resultados registrados |
| [guia-de-evidencias.md](guia-de-evidencias.md) | Cómo guardar evidencia |
| [backend/README.md](../backend/README.md) | Cómo correr y probar la API |
