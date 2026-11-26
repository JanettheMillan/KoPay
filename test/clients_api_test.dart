// S5-09 · Cliente HTTP de las consultas del contador (HU-39, HU-40,
// HU-41).
//
// Sin red: MockClient responde como /api/clients (contrato §3.10). El plan
// de pruebas no tiene casos de este cliente; CLA-01 a CLA-06 son pruebas
// nuevas, anotadas en el PR.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/clients_api.dart';

final _base = Uri.parse('http://api.prueba:3000');

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

({HttpClientsApi api, List<http.Request> requests}) _answering(
  http.Response response,
) {
  final requests = <http.Request>[];
  return (
    api: HttpClientsApi(
      client: MockClient((r) async {
        requests.add(r);
        return response;
      }),
      baseUrl: _base,
    ),
    requests: requests,
  );
}

Map<String, Object?> _mov(String id, num amount, String day, {String? type}) =>
    {
      'id': id,
      'amount': amount,
      'description': 'Mov $id',
      'category': 'Comida',
      'date': '${day}T00:00:00.000Z',
      'note': null,
      'type': type ?? 'regular',
      'cardId': null,
      'debtId': null,
      'version': 1,
      'createdAt': '2026-11-26T18:30:00.000Z',
      'updatedAt': '2026-11-26T18:30:00.000Z',
    };

const _forbidden = {
  'error': 'No tienes acceso a los datos de esta persona',
  'code': 'FORBIDDEN',
};

void main() {
  final noviembre = DateTime(2026, 11);

  test('CLA-01 · HU-39 · list manda el token y lee los clientes con su '
      'fecha de autorización', () async {
    final (:api, :requests) = _answering(
      _json(200, {
        'clients': [
          {
            'id': 'u1',
            'name': 'Ana',
            'email': 'ana@mail.com',
            'grantedAt': '2026-11-20T18:00:00.000Z',
          },
        ],
      }),
    );

    final clientes = await api.list('tok');

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/clients');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
    expect(clientes.single.id, 'u1');
    expect(clientes.single.email, 'ana@mail.com');
    expect(
      clientes.single.grantedAt.isAtSameMomentAs(
        DateTime.utc(2026, 11, 20, 18),
      ),
      isTrue,
    );
  });

  test('CLA-02 · HU-40 · summary pide solo ese cliente y ese mes '
      '(AAAA-MM)', () async {
    final (:api, :requests) = _answering(
      _json(200, {
        'month': '2026-11',
        'income': 15000,
        'expenses': 7750.5,
        'payments': 2000,
        'balance': 5249.5,
      }),
    );

    final resumen = await api.summary('tok', 'u1', noviembre);

    expect(requests.single.url.path, '/api/clients/u1/summary');
    expect(requests.single.url.queryParameters, {'month': '2026-11'});
    expect(resumen.income, 15000);
    expect(resumen.expenses, 7750.5);
    expect(resumen.cardPayments, 2000);
    expect(resumen.balance, 5249.5);
    expect(HttpClientsApi.monthParam(DateTime(2027, 2, 28)), '2027-02');
  });

  test('CLA-03 · HU-40 · movements junta gastos, pagos e ingresos del mes, '
      'del más reciente al más antiguo', () async {
    final (:api, :requests) = _answering(
      _json(200, {
        'movements': [
          _mov('m2', -300, '2026-11-20'),
          _mov('m1', -2000, '2026-11-08', type: 'payment'),
        ],
        'incomes': [
          {
            'id': 'i1',
            'name': 'Nómina',
            'amount': 15000,
            'date': '2026-11-15T00:00:00.000Z',
            'note': null,
            'version': 1,
            'createdAt': '2026-11-26T18:30:00.000Z',
            'updatedAt': '2026-11-26T18:30:00.000Z',
          },
        ],
      }),
    );

    final lista = await api.movements('tok', 'u1', noviembre);

    expect(requests.single.url.path, '/api/clients/u1/movements');
    expect(requests.single.url.queryParameters, {'month': '2026-11'});
    expect(lista.map((m) => m.description), ['Mov m2', 'Nómina', 'Mov m1']);
    expect(lista[1].category, Income.category);
    expect(lista[1].amount, 15000);
    expect(lista[1].date, DateTime(2026, 11, 15));
    expect(lista[2].type, MovementType.payment);
  });

  test('CLA-04 · HU-41 · sin permiso vigente la API responde 403 y llega '
      'como ApiException', () async {
    final (:api, requests: _) = _answering(_json(403, _forbidden));

    for (final call in [
      () => api.summary('tok', 'u1', noviembre),
      () => api.movements('tok', 'u1', noviembre),
    ]) {
      await expectLater(
        call(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    }
  });

  test('CLA-05 · HU-40 · el id del cliente va codificado en la ruta', () async {
    final (:api, :requests) = _answering(_json(403, _forbidden));

    await expectLater(
      api.summary('tok', '../accountants', noviembre),
      throwsA(isA<ApiException>()),
    );

    expect(requests.single.url.path, '/api/clients/..%2Faccountants/summary');
  });

  test('CLA-06 · HU-39 · sin red, tiempo agotado o respuesta mal formada → '
      'NetworkException', () async {
    final sinRed = HttpClientsApi(
      client: MockClient((_) async => throw http.ClientException('sin red')),
      baseUrl: _base,
    );
    final html = _answering(http.Response('<html>502</html>', 502)).api;
    final lento = HttpClientsApi(
      client: MockClient(
        (_) => Future.delayed(const Duration(seconds: 1), () => _json(200, {})),
      ),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 20),
    );
    final malFormado = _answering(_json(200, {'clients': 'nada'})).api;

    for (final api in [sinRed, html, lento, malFormado]) {
      await expectLater(api.list('tok'), throwsA(isA<NetworkException>()));
    }
  });
}
