import '../utils/auth_validators.dart';
import 'accountants_api.dart';
import 'auth_api.dart';

/// [AccountantsApi] en memoria que responde como el contrato §3.6, para
/// las pruebas y el recorrido sin servidor. **No se conecta a nada.**
///
/// [accountants] son las cuentas `accountant` que existen, por correo. Las
/// pruebas pueden simular un fallo con [failNextWith] y una espera con
/// [delay].
class FakeAccountantsApi implements AccountantsApi {
  FakeAccountantsApi({
    Map<String, String> accountants = const {},
    this.delay = Duration.zero,
    DateTime Function()? now,
  }) : _accountants = {
         for (final e in accountants.entries)
           AuthValidators.normalizeEmail(e.key): e.value,
       },
       _now = now ?? DateTime.now;

  /// Correo normalizado → nombre del contador.
  final Map<String, String> _accountants;
  final Duration delay;
  final DateTime Function() _now;
  final List<AccountantGrant> _grants = [];
  int _nextId = 1;
  Object? _nextError;

  /// Llamadas recibidas, por ejemplo `grant carla@conta.mx`.
  final List<String> calls = [];

  /// Permisos vigentes.
  List<AccountantGrant> get grants => List.unmodifiable(_grants);

  /// La siguiente llamada lanza [error] en vez de responder.
  void failNextWith(Object error) => _nextError = error;

  Future<void> _start(String call) async {
    calls.add(call);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = _nextError;
    if (error != null) {
      _nextError = null;
      throw error;
    }
  }

  @override
  Future<List<AccountantGrant>> list(String accessToken) async {
    await _start('list');
    return List.of(_grants);
  }

  @override
  Future<AccountantGrant> grant(
    String accessToken,
    String accountantEmail,
  ) async {
    final email = AuthValidators.normalizeEmail(accountantEmail);
    await _start('grant $email');
    final invalid = AuthValidators.email(email);
    if (invalid != null) {
      throw ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: {'accountantEmail': invalid},
      );
    }
    final name = _accountants[email];
    if (name == null) {
      throw const ApiException(
        404,
        ApiErrorCode.notFound,
        'No hay un contador con ese correo',
      );
    }
    for (final g in _grants) {
      if (g.accountantEmail == email) return g;
    }
    final grant = AccountantGrant(
      id: 'g-${_nextId++}',
      accountantId: 'c-$email',
      accountantName: name,
      accountantEmail: email,
      grantedAt: _now().toUtc(),
    );
    _grants.add(grant);
    return grant;
  }

  @override
  Future<void> revoke(String accessToken, String grantId) async {
    await _start('revoke $grantId');
    final before = _grants.length;
    _grants.removeWhere((g) => g.id == grantId);
    if (_grants.length == before) {
      throw const ApiException(
        404,
        ApiErrorCode.notFound,
        'No encontramos ese permiso',
      );
    }
  }
}
