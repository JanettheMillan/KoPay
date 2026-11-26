import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_api.dart';

/// [AuthApi] que habla con la API Node por HTTP (S4-07, HU-31).
///
/// Sigue docs/contrato-api-acceso.md:
/// - Una respuesta `{ error, code, fields? }` se convierte en
///   [ApiException.fromBody].
/// - Sin red, con tiempo agotado o con una respuesta que no es JSON
///   (o no tiene la forma del contrato) lanza [NetworkException].
///
/// [client] y [baseUrl] se pueden reemplazar en las pruebas.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final bool _ownsClient;

  /// Dirección de la API, por ejemplo `http://10.0.2.2:3000`.
  final Uri baseUrl;

  /// Tiempo máximo de espera de cada petición.
  final Duration timeout;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/api/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return _parse(() => AuthUser.fromMap(body['user'] as Map<String, dynamic>));
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return _parse(() => AuthSession.fromMap(body));
  }

  @override
  Future<AuthUser> me(String accessToken) async {
    final body = await _send('GET', '/api/auth/me', token: accessToken);
    return _parse(() => AuthUser.fromMap(body['user'] as Map<String, dynamic>));
  }

  /// Cierra las conexiones si el cliente lo creó esta clase.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Hace la petición y devuelve el cuerpo JSON de una respuesta 2xx.
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final request = http.Request(method, _url(path))
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
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
      // Sin red, servidor apagado o conexión cortada.
      throw const NetworkException();
    }

    final json = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    throw ApiException.fromBody(response.statusCode, json);
  }

  Uri _url(String path) => baseUrl.replace(path: '${baseUrl.path}$path');

  /// Cuerpo JSON (objeto) de la respuesta, o [NetworkException] si no lo es,
  /// por ejemplo una página HTML de un proxy.
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Sigue abajo.
    }
    throw const NetworkException();
  }

  /// Lee una respuesta 2xx; si no tiene la forma del contrato es como si
  /// no fuera JSON.
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
