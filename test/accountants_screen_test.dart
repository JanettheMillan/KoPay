// S4-11 · Autorizar y revocar contador en la app (HU-38, HU-41).
//
// Casos nuevos ACC-01 a ACC-09. Siguen los recorridos "El usuario autoriza
// y luego cancela" y "El usuario autoriza y confirma" de
// docs/navegacion-usuario-contador.md §6, y el consentimiento de la §3.
// Criterio de la tarjeta: la persona elige contador y puede retirar acceso.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/accountants_screen.dart';
import 'package:kopay/screens/settings_screen.dart';
import 'package:kopay/services/accountants_api.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_accountants_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/auth_validators.dart';
import 'package:provider/provider.dart';

const es = AppStrings.es;

/// Sesión de Ana, cuenta `user`, ya iniciada.
Future<SessionProvider> sesionDeAna() async {
  final auth = FakeAuthApi();
  await auth.register(
    name: 'Ana López',
    email: 'ana@mail.com',
    password: 'kopay2026',
  );
  final session = SessionProvider(api: auth, store: MemorySessionStore());
  await session.login(email: 'ana@mail.com', password: 'kopay2026');
  return session;
}

FakeAccountantsApi contadores() => FakeAccountantsApi(
  accountants: {'carla@conta.mx': 'Carla Contadora', 'luis@conta.mx': 'Luis'},
  now: () => DateTime.utc(2026, 11, 26, 12),
);

