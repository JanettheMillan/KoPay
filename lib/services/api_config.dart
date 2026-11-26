/// Dirección de la API Node según el ambiente (S4-07).
///
/// Se elige al compilar con `--dart-define`, nunca escrita en el código:
///
/// ```
/// flutter run --dart-define=API_URL=http://10.0.2.2:3000
/// flutter build apk --dart-define=API_URL=https://api.kopay.example
/// ```
///
/// Sin `API_URL` se usa la de la computadora vista desde el emulador de
/// Android (`10.0.2.2`), con el puerto de `npm start`.
class ApiConfig {
  ApiConfig._();

  /// Valor por defecto: la API local vista desde el emulador de Android.
  static const String defaultUrl = 'http://10.0.2.2:3000';

  /// `API_URL` de `--dart-define`, o [defaultUrl].
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: defaultUrl,
  );

  /// [apiUrl] como `Uri`, sin la diagonal final.
  static Uri get baseUrl => parse(apiUrl);

  /// Convierte [url] en la base de la API. Lanza [FormatException] si no
  /// es una dirección `http` o `https` con servidor.
  static Uri parse(String url) {
    final uri = Uri.parse(url.trim());
    if (!(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw FormatException(
        'API_URL debe ser http(s)://servidor[:puerto]',
        url,
      );
    }
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: path);
  }
}
