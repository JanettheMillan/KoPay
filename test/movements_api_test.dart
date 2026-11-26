// S5-07 · Cliente HTTP de movimientos (HU-01, HU-05, HU-06).
//
// Sin red: MockClient responde como /api/movements (contrato §3.12).
// El plan de pruebas no tiene casos del cliente de movimientos; MVA-01 a
// MVA-08 son pruebas nuevas, anotadas en el PR.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/movements_api.dart';

final _base = Uri.parse('http://api.prueba:3000');

Map<String, Object?> _apiMov({
  String id = 'b1c2',
  num amount = -150.5,
  String date = '2026-11-26T00:00:00.000Z',
  int version = 1,
  String type = 'regular',
  String? note,
}) => {
  'id': id,
  'amount': amount,
  'description': 'Súper',
  'category': 'Comida',
  'date': date,
  'note': note,
  'type': type,
  'cardId': null,
  'debtId': null,
  'version': version,
  'createdAt': '2026-11-26T18:30:00.000Z',
  'updatedAt': '2026-11-26T18:30:00.000Z',
};

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

({HttpMovementsApi api, List<http.Request> requests}) _answering(
  http.Response response,
) {
  final requests = <http.Request>[];
  return (
    api: HttpMovementsApi(
      client: MockClient((r) async {
        requests.add(r);
        return response;
      }),
      baseUrl: _base,
    ),
    requests: requests,
  );
}

final _gasto = Movement(
  amount: -150.5,
  description: 'Súper',
  category: 'Comida',
  date: DateTime(2026, 11, 26, 21, 45),
  note: 'con Ana',
);

void main() {
  test('MVA-01 · HU-07 · list manda el token y lee los movimientos', () async {
    final (:api, :requests) = _answering(
      _json(200, {
        'movements': [_apiMov(), _apiMov(id: 'b2', amount: 500, version: 3)],
      }),
    );

    final lista = await api.list('tok');

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/movements');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
    expect(lista.map((r) => r.remoteId), ['b1c2', 'b2']);
    expect(lista[1].version, 3);
    expect(lista[1].movement.amount, 500);
    expect(lista[0].movement.description, 'Súper');
  });

  test('MVA-02 · HU-01 · create envía la fecha como AAAA-MM-DD, sin hora ni '
      'zona', () async {
    final (:api, :requests) = _answering(
      _json(201, {'movement': _apiMov(note: 'con Ana')}),
    );

    final creado = await api.create('tok', _gasto);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.method, 'POST');
    expect(body, {
      'amount': -150.5,
      'description': 'Súper',
      'category': 'Comida',
      'date': '2026-11-26',
      'note': 'con Ana',
    });
    expect(creado.remoteId, 'b1c2');
    expect(creado.version, 1);
  });

  test('MVA-03 · HU-01 · la fecha de la API se lee como el mismo día, sin '
      'importar la zona del teléfono', () {
    final r = HttpMovementsApi.fromApi(
      _apiMov(date: '2026-11-01T00:00:00.000Z'),
    );

    expect(r.movement.date, DateTime(2026, 11, 1));
  });

  test('MVA-04 · HU-05 · update manda la versión leída', () async {
    final (:api, :requests) = _answering(
      _json(200, {'movement': _apiMov(version: 2)}),
    );

    final r = await api.update('tok', 'b1c2', _gasto, version: 1);

    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/movements/b1c2');
    expect((jsonDecode(requests.single.body) as Map)['version'], 1);
    expect(r.version, 2);
  });

  test('MVA-05 · HU-36 · una versión vieja llega como 409 '
      'VERSION_CONFLICT', () async {
    final (:api, requests: _) = _answering(
      _json(409, {
        'error': 'El movimiento cambió en otro dispositivo. Vuelve a cargarlo.',
        'code': 'VERSION_CONFLICT',
      }),
    );

    await expectLater(
      api.update('tok', 'b1c2', _gasto, version: 1),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'VERSION_CONFLICT')
            .having(
              (e) => e.displayMessage,
              'displayMessage',
              'El movimiento cambió en otro dispositivo. Vuelve a cargarlo.',
            ),
      ),
    );
  });

  test('MVA-06 · HU-06 · delete acepta 204 sin cuerpo', () async {
    final (:api, :requests) = _answering(http.Response('', 204));

    await api.delete('tok', 'b1c2');

    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/movements/b1c2');
  });

  test(
    'MVA-07 · HU-04 · un 400 trae el mensaje del campo para mostrarlo',
    () async {
      final (:api, requests: _) = _answering(
        _json(400, {
          'error': 'Revisa los datos marcados',
          'code': 'VALIDATION_FAILED',
          'fields': {
            'description': 'La descripción puede tener hasta 60 caracteres',
          },
        }),
      );

      await expectLater(
        api.create('tok', _gasto),
        throwsA(
          isA<ApiException>().having(
            (e) => e.displayMessage,
            'displayMessage',
            'La descripción puede tener hasta 60 caracteres',
          ),
        ),
      );
    },
  );

  test('MVA-08 · HU-01 · sin red, tiempo agotado o respuesta que no es JSON → '
      'NetworkException', () async {
    final sinRed = HttpMovementsApi(
      client: MockClient((_) async => throw http.ClientException('sin red')),
      baseUrl: _base,
    );
    final html = _answering(http.Response('<html>502</html>', 502)).api;
    final lento = HttpMovementsApi(
      client: MockClient(
        (_) => Future.delayed(const Duration(seconds: 1), () => _json(200, {})),
      ),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 20),
    );

    for (final api in [sinRed, html, lento]) {
      await expectLater(api.list('tok'), throwsA(isA<NetworkException>()));
    }
  });
}
