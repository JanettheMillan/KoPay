import 'dart:math';

import '../utils/auth_validators.dart';
import 'auth_api.dart';

/// [AuthApi] en memoria que responde como el contrato (S3-13) mientras
/// no existe el cliente HTTP (S4-07). **No guarda nada fuera de la app
/// ni se conecta a ningún servidor.**
///
/// Aplica las mismas reglas que Node: valida todos los campos a la vez,
/// guarda el correo normalizado, rechaza un correo repetido con
/// `409 EMAIL_TAKEN` y responde el login, `me`, la renovación con
/// rotación y el cierre de sesión como §3.2 a §3.5. Las pruebas pueden simular un fallo con
/// [failNextWith] y una espera con [delay].
class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.delay = Duration.zero, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Espera antes de responder, para ver el estado "enviando".
  final Duration delay;
  final DateTime Function() _now;
  final Random _random = Random();

  final Map<String, AuthUser> _accounts = {};
  final Map<String, String> _passwords = {};

  /// Token de acceso → correo de la sesión.
  final Map<String, String> _sessions = {};

  /// Token de renovación → correo y token de acceso de esa sesión.
  final Map<String, ({String email, String access})> _refreshTokens = {};
  Object? _nextError;

  /// Cuentas registradas, por correo normalizado.
  Map<String, AuthUser> get accounts => Map.unmodifiable(_accounts);

  /// La siguiente llamada lanza [error] en vez de responder.
  void failNextWith(Object error) => _nextError = error;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _beforeAnswer();

    final fields = AuthValidators.registration(
      name: name,
      email: email,
      password: password,
    );
    if (fields.isNotEmpty) {
      throw ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: fields,
      );
    }
    final normalized = AuthValidators.normalizeEmail(email);
    if (_accounts.containsKey(normalized)) {
      throw const ApiException(
        409,
        ApiErrorCode.emailTaken,
        'Ya existe una cuenta con ese correo',
      );
    }
    final user = AuthUser(
      id: _uuid(),
      name: name.trim(),
      email: normalized,
      role: 'user',
      createdAt: _now().toUtc(),
    );
    _accounts[normalized] = user;
    // Solo en memoria y solo para pruebas: la API real guarda un hash.
    _passwords[normalized] = password;
    return user;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await _beforeAnswer();
    final fields = {
      if (AuthValidators.normalizeEmail(email).isEmpty)
        'email': AuthValidators.emailRequired,
      'password': ?AuthValidators.password(password),
    };
    if (fields.isNotEmpty) {
      throw ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: fields,
      );
    }
    final normalized = AuthValidators.normalizeEmail(email);
    final user = _accounts[normalized];
    // Mismo error si el correo no existe o la contraseña no coincide.
    if (user == null || _passwords[normalized] != password) {
      throw const ApiException(
        401,
        ApiErrorCode.invalidCredentials,
        'Correo o contraseña incorrectos',
      );
    }
    return _openSession(normalized);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    await _beforeAnswer();
    final pair = _refreshTokens.remove(refreshToken);
    if (pair == null || !_accounts.containsKey(pair.email)) {
      throw const ApiException(
        401,
        ApiErrorCode.unauthenticated,
        'Inicia sesión para continuar',
      );
    }
    // Rotación (§3.5): el token de acceso de esa sesión también deja de
    // servir. Las sesiones de otros dispositivos siguen abiertas.
    _sessions.remove(pair.access);
    return _openSession(pair.email);
  }

  @override
  Future<void> logout(String accessToken) async {
    await _beforeAnswer();
    // Cierra solo esa sesión (§3.4).
    _sessions.remove(accessToken);
    _refreshTokens.removeWhere((_, pair) => pair.access == accessToken);
  }

  /// Abre una sesión con tokens nuevos, como el login y la renovación.
  AuthSession _openSession(String email) {
    final access = _uuid();
    final refresh = _uuid();
    _sessions[access] = email;
    _refreshTokens[refresh] = (email: email, access: access);
    return AuthSession(
      accessToken: access,
      tokenType: 'Bearer',
      expiresIn: 900,
      user: _accounts[email]!,
      refreshToken: refresh,
      refreshExpiresIn: 2592000,
    );
  }

  @override
  Future<AuthUser> me(String accessToken) async {
    await _beforeAnswer();
    final user = _accounts[_sessions[accessToken]];
    if (user == null) {
      throw const ApiException(
        401,
        ApiErrorCode.unauthenticated,
        'Inicia sesión para continuar',
      );
    }
    return user;
  }

  /// Espera [delay] y lanza el error de [failNextWith], si hay uno.
  Future<void> _beforeAnswer() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = _nextError;
    if (error != null) {
      _nextError = null;
      throw error;
    }
  }

  /// UUID v4 de texto, como los de `gen_random_uuid()`.
  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
