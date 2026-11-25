// S2-09 · Persistencia de pagos relacionados con tarjetas y deudas
// (HU-16, HU-20).
//
// UT-02 es un caso del plan (docs/plan-de-pruebas.md). Los casos PAG-xx
// son pruebas nuevas de la persistencia de pagos que no están en el plan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/movement_model.dart';
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
  );
  final auto = DebtModel(
    name: 'Préstamo auto',
    monthlyPayment: 100,
    remainingBalance: 300,
    dueDate: DateTime(2026, 12, 15),
  );
  final hoy = DateTime(2026, 11, 24);

  test('UT-02 · HU-16 · Un pago conserva su tipo y su tarjeta en el mapa', () {
    final pago = Movement(
      id: 4,
      amount: -100,
      description: 'Pago Oro',
      category: DatabaseHelper.paymentCategory,
      date: DateTime(2026, 11, 24, 9, 15),
      note: 'Quincena',
      type: MovementType.payment,
      cardId: 2,
    );
    final copia = Movement.fromMap(pago.toMap());

    expect(copia, pago);
    expect(copia.isPayment, isTrue);
    expect(copia.cardId, 2);
    expect(copia.debtId, isNull);
    expect(copia.date, DateTime(2026, 11, 24, 9, 15));
  });

  test('PAG-01 · HU-16 · Un movimiento sin tipo se lee como regular', () {
    final viejo = Movement.fromMap({
      'id': 1,
      'amount': -50,
      'description': 'Café',
      'category': 'Comida',
      'date': '2026-11-03T00:00:00.000',
      'note': null,
    });
    expect(viejo.type, MovementType.regular);
    expect(viejo.isPayment, isFalse);
    expect(viejo.cardId, isNull);
  });

  group('Base de datos', () {
    late Directory tempDir;
    late String dbPath;
    late DatabaseHelper helper;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kopay_payments_test');
      dbPath = '${tempDir.path}/${DatabaseHelper.fileName}';
      helper = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
    });

    tearDown(() async {
      await helper.close();
      tempDir.deleteSync(recursive: true);
    });

    test('PAG-02 · HU-16 · El pago de tarjeta queda asociado y descuenta el '
        'saldo usado', () async {
      final tarjeta = await helper.insertCard(oro);

      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 120,
        date: hoy,
      );

      expect(pago.id, isNotNull);
      expect(pago.amount, -120);
      expect(pago.type, MovementType.payment);
      expect(pago.cardId, tarjeta.id);
      expect(pago.category, DatabaseHelper.paymentCategory);
      expect(await helper.getMovement(pago.id!), pago);
      expect(await helper.getCardPayments(tarjeta.id!), [pago]);
      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 80);
    });

    test('PAG-03 · HU-20 · El pago de deuda queda asociado y descuenta el '
        'saldo restante', () async {
      final deuda = await helper.insertDebt(auto);

      final pago = await helper.insertDebtPayment(
        debtId: deuda.id!,
        amount: 100,
        date: hoy,
      );

      expect(pago.debtId, deuda.id);
      expect(pago.cardId, isNull);
      expect(await helper.getDebtPayments(deuda.id!), [pago]);
      final leida = (await helper.getDebt(deuda.id!))!;
      expect(leida.remainingBalance, 200);
      expect(leida.status, DebtStatus.pending);
    });

    test(
      'PAG-04 · HU-21 · Pagar el saldo restante deja la deuda pagada',
      () async {
        final deuda = await helper.insertDebt(auto);

        await helper.insertDebtPayment(
          debtId: deuda.id!,
          amount: 300,
          date: hoy,
        );

        final leida = (await helper.getDebt(deuda.id!))!;
        expect(leida.remainingBalance, 0);
        expect(leida.isPaid, isTrue);
      },
    );

    test(
      'PAG-05 · HU-16 · Cada pago queda solo en su propia entidad',
      () async {
        final primera = await helper.insertCard(oro);
        final segunda = await helper.insertCard(oro.copyWith(name: 'Azul'));
        final deuda = await helper.insertDebt(auto);

        final pago = await helper.insertCardPayment(
          cardId: primera.id!,
          amount: 50,
          date: hoy,
        );
        await helper.insertMovement(
          Movement(
            amount: -30,
            description: 'Café',
            category: 'Comida',
            date: hoy,
          ),
        );

        expect(await helper.getCardPayments(primera.id!), [pago]);
        expect(await helper.getCardPayments(segunda.id!), isEmpty);
        expect(await helper.getDebtPayments(deuda.id!), isEmpty);
        expect((await helper.getCard(segunda.id!))!.usedBalance, 200);
      },
    );

    test(
      'PAG-06 · HU-16 · Un pago inválido no guarda nada ni cambia saldos',
      () async {
        final tarjeta = await helper.insertCard(oro);
        final deuda = await helper.insertDebt(auto);

        Future<void> rechaza(Future<Movement> Function() pagar) =>
            expectLater(pagar(), throwsArgumentError);

        await rechaza(
          () => helper.insertCardPayment(
            cardId: tarjeta.id!,
            amount: 0,
            date: hoy,
          ),
        );
        await rechaza(
          () => helper.insertCardPayment(
            cardId: tarjeta.id!,
            amount: 250,
            date: hoy,
          ),
        );
        await rechaza(
          () => helper.insertCardPayment(cardId: 999, amount: 10, date: hoy),
        );
        await rechaza(
          () => helper.insertDebtPayment(
            debtId: deuda.id!,
            amount: 301,
            date: hoy,
          ),
        );
        await rechaza(
          () => helper.insertDebtPayment(debtId: 999, amount: 10, date: hoy),
        );

        expect(await helper.getMovements(), isEmpty);
        expect((await helper.getCard(tarjeta.id!))!.usedBalance, 200);
        expect((await helper.getDebt(deuda.id!))!.remainingBalance, 300);
      },
    );

    test('PAG-07 · HU-16 · Una base versión 3 se migra sin perder '
        'movimientos', () async {
      // Base como la dejó S2-08: movements sin columnas de pago.
      final v3 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
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
      await v3.close();

      final db = await helper.database;
      expect(await db.getVersion(), DatabaseHelper.version);
      final viejo = (await helper.getMovements()).single;
      expect(viejo.description, 'Café');
      expect(viejo.type, MovementType.regular);
      expect(viejo.cardId, isNull);
      expect(viejo.debtId, isNull);
    });

    test('PAG-08 · HU-16 · El pago persiste al reabrir la base', () async {
      final tarjeta = await helper.insertCard(oro);
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 100,
        date: hoy,
      );
      await helper.close();

      final reabierta = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
      final pagos = await reabierta.getCardPayments(tarjeta.id!);
      final leida = await reabierta.getCard(tarjeta.id!);
      await reabierta.close();

      expect(pagos, [pago]);
      expect(leida!.usedBalance, 100);
    });
  });
}
