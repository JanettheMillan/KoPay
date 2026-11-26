// S5-08 · Ingresos y resumen de Flutter conectados con la API (HU-02,
// HU-09, HU-34).
//
// SQLite real (sqflite_common_ffi) y una API de ingresos en memoria que
// separa los datos por cuenta, como /api/incomes. La sesión es
// SessionProvider con FakeAuthApi. El plan de pruebas no tiene casos de
// esto; RIN-01 a RIN-13 son pruebas nuevas, anotadas en el PR.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/incomes_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// /api/incomes en memoria: cada cuenta ve solo lo suyo (HU-34).
class _FakeIncomesApi implements IncomesApi {
  _FakeIncomesApi(this.auth);
  final FakeAuthApi auth;

  /// Correo de la cuenta → id remoto → ingreso.
  final Map<String, Map<String, RemoteIncome>> byAccount = {};
  int _next = 0;
  Object? failWith;
  int calls = 0;

  /// Si no es `null`, `create` espera a que se complete (para cambiar de
  /// cuenta a media subida).
  Completer<void>? holdCreate;

  /// Ingresos de la cuenta [email] en el servidor.
  Map<String, RemoteIncome> of(String email) => byAccount[email] ?? {};

  Future<Map<String, RemoteIncome>> _account(String token) async {
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
  Future<List<RemoteIncome>> list(String token) async =>
      (await _account(token)).values.toList();

  @override
  Future<RemoteIncome> create(String token, Income i) async {
    final store = await _account(token);
    await holdCreate?.future;
    if (i.name.length > 60) {
      throw const ApiException(
        400,
        ApiErrorCode.validationFailed,
        'Revisa los datos marcados',
        fields: {'name': 'El nombre puede tener hasta 60 caracteres'},
      );
    }
    final id = 'i${++_next}';
    final r = (remoteId: id, version: 1, income: _sinId(i));
    store[id] = r;
    return r;
  }

  @override
  Future<RemoteIncome> update(
    String token,
    String remoteId,
    Income i, {
    int? version,
  }) async {
    final store = await _account(token);
    final current = store[remoteId];
    if (current == null) throw _notFound;
    if (version != null && version != current.version) {
      throw const ApiException(
        409,
        'VERSION_CONFLICT',
        'El ingreso cambió en otro dispositivo. Vuelve a cargarlo.',
      );
    }
    final r = (
      remoteId: remoteId,
      version: current.version + 1,
      income: _sinId(i),
    );
    store[remoteId] = r;
    return r;
  }

  @override
  Future<void> delete(String token, String remoteId) async {
    final store = await _account(token);
    if (store.remove(remoteId) == null) throw _notFound;
  }

  static Income _sinId(Income i) =>
      Income(name: i.name, amount: i.amount, date: i.date, note: i.note);
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late FakeAuthApi auth;
  late _FakeIncomesApi api;
  late SessionProvider session;
  late IncomeProvider incomes;

  final noviembre = DateTime(2026, 11);

  Income ingreso(String name, {double amount = 1000, int dia = 15}) =>
      Income(name: name, amount: amount, date: DateTime(2026, 11, dia));

  /// Espera a que termine lo que dispara bindSession (microtareas y SQLite).
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> entrar(String email) async {
    await session.login(email: email, password: 'kopay2026');
    incomes.bindSession(session);
    await settle();
  }

  Future<void> salir() async {
    await session.logout();
    incomes.bindSession(session);
    await settle();
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kopay_income_remote');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    auth = FakeAuthApi();
    for (final email in ['ana@mail.com', 'beto@mail.com']) {
      await auth.register(name: 'Cuenta', email: email, password: 'kopay2026');
    }
    api = _FakeIncomesApi(auth);
    session = SessionProvider(api: auth, store: MemorySessionStore());
    incomes = IncomeProvider(database: db, api: api);
    await session.restore();
    incomes.bindSession(session);
    await incomes.load();
  });

