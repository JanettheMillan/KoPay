// S2-09 · Persistencia de pagos relacionados con tarjetas y deudas
// (HU-16, HU-20).
//
// UT-02 es un caso del plan (docs/plan-de-pruebas.md). Los casos PAG-xx
// son pruebas nuevas de la persistencia de pagos que no están en el plan.
// Los casos D10-xx corresponden a la corrección de D-10 (#207): anular un
// pago y devolver el saldo.

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

    test('PAG-09 · D-06 · HU-16 · HU-21 · Los pagos con centavos liquidan '
        'el saldo exacto', () async {
      // Deuda 0.30: 0.10 y luego 0.20. Con double quedaba 0.1999… y el
      // segundo pago se rechazaba.
      final chica = await helper.insertDebt(
        auto.copyWith(monthlyPayment: 0.1, remainingBalance: 0.3),
      );
      await helper.insertDebtPayment(debtId: chica.id!, amount: 0.1, date: hoy);
      expect((await helper.getDebt(chica.id!))!.remainingBalance, 0.2);
      await helper.insertDebtPayment(debtId: chica.id!, amount: 0.2, date: hoy);
      final liquidada = (await helper.getDebt(chica.id!))!;
      expect(liquidada.remainingBalance, 0);
      expect(liquidada.isPaid, isTrue);

      // Deuda 1.00: 0.70 + 0.10 + 0.20. Con double quedaba 2.7e-17 y
      // pendiente.
      final peso = await helper.insertDebt(
        auto.copyWith(monthlyPayment: 1, remainingBalance: 1),
      );
      for (final abono in [0.7, 0.1, 0.2]) {
        await helper.insertDebtPayment(
          debtId: peso.id!,
          amount: abono,
          date: hoy,
        );
      }
      final pagada = (await helper.getDebt(peso.id!))!;
      expect(pagada.remainingBalance, 0);
      expect(pagada.status, DebtStatus.paid);

      // Tarjeta con 0.30 usado: 0.10 y luego 0.20.
      final tarjeta = await helper.insertCard(oro.copyWith(usedBalance: 0.3));
      await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 0.1,
        date: hoy,
      );
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 0.2,
        date: hoy,
      );
      expect(pago.amount, -0.2);
      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 0);

      // Un centavo de más sigue rechazado y menos de un centavo no es pago.
      final otra = await helper.insertCard(oro.copyWith(usedBalance: 10));
      expect(
        () => helper.insertCardPayment(
          cardId: otra.id!,
          amount: 10.01,
          date: hoy,
        ),
        throwsArgumentError,
      );
      expect(
        () => helper.insertCardPayment(
          cardId: otra.id!,
          amount: 0.004,
          date: hoy,
        ),
        throwsArgumentError,
      );
      expect((await helper.getCard(otra.id!))!.usedBalance, 10);
    });
    test('D10-01 · HU-16 · Anular un pago de tarjeta devuelve el saldo usado y '
        'borra el pago', () async {
      final tarjeta = await helper.insertCard(oro);
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 120,
        date: hoy,
      );
      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 80);

      await helper.cancelPayment(pago.id!);

      final leida = (await helper.getCard(tarjeta.id!))!;
      expect(leida.usedBalance, 200);
      expect(leida.available, 800);
      expect(await helper.getCardPayments(tarjeta.id!), isEmpty);
      expect(await helper.getMovement(pago.id!), isNull);
      expect(await helper.getMovements(), isEmpty);
      // Un pago ya anulado no se puede volver a anular.
      await expectLater(helper.cancelPayment(pago.id!), throwsArgumentError);
      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 200);
    });

    test('D10-02 · HU-20 · HU-21 · Anular un pago de deuda devuelve el saldo y '
        'la deuda vuelve a pendiente', () async {
      final deuda = await helper.insertDebt(auto);
      final pago = await helper.insertDebtPayment(
        debtId: deuda.id!,
        amount: 300,
        date: hoy,
      );
      expect((await helper.getDebt(deuda.id!))!.isPaid, isTrue);

      await helper.cancelPayment(pago.id!);

      final leida = (await helper.getDebt(deuda.id!))!;
      expect(leida.remainingBalance, 300);
      expect(leida.status, DebtStatus.pending);
      expect(await helper.getDebtPayments(deuda.id!), isEmpty);
      expect(await helper.getMovement(pago.id!), isNull);
    });

    test('D10-03 · HU-16 · Anular algo que no es un pago de su tarjeta o deuda '
        'no cambia nada', () async {
      final tarjeta = await helper.insertCard(oro);
      final deuda = await helper.insertDebt(auto);
      final gasto = await helper.insertMovement(
        Movement(
          amount: -30,
          description: 'Café',
          category: 'Comida',
          date: hoy,
        ),
      );
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 50,
        date: hoy,
      );

      await expectLater(helper.cancelPayment(999), throwsArgumentError);
      await expectLater(helper.cancelPayment(gasto.id!), throwsArgumentError);
      // Al borrar la tarjeta el pago se desliga y ya no se puede anular.
      await helper.deleteCard(tarjeta.id!);
      await expectLater(helper.cancelPayment(pago.id!), throwsArgumentError);

      expect(await helper.getMovement(gasto.id!), gasto);
      expect(await helper.getMovement(pago.id!), isNotNull);
      expect((await helper.getDebt(deuda.id!))!.remainingBalance, 300);
    });

    test('D10-04 · HU-16 · Si borrar el pago falla, la transacción no devuelve '
        'el saldo ni borra el pago', () async {
      final tarjeta = await helper.insertCard(oro);
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 120,
        date: hoy,
      );
      final db = await helper.database;
      await db.execute(
        'CREATE TRIGGER falla_borrar_pago BEFORE DELETE ON movements '
        "BEGIN SELECT RAISE(ABORT, 'falla'); END",
      );

      await expectLater(helper.cancelPayment(pago.id!), throwsA(anything));

      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 80);
      expect(await helper.getCardPayments(tarjeta.id!), [pago]);
      expect(await helper.getMovement(pago.id!), pago);
    });

    test('D10-05 · D-06 · HU-16 · Anular un pago con centavos deja el saldo '
        'exacto', () async {
      final tarjeta = await helper.insertCard(oro.copyWith(usedBalance: 0.3));
      final pago = await helper.insertCardPayment(
        cardId: tarjeta.id!,
        amount: 0.1,
        date: hoy,
      );
      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 0.2);

      await helper.cancelPayment(pago.id!);

      expect((await helper.getCard(tarjeta.id!))!.usedBalance, 0.3);
    });
  });
}
