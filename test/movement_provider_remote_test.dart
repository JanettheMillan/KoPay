// S5-07 · Movimientos de Flutter conectados con la API (HU-01, HU-05,
// HU-06, HU-34).
//
// SQLite real (sqflite_common_ffi) y una API de movimientos en memoria que
// separa los datos por cuenta, como /api/movements. La sesión es
// SessionProvider con FakeAuthApi. El plan de pruebas no tiene casos de
// esto; REM-01 a REM-13 son pruebas nuevas, anotadas en el PR.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/movements_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// /api/movements en memoria: cada cuenta ve solo lo suyo (HU-34).
class _FakeMovementsApi implements MovementsApi {
  _FakeMovementsApi(this.auth);
  final FakeAuthApi auth;

  /// Correo de la cuenta → id remoto → movimiento.
  final Map<String, Map<String, RemoteMovement>> byAccount = {};
  int _next = 0;
  Object? failWith;
  int calls = 0;

  /// Si no es `null`, `create` espera a que se complete (para cambiar de
  /// cuenta a media subida).
  Completer<void>? holdCreate;

  /// Movimientos de la cuenta [email] en el servidor.
  Map<String, RemoteMovement> of(String email) => byAccount[email] ?? {};

  Future<Map<String, RemoteMovement>> _account(String token) async {
    calls++;
    final error = failWith;
    if (error != null) throw error;
    final email = (await auth.me(token)).email;
    return byAccount.putIfAbsent(email, () => {});
  }

  static const _notFound = ApiException(
    404,
    'NOT_FOUND',
    'No encontramos ese registro',
  );

  @override
  Future<List<RemoteMovement>> list(String token) async =>
      (await _account(token)).values.toList();

