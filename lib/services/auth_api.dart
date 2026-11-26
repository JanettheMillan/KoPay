/// Contrato de cuenta y sesión entre la app y la API Node
/// (docs/contrato-api-acceso.md, S3-13).
///
/// Las pantallas solo conocen esta interfaz. La implementan
/// `HttpAuthApi` (`http_auth_api.dart`, S4-07), que habla con la API, y
/// `FakeAuthApi` (`fake_auth_api.dart`), en memoria, para las pruebas.
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
  static const notFound = 'NOT_FOUND';
  static const forbidden = 'FORBIDDEN';
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

  /// Mensaje para mostrar en una sola línea: el del primer campo con
  /// problema, o [message] si no hay campos (S5-07).
  String get displayMessage =>
      fields.isNotEmpty ? fields.values.first : message;

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

  /// Mapa con los mismos nombres que la API, para guardar la cuenta en el
  /// dispositivo junto con la sesión (S4-08). `fromMap(toMap())` devuelve
  /// la misma cuenta (UT-49).
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.role == role &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode =>
      Object.hash(id, name, email, role, createdAt.millisecondsSinceEpoch);
}

/// Sesión que devuelve el login (§3.2). La app guarda [accessToken] sin
/// leerlo: para ella es opaco (S4-08 lo guarda en el dispositivo).
class AuthSession {
  final String accessToken;

  /// Siempre `Bearer`.
  final String tokenType;

  /// Segundos que dura [accessToken].
  final int expiresIn;
  final AuthUser user;

  /// Desde S4-02 la API agrega el token de renovación. La app acepta la
  /// respuesta con o sin él (§3.2).
  final String? refreshToken;
  final int? refreshExpiresIn;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
    this.refreshToken,
    this.refreshExpiresIn,
  });

  factory AuthSession.fromMap(Map<String, dynamic> map) => AuthSession(
    accessToken: map['accessToken'] as String,
    tokenType: map['tokenType'] as String,
    expiresIn: (map['expiresIn'] as num).toInt(),
    user: AuthUser.fromMap(map['user'] as Map<String, dynamic>),
    refreshToken: map['refreshToken'] as String?,
    refreshExpiresIn: (map['refreshExpiresIn'] as num?)?.toInt(),
  );

  @override
  String toString() => 'AuthSession(${user.email}, expiresIn: $expiresIn)';
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

  /// `POST /api/auth/login` (§3.2). Lanza [ApiException]
  /// (`VALIDATION_FAILED`, `INVALID_CREDENTIALS`, `TOO_MANY_ATTEMPTS`,
  /// `INTERNAL`, `UNAVAILABLE`) o [NetworkException].
  Future<AuthSession> login({required String email, required String password});

  /// `GET /api/auth/me` (§3.3): la cuenta de la sesión de [accessToken].
  /// Lanza [ApiException] (`UNAUTHENTICATED` si el token no sirve,
  /// `INTERNAL`, `UNAVAILABLE`) o [NetworkException].
  Future<AuthUser> me(String accessToken);

  /// `POST /api/auth/refresh` (§3.5). Devuelve una sesión con los dos
  /// tokens **nuevos**: el [refreshToken] usado y el token de acceso
  /// anterior dejan de servir. Lanza [ApiException] (`UNAUTHENTICATED` si
  /// venció, ya se usó o la sesión se cerró; `VALIDATION_FAILED`,
  /// `INTERNAL`, `UNAVAILABLE`) o [NetworkException].
  Future<AuthSession> refresh(String refreshToken);

  /// `POST /api/auth/logout` (§3.4). Cierra en el servidor la sesión de
  /// [accessToken]; la API responde `204` aunque el token ya no sirva.
  /// Puede lanzar [ApiException] o [NetworkException]: quien llama borra la
  /// sesión guardada de todos modos.
  Future<void> logout(String accessToken);
}
