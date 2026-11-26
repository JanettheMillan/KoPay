// S4-09 · Guardas de navegación por rol (HU-34, HU-37).
//
// El plan de pruebas no tiene un caso de las guardas en Flutter (FUT-25
// es la entrada a la vista de contador y depende de S4-12). GRD-01 a
// GRD-11 son pruebas nuevas, anotadas en el PR. La matriz esperada es la
// de docs/navegacion-usuario-contador.md §5.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/data/accountant_sample_data.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/accountant_clients_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/route_policy.dart';
import 'package:kopay/widgets/role_guard.dart';
import 'package:provider/provider.dart';

AuthUser _cuenta(String role) => AuthUser(
  id: 'id-$role',
  name: 'Cuenta $role',
  email: '$role@mail.com',
  role: role,
  createdAt: DateTime.utc(2026, 11, 26),
);

GuardDecision _check(AppScreen s, {SessionStatus? status, String? role}) =>
    RoutePolicy.check(
      s,
      status:
          status ??
          (role == null ? SessionStatus.signedOut : SessionStatus.signedIn),
      user: role == null ? null : _cuenta(role),
    );

void main() {
  group('RoutePolicy', () {
    // Sí = se abre. Columnas: sin sesión, usuario, contador (§5).
    const matriz = <AppScreen, (bool, bool, bool)>{
      AppScreen.splash: (true, true, true),
      AppScreen.login: (true, true, true),
      AppScreen.recover: (true, true, true),
      AppScreen.register: (true, true, false),
      AppScreen.userHome: (false, true, false),
      AppScreen.userForms: (false, true, false),
      AppScreen.manageAccountants: (false, true, false),
      AppScreen.accountantClients: (false, false, true),
      AppScreen.accountantClientData: (false, false, true),
    };

    test('GRD-01 · HU-34, HU-37 · cada pantalla se abre solo con la sesión y '
        'el rol de la matriz', () {
      expect(matriz.keys.toSet(), AppScreen.values.toSet());
      for (final MapEntry(key: pantalla, value: (sin, usuario, contador))
          in matriz.entries) {
        expect(_check(pantalla).allowed, sin, reason: '$pantalla sin sesión');
        expect(
          _check(pantalla, role: AppRole.user).allowed,
          usuario,
          reason: '$pantalla como usuario',
        );
        expect(
          _check(pantalla, role: AppRole.accountant).allowed,
          contador,
          reason: '$pantalla como contador',
        );
      }
    });

    test('GRD-02 · HU-34 · sin sesión, una pantalla privada manda a Iniciar '
        'sesión', () {
      final d = _check(AppScreen.userHome);

      expect(d.outcome, GuardOutcome.signIn);
      expect(d.redirectTo, AppScreen.login);
    });

    test('GRD-03 · HU-37 · con otro rol manda a la vista de su propio rol', () {
      final usuario = _check(AppScreen.accountantClients, role: AppRole.user);
      final contador = _check(AppScreen.userForms, role: AppRole.accountant);

      expect(usuario.outcome, GuardOutcome.goHome);
      expect(usuario.redirectTo, AppScreen.userHome);
      expect(contador.outcome, GuardOutcome.goHome);
      expect(contador.redirectTo, AppScreen.accountantClients);
    });

    test('GRD-04 · HU-37 · un rol desconocido no recibe privilegios y no queda '
        'en un ciclo', () {
      for (final role in ['admin', '', 'User', 'ACCOUNTANT']) {
        expect(
          _check(AppScreen.userHome, role: role).redirectTo,
          AppScreen.login,
        );
        expect(
          _check(AppScreen.accountantClients, role: role).allowed,
          isFalse,
        );
        // Iniciar sesión sí se abre, así no se redirige a sí misma.
        expect(_check(AppScreen.login, role: role).allowed, isTrue);
      }
      expect(RoutePolicy.homeFor('admin'), AppScreen.login);
      expect(RoutePolicy.homeFor(null), AppScreen.login);
    });

    test('GRD-05 · HU-31 · mientras se lee la sesión solo se ve el Splash', () {
      for (final pantalla in AppScreen.values) {
        final d = _check(pantalla, status: SessionStatus.unknown);
        expect(
          d.outcome,
          pantalla == AppScreen.splash ? GuardOutcome.allow : GuardOutcome.wait,
          reason: '$pantalla',
        );
      }
    });

    test('GRD-06 · HU-31 · si la sesión venció, la decisión lo indica para '
        'avisarlo', () {
      final d = RoutePolicy.check(
        AppScreen.userHome,
        status: SessionStatus.signedOut,
        sessionExpired: true,
      );

      expect(d.outcome, GuardOutcome.signIn);
      expect(d.sessionExpired, isTrue);
    });

    test('GRD-07 · HU-37 · cada rol empieza en su vista', () {
      expect(RoutePolicy.homeFor(AppRole.user), AppScreen.userHome);
      expect(
        RoutePolicy.homeFor(AppRole.accountant),
        AppScreen.accountantClients,
      );
    });
  });

  group('RoleGuard', () {
    late FakeAuthApi api;
    late SessionProvider session;
    late int construcciones;

    /// Pantalla privada que cuenta cuántas veces se construye.
    Widget privada(String texto) => Builder(
      builder: (_) {
        construcciones++;
        return Text(texto);
      },
    );

    Widget negada(BuildContext _, GuardDecision d) => Text(
      'negado → ${d.redirectTo?.name}${d.sessionExpired ? ' (venció)' : ''}',
    );

    Future<void> montar(WidgetTester tester, AppScreen pantalla, Widget hijo) =>
        tester.pumpWidget(
          ChangeNotifierProvider<SessionProvider>.value(
            value: session,
            child: MaterialApp(
              home: Scaffold(
                body: RoleGuard(screen: pantalla, denied: negada, child: hijo),
              ),
            ),
          ),
        );

    Future<void> entrarComo(WidgetTester tester, String role) async {
      await tester.runAsync(() async {
        await api.register(
          name: 'Cuenta',
          email: '$role@mail.com',
          password: 'kopay2026',
        );
        await session.login(email: '$role@mail.com', password: 'kopay2026');
      });
    }

    setUp(() {
      api = FakeAuthApi();
      session = SessionProvider(api: api, store: MemorySessionStore());
      construcciones = 0;
    });

    testWidgets(
      'GRD-08 · HU-31 · mientras se lee la sesión muestra la espera y '
      'no la pantalla',
      (tester) async {
        await montar(tester, AppScreen.userHome, privada('Inicio'));

        expect(find.byKey(const Key('role-guard-loading')), findsOneWidget);
        expect(find.text('Inicio'), findsNothing);
        expect(construcciones, 0);
      },
    );

    testWidgets('GRD-09 · HU-34 · sin sesión la pantalla privada no se '
        'construye y se manda a Iniciar sesión', (tester) async {
      await tester.runAsync(session.restore);
      await montar(tester, AppScreen.userHome, privada('Inicio'));

      expect(find.text('negado → login'), findsOneWidget);
      expect(find.text('Inicio'), findsNothing);
      expect(construcciones, 0);
    });

    testWidgets('GRD-10 · HU-37 · una cuenta de usuario no abre la pantalla '
        'del contador; una de contador sí', (tester) async {
      // FakeAuthApi crea cuentas `user`; el contador se simula con su rol.
      await entrarComo(tester, 'user');
      await montar(
        tester,
        AppScreen.accountantClients,
        AccountantClientsScreen(data: SampleAccountantData(const [])),
      );
      await tester.pump();
      expect(find.text('negado → userHome'), findsOneWidget);
      expect(find.byType(AccountantClientsScreen), findsNothing);

      final contador = SessionProvider(
        api: _ApiDeContador(),
        store: MemorySessionStore(),
      );
      await tester.runAsync(
        () => contador.login(email: 'carla@conta.mx', password: 'x'),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionProvider>.value(
          value: contador,
          child: MaterialApp(
            home: RoleGuard(
              screen: AppScreen.accountantClients,
              denied: negada,
              child: AccountantClientsScreen(
                data: SampleAccountantData(const []),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AccountantClientsScreen), findsOneWidget);
    });

    testWidgets('GRD-11 · HU-33, HU-34 · al cerrar sesión la pantalla privada '
        'se quita sola', (tester) async {
      await entrarComo(tester, 'user');
      await montar(tester, AppScreen.userHome, privada('Inicio'));
      expect(find.text('Inicio'), findsOneWidget);

      await tester.runAsync(session.logout);
      await tester.pump();

      expect(find.text('Inicio'), findsNothing);
      expect(find.text('negado → login'), findsOneWidget);
    });
  });
}

/// API que inicia sesión con una cuenta de contador.
class _ApiDeContador extends FakeAuthApi {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession(
    accessToken: 'acc',
    tokenType: 'Bearer',
    expiresIn: 900,
    user: _cuenta(AppRole.accountant),
  );
}
