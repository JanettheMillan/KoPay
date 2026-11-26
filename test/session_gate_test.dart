// S3-12 · Navegación inicial con acceso y sesión (HU-31, HU-34, HU-37).
//
// Casos nuevos NAV-01 a NAV-08, que siguen la tabla "Cómo se comprueba" de
// docs/navegacion-usuario-contador.md §6 en lo que toca a la entrada.
// Criterio de la tarjeta: una sesión válida abre la app; sin sesión se
// muestra el acceso.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/session_gate.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:provider/provider.dart';

AuthUser cuenta(String role) => AuthUser(
  id: role == 'user' ? 'u-1' : 'c-1',
  name: role == 'user' ? 'Ana López' : 'Carla Contadora',
  email: role == 'user' ? 'ana@mail.com' : 'carla@conta.mx',
  role: role,
  createdAt: DateTime.utc(2026, 11, 26),
);

/// API que responde lo que cada prueba necesita.
class _StubApi implements AuthApi {
  _StubApi({this.role = 'user', this.meError, this.refreshOk = true});

  final String role;

  /// Error de `me` (por ejemplo 401 o sin red); `null` responde la cuenta.
  Object? meError;
  final bool refreshOk;
  final meGate = Completer<void>()..complete();
  int logouts = 0;

  AuthSession _session() => AuthSession(
    accessToken: 'acceso-${DateTime.now().microsecondsSinceEpoch}',
    tokenType: 'Bearer',
    expiresIn: 900,
    refreshToken: 'renovar',
    refreshExpiresIn: 2592000,
    user: cuenta(role),
  );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _session();

  @override
  Future<AuthUser> me(String accessToken) async {
    await meGate.future;
    if (meError != null) throw meError!;
    return cuenta(role);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    if (!refreshOk) {
      throw const ApiException(
        401,
        ApiErrorCode.unauthenticated,
        'Inicia sesión para continuar',
      );
    }
    meError = null;
    return _session();
  }

  @override
  Future<void> logout(String accessToken) async => logouts++;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

StoredSession guardada(String role) => StoredSession(
  accessToken: 'acceso-guardado',
  accessExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
  refreshToken: 'renovar',
  refreshExpiresAt: DateTime.now().add(const Duration(days: 30)),
  user: cuenta(role),
);

void main() {
  const homeKey = Key('vista-usuario');
  const contadorKey = Key('vista-contador');

  Future<SessionProvider> open(
    WidgetTester tester, {
    required _StubApi api,
    StoredSession? stored,
    bool restore = true,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session = SessionProvider(
      api: api,
      store: MemorySessionStore(stored),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthApi>.value(value: api),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
        ],
        child: MaterialApp(
          home: SessionGate(
            home: const Scaffold(body: Text('Inicio', key: homeKey)),
            accountantHome: () =>
                const Scaffold(body: Text('Clientes', key: contadorKey)),
          ),
        ),
      ),
    );
    if (restore) {
      unawaited(session.restore());
      await tester.pumpAndSettle();
    }
    return session;
  }

  testWidgets('NAV-01 · HU-31 · mientras lee la sesión muestra el Splash y, '
      'sin sesión guardada, Iniciar sesión', (tester) async {
    await open(tester, api: _StubApi(), restore: false);
    expect(find.byKey(const Key('splash')), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);

    final session = tester
        .element(find.byType(SessionGate))
        .read<SessionProvider>();
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
  });

  testWidgets('NAV-02 · HU-31 · una sesión guardada y vigente abre la vista '
      'de usuario sin pedir login', (tester) async {
    await open(tester, api: _StubApi(), stored: guardada('user'));
    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.byKey(const Key('login-title')), findsNothing);
  });

  testWidgets('NAV-03 · HU-31 · iniciar sesión desde el acceso abre la vista '
      'de usuario', (tester) async {
    await open(tester, api: _StubApi());
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@mail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'kopay2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(homeKey), findsOneWidget);
  });

  testWidgets('NAV-04 · HU-37 · una cuenta de contador abre su vista y no la '
      'de usuario', (tester) async {
    await open(
      tester,
      api: _StubApi(role: 'accountant'),
      stored: guardada('accountant'),
    );
    expect(find.byKey(contadorKey), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
  });

  testWidgets('NAV-05 · HU-33 · al cerrar sesión vuelve al acceso y cierra lo '
      'que estaba abierto', (tester) async {
    final api = _StubApi();
    final session = await open(tester, api: api, stored: guardada('user'));
    Navigator.of(tester.element(find.byKey(homeKey))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detalle')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsOneWidget);

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.text('Detalle'), findsNothing);
    expect(api.logouts, 1);
  });

  testWidgets('NAV-06 · HU-34 · si la sesión guardada ya no sirve y no se '
      'puede renovar, abre el acceso con el aviso', (tester) async {
    final api = _StubApi(
      meError: const ApiException(
        401,
        ApiErrorCode.unauthenticated,
        'Inicia sesión para continuar',
      ),
      refreshOk: false,
    );
    await open(tester, api: api, stored: guardada('user'));
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.text(AppStrings.es.sessionExpiredNotice), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
  });

  testWidgets('NAV-07 · HU-31 · sin red con sesión guardada abre la app con la '
      'cuenta guardada', (tester) async {
    final api = _StubApi(meError: const NetworkException());
    await open(tester, api: api, stored: guardada('user'));
    expect(find.byKey(homeKey), findsOneWidget);
  });

  testWidgets('NAV-08 · HU-37 · un rol que la app no reconoce no abre ninguna '
      'vista y se queda en el acceso', (tester) async {
    await open(
      tester,
      api: _StubApi(role: 'admin'),
      stored: guardada('admin'),
    );
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
    expect(find.byKey(contadorKey), findsNothing);
  });
}
