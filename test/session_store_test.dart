// S4-08 · Sesión guardada en el dispositivo (HU-30, HU-31).
//
// UT-49 es el caso de docs/plan-de-pruebas.md, extendido en S4-08 con la
// conversión de ida y vuelta (toMap). STO-01 a STO-05 son pruebas nuevas.
// flutter_secure_storage usa su almacén de prueba (setMockInitialValues):
// no toca el Keystore ni el Keychain.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/session_store.dart';

const _cuenta = {
  'id': '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f',
  'name': 'Carla Ruiz',
  'email': 'carla@conta.mx',
  'role': 'accountant',
  'createdAt': '2026-11-26T18:30:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UT-49 · HU-30 · Conversión de cuenta', () {
    test('fromMap conserva id, name, email, role y createdAt', () {
      final user = AuthUser.fromMap(_cuenta);

      expect(user.id, _cuenta['id']);
      expect(user.name, 'Carla Ruiz');
      expect(user.email, 'carla@conta.mx');
      expect(user.role, 'accountant');
      expect(user.createdAt, DateTime.utc(2026, 11, 26, 18, 30));
    });

    test('isAccountant es verdadero con accountant y falso con user', () {
      expect(AuthUser.fromMap(_cuenta).isAccountant, isTrue);
      expect(
        AuthUser.fromMap({..._cuenta, 'role': 'user'}).isAccountant,
        isFalse,
      );
    });

    test(
      'toMap y fromMap de ida y vuelta devuelven la misma cuenta (S4-08)',
      () {
        final user = AuthUser.fromMap(_cuenta);

        final copia = AuthUser.fromMap(user.toMap());

        expect(user.toMap(), _cuenta);
        expect(copia, user);
        expect(copia.isAccountant, isTrue);
      },
    );
  });

  group('StoredSession', () {
    final recibida = DateTime.utc(2026, 11, 26, 20);
    final login = AuthSession(
      accessToken: 'access-1',
      tokenType: 'Bearer',
      expiresIn: 900,
      refreshToken: 'refresh-1',
      refreshExpiresIn: 2592000,
      user: AuthUser.fromMap(_cuenta),
    );

    test('STO-01 · HU-31 · calcula los vencimientos desde expiresIn y '
        'refreshExpiresIn', () {
      final s = StoredSession.fromAuthSession(login, recibida);

      expect(s.accessExpiresAt, DateTime.utc(2026, 11, 26, 20, 15));
      expect(s.refreshExpiresAt, DateTime.utc(2026, 12, 26, 20));
      expect(s.accessExpired(DateTime.utc(2026, 11, 26, 20, 14, 59)), isFalse);
      expect(s.accessExpired(DateTime.utc(2026, 11, 26, 20, 15)), isTrue);
      expect(s.canRefresh(DateTime.utc(2026, 12, 26, 19, 59)), isTrue);
      expect(s.canRefresh(DateTime.utc(2026, 12, 26, 20)), isFalse);
    });

    test('STO-02 · HU-31 · sin refreshToken (antes de S4-02) no se puede '
        'renovar', () {
      final viejo = AuthSession(
        accessToken: 'a',
        tokenType: 'Bearer',
        expiresIn: 900,
        user: login.user,
      );

      final s = StoredSession.fromAuthSession(viejo, recibida);

      expect(s.refreshToken, isNull);
      expect(s.canRefresh(recibida), isFalse);
    });

    test('STO-03 · HU-31 · toMap y fromMap de ida y vuelta', () {
      final s = StoredSession.fromAuthSession(login, recibida);

      final copia = StoredSession.fromMap(
        jsonDecode(jsonEncode(s.toMap())) as Map<String, dynamic>,
      );

      expect(copia.accessToken, 'access-1');
      expect(copia.refreshToken, 'refresh-1');
      expect(copia.accessExpiresAt, s.accessExpiresAt);
      expect(copia.refreshExpiresAt, s.refreshExpiresAt);
      expect(copia.user, s.user);
    });
  });

  group('SecureSessionStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    final sesion = StoredSession.fromAuthSession(
      AuthSession(
        accessToken: 'access-1',
        tokenType: 'Bearer',
        expiresIn: 900,
        refreshToken: 'refresh-1',
        refreshExpiresIn: 2592000,
        user: AuthUser.fromMap(_cuenta),
      ),
      DateTime.utc(2026, 11, 26, 20),
    );

    test('STO-04 · HU-31 · guarda, lee y borra la sesión cifrada', () async {
      final store = SecureSessionStore();
      expect(await store.read(), isNull);

      await store.write(sesion);
      final leida = await store.read();
      expect(leida!.accessToken, 'access-1');
      expect(leida.user.email, 'carla@conta.mx');

      // Se guarda en flutter_secure_storage con una sola clave.
      final raw = await const FlutterSecureStorage().read(
        key: SecureSessionStore.key,
      );
      expect(raw, contains('refresh-1'));

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('STO-05 · HU-31 · una sesión dañada se descarta y se borra', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureSessionStore.key: '{"accessToken": 1',
      });
      final store = SecureSessionStore();

      expect(await store.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: SecureSessionStore.key),
        isNull,
      );
    });
  });
}
