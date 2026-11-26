# Casos unitarios de validación y autorización

**Tarjeta:** S3-16 · [#64](https://github.com/JanettheMillan/KoPay/issues/64). **Historias:** HU-30, HU-34 y HU-37. Los casos de login y recuperación corresponden a HU-31 y HU-32.
**Base:** [contrato-api-acceso.md](contrato-api-acceso.md) (secciones 3.1, 3.2, 3.7 y 3.8) y [reglas-roles-contador.md](reglas-roles-contador.md) (sección 1).

FUT y UT son casos de [plan-de-pruebas.md](plan-de-pruebas.md). VAL y AUT son casos nuevos de esta tarjeta. Este documento no repite los límites que ya prueban REG-07, UT-REG-01 a UT-REG-03 y RBAC-09.

## 1. API Node

Pruebas en `backend/test/validation-authorization-limits.test.js`.

| Caso | Historia | Tipo | Entrada | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- |
| FUT-01 | HU-30 | Datos inválidos | Registro válido, vacío y con correo mal formado | Solo el válido pasa; cada campo inválido tiene su mensaje |
| FUT-14 | HU-30 | Límite | Contraseña de 7, 8, 72 y 73 caracteres | 8 y 72 pasan; 7 es corta y 73 es larga |
| VAL-01 | HU-30 | Límite | Nombre de solo espacios; 80 caracteres con espacios alrededor | El primero falta; el segundo pasa |
| VAL-02 | HU-30 | Límite | Nombre y contraseña con emojis en el límite | Cada emoji cuenta como un carácter |
| VAL-03 | HU-30 | Límite | Correo de 254 caracteres con espacios alrededor | Pasa |
| VAL-04 | HU-31 | Datos inválidos | Login sin cuerpo, nulo, texto o lista | Pide correo y contraseña |
| VAL-05 | HU-31 | Límite | Login con correo y contraseña de solo espacios | Falta el correo; la contraseña no se recorta |
| VAL-06 | HU-32 | Datos inválidos | Pedir código sin correo, con correo incompleto y con mayúsculas | Los dos primeros se rechazan; el tercero se normaliza |
| VAL-07 | HU-32 | Límite y datos inválidos | Código vacío, de 5 o 7 dígitos, con letra, espacio interior, signo, dígitos de ancho completo, número o nulo | `Escribe el código de 6 dígitos` |
| VAL-08 | HU-32 | Límite | Código de 6 dígitos, con ceros iniciales o espacios alrededor | Pasa y se recorta |
| VAL-09 | HU-32 | Datos inválidos | Cambio de contraseña sin datos | Reporta correo, código y contraseña a la vez |
| FUT-21 | HU-37 | Rol | Permiso de lectura contable con `accountant` y `user` | Solo `accountant` lo tiene |
| AUT-01 | HU-34 | Rol inválido | `admin`, mayúsculas, espacios, vacío, nulo, sin valor y `0` | Ningún permiso |
| AUT-02 | HU-34 | Datos inválidos | Permiso desconocido o sin valor | No se concede |
| AUT-03 | HU-34 | Rol inválido | `constructor`, `toString`, `__proto__` y `hasOwnProperty` | `false`. **Hoy no se cumple** (ver sección 3) |

## 2. App Flutter

Pruebas en `test/auth_roles_limits_test.dart`.

| Caso | Historia | Tipo | Entrada | Resultado esperado |
| :--- | :--- | :--- | :--- | :--- |
| UT-47 | HU-37 | Rol | `AuthUser` con rol `user` | `isAccountant` es falso |
| UT-48 | HU-37 | Rol | `AuthUser` con rol `accountant` | `isAccountant` es verdadero |
| UT-49 | HU-30 | Conversión | `AuthUser.fromMap` con rol `user` y `accountant` | Conserva `id`, `name`, `email`, `role` y `createdAt`; `isAccountant` según el rol |
| AUT-F01 | HU-37 | Rol inválido | Rol con mayúsculas, espacios, desconocido o vacío | `isAccountant` es falso |
| VAL-F01 | HU-30 | Límite | Contraseña de 7, 8, 72 y 73 caracteres | 8 y 72 pasan; 7 es corta y 73 es larga |
| VAL-F02 | HU-30 | Límite | Correo de 254 y 255 caracteres | 254 pasa y 255 no |
| VAL-F03 | HU-30 | Límite | Nombre y contraseña con emojis en el límite | Cada emoji cuenta como un carácter |
| VAL-F04 | HU-30 | Datos inválidos | Valores nulos o nombre de solo espacios | Se rechazan |
| VAL-F05 | HU-31 | Límite | Contraseña del login nula, vacía, de un carácter y de espacios | Solo la nula y la vacía se rechazan |

## 3. Defecto encontrado

**D-07** · [#183](https://github.com/JanettheMillan/KoPay/issues/183). `can()` en `backend/src/middleware/rbac.js` busca el rol en un objeto normal. Con `constructor`, `toString`, `__proto__` o `hasOwnProperty` lanza `TypeError` en lugar de devolver `false`. La base solo admite `user` y `accountant` (migración `001_users_roles_sessions.sql`). AUT-03 está marcado con `test.failing`: Jest lo cuenta como aprobado mientras el defecto exista y fallará cuando se corrija, para cambiarlo a `test`. Esta tarjeta no modifica el código de la API.
