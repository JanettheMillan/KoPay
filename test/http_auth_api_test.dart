// S4-07 · Cliente Flutter de autenticación con la API Node (HU-31).
//
// Sin red: package:http/testing.dart (MockClient) responde como la API.
// CON-15 es el caso de docs/contrato-api-acceso.md (respuestas 400, 401,
// 409 y sin red en Flutter). CLI-01 a CLI-14 son pruebas nuevas de S4-07 y
// CLI-15 a CLI-18 de S4-08 (renovar y cerrar sesión), anotadas en sus PR.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/services/api_config.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/http_auth_api.dart';

final _base = Uri.parse('http://api.prueba:3000');

const _user = {
  'id': '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f',
  'name': 'Ana López',
  'email': 'ana@mail.com',
  'role': 'user',
  'createdAt': '2026-11-26T18:30:00.000Z',
};

/// Respuesta JSON en UTF-8, como la manda Express.
http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Cliente que siempre responde [response] y guarda la última petición.
({HttpAuthApi api, List<http.Request> requests}) _apiAnswering(
  http.Response response,
) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return response;
  });
  return (api: HttpAuthApi(client: client, baseUrl: _base), requests: requests);
}

TypeMatcher<ApiException> _apiError(
  int status,
  String code, {
  Map<String, String>? fields,
}) => isA<ApiException>()
    .having((e) => e.status, 'status', status)
    .having((e) => e.code, 'code', code)
    .having((e) => e.fields, 'fields', fields ?? const <String, String>{});

