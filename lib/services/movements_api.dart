import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/movement_model.dart';
import 'api_config.dart';
import 'auth_api.dart';

/// Movimiento como lo guarda la API: su `id` en el servidor (UUID), la
/// `version` para detectar cambios de otro dispositivo (HU-36) y los
/// datos, sin `id` local.
typedef RemoteMovement = ({String remoteId, int version, Movement movement});

/// `/api/movements` (contrato §3.12, S5-01). Cada método recibe el token
/// de acceso; quien llama usa `SessionProvider.authorized`, que lo renueva
/// si venció. Lanza [ApiException] o [NetworkException], igual que
/// `HttpAuthApi`.
abstract class MovementsApi {
  /// Movimientos de la cuenta, del más reciente al más antiguo.
  Future<List<RemoteMovement>> list(String accessToken);

  /// Crea un movimiento normal. Responde con `version` 1.
  Future<RemoteMovement> create(String accessToken, Movement movement);

  /// Cambia el movimiento [remoteId]. Con [version] vieja la API responde
  /// `409 VERSION_CONFLICT` sin cambiar nada.
  Future<RemoteMovement> update(
    String accessToken,
    String remoteId,
    Movement movement, {
    int? version,
  });

  Future<void> delete(String accessToken, String remoteId);
}

/// [MovementsApi] por HTTP.
class HttpMovementsApi implements MovementsApi {
  HttpMovementsApi({
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
  Future<List<RemoteMovement>> list(String accessToken) async {
    final body = await _send('GET', '/api/movements', accessToken);
    return _parse(
      () => (body['movements'] as List)
          .map((m) => fromApi(m as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<RemoteMovement> create(String accessToken, Movement movement) async {
    final body = await _send(
      'POST',
      '/api/movements',
      accessToken,
      body: toApi(movement),
    );
    return _parse(() => fromApi(body['movement'] as Map<String, dynamic>));
  }

  @override
  Future<RemoteMovement> update(
    String accessToken,
    String remoteId,
    Movement movement, {
    int? version,
  }) async {
    final body = await _send(
      'PUT',
      '/api/movements/${Uri.encodeComponent(remoteId)}',
      accessToken,
      body: {...toApi(movement), 'version': ?version},
    );
    return _parse(() => fromApi(body['movement'] as Map<String, dynamic>));
  }

  @override
  Future<void> delete(String accessToken, String remoteId) async {
    await _send(
      'DELETE',
      '/api/movements/${Uri.encodeComponent(remoteId)}',
      accessToken,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Cuerpo de `POST` y `PUT` (§3.12). La fecha va como `AAAA-MM-DD`: la
  /// API la guarda a las 00:00 UTC, y así no cambia de día por la zona
  /// horaria del teléfono.
  static Map<String, Object?> toApi(Movement m) => {
    'amount': m.amount,
    'description': m.description,
    'category': m.category,
    'date': _day(m.date),
    'note': m.note,
  };

  /// Movimiento de la API. La fecha se toma por su día en UTC, el mismo
  /// que se envió.
  static RemoteMovement fromApi(Map<String, dynamic> map) {
    final utc = DateTime.parse(map['date'] as String).toUtc();
    return (
      remoteId: map['id'] as String,
      version: (map['version'] as num).toInt(),
      movement: Movement(
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        category: map['category'] as String,
        date: DateTime(utc.year, utc.month, utc.day),
        note: map['note'] as String?,
        type: MovementType.fromName(map['type'] as String?),
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