  tearDown(() async {
    incomes.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('RIN-01 · HU-02 · sin sesión todo queda en SQLite y no llama a la '
      'API', () async {
    await incomes.add(ingreso('Nómina'));

    expect(incomes.isRemote, isFalse);
    expect(incomes.incomes.single.name, 'Nómina');
    expect(api.calls, 0);
  });

  test('RIN-02 · HU-02 · al iniciar sesión sube lo que solo estaba en el '
      'teléfono y no se pierde', () async {
    await incomes.add(ingreso('Antes de entrar'));

    await entrar('ana@mail.com');

    expect(incomes.isRemote, isTrue);
    expect(api.of('ana@mail.com').values.map((r) => r.income.name), [
      'Antes de entrar',
    ]);
    expect(incomes.incomes.map((i) => i.name), ['Antes de entrar']);
    expect(await db.getLocalOnlyIncomes(), isEmpty);
  });

  test('RIN-03 · HU-02 · con sesión, un ingreso nuevo se crea en la API y '
      'queda en la copia', () async {
    await entrar('ana@mail.com');

    final saved = await incomes.add(ingreso('Nómina', amount: 12500));

    final remoto = api.of('ana@mail.com').values.single;
    expect(remoto.income.amount, 12500);
    expect(remoto.version, 1);
    expect(saved.id, isNotNull);
    expect((await db.getIncomeRemote(saved.id!))?.remoteId, remoto.remoteId);
    expect(incomes.incomes.single.name, 'Nómina');
  });

  test('RIN-04 · HU-09 · los datos remotos actualizan el resumen del mes sin '
      'duplicados', () async {
    // Ingresos que ya estaban en la cuenta, por ejemplo desde otro
    // teléfono.
    api.byAccount['ana@mail.com'] = {
      'x1': (
        remoteId: 'x1',
        version: 1,
        income: ingreso('Nómina', amount: 12500),
      ),
      'x2': (
        remoteId: 'x2',
        version: 1,
        income: ingreso('Freelance', amount: 800.5, dia: 20),
      ),
      'x3': (
        remoteId: 'x3',
        version: 1,
        income: Income(
          name: 'Octubre',
          amount: 999,
          date: DateTime(2026, 10, 30),
        ),
      ),
    };
    var avisos = 0;
    incomes.addListener(() => avisos++);

    await entrar('ana@mail.com');
    // Volver a leer (al abrir la app o tras otro cambio) no los repite.
    await incomes.sync();
    await incomes.load();

    expect(avisos, greaterThan(0));
    expect(incomes.incomes, hasLength(3));
    expect(incomes.forMonth(noviembre).map((i) => i.name), [
      'Freelance',
      'Nómina',
    ]);
    expect(incomes.totalForMonth(noviembre), 13300.5);
    expect(await db.getIncomes(), hasLength(3));
  });

  test('RIN-05 · HU-09 · un cambio en otro dispositivo se ve en la siguiente '
      'lectura sin duplicar', () async {
    await entrar('ana@mail.com');
    await incomes.add(ingreso('Nómina', amount: 12500));

    // Otro dispositivo corrige el monto y agrega un ingreso.
    final id = api.of('ana@mail.com').keys.single;
    api.byAccount['ana@mail.com']![id] = (
      remoteId: id,
      version: 2,
      income: ingreso('Nómina', amount: 13000),
    );
    api.byAccount['ana@mail.com']!['otro'] = (
      remoteId: 'otro',
      version: 1,
      income: ingreso('Venta', amount: 300, dia: 2),
    );

    await incomes.sync();

    expect(incomes.incomes.map((i) => i.name), ['Nómina', 'Venta']);
    expect(incomes.totalForMonth(noviembre), 13300);
  });

  test(
    'RIN-06 · HU-02 · editar manda la versión y la guarda aumentada',
    () async {
      await entrar('ana@mail.com');
      final saved = await incomes.add(ingreso('Nómina', amount: 12500));

      await incomes.update(saved.copyWith(amount: 13000, name: 'Nómina dic'));

      final remoto = api.of('ana@mail.com').values.single;
      expect(remoto.income.amount, 13000);
      expect(remoto.version, 2);
      expect((await db.getIncomeRemote(saved.id!))?.version, 2);
      expect(incomes.incomes.single.name, 'Nómina dic');
    },
  );

  test('RIN-07 · HU-36 · si cambió en otro dispositivo (409) avisa y recarga '
      'lo que hay en la API', () async {
    await entrar('ana@mail.com');
    final saved = await incomes.add(ingreso('Nómina', amount: 12500));
    final id = api.of('ana@mail.com').keys.single;
    api.byAccount['ana@mail.com']![id] = (
      remoteId: id,
      version: 2,
      income: ingreso('Nómina noviembre', amount: 12800),
    );

    await expectLater(
      incomes.update(saved.copyWith(name: 'Mi nómina')),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );

    expect(incomes.incomes.single.name, 'Nómina noviembre');
    expect(incomes.totalForMonth(noviembre), 12800);
  });

  test('RIN-08 · HU-02 · borrar lo quita de la API y del teléfono; si ya no '
      'existía allá, igual se quita', () async {
    await entrar('ana@mail.com');
    final a = await incomes.add(ingreso('Uno'));
    final b = await incomes.add(ingreso('Dos', dia: 16));
    api.byAccount['ana@mail.com']!.removeWhere(
      (_, r) => r.income.name == 'Dos',
    );

    await incomes.delete(a.id!);
    await incomes.delete(b.id!);

    expect(api.of('ana@mail.com'), isEmpty);
    expect(incomes.incomes, isEmpty);
    expect(incomes.totalForMonth(noviembre), 0);
  });

  test('RIN-09 · HU-09 · sin red se ve la copia guardada y guardar avisa sin '
      'guardar a medias', () async {
    await entrar('ana@mail.com');
    await incomes.add(ingreso('Nómina', amount: 12500));
    api.failWith = const NetworkException();

    await incomes.sync();
    expect(incomes.offline, isTrue);
    expect(incomes.totalForMonth(noviembre), 12500);

    await expectLater(
      incomes.add(ingreso('Sin red')),
      throwsA(isA<NetworkException>()),
    );
    expect(incomes.incomes.map((i) => i.name), ['Nómina']);

    api.failWith = null;
    await incomes.sync();
    expect(incomes.offline, isFalse);
  });

  test('RIN-10 · HU-34 · al cerrar sesión se borra la copia, y otra cuenta en '
      'el mismo teléfono solo ve lo suyo', () async {
    await entrar('ana@mail.com');
    await incomes.add(ingreso('De Ana'));

    await salir();
    expect(incomes.incomes, isEmpty);

    await entrar('beto@mail.com');
    await incomes.add(ingreso('De Beto'));
    expect(incomes.incomes.map((i) => i.name), ['De Beto']);
    expect(api.of('ana@mail.com').values.single.income.name, 'De Ana');

    await salir();
    await entrar('ana@mail.com');
    expect(incomes.incomes.map((i) => i.name), ['De Ana']);
  });

  test('RIN-11 · HU-02 · un ingreso viejo que la API rechaza se queda en el '
      'teléfono, no detiene a los demás y un error llega con el mensaje del '
      'campo', () async {
    await incomes.add(ingreso('x' * 61));
    await incomes.add(ingreso('Normal', dia: 16));

    await entrar('ana@mail.com');

    expect(api.of('ana@mail.com').values.map((r) => r.income.name), ['Normal']);
    expect(incomes.offline, isFalse);
    expect(incomes.incomes, hasLength(2));

    await expectLater(
      incomes.add(ingreso('y' * 61)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.displayMessage,
          'displayMessage',
          'El nombre puede tener hasta 60 caracteres',
        ),
      ),
    );
    expect(incomes.incomes, hasLength(2));
  });

  test('RIN-12 · HU-37 · una cuenta de contador no usa los ingresos de la '
      'API', () async {
    final contador = SessionProvider(
      api: _ContadorApi(),
      store: MemorySessionStore(),
    );
    await contador.login(email: 'carla@conta.mx', password: 'x');

    incomes.bindSession(contador);
    await settle();

    expect(incomes.isRemote, isFalse);
    expect(api.calls, 0);
  });

  test('RIN-14 · HU-34 · si se cambia de cuenta a media subida, no se sigue '
      'subiendo a la anterior y la nueva sí se sincroniza', () async {
    await incomes.add(ingreso('Uno', dia: 1));
    await incomes.add(ingreso('Dos', dia: 2));
    api.byAccount['beto@mail.com'] = {
      'b1': (remoteId: 'b1', version: 1, income: ingreso('De Beto')),
    };
    api.holdCreate = Completer<void>();

    // Ana entra y la subida de "Uno" se queda esperando.
    await entrar('ana@mail.com');
    // Cambia a Beto antes de que termine.
    await salir();
    await session.login(email: 'beto@mail.com', password: 'kopay2026');
    incomes.bindSession(session);
    api.holdCreate!.complete();
    api.holdCreate = null;
    await settle();

    // A Ana solo llegó lo que ya se estaba subiendo.
    expect(api.of('ana@mail.com').values.map((r) => r.income.name), ['Uno']);
    expect(incomes.isRemote, isTrue);
    expect(incomes.incomes.map((i) => i.name), contains('De Beto'));
    expect(incomes.incomes.map((i) => i.name), isNot(contains('Uno')));
  });

  test('RIN-13 · HU-09 · una base versión 5 se migra a la 6 sin perder '
      'ingresos y todos quedan como solo del teléfono', () async {
    // Base como la dejó S5-07 (versión 5), con un ingreso.
    await db.close();
    final path = '${tempDir.path}/v5.db';
    final v5 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE incomes (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, amount REAL NOT NULL CHECK (amount >= 0), '
            'date TEXT NOT NULL, note TEXT)',
          );
          await d.insert('incomes', {
            'name': 'Nómina',
            'amount': 12500,
            'date': DateTime(2026, 11, 15).toIso8601String(),
          });
        },
      ),
    );
    await v5.close();

    db = DatabaseHelper.withFactory(databaseFactoryFfi, path);
    final base = await db.database;

    expect(await base.getVersion(), 6);
    expect((await db.getIncomes()).single.name, 'Nómina');
    expect((await db.getLocalOnlyIncomes()).single.name, 'Nómina');
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