void main() {
  Future<void> open(
    WidgetTester tester, {
    required SessionProvider? session,
    required AccountantsApi api,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        key: UniqueKey(),
        providers: [
          if (session != null)
            ChangeNotifierProvider<SessionProvider>.value(value: session),
          Provider<AccountantsApi>.value(value: api),
        ],
        child: MaterialApp(home: home ?? const AccountantsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> escribirCorreo(WidgetTester tester, String email) async {
    await tap(tester, 'accountants-authorize');
    await tester.enterText(find.byKey(const Key('authorize-email')), email);
    await tap(tester, 'authorize-continue');
  }

  testWidgets('ACC-01 · HU-38 · sin permisos muestra el aviso; con permisos, '
      'nombre, correo, fecha y Revocar', (tester) async {
    final api = contadores();
    await open(tester, session: await sesionDeAna(), api: api);
    expect(find.byKey(const Key('accountants-empty')), findsOneWidget);
    expect(find.byKey(const Key('accountants-authorize')), findsOneWidget);

    await api.grant('t', 'carla@conta.mx');
    await open(tester, session: await sesionDeAna(), api: api);
    expect(find.text('Carla Contadora'), findsOneWidget);
    expect(find.text('carla@conta.mx'), findsOneWidget);
    expect(find.text('Autorizado el 26 nov 2026'), findsOneWidget);
    expect(find.byKey(const Key('accountant-revoke-g-1')), findsOneWidget);
  });

  testWidgets(
    'ACC-02 · HU-38 · autorizar y luego cancelar no crea el permiso',
    (tester) async {
      final api = contadores();
      await open(tester, session: await sesionDeAna(), api: api);
      await escribirCorreo(tester, 'carla@conta.mx');

      // El diálogo explica quién, qué ve, que es solo lectura y revocable.
      expect(find.byKey(const Key('authorize-confirm-dialog')), findsOneWidget);
      expect(find.text('¿Autorizar a carla@conta.mx?'), findsOneWidget);
      expect(find.text(es.authorizeConfirmBody), findsOneWidget);

      await tap(tester, 'authorize-cancel');
      expect(find.byKey(const Key('authorize-email')), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('grant')), isEmpty);
      expect(api.grants, isEmpty);
    },
  );

  testWidgets(
    'ACC-03 · HU-38 · autorizar y confirmar crea el permiso y aparece '
    'en la lista',
    (tester) async {
      final api = contadores();
      await open(tester, session: await sesionDeAna(), api: api);
      await escribirCorreo(tester, '  Carla@Conta.MX ');
      await tap(tester, 'authorize-confirm');

      expect(api.calls, contains('grant carla@conta.mx'));
      expect(api.grants.single.accountantEmail, 'carla@conta.mx');
      expect(find.byKey(const Key('authorize-email')), findsNothing);
      expect(find.text('Carla Contadora'), findsOneWidget);
      expect(find.text(es.accountantAuthorized), findsOneWidget);
      expect(find.byKey(const Key('accountants-empty')), findsNothing);
    },
  );

  testWidgets('ACC-04 · HU-38 · un correo inválido no se envía y uno sin '
      'contador muestra el error sin crear nada', (tester) async {
    final api = contadores();
    await open(tester, session: await sesionDeAna(), api: api);
    await escribirCorreo(tester, 'carla');
    expect(find.text(AuthValidators.emailInvalid), findsOneWidget);
    expect(find.byKey(const Key('authorize-confirm-dialog')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('authorize-email')),
      'nadie@conta.mx',
    );
    await tap(tester, 'authorize-continue');
    await tap(tester, 'authorize-confirm');
    expect(find.text('No hay un contador con ese correo'), findsOneWidget);
    expect(find.byKey(const Key('authorize-email')), findsOneWidget);
    expect(api.grants, isEmpty);

    // Al corregir el correo el error se quita.
    await tester.enterText(
      find.byKey(const Key('authorize-email')),
      'luis@conta.mx',
    );
    await tester.pump();
    expect(find.text('No hay un contador con ese correo'), findsNothing);
  });

  testWidgets('ACC-05 · HU-41 · revocar pide confirmación; cancelar conserva y '
      'confirmar retira el acceso', (tester) async {
    final api = contadores();
    await api.grant('t', 'carla@conta.mx');
    await api.grant('t', 'luis@conta.mx');
    await open(tester, session: await sesionDeAna(), api: api);

    await tap(tester, 'accountant-revoke-g-1');
    expect(find.text('¿Retirar el acceso a Carla Contadora?'), findsOneWidget);
    await tap(tester, 'accountant-revoke-cancel');
    expect(find.text('Carla Contadora'), findsOneWidget);
    expect(api.grants, hasLength(2));

    await tap(tester, 'accountant-revoke-g-1');
    await tap(tester, 'accountant-revoke-confirm');
    expect(api.calls, contains('revoke g-1'));
    expect(find.text('Carla Contadora'), findsNothing);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text(es.accessRevoked), findsOneWidget);
    expect(api.grants.single.accountantEmail, 'luis@conta.mx');
  });

  testWidgets(
    'ACC-06 · HU-41 · si el permiso ya estaba revocado (404) se quita '
    'de la lista igual',
    (tester) async {
      final api = contadores();
      await api.grant('t', 'carla@conta.mx');
      await open(tester, session: await sesionDeAna(), api: api);
      // Lo revocaron en otro dispositivo después de cargar la lista.
      await api.revoke('t', 'g-1');

      await tap(tester, 'accountant-revoke-g-1');
      await tap(tester, 'accountant-revoke-confirm');
      expect(find.text('Carla Contadora'), findsNothing);
      expect(find.byKey(const Key('accountants-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'ACC-07 · HU-38 · sin red al cargar muestra el aviso y Reintentar '
    'vuelve a pedir la lista',
    (tester) async {
      final api = contadores()..failNextWith(const NetworkException());
      await open(tester, session: await sesionDeAna(), api: api);
      expect(find.byKey(const Key('accountants-error')), findsOneWidget);
      expect(find.text(NetworkException.message), findsOneWidget);
      expect(find.byKey(const Key('accountants-authorize')), findsNothing);

      await tap(tester, 'accountants-retry');
      expect(find.byKey(const Key('accountants-error')), findsNothing);
      expect(find.byKey(const Key('accountants-empty')), findsOneWidget);
    },
  );

  testWidgets(
    'ACC-08 · HU-37 · Ajustes muestra Contadores autorizados solo con '
    'sesión de usuario',
    (tester) async {
      final api = contadores();
      const ajustes = Scaffold(body: SettingsScreen());
      await open(tester, session: null, api: api, home: ajustes);
      expect(find.byKey(const Key('settings-accountants')), findsNothing);

      await open(tester, session: await sesionDeAna(), api: api, home: ajustes);
      await tap(tester, 'settings-accountants');
      expect(find.byKey(const Key('accountants-title')), findsOneWidget);
    },
  );

  test('ACC-09 · HU-38 · HU-41 · HttpAccountantsApi usa las rutas del '
      'contrato §3.6 y convierte los errores', () async {
    final requests = <http.Request>[];
    final grant = {
      'id': 'g-9',
      'accountant': {'id': 'c-1', 'name': 'Carla', 'email': 'carla@conta.mx'},
      'grantedAt': '2026-11-26T12:00:00.000Z',
    };
    final client = MockClient((request) async {
      requests.add(request);
      final json = {'Content-Type': 'application/json'};
      return switch ((request.method, request.url.path)) {
        ('GET', '/api/accountants') => http.Response(
          jsonEncode({
            'grants': [grant],
          }),
          200,
          headers: json,
        ),
        ('POST', '/api/accountants') => http.Response(
          jsonEncode(
            jsonDecode(request.body)['accountantEmail'] == 'carla@conta.mx'
                ? {'grant': grant}
                : {
                    'error': 'No hay un contador con ese correo',
                    'code': 'NOT_FOUND',
                  },
          ),
          jsonDecode(request.body)['accountantEmail'] == 'carla@conta.mx'
              ? 201
              : 404,
          headers: json,
        ),
        ('DELETE', '/api/accountants/g-9') => http.Response('', 204),
        _ => http.Response('<html>', 502),
      };
    });
    final api = HttpAccountantsApi(
      client: client,
      baseUrl: Uri.parse('http://kopay.test'),
    );

    final list = await api.list('tok');
    expect(list.single.accountantName, 'Carla');
    expect(list.single.grantedAt, DateTime.utc(2026, 11, 26, 12));
    expect(requests.last.headers['Authorization'], 'Bearer tok');

    expect((await api.grant('tok', 'carla@conta.mx')).id, 'g-9');
    expect(
      () => api.grant('tok', 'nadie@conta.mx'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.code, 'code', ApiErrorCode.notFound),
      ),
    );
    await api.revoke('tok', 'g-9');
    expect(requests.last.method, 'DELETE');
    expect(() => api.revoke('tok', 'otro'), throwsA(isA<NetworkException>()));
  });
}
