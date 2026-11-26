// S3-11 · Pantalla de inicio de sesión (HU-31).
//
// UI-LOG-xx son casos nuevos de esta tarjeta. CON-15 es el caso del
// contrato que pide que Flutter muestre las respuestas 400, 401 y sin red
// sin datos privados. La API es FakeAuthApi, que responde como el
// contrato, y la sesión se guarda en MemorySessionStore.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/login_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/auth_validators.dart';
import 'package:provider/provider.dart';

/// Sesión que viene de vencer, para el aviso de UI-LOG-07.
class _ExpiredSession extends SessionProvider {
  _ExpiredSession({required super.api, required super.store});

  @override
  bool get sessionExpired => true;
}

class _FixedSettings extends SettingsProvider {
  _FixedSettings(this._language);
  final String _language;

  @override
  String get language => _language;
}

/// API que no responde hasta que la prueba la libera.
class _PendingApi extends FakeAuthApi {
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    calls++;
    await gate.future;
    return super.login(email: email, password: password);
  }
}

void main() {
  const ana = (email: 'ana@mail.com', password: 'kopay2026');

  late FakeAuthApi api;
  late MemorySessionStore store;
  late SessionProvider session;
  late int signedIn;

  Future<void> setUpApi(FakeAuthApi fake) async {
    api = fake;
    await api.register(
      name: 'Ana López',
      email: ana.email,
      password: ana.password,
    );
    store = MemorySessionStore();
    session = SessionProvider(api: api, store: store);
    signedIn = 0;
  }

  Future<void> open(
    WidgetTester tester, {
    String? email,
    String language = 'es',
    SessionProvider? provider,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthApi>.value(value: api),
          ChangeNotifierProvider<SessionProvider>.value(
            value: provider ?? session,
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: _FixedSettings(language),
          ),
        ],
        child: MaterialApp(
          home: LoginScreen(initialEmail: email, onSignedIn: () => signedIn++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  String passwordText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('login-password')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('UI-LOG-01 · HU-31 · sin correo ni contraseña muestra los dos '
      'errores y no envía', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);
    await submit(tester);

    expect(find.text(AuthValidators.emailRequired), findsOneWidget);
    expect(find.text(AuthValidators.passwordRequired), findsOneWidget);
    expect(session.isSignedIn, isFalse);
    // Aquí no se revisan las reglas del registro (contrato §3.2).
    await fill(tester, 'ana@mail.com', 'x');
    await tester.pumpAndSettle();
    expect(find.text(AuthValidators.passwordTooShort), findsNothing);
  });

  testWidgets('UI-LOG-02 · HU-31 · CON-11 · credenciales correctas abren la '
      'sesión y la guardan en el dispositivo', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);
    await fill(tester, '  Ana@Mail.com ', ana.password);
    await submit(tester);

    expect(session.status, SessionStatus.signedIn);
    expect(session.user!.email, ana.email);
    expect(store.current, isNotNull);
    expect(signedIn, 1);
  });

  testWidgets('UI-LOG-03 · HU-31 · CON-15 · 401 avisa arriba, limpia la '
      'contraseña y no dice si el correo existe', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);

    await fill(tester, ana.email, 'otra2026');
    await submit(tester);
    expect(find.byKey(const Key('login-banner')), findsOneWidget);
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(passwordText(tester), isEmpty);
    expect(find.text(AuthValidators.passwordRequired), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('login-email')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      ana.email,
    );

    // Un correo sin cuenta recibe exactamente el mismo mensaje.
    await fill(tester, 'nadie@mail.com', 'otra2026');
    await submit(tester);
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(session.isSignedIn, isFalse);
    expect(signedIn, 0);
  });

  testWidgets('UI-LOG-04 · HU-31 · CON-15 · 400 de la API se muestra bajo '
      'el campo', (tester) async {
    await setUpApi(FakeAuthApi());
    api.failNextWith(
      const ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: {'email': 'Escribe un correo válido'},
      ),
    );
    await open(tester);
    await fill(tester, ana.email, ana.password);
    await submit(tester);

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.byKey(const Key('login-banner')), findsNothing);
  });

  testWidgets('UI-LOG-05 · HU-31 · CON-15 · sin red o con la API caída avisa, '
      'no muestra la contraseña y permite reintentar', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);

    api.failNextWith(const NetworkException());
    await fill(tester, ana.email, ana.password);
    await submit(tester);
    expect(find.text(NetworkException.message), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('login-banner')),
        matching: find.textContaining(ana.password),
      ),
      findsNothing,
    );

    api.failNextWith(
      const ApiException(
        503,
        ApiErrorCode.unavailable,
        'El servicio no está disponible. Inténtalo de nuevo.',
      ),
    );
    await submit(tester);
    expect(
      find.text('El servicio no está disponible. Inténtalo de nuevo.'),
      findsOneWidget,
    );

    await submit(tester);
    expect(session.isSignedIn, isTrue);
  });

  testWidgets('D-12 · HU-31 · después de un 429 el botón se desactiva '
      '30 segundos y luego vuelve a funcionar', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);
    const tooMany =
        'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    bool enabled() => tester
        .widget<ButtonStyleButton>(
          find.descendant(
            of: find.byKey(const Key('login-submit')),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        )
        .enabled;

    api.failNextWith(
      const ApiException(429, ApiErrorCode.tooManyAttempts, tooMany),
    );
    await fill(tester, ana.email, ana.password);
    await submit(tester);
    expect(find.text(tooMany), findsOneWidget);
    expect(enabled(), isFalse);

    // Ni el botón ni el teclado envían mientras dura la espera.
    await tester.tap(
      find.byKey(const Key('login-submit')),
      warnIfMissed: false,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(session.isSignedIn, isFalse);

    await tester.pump(loginRetryDelay - const Duration(seconds: 1));
    expect(enabled(), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(enabled(), isTrue);

    await submit(tester);
    expect(session.isSignedIn, isTrue);
  });

  testWidgets('UI-LOG-06 · HU-31 · mientras envía bloquea el formulario y no '
      'envía dos veces', (tester) async {
    final pending = _PendingApi();
    await setUpApi(pending);
    await open(tester);
    await fill(tester, ana.email, ana.password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(pending.calls, 1);

    pending.gate.complete();
    await tester.pumpAndSettle();
    expect(session.isSignedIn, isTrue);
  });

  testWidgets('UI-LOG-07 · HU-31 · si la sesión venció lo avisa', (
    tester,
  ) async {
    await setUpApi(FakeAuthApi());
    await open(
      tester,
      provider: _ExpiredSession(api: api, store: store),
    );
    expect(find.byKey(const Key('login-expired')), findsOneWidget);
    expect(find.text(AppStrings.es.sessionExpiredNotice), findsOneWidget);
  });

  testWidgets('UI-LOG-08 · HU-30 · HU-31 · Crear cuenta regresa con el correo '
      'escrito', (tester) async {
    await setUpApi(FakeAuthApi());
    await open(tester);
    await tester.tap(find.byKey(const Key('login-to-register')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('register-name')), 'Luis');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'Luis@Mail.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'kopay2026',
    );
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.text('luis@mail.com'), findsOneWidget);
    expect(passwordText(tester), isEmpty);
  });

  testWidgets('UI-LOG-09 · HU-25 · la pantalla cambia a inglés', (
    tester,
  ) async {
    await setUpApi(FakeAuthApi());
    await open(tester, language: 'en', email: 'ana@mail.com');
    expect(find.text('Sign in'), findsNWidgets(2)); // título y botón
    expect(find.text('No account yet? Create one'), findsOneWidget);
    expect(find.text('ana@mail.com'), findsOneWidget);
  });
}
