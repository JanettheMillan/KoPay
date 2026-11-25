// S2-07 · Modelo y tabla local de tarjetas (HU-13, HU-14).
//
// UT-04 y UT-16 son casos del plan (docs/plan-de-pruebas.md). Los casos
// TAR-xx son pruebas nuevas de la tabla `cards` que no están en el plan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  const oro = CardModel(
    name: 'Oro',
    bank: 'BBVA',
    creditLimit: 1000,
    usedBalance: 200,
    cutDay: 5,
    paymentDay: 25,
    minimumPayment: 100,
  );

  group('Modelo', () {
    test('UT-04 · HU-13 · Conversión de tarjeta a mapa', () {
      final copia = CardModel.fromMap(oro.copyWith(id: 7).toMap());

      expect(copia, oro.copyWith(id: 7));
      expect(copia.creditLimit, 1000);
      expect(copia.usedBalance, 200);
      expect(copia.available, 800);
      expect(copia.cutDay, 5);
      expect(copia.paymentDay, 25);
    });

    test('UT-16 · HU-14 · Copia parcial de tarjeta', () {
      final copia = oro.copyWith(usedBalance: 450);

      expect(copia.usedBalance, 450);
      expect(copia.name, 'Oro');
      expect(copia.bank, 'BBVA');
      expect(copia.creditLimit, 1000);
      expect(copia.cutDay, 5);
      expect(copia.paymentDay, 25);
      expect(copia.minimumPayment, 100);
    });

    test('TAR-01 · HU-13 · El disponible nunca es negativo', () {
      expect(oro.copyWith(usedBalance: 1000).available, 0);
      expect(oro.copyWith(usedBalance: 1300).available, 0);
    });
  });

  group('Tabla cards', () {
    late Directory tempDir;
    late String dbPath;
    late DatabaseHelper helper;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kopay_cards_test');
      dbPath = '${tempDir.path}/${DatabaseHelper.fileName}';
      helper = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
    });

    tearDown(() async {
      await helper.close();
      tempDir.deleteSync(recursive: true);
    });

    test('TAR-02 · HU-13 · Las columnas coinciden con el modelo', () async {
      final db = await helper.database;
      final info = await db.rawQuery('PRAGMA table_info(cards)');
      expect(
        info.map((c) => c['name']),
        unorderedEquals(oro.copyWith(id: 1).toMap().keys),
      );
    });

    test('TAR-03 · HU-13 · Se guarda y se lee sin perder campos', () async {
      final guardada = await helper.insertCard(oro);

      expect(guardada.id, isNotNull);
      expect(await helper.getCard(guardada.id!), guardada);
      expect(await helper.getCards(), [guardada]);
    });

    test('TAR-04 · HU-14 · Editar límite, saldo y fechas persiste', () async {
      final guardada = await helper.insertCard(oro);
      final editada = guardada.copyWith(
        creditLimit: 1500,
        usedBalance: 300,
        cutDay: 10,
        paymentDay: 30,
      );

      expect(await helper.updateCard(editada), 1);
      final leida = await helper.getCard(guardada.id!);
      expect(leida, editada);
      expect(leida!.available, 1200);
    });

    test('TAR-05 · HU-13 · Borrar y editar una tarjeta inexistente', () async {
      final guardada = await helper.insertCard(oro);

      expect(await helper.deleteCard(guardada.id!), 1);
      expect(await helper.getCard(guardada.id!), isNull);
      expect(await helper.updateCard(guardada), 0);
      expect(() => helper.updateCard(oro), throwsArgumentError);
    });

    test(
      'TAR-06 · HU-13 · La tabla rechaza importes y días inválidos',
      () async {
        Future<void> rechaza(CardModel card) => expectLater(
          helper.insertCard(card),
          throwsA(isA<DatabaseException>()),
        );

        await rechaza(oro.copyWith(creditLimit: -1));
        await rechaza(oro.copyWith(usedBalance: -1));
        await rechaza(oro.copyWith(minimumPayment: -1));
        await rechaza(oro.copyWith(cutDay: 0));
        await rechaza(oro.copyWith(paymentDay: 32));
        expect(await helper.getCards(), isEmpty);
      },
    );

    test('TAR-07 · HU-13 · Los datos persisten al reabrir la base', () async {
      await helper.insertCard(oro);
      await helper.close();

      final reabierta = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
      final tarjetas = await reabierta.getCards();
      await reabierta.close();

      expect(tarjetas.single, oro.copyWith(id: tarjetas.single.id));
    });

    test(
      'TAR-08 · HU-13 · Una base versión 1 se migra sin perder datos',
      () async {
        // Base como la dejó el Sprint 1: sin tabla cards.
        final v1 = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE movements (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'amount REAL NOT NULL, description TEXT NOT NULL, '
                'category TEXT NOT NULL, date TEXT NOT NULL, note TEXT)',
              );
              await db.insert('movements', {
                'amount': -50,
                'description': 'Café',
                'category': 'Comida',
                'date': DateTime(2026, 11, 3).toIso8601String(),
              });
            },
          ),
        );
        await v1.close();

        final db = await helper.database;
        expect(await db.getVersion(), DatabaseHelper.version);
        expect(await db.query('movements'), hasLength(1));
        final guardada = await helper.insertCard(oro);
        expect(await helper.getCards(), [guardada]);
      },
    );

    test('TAR-09 · HU-13 · El borrado de datos incluye tarjetas', () async {
      await helper.insertCard(oro);
      await helper.deleteFinancialData();
      expect(await helper.getCards(), isEmpty);
    });
  });
}