void main() {
  group('Éxito', () {
    test('CLI-01 · HU-30 · register envía el JSON del contrato y devuelve la '
        'cuenta', () async {
      final (:api, :requests) = _apiAnswering(_json(201, {'user': _user}));

      final user = await api.register(
        name: 'Ana López',
        email: 'ana@mail.com',
        password: 'kopay2026',
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://api.prueba:3000/api/auth/register',
      );
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.headers['Accept'], 'application/json');
      expect(jsonDecode(request.body), {
        'name': 'Ana López',
        'email': 'ana@mail.com',
        'password': 'kopay2026',
      });
      expect(user.name, 'Ana López');
      expect(user.role, 'user');
      expect(user.createdAt, DateTime.utc(2026, 11, 26, 18, 30));
    });

    test('CLI-02 · HU-31 · login 200 devuelve token, tipo, vigencia y '
        'cuenta', () async {
      final (:api, :requests) = _apiAnswering(
        _json(200, {
          'accessToken': 'abc.def.ghi',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'user': _user,
        }),
      );

      final session = await api.login(
        email: 'ana@mail.com',
        password: 'kopay2026',
      );

      expect(requests.single.url.path, '/api/auth/login');
      expect(jsonDecode(requests.single.body), {
        'email': 'ana@mail.com',
        'password': 'kopay2026',
      });
      expect(session.accessToken, 'abc.def.ghi');
      expect(session.tokenType, 'Bearer');
      expect(session.expiresIn, 900);
      expect(session.user.email, 'ana@mail.com');
      expect(session.refreshToken, isNull);
    });

    test('CLI-03 · HU-31 · login acepta refreshToken cuando la API lo '
        'agrega (S4-02)', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(200, {
          'accessToken': 'abc',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'refreshToken': 'r123',
          'refreshExpiresIn': 2592000,
          'user': _user,
        }),
      );

      final session = await api.login(email: 'ana@mail.com', password: 'x');

      expect(session.refreshToken, 'r123');
      expect(session.refreshExpiresIn, 2592000);
    });

    test('CLI-04 · HU-31 · me manda el token como Bearer y devuelve la '
        'cuenta', () async {
      final (:api, :requests) = _apiAnswering(_json(200, {'user': _user}));

      final user = await api.me('abc.def.ghi');

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/auth/me');
      expect(request.headers['Authorization'], 'Bearer abc.def.ghi');
      expect(request.body, isEmpty);
      expect(user.id, _user['id']);
    });
  });

  group('CON-15 · HU-31 · errores de la API', () {
    test('400 VALIDATION_FAILED trae un mensaje por campo', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(400, {
          'error': 'Revisa los datos marcados',
          'code': 'VALIDATION_FAILED',
          'fields': {
            'email': 'Escribe un correo válido',
            'password': 'La contraseña debe tener al menos 8 caracteres',
          },
        }),
      );

      await expectLater(
        api.register(name: 'Ana', email: 'ana@', password: 'abc'),
        throwsA(
          _apiError(
            400,
            ApiErrorCode.validationFailed,
            fields: {
              'email': 'Escribe un correo válido',
              'password': 'La contraseña debe tener al menos 8 caracteres',
            },
          ),
        ),
      );
    });

    test('401 INVALID_CREDENTIALS en el login', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(401, {
          'error': 'Correo o contraseña incorrectos',
          'code': 'INVALID_CREDENTIALS',
        }),
      );

      await expectLater(
        api.login(email: 'ana@mail.com', password: 'mala'),
        throwsA(
          _apiError(401, ApiErrorCode.invalidCredentials).having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos',
          ),
        ),
      );
    });

    test('401 UNAUTHENTICATED en me con un token que ya no sirve', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(401, {
          'error': 'Inicia sesión para continuar',
          'code': 'UNAUTHENTICATED',
        }),
      );

      await expectLater(
        api.me('vencido'),
        throwsA(_apiError(401, ApiErrorCode.unauthenticated)),
      );
    });

    test('409 EMAIL_TAKEN en el registro', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(409, {
          'error': 'Ya existe una cuenta con ese correo',
          'code': 'EMAIL_TAKEN',
        }),
      );

      await expectLater(
        api.register(name: 'Ana', email: 'ana@mail.com', password: 'kopay2026'),
        throwsA(_apiError(409, ApiErrorCode.emailTaken)),
      );
    });

    test('503 UNAVAILABLE cuando la base no responde', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(503, {
          'error': 'El servicio no está disponible. Inténtalo de nuevo.',
          'code': 'UNAVAILABLE',
        }),
      );

      await expectLater(
        api.login(email: 'ana@mail.com', password: 'kopay2026'),
        throwsA(_apiError(503, ApiErrorCode.unavailable)),
      );
    });

    test('sin red → NetworkException', () async {
      final api = HttpAuthApi(
        client: MockClient(
          (_) async => throw http.ClientException('Connection refused'),
        ),
        baseUrl: _base,
      );

      await expectLater(
        api.login(email: 'ana@mail.com', password: 'kopay2026'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('Respuestas que no llegan o no son del contrato', () {
    test('CLI-05 · HU-31 · tiempo agotado → NetworkException', () async {
      final api = HttpAuthApi(
        client: MockClient((_) => Completer<http.Response>().future),
        baseUrl: _base,
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(api.me('abc'), throwsA(isA<NetworkException>()));
    });

    test('CLI-06 · HU-31 · el tiempo por defecto es de 10 segundos', () {
      expect(HttpAuthApi(baseUrl: _base).timeout, const Duration(seconds: 10));
    });

    test('CLI-07 · HU-31 · un cuerpo que no es JSON → NetworkException, aunque '
        'sea 200 o 502', () async {
      for (final status in [200, 502]) {
        final (:api, requests: _) = _apiAnswering(
          http.Response('<html>Bad Gateway</html>', status),
        );
        await expectLater(
          api.login(email: 'ana@mail.com', password: 'kopay2026'),
          throwsA(isA<NetworkException>()),
          reason: 'estado $status',
        );
      }
    });

    test('CLI-08 · HU-31 · JSON sin la forma del contrato → '
        'NetworkException', () async {
      for (final body in <Object>[
        [1, 2, 3],
        {'user': 'no es objeto'},
        {'accessToken': 'abc'},
      ]) {
        final (:api, requests: _) = _apiAnswering(_json(200, body));
        await expectLater(
          api.login(email: 'ana@mail.com', password: 'kopay2026'),
          throwsA(isA<NetworkException>()),
          reason: '$body',
        );
      }
    });

    test('CLI-09 · HU-31 · un error sin code se trata como INTERNAL', () async {
      final (:api, requests: _) = _apiAnswering(_json(500, {}));

      await expectLater(
        api.me('abc'),
        throwsA(_apiError(500, ApiErrorCode.internal)),
      );
    });

    test('CLI-10 · HU-30 · acentos y ñ llegan bien en UTF-8', () async {
      final (:api, :requests) = _apiAnswering(
        _json(201, {
          'user': {..._user, 'name': 'Begoña Núñez'},
        }),
      );

      final user = await api.register(
        name: 'Begoña Núñez',
        email: 'bego@mail.com',
        password: 'mañana2026',
      );

      expect(user.name, 'Begoña Núñez');
      expect(utf8.decode(requests.single.bodyBytes), contains('mañana2026'));
    });
  });

  group('Renovar y cerrar sesión (S4-08)', () {
    test('CLI-15 · HU-31 · refresh manda solo el refreshToken, sin '
        'Authorization, y devuelve los tokens nuevos', () async {
      final (:api, :requests) = _apiAnswering(
        _json(200, {
          'accessToken': 'acc-2',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'refreshToken': 'ref-2',
          'refreshExpiresIn': 2592000,
          'user': _user,
        }),
      );

      final session = await api.refresh('ref-1');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/refresh');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {'refreshToken': 'ref-1'});
      expect(session.accessToken, 'acc-2');
      expect(session.refreshToken, 'ref-2');
    });

    test('CLI-16 · HU-31 · refresh vencido o ya usado → 401 '
        'UNAUTHENTICATED', () async {
      final (:api, requests: _) = _apiAnswering(
        _json(401, {
          'error': 'Inicia sesión para continuar',
          'code': 'UNAUTHENTICATED',
        }),
      );

      await expectLater(
        api.refresh('ref-usado'),
        throwsA(_apiError(401, ApiErrorCode.unauthenticated)),
      );
    });

    test('CLI-17 · HU-33 · logout manda el token como Bearer y acepta 204 sin '
        'cuerpo', () async {
      final (:api, :requests) = _apiAnswering(http.Response('', 204));

      await api.logout('acc-1');

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/logout');
      expect(request.headers['Authorization'], 'Bearer acc-1');
    });

    test('CLI-18 · HU-33 · logout sin red → NetworkException', () async {
      final api = HttpAuthApi(
        client: MockClient((_) async => throw http.ClientException('sin red')),
        baseUrl: _base,
      );

      await expectLater(api.logout('acc-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('API_URL', () {
    test('CLI-11 · HU-31 · por defecto apunta a la computadora desde el '
        'emulador Android', () {
      // Estas pruebas corren sin --dart-define.
      expect(ApiConfig.apiUrl, 'http://10.0.2.2:3000');
      expect(ApiConfig.baseUrl, Uri.parse('http://10.0.2.2:3000'));
      expect(HttpAuthApi().baseUrl, ApiConfig.baseUrl);
    });

    test('CLI-12 · HU-31 · la URL se limpia y se arma bien con o sin '
        'diagonal final', () async {
      expect(
        ApiConfig.parse(' https://api.kopay.mx/ '),
        Uri.parse('https://api.kopay.mx'),
      );
      expect(
        ApiConfig.parse('https://kopay.mx/api-v1/'),
        Uri.parse('https://kopay.mx/api-v1'),
      );

      final requests = <http.Request>[];
      final api = HttpAuthApi(
        client: MockClient((r) async {
          requests.add(r);
          return _json(200, {'user': _user});
        }),
        baseUrl: ApiConfig.parse('https://kopay.mx/api-v1/'),
      );
      await api.me('abc');
      expect(
        requests.single.url.toString(),
        'https://kopay.mx/api-v1/api/auth/me',
      );
    });

    test('CLI-13 · HU-31 · una API_URL que no es http(s) se rechaza', () {
      for (final url in ['10.0.2.2:3000', 'ftp://kopay.mx', 'http://', '']) {
        expect(() => ApiConfig.parse(url), throwsFormatException, reason: url);
      }
    });
  });

  test(
    'CLI-14 · HU-31 · FakeAuthApi responde login y me como el contrato',
    () async {
      final api = FakeAuthApi();
      await api.register(
        name: 'Ana López',
        email: 'Ana@Mail.com',
        password: 'kopay2026',
      );

      final session = await api.login(
        email: ' ANA@mail.com ',
        password: 'kopay2026',
      );
      expect(session.tokenType, 'Bearer');
      expect((await api.me(session.accessToken)).email, 'ana@mail.com');

      await expectLater(
        api.login(email: 'ana@mail.com', password: 'otra2026'),
        throwsA(_apiError(401, ApiErrorCode.invalidCredentials)),
      );
      await expectLater(
        api.login(email: 'nadie@mail.com', password: 'kopay2026'),
        throwsA(_apiError(401, ApiErrorCode.invalidCredentials)),
      );
      await expectLater(
        api.login(email: '', password: ''),
        throwsA(
          _apiError(
            400,
            ApiErrorCode.validationFailed,
            fields: {
              'email': 'Escribe tu correo',
              'password': 'Escribe tu contraseña',
            },
          ),
        ),
      );
      await expectLater(
        api.me('no-existe'),
        throwsA(_apiError(401, ApiErrorCode.unauthenticated)),
      );
    },
  );
}
