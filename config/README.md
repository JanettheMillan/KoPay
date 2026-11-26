# Ambientes de la app

Dirección de la API Node que usa la app, por ambiente. Se elige **al compilar** con `--dart-define-from-file` y la lee `lib/services/api_config.dart`. Ninguna dirección va escrita en el código.

| Archivo | Para qué | `API_URL` |
| :--- | :--- | :--- |
| `dev.json` | Emulador de Android con `npm start` en la computadora. | `http://10.0.2.2:3000` |
| `dev-local.json` | Simulador de iOS, escritorio (macOS, Windows) o web, con la API en la misma computadora. | `http://localhost:3000` |
| `prod.json` | APK de entrega, contra la API publicada en Railway (#189). Siempre `https`. | **Pendiente:** el dominio sale del despliegue. Hoy dice `kopay-api-pendiente.invalid`, que no existe a propósito: un APK compilado así no se conecta y muestra "No se pudo conectar con KoPay". |

## Comandos

```bash
# Desarrollo con el emulador de Android
flutter run --dart-define-from-file=config/dev.json

# Simulador de iOS, escritorio o web
flutter run --dart-define-from-file=config/dev-local.json

# APK de entrega (ver docs/manual-del-sistema.md §12)
flutter build apk --release --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols
```

Sin `--dart-define-from-file`, la app usa `http://10.0.2.2:3000`.

## Reglas

- Aquí solo va la dirección de la API, que no es secreta. **Nunca** tokens, contraseñas ni la `DATABASE_URL`: esos viven en el servidor (`backend/.env` o el panel de Railway).
- `prod.json` siempre con `https`. Un APK de release no permite `http` sin cifrar.
- Para un teléfono físico en la misma red Wi-Fi, copia `dev.json`, cambia la IP por la de tu computadora (por ejemplo `http://192.168.1.50:3000`) y no subas esa copia. Funciona en `flutter run` (debug), no en un APK de release.
- Cuando Rubén tenga el dominio de Railway, se cambia en `prod.json` y se quita el `skip` de la prueba CFG-05 (`test/api_config_files_test.dart`).
