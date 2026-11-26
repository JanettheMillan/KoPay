import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart';

/// Contador que la persona usuaria autorizó (contrato §3.6, S4-05).
class AccountantGrant {
  /// Id del permiso; se usa para revocarlo.
  final String id;
  final String accountantId;
  final String accountantName;
  final String accountantEmail;
  final DateTime grantedAt;

  const AccountantGrant({
    required this.id,
    required this.accountantId,
    required this.accountantName,
    required this.accountantEmail,
    required this.grantedAt,
  });

  factory AccountantGrant.fromMap(Map<String, dynamic> map) {
    final accountant = map['accountant'] as Map<String, dynamic>;
    return AccountantGrant(
      id: map['id'] as String,
      accountantId: accountant['id'] as String,
      accountantName: accountant['name'] as String,
      accountantEmail: accountant['email'] as String,
      grantedAt: DateTime.parse(map['grantedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AccountantGrant &&
      other.id == id &&
      other.accountantId == accountantId &&
      other.accountantName == accountantName &&
      other.accountantEmail == accountantEmail &&
      other.grantedAt.isAtSameMomentAs(grantedAt);

  @override
  int get hashCode => Object.hash(id, accountantId, accountantEmail);
}

/// Rutas de `/api/accountants` (contrato §3.6, HU-38, HU-41). Cada método
/// recibe el token de acceso; la pantalla las llama con
/// `SessionProvider.authorized`, que renueva la sesión si venció.
abstract class AccountantsApi {
  /// `GET /api/accountants`: permisos vigentes, del más antiguo al más nuevo.
  Future<List<AccountantGrant>> list(String accessToken);

  /// `POST /api/accountants`. Lanza [ApiException] `NOT_FOUND` si no hay un
  /// contador con ese correo y `VALIDATION_FAILED` con
  /// `fields.accountantEmail` si el correo no es válido. Si ya estaba
  /// autorizado, devuelve el mismo permiso.
  Future<AccountantGrant> grant(String accessToken, String accountantEmail);

  /// `DELETE /api/accountants/:grantId`. Lanza [ApiException] `NOT_FOUND` si
  /// ya estaba revocado o no es de esta cuenta.
  Future<void> revoke(String accessToken, String grantId);
}

/// [AccountantsApi] por HTTP. Sigue las mismas reglas que `HttpAuthApi`
/// (S4-07): un error `{ error, code, fields? }` es [ApiException] y sin red,
/// tiempo agotado o una respuesta que no es JSON es [NetworkException].
class HttpAccountantsApi implements AccountantsApi {
  HttpAccountantsApi({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final bool _ownsClient;
  final Uri baseUrl;
  final Duration timeout;

  @override
  Future<List<AccountantGrant>> list(String accessToken) async {
    final body = await _send('GET', '/api/accountants', accessToken);
    return _parse(
      () => (body['grants'] as List)
          .map((g) => AccountantGrant.fromMap(g as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<AccountantGrant> grant(
    String accessToken,
    String accountantEmail,
  ) async {
    final body = await _send(
      'POST',
      '/api/accountants',
      accessToken,
      body: {'accountantEmail': accountantEmail},
    );
    return _parse(
      () => AccountantGrant.fromMap(body['grant'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> revoke(String accessToken, String grantId) async {
    await _send(
      'DELETE',
      '/api/accountants/${Uri.encodeComponent(grantId)}',
      accessToken,
    );
  }

  /// Cierra las conexiones si el cliente lo creó esta clase.
  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    String token, {
    Map<String, Object?>? body,
  }) async {
    final request =
        http.Request(method, baseUrl.replace(path: '${baseUrl.path}$path'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 204) return const {};
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const NetworkException();
      json = decoded;
    } on FormatException {
      throw const NetworkException();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    throw ApiException.fromBody(response.statusCode, json);
  }

  static T _parse<T>(T Function() read) {
    try {
      return read();
    } on TypeError {
      throw const NetworkException();
    } on FormatException {
      throw const NetworkException();
    }
  }
}
