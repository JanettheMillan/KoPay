/// Contrato de cuenta y sesión entre la app y la API Node
/// (docs/contrato-api-acceso.md, S3-13).
///
/// Las pantallas solo conocen esta interfaz. Hoy la implementa
/// [FakeAuthApi] (`fake_auth_api.dart`), en memoria; S4-07 agrega el
/// cliente HTTP real sin cambiar las pantallas.
library;

/// Códigos estables de error del contrato (§2). La app decide con el
/// código, nunca comparando el texto del mensaje.
class ApiErrorCode {
  ApiErrorCode._();

  static const validationFailed = 'VALIDATION_FAILED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const unauthenticated = 'UNAUTHENTICATED';
  static const emailTaken = 'EMAIL_TAKEN';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';
  static const internal = 'INTERNAL';
  static const unavailable = 'UNAVAILABLE';
}

/// Respuesta de error de la API: `{ error, code, fields? }`.
class ApiException implements Exception {
  final int status;
  final String code;

  /// Mensaje en español que se puede mostrar tal cual.
  final String message;

  /// Un mensaje por campo, solo en `VALIDATION_FAILED`.
  final Map<String, String> fields;

  const ApiException(
    this.status,
    this.code,
    this.message, {
    this.fields = const {},
  });

  /// Arma la excepción desde el cuerpo JSON de la respuesta.
  factory ApiException.fromBody(int status, Map<String, dynamic> body) {
    final raw = body['fields'];
    return ApiException(
      status,
      body['code'] as String? ?? ApiErrorCode.internal,
      body['error'] as String? ?? 'Error interno del servidor',
      fields: raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  @override
  String toString() => 'ApiException($status $code)';
}

/// La petición no llegó al servidor (sin red, tiempo agotado o respuesta
/// que no es JSON).
class NetworkException implements Exception {
  static const String message =
      'No se pudo conectar con KoPay. Revisa tu conexión e inténtalo de nuevo.';

  const NetworkException();

  @override
  String toString() => 'NetworkException';
}

/// Cuenta como la devuelve la API. Nunca trae la contraseña.
class AuthUser {
  final String id;
  final String name;
  final String email;

  /// `user` o `accountant` (HU-37).
  final String role;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAccountant => role == 'accountant';

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
    id: map['id'] as String,
    name: map['name'] as String,
    email: map['email'] as String,
    role: map['role'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

/// Rutas de cuenta y sesión que usa la app.
abstract class AuthApi {
  /// `POST /api/auth/register` (§3.1). Devuelve la cuenta creada; no abre
  /// sesión. Lanza [ApiException] (`VALIDATION_FAILED`, `EMAIL_TAKEN`,
  /// `INTERNAL`, `UNAVAILABLE`) o [NetworkException].
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  });
}
