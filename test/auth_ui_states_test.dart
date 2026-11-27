// S3-17 · Interfaz de registro e inicio de sesión: carga, error y éxito
// (HU-30 y HU-31).
//
// Las pruebas de pantalla de S3-10 y S3-11 usan FakeAuthApi, que reemplaza
// al cliente completo. Estos casos nuevos (UI-AUTH-xx) usan las pantallas
// con el cliente real (HttpAuthApi) y solo simulan las respuestas HTTP del
// contrato (docs/contrato-api-acceso.md). No usan la API ni la base reales:
// eso es S3-18. Están descritos en docs/casos-s3-17.md.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/login_screen.dart';
import 'package:kopay/screens/register_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/http_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/auth_validators.dart';
import 'package:provider/provider.dart';

class _SpanishSettings extends SettingsProvider {
  @override
  String get language => 'es';
}

const _user = {
  'id': '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f',
  'name': 'Ana López',
  'email': 'ana@mail.com',
  'role': 'user',
  'createdAt': '2026-11-26T18:30:00.000Z',
};

const _session = {
  'accessToken': 'token-de-prueba',
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'user': _user,
};

const _tooMany =
    'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _error(int status, String code, String message) =>
    _json(status, {'error': message, 'code': code});

/// Servidor simulado: guarda las peticiones y responde con lo que se haya
/// puesto en la cola, en orden.
class _Server {
  final requests = <http.Request>[];
  final _queue = <Future<http.Response>>[];

  void reply(http.Response response) => _queue.add(Future.value(response));

  /// Deja la siguiente petición esperando hasta completar el resultado.
  Completer<http.Response> hold() {
    final completer = Completer<http.Response>();
    _queue.add(completer.future);
    return completer;
  }

  http.Client get client => MockClient((request) {
    requests.add(request);
    return _queue.removeAt(0);
  });
}

