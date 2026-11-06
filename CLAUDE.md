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
- **Pruebas obligatorias:** no se sube código sin pruebas. Cada quien escribe y ejecuta las pruebas de su propia tarjeta (ver "Pruebas en cada PR").

## El Pull Request

- Base: `develop`. Reviewer: `RuAbogado`.
- Título: `[S1-XX] <título de la tarjeta>`.
- Descripción: `Closes #N`, qué incluye y la captura de pantalla.
- Descripción: agrega la sección **Pruebas** (ver abajo).
- Un commit limpio por tarjeta. Mensaje: `feat: <qué hiciste> (S1-XX)`.
- No abras el siguiente PR hasta que el anterior esté mergeado.

## Prohibido

- Push directo a `main` o `develop`.
- `git push --force` en `main` o `develop`. En tu propia rama usa `--force-with-lease` solo para un rebase.
- Co-Authored-By de herramientas de IA en los commits.
- Subir `.env`, claves, keystores, `local.properties`, `google-services.json`, `build/`, `.dart_tool/`, `.idea/`, `backend/`.
- Dependencias fuera del sprint. En Sprint 1 solo `provider`, `intl`, `fl_chart` y, para la persistencia local (S1-08 y S1-09), `sqflite` y `path`. Para probar la base sin emulador se permite `sqflite_common_ffi` solo como `dev_dependency`. Para el recorrido en dispositivo se permite `integration_test` (viene con el SDK de Flutter) solo como `dev_dependency`. Sin `http` ni `flutter_secure_storage`.
- Usar la cuenta, el token o la sesión de otra persona.

## Squash y rebase

Los PRs se mergean con **Squash and merge**. Si tu rama se apoya en otra tarjeta ya mergeada, rebásala antes de abrir el PR:

```
git fetch origin
git checkout <tu-rama>
git rebase --onto origin/develop <commit-de-la-tarjeta-anterior>
git push --force-with-lease
```

## Pruebas en cada PR

Un PR sin pruebas no se revisa ni se mergea. Quien hace la tarjeta es quien deja sus pruebas; QA no las hace por los demás.

La descripción del PR debe incluir una sección **Pruebas** con:

- **Historia de usuario** que implementa la tarjeta (`HU-xx`), tal como está en `docs/historias-de-usuario.md`. Las historias no se modifican.
- **Caso del plan** que cubre (`UT-xx`, `UI-xx`, `INT-xx`) según `docs/plan-de-pruebas.md`. Si el caso no existe en el plan, dilo y escribe el nombre de la prueba nueva.
- **Archivo y nombre de cada prueba** que escribiste o ejecutaste, por ejemplo `test/validators_test.dart`.
- **Resultado real**: comando ejecutado y cuántas pruebas pasaron, fallaron u omitieron. Si algo falla, abre un issue con la etiqueta `bug` y enlázalo.
- **Evidencia**: captura o salida de consola. Si cambia la interfaz, prueba también en un iPhone o un Android (teclado, botones y sin `RenderFlex overflow`), como pide el Manual de Estilo.

En el código de la prueba, incluye en el nombre el identificador del caso del plan (por ejemplo `UT-03 · ...`) y la historia (`HU-02`) para que se pueda rastrear.

Todo el código del repositorio debe responder a una historia de usuario. Si no puedes enlazar tu cambio a una `HU-xx`, no pertenece a esta tarjeta.

## Project y tarjetas

El Project 3 es el reflejo del trabajo real. Debe verse un flujo, no tarjetas que saltan al final.

- **Toda tarjeta tiene responsable** y sprint antes de empezar. No se trabaja en una tarjeta sin asignar.
- **Una tarjeta en In progress por persona.** Mueve la tuya a **In progress** al empezar y a **In review** al abrir el PR.
- **Al terminar, pasa a Done** solo si el PR está mergeado. En la tarjeta (o en el issue) deja un comentario con: el PR, la historia de usuario, los casos del plan y las pruebas que pasaron, con el resultado real. Una tarjeta en Done sin pruebas citadas no está terminada.
- Las tarjetas de QA (S1-16, S1-17, S1-18 y similares) citan los mismos casos del plan que ejecutan y enlazan su evidencia.
- Al mergear, el issue se cierra a mano porque `develop` no es la rama por defecto. Lo cierra quien mergea.
- Solo se usan las etiquetas `feature`, `bug` y `bloqueado`.

## Alcance del primer entregable (5% del front)

Solo la parte visual del Sprint 1: proyecto base, tema y navegación, Inicio, formularios, historial. Nada de backend, sesión ni contador.

Instrucciones por persona: `docs/instrucciones-equipo.md`.
