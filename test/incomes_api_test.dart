// S5-08 · Cliente HTTP de ingresos (HU-02, HU-09).
//
// Sin red: MockClient responde como /api/incomes (contrato §3.13).
// El plan de pruebas no tiene casos del cliente de ingresos; INA-01 a
// INA-07 son pruebas nuevas, anotadas en el PR.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/incomes_api.dart';

final _base = Uri.parse('http://api.prueba:3000');

Map<String, Object?> _apiIncome({
  String id = 'c3d4',
  num amount = 12500,
  String date = '2026-11-15T00:00:00.000Z',
  int version = 1,
  String? note,
}) => {
  'id': id,
  'name': 'Nómina',
  'amount': amount,
  'date': date,
  'note': note,
  'version': version,
  'createdAt': '2026-11-26T18:30:00.000Z',
  'updatedAt': '2026-11-26T18:30:00.000Z',
};

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

({HttpIncomesApi api, List<http.Request> requests}) _answering(
  http.Response response,
) {
  final requests = <http.Request>[];
  return (
    api: HttpIncomesApi(
      client: MockClient((r) async {
        requests.add(r);
        return response;
      }),
      baseUrl: _base,
    ),
    requests: requests,
  );
}

final _nomina = Income(
  name: 'Nómina',
  amount: 12500,
  date: DateTime(2026, 11, 15, 21, 45),
  note: 'quincena',
);

void main() {
  test(
    'INA-01 · HU-09 · list manda el token y lee los ingresos de la cuenta',
    () async {
      final (:api, :requests) = _answering(
        _json(200, {
          'incomes': [
            _apiIncome(),
            _apiIncome(id: 'c5', amount: 800.5, version: 3),
          ],
        }),
      );

      final lista = await api.list('tok');

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/incomes');
      expect(requests.single.headers['Authorization'], 'Bearer tok');
      expect(lista.map((r) => r.remoteId), ['c3d4', 'c5']);
      expect(lista[1].version, 3);
      expect(lista[1].income.amount, 800.5);
      expect(lista[0].income.name, 'Nómina');
      expect(lista[0].income.id, isNull);
    },
  );

  test('INA-02 · HU-02 · create envía nombre, monto, fecha AAAA-MM-DD y '
      'nota', () async {
    final (:api, :requests) = _answering(
      _json(201, {'income': _apiIncome(note: 'quincena')}),
    );

    final creado = await api.create('tok', _nomina);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/incomes');
    expect(body, {
      'name': 'Nómina',
      'amount': 12500,
      'date': '2026-11-15',
      'note': 'quincena',
    });
    expect(creado.remoteId, 'c3d4');
    expect(creado.version, 1);
    expect(creado.income.note, 'quincena');
  });

  test('INA-03 · HU-09 · la fecha de la API se lee como el mismo día, sin '
      'importar la zona del teléfono', () {
    final r = HttpIncomesApi.fromApi(
      _apiIncome(date: '2026-12-01T00:00:00.000Z'),
    );

    // Si se leyera en hora local (UTC-6) caería en noviembre y el resumen
    // del mes en Inicio saldría mal.
    expect(r.income.date, DateTime(2026, 12, 1));
  });

  test('INA-04 · HU-02 · update manda la versión leída', () async {
    final (:api, :requests) = _answering(
      _json(200, {'income': _apiIncome(version: 2)}),
    );

    final r = await api.update('tok', 'c3d4', _nomina, version: 1);

    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/incomes/c3d4');
    expect((jsonDecode(requests.single.body) as Map)['version'], 1);
    expect(r.version, 2);
  });

  test('INA-05 · HU-36 · una versión vieja llega como 409 '
      'VERSION_CONFLICT con su mensaje', () async {
    final (:api, requests: _) = _answering(
      _json(409, {
        'error': 'El ingreso cambió en otro dispositivo. Vuelve a cargarlo.',
        'code': 'VERSION_CONFLICT',
      }),
    );

    await expectLater(
      api.update('tok', 'c3d4', _nomina, version: 1),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'VERSION_CONFLICT')
            .having(
              (e) => e.displayMessage,
              'displayMessage',
              'El ingreso cambió en otro dispositivo. Vuelve a cargarlo.',
            ),
      ),
    );
  });

  test(
    'INA-06 · HU-02 · delete acepta 204 y un 400 trae el mensaje del campo',
    () async {
      final borrar = _answering(http.Response('', 204));
      await borrar.api.delete('tok', 'c3d4');
      expect(borrar.requests.single.method, 'DELETE');
      expect(borrar.requests.single.url.path, '/api/incomes/c3d4');

      final (:api, requests: _) = _answering(
        _json(400, {
          'error': 'Revisa los datos marcados',
          'code': 'VALIDATION_FAILED',
          'fields': {'name': 'El nombre puede tener hasta 60 caracteres'},
        }),
      );
      await expectLater(
        api.create('tok', _nomina),
        throwsA(
          isA<ApiException>().having(
            (e) => e.displayMessage,
            'displayMessage',
            'El nombre puede tener hasta 60 caracteres',
          ),
        ),
      );
    },
  );

  test('INA-07 · HU-02 · sin red, tiempo agotado o respuesta que no es JSON → '
      'NetworkException', () async {
    final sinRed = HttpIncomesApi(
      client: MockClient((_) async => throw http.ClientException('sin red')),
      baseUrl: _base,
    );
    final html = _answering(http.Response('<html>502</html>', 502)).api;
    final lento = HttpIncomesApi(
      client: MockClient(
        (_) => Future.delayed(const Duration(seconds: 1), () => _json(200, {})),
      ),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 20),
    );
    final malFormado = _answering(_json(200, {'incomes': 'nada'})).api;

    for (final api in [sinRed, html, lento, malFormado]) {
      await expectLater(api.list('tok'), throwsA(isA<NetworkException>()));
    }
  });
}