  @override
  Future<RemoteMovement> create(String token, Movement m) async {
    final store = await _account(token);
    await holdCreate?.future;
    if (m.description.length > 60) {
      throw const ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: {
          'description': 'La descripción puede tener hasta 60 caracteres',
        },
      );
    }
    final id = 'r${++_next}';
    final r = (remoteId: id, version: 1, movement: _sinId(m));
    store[id] = r;
    return r;
  }

  @override
  Future<RemoteMovement> update(
    String token,
    String remoteId,
    Movement m, {
    int? version,
  }) async {
    final store = await _account(token);
    final current = store[remoteId];
    if (current == null) throw _notFound;
    if (version != null && version != current.version) {
      throw const ApiException(
        409,
        'VERSION_CONFLICT',
        'El movimiento cambió en otro dispositivo. Vuelve a cargarlo.',
      );
    }
    final r = (
      remoteId: remoteId,
      version: current.version + 1,
      movement: _sinId(m),
    );
    store[remoteId] = r;
    return r;
  }

  @override
  Future<void> delete(String token, String remoteId) async {
    final store = await _account(token);
    if (store.remove(remoteId) == null) throw _notFound;
  }

  static Movement _sinId(Movement m) => Movement(
    amount: m.amount,
    description: m.description,
    category: m.category,
    date: m.date,
    note: m.note,
    type: m.type,
  );
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late FakeAuthApi auth;
  late _FakeMovementsApi api;
  late SessionProvider session;
  late MovementProvider movements;

  Movement gasto(String description, {double amount = -100, int dia = 3}) =>
      Movement(
        amount: amount,
        description: description,
        category: 'Comida',
        date: DateTime(2026, 11, dia),
      );

  /// Espera a que termine lo que dispara bindSession (microtareas y SQLite).
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> entrar(String email) async {
    await session.login(email: email, password: 'kopay2026');
    movements.bindSession(session);
    await settle();
  }

  Future<void> salir() async {
    await session.logout();
    movements.bindSession(session);
    await settle();
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kopay_remote_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    auth = FakeAuthApi();
    for (final email in ['ana@mail.com', 'beto@mail.com']) {
      await auth.register(name: 'Cuenta', email: email, password: 'kopay2026');
    }
    api = _FakeMovementsApi(auth);
    session = SessionProvider(api: auth, store: MemorySessionStore());
    movements = MovementProvider(database: db, api: api);
    await session.restore();
    movements.bindSession(session);
    await movements.load();
  });

  tearDown(() async {
    movements.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('REM-01 · HU-01 · sin sesión todo queda en SQLite y no llama a la '
      'API', () async {
    await movements.add(gasto('Súper'));

    expect(movements.isRemote, isFalse);
    expect(movements.movements.single.description, 'Súper');
    expect(api.calls, 0);
  });

  test('REM-02 · HU-01 · al iniciar sesión sube lo que solo estaba en el '
      'teléfono y no se pierde', () async {
    await movements.add(gasto('Antes de entrar'));

    await entrar('ana@mail.com');

    expect(movements.isRemote, isTrue);
    expect(api.of('ana@mail.com').values.map((r) => r.movement.description), [
      'Antes de entrar',
    ]);
    expect(movements.movements.map((m) => m.description), ['Antes de entrar']);
    expect(await db.getLocalOnlyMovements(), isEmpty);
  });

  test('REM-03 · HU-01 · con sesión, un gasto nuevo se crea en la API y queda '
      'en la copia', () async {
    await entrar('ana@mail.com');

    final saved = await movements.add(gasto('Gasolina', amount: -650));

    final remoto = api.of('ana@mail.com').values.single;
    expect(remoto.movement.amount, -650);
    expect(remoto.version, 1);
    expect(saved.id, isNotNull);
    final link = await db.getMovementRemote(saved.id!);
    expect(link?.remoteId, remoto.remoteId);
    expect(movements.movements.single.description, 'Gasolina');
  });

  test(
    'REM-04 · HU-05 · editar manda la versión y la guarda aumentada',
    () async {
      await entrar('ana@mail.com');
      final saved = await movements.add(gasto('Café', amount: -45));

      await movements.update(
        saved.copyWith(amount: -55, description: 'Café grande'),
      );

      final remoto = api.of('ana@mail.com').values.single;
      expect(remoto.movement.amount, -55);
      expect(remoto.version, 2);
      expect((await db.getMovementRemote(saved.id!))?.version, 2);
      expect(movements.movements.single.description, 'Café grande');
    },
  );

  test('REM-05 · HU-36 · si cambió en otro dispositivo (409) avisa y recarga '
      'lo que hay en la API', () async {
    await entrar('ana@mail.com');
    final saved = await movements.add(gasto('Renta', amount: -5000));
    // Otro dispositivo lo edita primero.
    final id = api.of('ana@mail.com').keys.single;
    api.byAccount['ana@mail.com']![id] = (
      remoteId: id,
      version: 2,
      movement: gasto('Renta noviembre', amount: -5200),
    );

    await expectLater(
      movements.update(saved.copyWith(description: 'Renta mía')),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );

    expect(movements.movements.single.description, 'Renta noviembre');
    expect(movements.movements.single.amount, -5200);
  });

  test('REM-06 · HU-06 · borrar lo quita de la API y del teléfono; si ya no '
      'existía allá, igual se quita', () async {
    await entrar('ana@mail.com');
    final a = await movements.add(gasto('Uno'));
    final b = await movements.add(gasto('Dos', dia: 4));
    api.byAccount['ana@mail.com']!.removeWhere(
      (_, r) => r.movement.description == 'Dos',
    );

    await movements.delete(a.id!);
    await movements.delete(b.id!);

    expect(api.of('ana@mail.com'), isEmpty);
    expect(movements.movements, isEmpty);
  });

  test('REM-07 · HU-01 · sin red se ve la copia guardada y guardar avisa sin '
      'guardar a medias', () async {
    await entrar('ana@mail.com');
    await movements.add(gasto('Súper'));
    api.failWith = const NetworkException();

    await movements.sync();
    expect(movements.offline, isTrue);
    expect(movements.movements.single.description, 'Súper');

    await expectLater(
      movements.add(gasto('Sin red')),
      throwsA(isA<NetworkException>()),
    );
    expect(movements.movements.map((m) => m.description), ['Súper']);

    api.failWith = null;
    await movements.sync();
    expect(movements.offline, isFalse);
  });

  test('REM-08 · HU-34 · al cerrar sesión se borra la copia, y otra cuenta en '
      'el mismo teléfono solo ve lo suyo', () async {
    await entrar('ana@mail.com');
    await movements.add(gasto('De Ana'));

    await salir();
    expect(movements.movements, isEmpty);

    await entrar('beto@mail.com');
    await movements.add(gasto('De Beto'));
    expect(movements.movements.map((m) => m.description), ['De Beto']);
    expect(api.of('ana@mail.com').values.single.movement.description, 'De Ana');

    await salir();
    await entrar('ana@mail.com');
    expect(movements.movements.map((m) => m.description), ['De Ana']);
  });

  test('REM-09 · HU-16 · los pagos no se mandan a la API y se conservan al '
      'cambiar de cuenta', () async {
    final card = await db.insertCard(
      const CardModel(
        name: 'Oro',
        bank: 'BBVA',
        creditLimit: 1000,
        usedBalance: 500,
        cutDay: 5,
        paymentDay: 25,
      ),
    );
    await db.insertCardPayment(
      cardId: card.id!,
      amount: 200,
      date: DateTime(2026, 11, 10),
    );

    await entrar('ana@mail.com');
    await salir();

    expect(api.of('ana@mail.com'), isEmpty);
    expect(movements.movements.single.isPayment, isTrue);
  });

  test('REM-10 · HU-04 · un movimiento viejo que la API rechaza se queda en el '
      'teléfono y no detiene a los demás', () async {
    await movements.add(gasto('x' * 61));
    await movements.add(gasto('Normal', dia: 4));

    await entrar('ana@mail.com');

    expect(api.of('ana@mail.com').values.map((r) => r.movement.description), [
      'Normal',
    ]);
    expect(movements.offline, isFalse);
    expect(movements.movements, hasLength(2));
  });

  test(
    'REM-11 · HU-04 · un error de la API llega con el mensaje del campo',
    () async {
      await entrar('ana@mail.com');

      // La regla local de la app no limita el largo; la API sí (§3.12).
      await expectLater(
        movements.add(gasto('y' * 61)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.displayMessage,
            'displayMessage',
            'La descripción puede tener hasta 60 caracteres',
          ),
        ),
      );
      expect(movements.movements, isEmpty);
    },
  );

  test('REM-12 · HU-37 · una cuenta de contador no usa los movimientos de la '
      'API', () async {
    final contador = SessionProvider(
      api: _ContadorApi(),
      store: MemorySessionStore(),
    );
    await contador.login(email: 'carla@conta.mx', password: 'x');

    movements.bindSession(contador);
    await settle();

    expect(movements.isRemote, isFalse);
    expect(api.calls, 0);
  });

  test('REM-13 · HU-31 · si la sesión se cierra en el servidor, la copia de '
      'la cuenta se borra', () async {
    await entrar('ana@mail.com');
    await movements.add(gasto('De Ana'));

    // Por ejemplo, un cambio de contraseña (S4-19): el token y la
    // renovación dejan de servir.
    await auth.logout(await session.authorized((t) async => t));
    await movements.sync();
    movements.bindSession(session);
    await settle();

    expect(session.status, SessionStatus.signedOut);
    expect(session.sessionExpired, isTrue);
    expect(movements.isRemote, isFalse);
    expect(movements.movements, isEmpty);
  });

  test('REM-15 · HU-34 · si se cambia de cuenta a media subida, no se sigue '
      'con la anterior y la nueva sí se sincroniza', () async {
    await movements.add(gasto('Uno', dia: 1));
    await movements.add(gasto('Dos', dia: 2));
    api.byAccount['beto@mail.com'] = {
      'b1': (remoteId: 'b1', version: 1, movement: gasto('De Beto')),
    };
    api.holdCreate = Completer<void>();

    // Ana entra y la subida de "Uno" se queda esperando.
    await entrar('ana@mail.com');
    // Cambia a Beto antes de que termine.
    await salir();
    await session.login(email: 'beto@mail.com', password: 'kopay2026');
    movements.bindSession(session);
    api.holdCreate!.complete();
    api.holdCreate = null;
    await settle();

    // A Ana solo llegó lo que ya se estaba subiendo.
    expect(api.of('ana@mail.com').values.map((r) => r.movement.description), [
      'Uno',
    ]);
    expect(movements.isRemote, isTrue);
    expect(movements.movements.map((m) => m.description), contains('De Beto'));
    expect(
      movements.movements.map((m) => m.description),
      isNot(contains('Uno')),
    );
  });

  test('REM-16 · HU-34 · lo que la API rechazó se borra al cerrar sesión y '
      'la siguiente cuenta no lo ve ni lo sube', () async {
    await movements.add(gasto('x' * 61));

    await entrar('ana@mail.com');
    expect(movements.movements.single.description, 'x' * 61);

    await salir();
    expect(movements.movements, isEmpty);

    await entrar('beto@mail.com');
    expect(movements.movements, isEmpty);
    expect(api.of('beto@mail.com'), isEmpty);
  });

  test('REM-17 · HU-36 · dos instalaciones con la misma cuenta ven los mismos '
      'cambios, sin duplicados ni datos de otra cuenta', () async {
    // Segunda instalación: otra base y otra sesión, misma API.
    final db2 = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/segunda.db',
    );
    final session2 = SessionProvider(api: auth, store: MemorySessionStore());
    final movements2 = MovementProvider(database: db2, api: api);
    addTearDown(() async {
      movements2.dispose();
      await db2.close();
    });
    await session2.restore();
    await movements2.load();
    api.byAccount['beto@mail.com'] = {
      'b1': (remoteId: 'b1', version: 1, movement: gasto('De Beto')),
    };

    await entrar('ana@mail.com');
    await session2.login(email: 'ana@mail.com', password: 'kopay2026');
    movements2.bindSession(session2);
    await settle();

    // Alta en la primera; la segunda la ve una sola vez.
    await movements.add(gasto('Café', amount: -45));
    await movements2.sync();
    await movements2.sync();
    expect(movements2.movements.map((m) => m.description), ['Café']);

    // Edición en la segunda; la primera la ve.
    await movements2.update(
      movements2.movements.single.copyWith(amount: -55, description: 'Café 2'),
    );
    await movements.sync();
    expect(movements.movements.single.description, 'Café 2');
    expect(movements.movements.single.amount, -55);

    // Borrado en la primera; la segunda ya no lo ve.
    await movements.delete(movements.movements.single.id!);
    await movements2.sync();
    expect(movements2.movements, isEmpty);
    expect(movements.movements, isEmpty);
    expect(api.of('beto@mail.com'), hasLength(1));
  });

  test('REM-14 · HU-01 · una base versión 4 se migra a la actual sin perder '
      'movimientos y todos quedan como solo del teléfono', () async {
    // Base como la dejó S2-09 (versión 4), con un gasto.
    await db.close();
    final path = '${tempDir.path}/v4.db';
    final v4 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE movements (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'amount REAL NOT NULL, description TEXT NOT NULL, '
            'category TEXT NOT NULL, date TEXT NOT NULL, note TEXT, '
            "type TEXT NOT NULL DEFAULT 'regular', card_id INTEGER, "
            'debt_id INTEGER)',
          );
          await d.insert('movements', {
            'amount': -50,
            'description': 'Café',
            'category': 'Comida',
            'date': DateTime(2026, 11, 3).toIso8601String(),
          });
        },
      ),
    );
    await v4.close();

    db = DatabaseHelper.withFactory(databaseFactoryFfi, path);
    final base = await db.database;

    // S5-08 subió la base a la versión 6 (ingresos de la API).
    expect(await base.getVersion(), DatabaseHelper.version);
    expect((await db.getMovements()).single.description, 'Café');
    expect((await db.getLocalOnlyMovements()).single.description, 'Café');
  });
}

class _ContadorApi extends FakeAuthApi {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession(
    accessToken: 'acc',
    tokenType: 'Bearer',
    expiresIn: 900,
    user: AuthUser(
      id: 'c1',
      name: 'Carla',
      email: email,
      role: 'accountant',
      createdAt: DateTime.utc(2026, 11, 26),
    ),
  );
}
