// S3-10 · Pantalla de registro (HU-30).
//
// UT-REG-xx: reglas del registro en Flutter, iguales a las de Node
// (contrato §3.1; CON-07 y CON-08 del lado de la API).
// UI-REG-xx: captura, validaciones y estados de envío. CON-15 es el caso
// del plan del contrato que pide estas respuestas en Flutter (400, 409 y
// sin red). La API es FakeAuthApi, que responde como el contrato.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/screens/register_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/utils/auth_validators.dart';

/// API que no responde hasta que la prueba la libera.
class _PendingApi implements AuthApi {
  final completer = Completer<AuthUser>();
  int calls = 0;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) {
    calls++;
    return completer.future;
  }

  // La pantalla de registro no usa estas dos (S4-07 las agregó a AuthApi).
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> me(String accessToken) => throw UnimplementedError();
}

void main() {
  group('Reglas del registro', () {
    test('UT-REG-01 · HU-30 · CON-07 · revisa los tres campos a la vez', () {
      final fields = AuthValidators.registration(
        name: '   ',
        email: 'ana@',
        password: 'abc1234',
      );
      expect(fields, {
        'name': AuthValidators.nameRequired,
        'email': AuthValidators.emailInvalid,
        'password': AuthValidators.passwordTooShort,
      });
    });

    test('UT-REG-02 · HU-30 · CON-08 · contraseña sin números y de 73', () {
      expect(
        AuthValidators.newPassword('kopaykopay'),
        AuthValidators.passwordWeak,
      );
      expect(
        AuthValidators.newPassword('a1${'x' * 71}'),
        AuthValidators.passwordTooLong,
      );
      expect(AuthValidators.newPassword('kopay2026'), isNull);
      // Los espacios cuentan y no se recortan.
      expect(AuthValidators.newPassword(' a1     '), isNull);
    });

    test(
      'UT-REG-03 · HU-30 · nombre de 80 sí, de 81 no; correo normalizado',
      () {
        expect(AuthValidators.name('a' * 80), isNull);
        expect(AuthValidators.name('a' * 81), AuthValidators.nameTooLong);
        expect(
          AuthValidators.normalizeEmail('  Ana@Mail.COM '),
          'ana@mail.com',
        );
        expect(AuthValidators.email('ana@mail.com'), isNull);
        expect(
          AuthValidators.email('ana mail@x.com'),
          AuthValidators.emailInvalid,
        );
      },
    );
  });

  group('Pantalla', () {
    late FakeAuthApi api;

    setUp(() => api = FakeAuthApi());

    /// Abre una pantalla con un botón que empuja el registro, para poder
    /// leer lo que devuelve al cerrarse.
    Future<List<Object?>> open(WidgetTester tester, AuthApi authApi) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final results = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () async => results.add(
                  await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(api: authApi),
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      return results;
    }

    Future<void> fill(
      WidgetTester tester, {
      String name = 'Ana López',
      String email = 'ana@mail.com',
      String password = 'kopay2026',
    }) async {
      await tester.enterText(find.byKey(const Key('register-name')), name);
      await tester.enterText(find.byKey(const Key('register-email')), email);
      await tester.enterText(
        find.byKey(const Key('register-password')),
        password,
      );
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('register-submit')));
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('UI-REG-01 · HU-30 · Formulario vacío muestra los tres '
        'errores y no envía', (tester) async {
      await open(tester, api);
      await submit(tester);

      expect(find.text(AuthValidators.nameRequired), findsOneWidget);
      expect(find.text(AuthValidators.emailInvalid), findsOneWidget);
      expect(find.text(AuthValidators.passwordTooShort), findsOneWidget);
      expect(api.accounts, isEmpty);
    });

    testWidgets('UI-REG-02 · HU-30 · Mientras envía bloquea el formulario y '
        'no envía dos veces', (tester) async {
      final pending = _PendingApi();
      await open(tester, pending);
      await fill(tester);
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('register-email')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.enabled, isFalse);
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pump();
      expect(pending.calls, 1);

      pending.completer.complete(
        AuthUser(
          id: '1',
          name: 'Ana López',
          email: 'ana@mail.com',
          role: 'user',
          createdAt: DateTime.utc(2026, 11, 26),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('UI-REG-03 · HU-30 · Registro válido cierra la pantalla y '
        'devuelve el correo normalizado', (tester) async {
      final results = await open(tester, api);
      await fill(tester, email: '  Ana@Mail.com ');
      await submit(tester);

      expect(find.byType(RegisterScreen), findsNothing);
      expect(results, ['ana@mail.com']);
      expect(api.accounts.keys, ['ana@mail.com']);
      expect(api.accounts['ana@mail.com']!.role, 'user');
    });

    testWidgets('UI-REG-04 · HU-30 · CON-15 · 409 marca el correo y se '
        'borra al editarlo', (tester) async {
      await api.register(
        name: 'Ana',
        email: 'ana@mail.com',
        password: 'kopay2026',
      );
      await open(tester, api);
      await fill(tester);
      await submit(tester);

      expect(find.text('Ya existe una cuenta con ese correo'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('register-email')),
        'otra@mail.com',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una cuenta con ese correo'), findsNothing);
    });

    testWidgets('UI-REG-05 · HU-30 · CON-15 · 400 de la API se muestra bajo '
        'cada campo', (tester) async {
      api.failNextWith(
        const ApiException(
          400,
          ApiErrorCode.validationFailed,
          'Revisa los datos marcados',
          fields: {'name': 'El nombre puede tener hasta 80 caracteres'},
        ),
      );
      await open(tester, api);
      await fill(tester);
      await submit(tester);

      expect(
        find.text('El nombre puede tener hasta 80 caracteres'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('register-banner')), findsNothing);
    });

    testWidgets('UI-REG-06 · HU-30 · CON-15 · sin red avisa arriba, no muestra '
        'la contraseña y permite reintentar', (tester) async {
      api.failNextWith(const NetworkException());
      final results = await open(tester, api);
      await fill(tester, password: 'secreta2026');
      await submit(tester);

      expect(find.byKey(const Key('register-banner')), findsOneWidget);
      expect(find.text(NetworkException.message), findsOneWidget);
      // Ningún mensaje repite la contraseña (solo está en su campo).
      expect(
        find.descendant(
          of: find.byKey(const Key('register-banner')),
          matching: find.textContaining('secreta2026'),
        ),
        findsNothing,
      );
      expect(api.accounts, isEmpty);

      await submit(tester);
      expect(results, ['ana@mail.com']);
    });

    testWidgets('UI-REG-07 · HU-30 · 503 muestra el mensaje de la API', (
      tester,
    ) async {
      api.failNextWith(
        const ApiException(
          503,
          ApiErrorCode.unavailable,
          'El servicio no está disponible',
        ),
      );
      await open(tester, api);
      await fill(tester);
      await submit(tester);
      expect(find.text('El servicio no está disponible'), findsOneWidget);
    });

    testWidgets('UI-REG-08 · HU-30 · la contraseña va oculta y se puede '
        'mostrar', (tester) async {
      await open(tester, api);
      TextField password() => tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('register-password')),
          matching: find.byType(TextField),
        ),
      );
      expect(password().obscureText, isTrue);
      await tester.tap(find.byKey(const Key('register-toggle-password')));
      await tester.pump();
      expect(password().obscureText, isFalse);
    });
  });
}
