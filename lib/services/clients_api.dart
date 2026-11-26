import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/accountant_client.dart';
import '../models/movement_model.dart';
import 'api_config.dart';
import 'auth_api.dart';
import 'incomes_api.dart';
import 'movements_api.dart';

/// Consultas del contador en `/api/clients` (contrato §3.10, S4-06 y
/// S5-03). Solo lectura (HU-42). Cada método recibe el token de acceso de
/// una cuenta `accountant`; la API revisa el permiso en cada petición y
/// responde `403 FORBIDDEN` si la persona ya no lo autoriza (HU-41).
/// Lanza [ApiException] o [NetworkException], igual que `HttpAuthApi`.
abstract class ClientsApi {
  /// Personas con permiso vigente, del permiso más antiguo al más nuevo.
  Future<List<ClientInfo>> list(String accessToken);

  /// Totales de [clientId] en [month].
  Future<PeriodSummary> summary(
    String accessToken,
    String clientId,
    DateTime month,
  );

  /// Movimientos e ingresos de [clientId] en [month], juntos y del más
  /// reciente al más antiguo. Los ingresos llegan como movimientos
  /// positivos con la categoría "Ingreso" (`Income.toMovement`).
  Future<List<Movement>> movements(
    String accessToken,
    String clientId,
    DateTime month,
  );
}

/// [ClientsApi] por HTTP.
class HttpClientsApi implements ClientsApi {
  HttpClientsApi({
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
  Future<List<ClientInfo>> list(String accessToken) async {
    final body = await _get('/api/clients', accessToken);
    return _parse(
      () => (body['clients'] as List)
          .map((c) => ClientInfo.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<PeriodSummary> summary(
    String accessToken,
    String clientId,
    DateTime month,
  ) async {
    final body = await _get(
      '/api/clients/${Uri.encodeComponent(clientId)}/summary',
      accessToken,
      month: month,
    );
    return _parse(() => PeriodSummary.fromMap(body));
  }

  @override
  Future<List<Movement>> movements(
    String accessToken,
    String clientId,
    DateTime month,
  ) async {
    final body = await _get(
      '/api/clients/${Uri.encodeComponent(clientId)}/movements',
      accessToken,
      month: month,
    );
    return _parse(() {
      final moves = [
        for (final m in body['movements'] as List)
          HttpMovementsApi.fromApi(m as Map<String, dynamic>).movement,
        for (final i in body['incomes'] as List)
          HttpIncomesApi.fromApi(i as Map<String, dynamic>).income.toMovement(),
      ];
      return moves..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Mes como `AAAA-MM`, el formato de `?month=` (§3.10).
  static String monthParam(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _get(
    String path,
    String token, {
    DateTime? month,
  }) async {
    final url = baseUrl.replace(
      path: '${baseUrl.path}$path',
      queryParameters: month == null ? null : {'month': monthParam(month)},
    );
    final request = http.Request('GET', url)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';

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
