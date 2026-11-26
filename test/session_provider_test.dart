// S4-08 · Conservar y renovar la sesión en Flutter (HU-31, HU-33).
//
// El plan de pruebas no tiene casos de la sesión en Flutter; SES-01 a
// SES-15 son pruebas nuevas de esta tarjeta, anotadas en el PR. Siguen
// docs/contrato-api-acceso.md §2, §3.3, §3.4 y §3.5. Sin red: la API es
// FakeAuthApi o una API con respuestas fijas.

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';

final _ana = AuthUser(
  id: 'u1',
  name: 'Ana López',
  email: 'ana@mail.com',
  role: 'user',
  createdAt: DateTime.utc(2026, 11, 26, 18, 30),
);

const _unauth = ApiException(
  401,
  ApiErrorCode.unauthenticated,
  'Inicia sesión para continuar',
);

AuthSession _session(String n, {AuthUser? user}) => AuthSession(
  accessToken: 'access-$n',
  tokenType: 'Bearer',
  expiresIn: 900,
  refreshToken: 'refresh-$n',
  refreshExpiresIn: 2592000,
  user: user ?? _ana,
);

/// API con respuestas que decide cada prueba. Cuenta las llamadas.
class _ScriptedApi implements AuthApi {
  Future<AuthUser> Function(String token)? onMe;
  Future<AuthSession> Function(String refreshToken)? onRefresh;
  Future<void> Function(String token)? onLogout;
  final meTokens = <String>[];
  final refreshTokens = <String>[];
  final logoutTokens = <String>[];

  @override
  Future<AuthUser> me(String accessToken) {
    meTokens.add(accessToken);
    return onMe!(accessToken);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) {
    refreshTokens.add(refreshToken);
    return onRefresh!(refreshToken);
  }

