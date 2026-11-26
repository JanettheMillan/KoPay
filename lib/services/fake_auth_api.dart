import 'dart:math';

import '../utils/auth_validators.dart';
import 'auth_api.dart';

/// [AuthApi] en memoria que responde como el contrato (S3-13) mientras
/// no existe el cliente HTTP (S4-07). **No guarda nada fuera de la app
/// ni se conecta a ningún servidor.**
///
/// Aplica las mismas reglas que Node: valida todos los campos a la vez,
/// guarda el correo normalizado y rechaza un correo repetido con
/// `409 EMAIL_TAKEN`. Las pruebas pueden simular un fallo con
/// [failNextWith] y una espera con [delay].
class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.delay = Duration.zero, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Espera antes de responder, para ver el estado "enviando".
  final Duration delay;
  final DateTime Function() _now;
  final Random _random = Random();

  final Map<String, AuthUser> _accounts = {};
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
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = _nextError;
    if (error != null) {
      _nextError = null;
      throw error;
    }

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
    return user;
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
