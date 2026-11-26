import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/income_model.dart';
import 'api_config.dart';
import 'auth_api.dart';

/// Ingreso como lo guarda la API: su `id` en el servidor (UUID), la
/// `version` para detectar cambios de otro dispositivo (HU-36) y los
/// datos, sin `id` local.
typedef RemoteIncome = ({String remoteId, int version, Income income});

/// `/api/incomes` (contrato §3.13, S5-02). Igual que `MovementsApi`: cada
/// método recibe el token de acceso, que quien llama obtiene con
/// `SessionProvider.authorized`. Lanza [ApiException] o
/// [NetworkException], igual que `HttpAuthApi`.
abstract class IncomesApi {
  /// Ingresos de la cuenta, del más reciente al más antiguo.
  Future<List<RemoteIncome>> list(String accessToken);

  /// Registra un ingreso. Responde con `version` 1.
  Future<RemoteIncome> create(String accessToken, Income income);

  /// Cambia el ingreso [remoteId]. Con [version] vieja la API responde
  /// `409 VERSION_CONFLICT` sin cambiar nada.
  Future<RemoteIncome> update(
    String accessToken,
    String remoteId,
    Income income, {
    int? version,
  });

  Future<void> delete(String accessToken, String remoteId);
}

/// [IncomesApi] por HTTP.
class HttpIncomesApi implements IncomesApi {
  HttpIncomesApi({
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
  Future<List<RemoteIncome>> list(String accessToken) async {
    final body = await _send('GET', '/api/incomes', accessToken);
    return _parse(
      () => (body['incomes'] as List)
          .map((i) => fromApi(i as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<RemoteIncome> create(String accessToken, Income income) async {
    final body = await _send(
      'POST',
      '/api/incomes',
      accessToken,
      body: toApi(income),
    );
    return _parse(() => fromApi(body['income'] as Map<String, dynamic>));
  }

  @override
  Future<RemoteIncome> update(
    String accessToken,
    String remoteId,
    Income income, {
    int? version,
  }) async {
    final body = await _send(
      'PUT',
      '/api/incomes/${Uri.encodeComponent(remoteId)}',
      accessToken,
      body: {...toApi(income), 'version': ?version},
    );
    return _parse(() => fromApi(body['income'] as Map<String, dynamic>));
  }

  @override
  Future<void> delete(String accessToken, String remoteId) async {
    await _send(
      'DELETE',
      '/api/incomes/${Uri.encodeComponent(remoteId)}',
      accessToken,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Cuerpo de `POST` y `PUT` (§3.13). La fecha va como `AAAA-MM-DD`,
  /// igual que en los movimientos, para que no cambie de día por la zona
  /// horaria del teléfono.
  static Map<String, Object?> toApi(Income i) => {
    'name': i.name,
    'amount': i.amount,
    'date': _day(i.date),
    'note': i.note,
  };

  /// Ingreso de la API. La fecha se toma por su día en UTC, el mismo que
  /// se envió.
  static RemoteIncome fromApi(Map<String, dynamic> map) {
    final utc = DateTime.parse(map['date'] as String).toUtc();
    return (
      remoteId: map['id'] as String,
      version: (map['version'] as num).toInt(),
      income: Income(
        name: map['name'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime(utc.year, utc.month, utc.day),
        note: map['note'] as String?,
      ),
    );
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