void main() {
  late _Server server;
  late SessionProvider session;
  late HttpAuthApi api;

  setUp(() {
    server = _Server();
    api = HttpAuthApi(
      client: server.client,
      baseUrl: Uri.parse('http://kopay.test'),
      timeout: const Duration(seconds: 2),
    );
    session = SessionProvider(api: api, store: MemorySessionStore());
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthApi>.value(value: api),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: _SpanishSettings(),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  Future<void> fillLogin(WidgetTester tester) async {
    await type(tester, 'login-email', 'ana@mail.com');
    await type(tester, 'login-password', 'kopay2026');
  }

  Future<void> fillRegister(WidgetTester tester) async {
    await type(tester, 'register-name', 'Ana López');
    await type(tester, 'register-email', 'ana@mail.com');
    await type(tester, 'register-password', 'kopay2026');
  }

  /// Toca el botón sin esperar a que termine la petición.
  Future<void> press(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String key) async {
    await press(tester, key);
    await tester.pumpAndSettle();
  }

  bool fieldEnabled(WidgetTester tester, String key) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        ),
      )
      .enabled!;

  bool linkEnabled(WidgetTester tester, String key) =>
      tester.widget<TextButton>(find.byKey(Key(key))).enabled;

  FilledButton button(WidgetTester tester, String key) =>
      tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(FilledButton),
        ),
      );

  group('Éxito', () {
    testWidgets('UI-AUTH-01 · HU-30 · HU-31 · crear la cuenta y después '
        'entrar manda lo del contrato y abre la sesión', (tester) async {
      await open(tester, const LoginScreen());
      await submit(tester, 'login-to-register');

      server.reply(_json(201, {'user': _user}));
      await fillRegister(tester);
      await submit(tester, 'register-submit');

      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.text('ana@mail.com'), findsOneWidget);
      expect(session.isSignedIn, isFalse, reason: 'registrar no abre sesión');

      server.reply(_json(200, _session));
      await type(tester, 'login-password', 'kopay2026');
      await submit(tester, 'login-submit');

      expect(session.status, SessionStatus.signedIn);
      expect(server.requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/auth/register',
        'POST /api/auth/login',
      ]);
      expect(jsonDecode(server.requests.first.body), {
        'name': 'Ana López',
        'email': 'ana@mail.com',
        'password': 'kopay2026',
      });
      expect(jsonDecode(server.requests.last.body), {
        'email': 'ana@mail.com',
        'password': 'kopay2026',
      });
    });
  });

  group('Carga', () {
    testWidgets('UI-AUTH-02 · HU-30 · mientras registra bloquea los tres '
        'campos y el enlace de regreso', (tester) async {
      final pending = server.hold();
      await open(tester, const RegisterScreen());
      await fillRegister(tester);
      await press(tester, 'register-submit');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(button(tester, 'register-submit').onPressed, isNull);
      for (final key in [
        'register-name',
        'register-email',
        'register-password',
      ]) {
        expect(fieldEnabled(tester, key), isFalse, reason: key);
      }
      expect(linkEnabled(tester, 'register-to-login'), isFalse);

      pending.complete(_error(503, 'UNAVAILABLE', 'Servicio no disponible'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fieldEnabled(tester, 'register-email'), isTrue);
      expect(linkEnabled(tester, 'register-to-login'), isTrue);
    });

    testWidgets('UI-AUTH-03 · HU-31 · mientras inicia sesión bloquea los '
        'campos y el enlace para crear cuenta', (tester) async {
      final pending = server.hold();
      await open(tester, const LoginScreen());
      await fillLogin(tester);
      await press(tester, 'login-submit');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(button(tester, 'login-submit').onPressed, isNull);
      expect(fieldEnabled(tester, 'login-email'), isFalse);
      expect(fieldEnabled(tester, 'login-password'), isFalse);
      expect(linkEnabled(tester, 'login-to-register'), isFalse);
      expect(server.requests, hasLength(1));

      pending.complete(_json(200, _session));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(session.isSignedIn, isTrue);
    });
  });

  group('Error', () {
    testWidgets('UI-AUTH-04 · HU-30 · CON-15 · un 400 y un 409 por HTTP '
        'marcan sus campos', (tester) async {
      await open(tester, const RegisterScreen());
      await fillRegister(tester);

      server.reply(
        _json(400, {
          'error': 'Revisa los datos marcados',
          'code': 'VALIDATION_FAILED',
          'fields': {'password': AuthValidators.passwordWeak},
        }),
      );
      await submit(tester, 'register-submit');
      expect(find.text(AuthValidators.passwordWeak), findsOneWidget);
      expect(find.byKey(const Key('register-banner')), findsNothing);

      server.reply(
        _error(409, 'EMAIL_TAKEN', 'Ya existe una cuenta con ese correo'),
      );
      await type(tester, 'register-password', 'kopay2027');
      await submit(tester, 'register-submit');
      expect(find.text('Ya existe una cuenta con ese correo'), findsOneWidget);
      expect(find.byKey(const Key('register-banner')), findsNothing);
    });

    for (final (screen, prefix, status, code) in [
      (const RegisterScreen() as Widget, 'register', 500, 'INTERNAL'),
      (const LoginScreen() as Widget, 'login', 500, 'INTERNAL'),
      (const LoginScreen() as Widget, 'login', 503, 'UNAVAILABLE'),
    ]) {
      testWidgets('UI-AUTH-05 · HU-30 · HU-31 · $status en $prefix muestra el '
          'mensaje de la API, se borra al editar y permite reintentar', (
        tester,
      ) async {
        final isLogin = prefix == 'login';
        await open(tester, screen);
        isLogin ? await fillLogin(tester) : await fillRegister(tester);

        server.reply(_error(status, code, 'Mensaje $code del servidor'));
        await submit(tester, '$prefix-submit');
        expect(find.byKey(Key('$prefix-banner')), findsOneWidget);
        expect(find.text('Mensaje $code del servidor'), findsOneWidget);

        await type(tester, '$prefix-email', 'ana2@mail.com');
        await tester.pumpAndSettle();
        expect(find.byKey(Key('$prefix-banner')), findsNothing);

        server.reply(
          isLogin ? _json(200, _session) : _json(201, {'user': _user}),
        );
        await submit(tester, '$prefix-submit');
        expect(server.requests, hasLength(2));
        expect(find.byKey(Key('$prefix-banner')), findsNothing);
      });
    }

    testWidgets('UI-AUTH-06 · HU-31 · CON-15 · si la API no responde a tiempo '
        'quita la carga y avisa que no hay conexión', (tester) async {
      server.hold(); // Nunca responde.
      await open(tester, const LoginScreen());
      await fillLogin(tester);
      await press(tester, 'login-submit');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(NetworkException.message), findsOneWidget);
      expect(button(tester, 'login-submit').onPressed, isNotNull);
      expect(session.isSignedIn, isFalse);
    });

    testWidgets('UI-AUTH-07 · HU-30 · CON-15 · una respuesta que no es JSON '
        'se avisa como falta de conexión', (tester) async {
      server.reply(http.Response('<html>502 Bad Gateway</html>', 502));
      await open(tester, const RegisterScreen());
      await fillRegister(tester);
      await submit(tester, 'register-submit');

      expect(find.text(NetworkException.message), findsOneWidget);
      expect(find.textContaining('Bad Gateway'), findsNothing);
    });

    testWidgets('UI-AUTH-08 · HU-31 · un 429 muestra el mensaje de demasiados '
        'intentos', (tester) async {
      server.reply(_error(429, 'TOO_MANY_ATTEMPTS', _tooMany));
      await open(tester, const LoginScreen());
      await fillLogin(tester);
      await submit(tester, 'login-submit');

      expect(find.text(_tooMany), findsOneWidget);
      expect(session.isSignedIn, isFalse);
    });

    // UI-AUTH-09 encontró D-12 (#220): la pantalla dejaba el botón activo
    // después de un 429. Se corrigió en #221.
    testWidgets('UI-AUTH-09 · HU-31 · contrato §2 · después de un 429 el botón '
        'queda desactivado un momento y luego vuelve', (tester) async {
      server.reply(_error(429, 'TOO_MANY_ATTEMPTS', _tooMany));
      await open(tester, const LoginScreen());
      await fillLogin(tester);
      await submit(tester, 'login-submit');

      expect(button(tester, 'login-submit').onPressed, isNull);

      await tester.pump(loginRetryDelay);
      await tester.pumpAndSettle();

      expect(button(tester, 'login-submit').onPressed, isNotNull);
      expect(server.requests, hasLength(1));
    });
  });

  group('Pantalla pequeña con teclado', () {
    for (final (screen, prefix) in [
      (const RegisterScreen() as Widget, 'register'),
      (const LoginScreen() as Widget, 'login'),
    ]) {
      testWidgets('UI-AUTH-10 · HU-30 · HU-31 · $prefix a 320 × 568 con '
          'teclado y errores no se desborda y el botón se alcanza', (
        tester,
      ) async {
        await open(tester, screen, size: const Size(320, 568), keyboard: 260);
        await submit(tester, '$prefix-submit');
        await tester.ensureVisible(find.byKey(Key('$prefix-submit')));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('$prefix-submit')).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(server.requests, isEmpty);
      });
    }
  });
}