  @override
  Future<void> logout(String accessToken) {
    logoutTokens.add(accessToken);
    return onLogout?.call(accessToken) ?? Future.value();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => Future.value(_session('1'));

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

void main() {
  late DateTime ahora;
  DateTime reloj() => ahora;

  setUp(() => ahora = DateTime.utc(2026, 11, 26, 20));

  /// Sesión guardada recibida en [recibida] (vence 15 min después).
  StoredSession guardada(String n, {DateTime? recibida}) =>
      StoredSession.fromAuthSession(_session(n), recibida ?? ahora);

  group('Con la API en memoria (FakeAuthApi)', () {
    late FakeAuthApi api;
    late MemorySessionStore store;
    late SessionProvider session;

    setUp(() async {
      api = FakeAuthApi(now: reloj);
      await api.register(
        name: 'Ana López',
        email: 'ana@mail.com',
        password: 'kopay2026',
      );
      store = MemorySessionStore();
      session = SessionProvider(api: api, store: store, now: reloj);
    });

    test(
      'SES-01 · HU-31 · sin sesión guardada se abre Iniciar sesión',
      () async {
        expect(session.status, SessionStatus.unknown);

        await session.restore();

        expect(session.status, SessionStatus.signedOut);
        expect(session.user, isNull);
        expect(session.sessionExpired, isFalse);
      },
    );

    test(
      'SES-02 · HU-31 · el login guarda tokens, vencimientos y cuenta',
      () async {
        final avisos = <SessionStatus>[];
        session.addListener(() => avisos.add(session.status));

        final user = await session.login(
          email: 'ana@mail.com',
          password: 'kopay2026',
        );

        final saved = store.current!;
        expect(user.email, 'ana@mail.com');
        expect(session.status, SessionStatus.signedIn);
        expect(session.user, user);
        expect(saved.refreshToken, isNotNull);
        expect(saved.accessExpiresAt, ahora.add(const Duration(minutes: 15)));
        expect(saved.refreshExpiresAt, ahora.add(const Duration(days: 30)));
        expect(avisos, [SessionStatus.signedIn]);
      },
    );

    test('SES-03 · HU-31 · al reabrir la app la sesión guardada sigue y se '
        'confirma con me', () async {
      await session.login(email: 'ana@mail.com', password: 'kopay2026');
      final reabierta = SessionProvider(api: api, store: store, now: reloj);

      await reabierta.restore();

      expect(reabierta.status, SessionStatus.signedIn);
      expect(reabierta.user!.email, 'ana@mail.com');
      expect(reabierta.offline, isFalse);
    });

    test('SES-04 · HU-31 · con el token vencido renueva antes de llamar y '
        'reemplaza los dos tokens', () async {
      await session.login(email: 'ana@mail.com', password: 'kopay2026');
      final antes = store.current!;

      ahora = ahora.add(const Duration(minutes: 16));
      final reabierta = SessionProvider(api: api, store: store, now: reloj);
      await reabierta.restore();

      final despues = store.current!;
      expect(reabierta.status, SessionStatus.signedIn);
      expect(despues.accessToken, isNot(antes.accessToken));
      expect(despues.refreshToken, isNot(antes.refreshToken));
      // Rotación (§3.5): el refreshToken usado ya no sirve.
      await expectLater(
        api.refresh(antes.refreshToken!),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });

    test(
      'SES-05 · HU-33 · logout borra la sesión y la cierra en la API',
      () async {
        await session.login(email: 'ana@mail.com', password: 'kopay2026');
        final token = store.current!.accessToken;

        await session.logout();

        expect(session.status, SessionStatus.signedOut);
        expect(store.current, isNull);
        expect(session.sessionExpired, isFalse);
        await expectLater(api.me(token), throwsA(isA<ApiException>()));
      },
    );

    test('SES-06 · HU-33 · logout sin red también cierra la sesión', () async {
      await session.login(email: 'ana@mail.com', password: 'kopay2026');
      api.failNextWith(const NetworkException());

      await session.logout();

      expect(session.status, SessionStatus.signedOut);
      expect(store.current, isNull);
    });

    test('SES-07 · HU-31 · un login fallido no cambia la sesión', () async {
      await expectLater(
        session.login(email: 'ana@mail.com', password: 'mala2026'),
        throwsA(isA<ApiException>()),
      );

      expect(session.status, SessionStatus.unknown);
      expect(store.current, isNull);
    });
  });

  group('Renovación y retorno a Iniciar sesión', () {
    late _ScriptedApi api;
    late MemorySessionStore store;

    setUp(() {
      api = _ScriptedApi();
      store = MemorySessionStore(guardada('1'));
    });

    SessionProvider provider() =>
        SessionProvider(api: api, store: store, now: reloj);

    test('SES-08 · HU-31 · un 401 de la API renueva y repite la petición una '
        'vez', () async {
      api.onMe = (t) async => t == 'access-1' ? throw _unauth : _ana;
      api.onRefresh = (_) async => _session('2');
      final session = provider();

      await session.restore();

      expect(api.meTokens, ['access-1', 'access-2']);
      expect(api.refreshTokens, ['refresh-1']);
      expect(store.current!.accessToken, 'access-2');
      expect(session.status, SessionStatus.signedIn);
    });

    test('SES-09 · HU-31 · si la renovación responde 401 se borra la sesión y '
        'vuelve a Iniciar sesión', () async {
      // Por ejemplo: la contraseña se cambió en otro dispositivo (HU-32).
      api.onMe = (_) async => throw _unauth;
      api.onRefresh = (_) async => throw _unauth;
      final session = provider();

      await session.restore();

      expect(session.status, SessionStatus.signedOut);
      expect(session.sessionExpired, isTrue);
      expect(store.current, isNull);
    });

    test('SES-10 · HU-31 · pasados 30 días no intenta renovar: vuelve a '
        'Iniciar sesión', () async {
      api.onMe = (_) async => _ana;
      ahora = ahora.add(const Duration(days: 30));
      final session = provider();

      await session.restore();

      expect(api.refreshTokens, isEmpty);
      expect(api.meTokens, isEmpty);
      expect(session.status, SessionStatus.signedOut);
      expect(session.sessionExpired, isTrue);
      expect(store.current, isNull);
    });

    test('SES-11 · HU-31 · sin red se conserva la sesión guardada', () async {
      api.onMe = (_) async => throw const NetworkException();
      final session = provider();

      await session.restore();

      expect(session.status, SessionStatus.signedIn);
      expect(session.offline, isTrue);
      expect(session.user, _ana);
      expect(store.current!.accessToken, 'access-1');
    });

    test('SES-12 · HU-31 · con la API caída (503) o sin red al renovar se '
        'conserva la sesión', () async {
      api.onMe = (_) async => throw const ApiException(
        503,
        ApiErrorCode.unavailable,
        'El servicio no está disponible. Inténtalo de nuevo.',
      );
      final caida = provider();
      await caida.restore();
      expect(caida.status, SessionStatus.signedIn);
      expect(caida.offline, isTrue);

      // Token vencido y renovación sin red.
      ahora = ahora.add(const Duration(minutes: 16));
      api.onRefresh = (_) async => throw const NetworkException();
      final sinRed = provider();
      await sinRed.restore();
      expect(sinRed.status, SessionStatus.signedIn);
      expect(sinRed.offline, isTrue);
      expect(store.current!.refreshToken, 'refresh-1');
    });

    test('SES-13 · HU-31 · varias peticiones con el token vencido hacen una '
        'sola renovación', () async {
      api.onMe = (_) async => _ana;
      api.onRefresh = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _session('2');
      };
      final session = provider();
      await session.restore(); // token vigente: no renueva
      expect(api.refreshTokens, isEmpty);

      ahora = ahora.add(const Duration(minutes: 16));
      final tokens = await Future.wait([
        for (var i = 0; i < 5; i++) session.authorized((t) async => t),
      ]);

      expect(api.refreshTokens, ['refresh-1']);
      expect(tokens, everyElement('access-2'));
    });

    test('SES-14 · HU-31 · varios 401 a la vez también hacen una sola '
        'renovación', () async {
      api.onRefresh = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _session('2');
      };
      final session = provider();
      api.onMe = (_) async => _ana;
      await session.restore();

      final llamadas = <String>[];
      Future<String> llamada(String t) async {
        llamadas.add(t);
        if (t == 'access-1') throw _unauth;
        return t;
      }

      final tokens = await Future.wait([
        for (var i = 0; i < 4; i++) session.authorized(llamada),
      ]);

      expect(api.refreshTokens, ['refresh-1']);
      expect(tokens, everyElement('access-2'));
      expect(llamadas.where((t) => t == 'access-2'), hasLength(4));
    });

    test('SES-15 · HU-31 · si después de renovar la API sigue diciendo 401, se '
        'cierra la sesión', () async {
      api.onMe = (_) async => _ana;
      api.onRefresh = (_) async => _session('2');
      final session = provider();
      await session.restore();

      await expectLater(
        session.authorized<void>((_) async => throw _unauth),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );

      expect(api.refreshTokens, ['refresh-1']);
      expect(session.status, SessionStatus.signedOut);
      expect(session.sessionExpired, isTrue);
      expect(store.current, isNull);
    });

    test('SES-16 · HU-31 · iniciar sesión otra vez apaga el aviso de sesión '
        'vencida', () async {
      api.onMe = (_) async => throw _unauth;
      api.onRefresh = (_) async => throw _unauth;
      final session = provider();
      await session.restore();
      expect(session.sessionExpired, isTrue);

      await session.login(email: 'ana@mail.com', password: 'kopay2026');

      expect(session.sessionExpired, isFalse);
      expect(session.status, SessionStatus.signedIn);
    });

    test('SES-17 · HU-31 · sin sesión, authorized responde 401 sin llamar a la '
        'API', () async {
      final session = SessionProvider(
        api: api,
        store: MemorySessionStore(),
        now: reloj,
      );
      await session.restore();

      await expectLater(
        session.authorized((t) async => t),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(api.meTokens, isEmpty);
    });
  });
}
