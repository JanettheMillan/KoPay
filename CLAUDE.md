# KoPay: reglas del repositorio

App Flutter de finanzas personales. Este archivo lo leen los agentes de IA y las personas del equipo. Cada quien trabaja con **su propia cuenta de GitHub** y **su propia sesión**.

## Flujo de ramas

- `main`: versión estable de entrega. No se hace push directo.
- `develop`: rama de integración. **Todos los Pull Requests van a `develop`.**
- Una rama por tarjeta: `feature/s1-XX-nombre-corto` (código) o `test/s1-XX-nombre` (pruebas) o `docs/nombre` (documentos).
- Una tarea activa por persona. Un PR por tarjeta.

## Antes de empezar una tarjeta

1. Lee el issue y su criterio de aceptación.
2. Revisa en `docs/backlog-desarrollo-desde-cero.md` de qué otra tarjeta depende. Si esa no está mergeada en `develop`, espera.
3. `git checkout develop && git pull`, luego crea tu rama.

## Antes de abrir el PR

- `flutter pub get`, `flutter analyze` sin errores y `flutter test` en verde.
- Corre la app (`flutter run`) y toma una captura de lo que hiciste.
- `git status`: solo deben aparecer los archivos de tu tarjeta. Usa `git add <archivos>`, nunca `git add .` sin revisar.

## El Pull Request

- Base: `develop`. Reviewer: `RuAbogado`.
- Título: `[S1-XX] <título de la tarjeta>`.
- Descripción: `Closes #N`, qué incluye y la captura de pantalla.
- Un commit limpio por tarjeta. Mensaje: `feat: <qué hiciste> (S1-XX)`.
- No abras el siguiente PR hasta que el anterior esté mergeado.

## Prohibido

- Push directo a `main` o `develop`.
- `git push --force` en `main` o `develop`. En tu propia rama usa `--force-with-lease` solo para un rebase.
- Co-Authored-By de herramientas de IA en los commits.
- Subir `.env`, claves, keystores, `local.properties`, `google-services.json`, `build/`, `.dart_tool/`, `.idea/`, `backend/`.
- Dependencias fuera del sprint. En Sprint 1 solo `provider`, `intl`, `fl_chart` y, para la persistencia local (S1-08 y S1-09), `sqflite` y `path`. Para probar la base sin emulador se permite `sqflite_common_ffi` solo como `dev_dependency`. Sin `http` ni `flutter_secure_storage`.
- Usar la cuenta, el token o la sesión de otra persona.

## Squash y rebase

Los PRs se mergean con **Squash and merge**. Si tu rama se apoya en otra tarjeta ya mergeada, rebásala antes de abrir el PR:

```
git fetch origin
git checkout <tu-rama>
git rebase --onto origin/develop <commit-de-la-tarjeta-anterior>
git push --force-with-lease
```

## Project y tarjetas

- Al abrir el PR, mueve tu tarjeta a **In review**.
- Al mergear, el issue se cierra a mano porque `develop` no es la rama por defecto. Lo cierra quien mergea.

## Alcance del primer entregable (5% del front)

Solo la parte visual del Sprint 1: proyecto base, tema y navegación, Inicio, formularios, historial. Nada de backend, sesión ni contador.

Instrucciones por persona: `docs/instrucciones-equipo.md`.
