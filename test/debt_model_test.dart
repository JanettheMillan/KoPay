// S2-08 · Modelo y tabla local de deudas (HU-19, HU-21).
//
// UT-05 y UT-17 son casos del plan (docs/plan-de-pruebas.md). Los casos
// DEU-xx son pruebas nuevas de la tabla `debts` que no están en el plan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final auto = DebtModel(
    name: 'Préstamo auto',
    monthlyPayment: 100,
    remainingBalance: 300,
    dueDate: DateTime(2026, 12, 15),
  );

  group('Modelo', () {
    test('UT-05 · HU-19 · Conversión de deuda a mapa', () {
      final original = auto.copyWith(id: 3, status: DebtStatus.paid);
      final copia = DebtModel.fromMap(original.toMap());

      expect(copia, original);
      expect(copia.monthlyPayment, 100);
      expect(copia.remainingBalance, 300);
      expect(copia.dueDate, DateTime(2026, 12, 15));
      expect(copia.status, DebtStatus.paid);
    });

    test('UT-17 · HU-21 · Copia parcial de deuda', () {
      final copia = auto.copyWith(remainingBalance: 0, status: DebtStatus.paid);

      expect(copia.remainingBalance, 0);
      expect(copia.status, DebtStatus.paid);
      expect(copia.isPaid, isTrue);
      expect(copia.name, 'Préstamo auto');
      expect(copia.monthlyPayment, 100);
      expect(copia.dueDate, DateTime(2026, 12, 15));
      // La instancia original conserva sus valores.
      expect(auto.remainingBalance, 300);
      expect(auto.status, DebtStatus.pending);
    });

    test('DEU-01 · HU-19 · Una deuda nueva empieza pendiente', () {
      expect(auto.status, DebtStatus.pending);
      expect(auto.isPaid, isFalse);
      expect(DebtStatus.fromName('desconocido'), DebtStatus.pending);
    });
  });

  group('Tabla debts', () {
    late Directory tempDir;
    late String dbPath;
    late DatabaseHelper helper;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kopay_debts_test');
      dbPath = '${tempDir.path}/${DatabaseHelper.fileName}';
      helper = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
    });

    tearDown(() async {
      await helper.close();
      tempDir.deleteSync(recursive: true);
    });

    test('DEU-02 · HU-19 · Las columnas coinciden con el modelo', () async {
      final db = await helper.database;
      final info = await db.rawQuery('PRAGMA table_info(debts)');
      expect(
        info.map((c) => c['name']),
        unorderedEquals(auto.copyWith(id: 1).toMap().keys),
      );
    });

    test('DEU-03 · HU-19 · Se guarda y se lee sin perder campos', () async {
      final guardada = await helper.insertDebt(auto);

      expect(guardada.id, isNotNull);
      expect(await helper.getDebt(guardada.id!), guardada);
      expect(await helper.getDebts(), [guardada]);
    });

    test('DEU-04 · HU-19 · La lista va de la que vence antes a la que vence '
        'después', () async {
      final tarde = await helper.insertDebt(auto);
      final pronto = await helper.insertDebt(
        auto.copyWith(name: 'Tienda', dueDate: DateTime(2026, 12, 1)),
      );

      expect(await helper.getDebts(), [pronto, tarde]);
    });

    test('DEU-05 · HU-21 · Liquidar deja saldo cero y estado pagada', () async {
      final guardada = await helper.insertDebt(auto);
      final liquidada = guardada.copyWith(
        remainingBalance: 0,
        status: DebtStatus.paid,
      );

      expect(await helper.updateDebt(liquidada), 1);
      final leida = await helper.getDebt(guardada.id!);
      expect(leida, liquidada);
      expect(leida!.isPaid, isTrue);
    });

    test('DEU-06 · HU-19 · Borrar y editar una deuda inexistente', () async {
      final guardada = await helper.insertDebt(auto);

      expect(await helper.deleteDebt(guardada.id!), 1);
      expect(await helper.getDebt(guardada.id!), isNull);
      expect(await helper.updateDebt(guardada), 0);
      expect(() => helper.updateDebt(auto), throwsArgumentError);
    });

    test(
      'DEU-07 · HU-19 · La tabla rechaza importes y estados inválidos',
      () async {
        final db = await helper.database;
        Future<void> rechaza(Map<String, Object?> cambios) => expectLater(
          db.insert('debts', {...auto.toMap(), ...cambios}),
          throwsA(isA<DatabaseException>()),
        );

        await rechaza({'monthly_payment': -1});
        await rechaza({'remaining_balance': -1});
        await rechaza({'status': 'vencida'});
        expect(await helper.getDebts(), isEmpty);
      },
    );

    test('DEU-08 · HU-19 · Los datos persisten al reabrir la base', () async {
      await helper.insertDebt(auto);
      await helper.close();

      final reabierta = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
      final deudas = await reabierta.getDebts();
      await reabierta.close();

      expect(deudas.single, auto.copyWith(id: deudas.single.id));
    });

    test(
      'DEU-09 · HU-19 · Una base versión 2 se migra sin perder tarjetas',
      () async {
        // Base como la dejó S2-07: con tarjetas y sin tabla debts.
        final v2 = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE movements (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'amount REAL NOT NULL, description TEXT NOT NULL, '
                'category TEXT NOT NULL, date TEXT NOT NULL, note TEXT)',
              );
              await db.execute(
                'CREATE TABLE cards (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'name TEXT NOT NULL, bank TEXT NOT NULL, '
                'credit_limit REAL NOT NULL, used_balance REAL NOT NULL, '
                'cut_day INTEGER NOT NULL, payment_day INTEGER NOT NULL, '
                'minimum_payment REAL NOT NULL DEFAULT 0)',
              );
              await db.insert(
                'cards',
                const CardModel(
                  name: 'Oro',
                  bank: 'BBVA',
                  creditLimit: 1000,
                  usedBalance: 200,
                  cutDay: 5,
                  paymentDay: 25,
                ).toMap(),
              );
            },
          ),
        );
        await v2.close();

        final db = await helper.database;
        expect(await db.getVersion(), DatabaseHelper.version);
        expect(await helper.getCards(), hasLength(1));
        final guardada = await helper.insertDebt(auto);
        expect(await helper.getDebts(), [guardada]);
      },
    );

    test('DEU-10 · HU-19 · El borrado de datos incluye deudas', () async {
      await helper.insertDebt(auto);
      await helper.deleteFinancialData();
      expect(await helper.getDebts(), isEmpty);
    });
  });
}
