// S2-12 · Cálculo de próximos pagos (HU-18, HU-21, HU-23).
//
// Casos UT-06 a UT-12, UT-22 a UT-28 y UT-64 a UT-69 de
// docs/plan-de-pruebas.md. PRX-01 a PRX-04 son pruebas nuevas de esta
// tarjeta (fin de mes, cambio de año, orden por estado y deuda con saldo
// menor a la mensualidad).

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/models/upcoming_payment.dart';
import 'package:kopay/utils/upcoming_payments.dart';

void main() {
  // Hoy, fijo para todas las pruebas: jueves 26 de noviembre de 2026.
  final hoy = DateTime(2026, 11, 26, 10, 30);

  CardModel tarjeta({
    int id = 1,
    String name = 'Oro',
    int paymentDay = 30,
    double minimumPayment = 100,
  }) => CardModel(
    id: id,
    name: name,
    bank: 'BBVA',
    creditLimit: 1000,
    usedBalance: 400,
    cutDay: 5,
    paymentDay: paymentDay,
    minimumPayment: minimumPayment,
  );

  DebtModel deuda({
    int id = 1,
    String name = 'Préstamo auto',
    DateTime? dueDate,
    double monthlyPayment = 100,
    double remainingBalance = 300,
    DebtStatus status = DebtStatus.pending,
  }) => DebtModel(
    id: id,
    name: name,
    monthlyPayment: monthlyPayment,
    remainingBalance: remainingBalance,
    dueDate: dueDate ?? DateTime(2026, 12, 1),
    status: status,
  );

  Movement pago(
    double amount,
    DateTime date, {
    int id = 10,
    int? cardId,
    int? debtId,
    MovementType type = MovementType.payment,
  }) => Movement(
    id: id,
    amount: -amount,
    description: 'Pago',
    category: 'Pagos',
    date: date,
    type: type,
    cardId: cardId,
    debtId: debtId,
  );

  List<UpcomingPayment> calcular({
    List<CardModel> cards = const [],
    List<DebtModel> debts = const [],
    List<Movement> movements = const [],
  }) => computeUpcoming(
    cards: cards,
    debts: debts,
    movements: movements,
    now: hoy,
  );

  UpcomingPayment proximo(int daysLeft, {bool isPaid = false}) =>
      UpcomingPayment(
        kind: UpcomingKind.card,
        name: 'Oro',
        dueDate: hoy,
        daysLeft: daysLeft,
        amount: 300,
        isPaid: isPaid,
      );

  group('UpcomingPayment', () {
    test('UT-06 · HU-23 · Urgencia de pago próximo', () {
      expect(proximo(5).isUrgent, isTrue);
      expect(proximo(6).isUrgent, isFalse);
      expect(proximo(2, isPaid: true).isUrgent, isFalse);
    });

    test('UT-07 · HU-23 · Importe visible de pago próximo', () {
      final pendiente = UpcomingPayment(
        kind: UpcomingKind.debt,
        name: 'Préstamo',
        dueDate: hoy,
        daysLeft: 3,
        amount: 300,
        paidAmount: 100,
      );
      final pagado = UpcomingPayment(
        kind: UpcomingKind.debt,
        name: 'Préstamo',
        dueDate: hoy,
        daysLeft: 3,
        amount: 300,
        paidAmount: 100,
        isPaid: true,
      );

      expect(pagado.displayAmount, 100);
      expect(pendiente.displayAmount, 300);
    });
  });

  group('computeUpcoming', () {
    test('UT-08 · HU-23 · Orden de compromisos', () {
      final lista = calcular(
        debts: [
          deuda(id: 1, name: 'A 10 días', dueDate: DateTime(2026, 12, 6)),
          deuda(id: 2, name: 'A 3 días', dueDate: DateTime(2026, 11, 29)),
        ],
      );

      expect(lista.map((p) => p.name), ['A 3 días', 'A 10 días']);
      expect(lista.map((p) => p.daysLeft), [3, 10]);
    });

    test('UT-09 · HU-18 · Tarjeta con pago cubierto', () {
      final lista = calcular(
        cards: [tarjeta()],
        movements: [pago(100, DateTime(2026, 11, 20), cardId: 1)],
      );

      expect(lista.single.kind, UpcomingKind.card);
      expect(lista.single.isPaid, isTrue);
      expect(lista.single.paidAmount, 100);
    });

    test('UT-10 · HU-23 · Deuda con pago cubierto', () {
      final lista = calcular(
        debts: [deuda()],
        movements: [pago(100, DateTime(2026, 11, 25), debtId: 1)],
      );

      expect(lista.single.kind, UpcomingKind.debt);
      expect(lista.single.isPaid, isTrue);
      expect(lista.single.paidAmount, 100);
      expect(lista.single.paidMovementIds, [10]);
    });

    test('UT-11 · HU-23 · Deuda pagada o vencida', () {
      final lista = calcular(
        debts: [
          deuda(id: 1, status: DebtStatus.paid, remainingBalance: 0),
          deuda(id: 2, dueDate: DateTime(2026, 11, 25)),
        ],
      );

      expect(lista, isEmpty);
    });

    test('UT-12 · HU-18 · Cambio de mes en vencimiento de tarjeta', () {
      final p = calcular(cards: [tarjeta(paymentDay: 10)]).single;

      expect(p.dueDate, DateTime(2026, 12, 10));
      expect(p.daysLeft, 14);
    });

    test('UT-22 · HU-23 · Sin compromisos próximos', () {
      expect(calcular(), isEmpty);
    });

    test('UT-23 · HU-18 · Tarjeta que vence hoy', () {
      final p = calcular(cards: [tarjeta(paymentDay: 26)]).single;

      expect(p.dueDate, DateTime(2026, 11, 26));
      expect(p.daysLeft, 0);
      expect(p.isUrgent, isTrue);
    });

    test('UT-24 · HU-23 · Deuda que vence hoy', () {
      final p = calcular(
        debts: [deuda(dueDate: DateTime(2026, 11, 26))],
      ).single;

      expect(p.daysLeft, 0);
    });

    test('UT-25 · HU-18 · Pago parcial de tarjeta', () {
      final p = calcular(
        cards: [tarjeta()],
        movements: [pago(60, DateTime(2026, 11, 20), cardId: 1)],
      ).single;

      expect(p.paidAmount, 60);
      expect(p.isPaid, isFalse);
      expect(p.displayAmount, 100);
    });

    test('UT-26 · HU-23 · Pago parcial de deuda', () {
      final p = calcular(
        debts: [deuda()],
        movements: [pago(60, DateTime(2026, 11, 20), debtId: 1)],
      ).single;

      expect(p.paidAmount, 60);
      expect(p.isPaid, isFalse);
    });

    test('UT-27 · HU-18 · Pago de otra tarjeta', () {
      final lista = calcular(
        cards: [
          tarjeta(id: 1),
          tarjeta(id: 2, name: 'Azul'),
        ],
        movements: [pago(100, DateTime(2026, 11, 20), cardId: 1)],
      );

      final azul = lista.firstWhere((p) => p.sourceId == 2);
      expect(azul.isPaid, isFalse);
      expect(azul.paidAmount, 0);
      expect(lista.firstWhere((p) => p.sourceId == 1).isPaid, isTrue);
    });

    test('UT-28 · HU-23 · Pago de otra deuda', () {
      final lista = calcular(
        debts: [
          deuda(id: 1),
          deuda(id: 2, name: 'Celular'),
        ],
        movements: [pago(100, DateTime(2026, 11, 20), debtId: 1)],
      );

      final celular = lista.firstWhere((p) => p.sourceId == 2);
      expect(celular.isPaid, isFalse);
      expect(celular.paidAmount, 0);
    });

    test('UT-64 · HU-23 · Deuda con fecha inválida no genera un vencimiento '
        'ficticio', () {
      // Una fecha imposible en la base no llega a computeUpcoming: fromMap
      // la rechaza (D-03).
      expect(
        () => DebtModel.fromMap({
          'id': 1,
          'name': 'Préstamo',
          'monthly_payment': 100,
          'remaining_balance': 300,
          'due_date': '2026-02-30T00:00:00.000',
          'status': 'pending',
        }),
        throwsFormatException,
      );
      // Y una deuda vencida no se recorre a un mes siguiente inventado,
      // como sí pasa con el día de pago de una tarjeta.
      final lista = calcular(debts: [deuda(dueDate: DateTime(2026, 10, 15))]);
      expect(lista, isEmpty);
    });

    test('UT-65 · HU-21 · Deuda liquidada fuera de próximos', () {
      final lista = calcular(
        debts: [deuda(status: DebtStatus.paid, remainingBalance: 0)],
      );

      expect(lista, isEmpty);
    });

    test('UT-66 · HU-18 · Tarjeta sin pagos registrados', () {
      final p = calcular(cards: [tarjeta()]).single;

      expect(p.isPaid, isFalse);
      expect(p.paidAmount, 0);
      expect(p.paidMovementIds, isEmpty);
    });

    test('UT-67 · HU-18 · Movimiento de tipo incorrecto', () {
      final p = calcular(
        cards: [tarjeta()],
        movements: [
          pago(
            100,
            DateTime(2026, 11, 20),
            cardId: 1,
            type: MovementType.regular,
          ),
        ],
      ).single;

      expect(p.paidAmount, 0);
      expect(p.isPaid, isFalse);
    });

    test('UT-68 · HU-18 · Pago fuera del periodo', () {
      // Vence el 30 de noviembre; el periodo va del 31 de octubre al 30
      // de noviembre.
      final p = calcular(
        cards: [tarjeta()],
        movements: [
          pago(100, DateTime(2026, 12, 1), id: 1, cardId: 1),
          pago(100, DateTime(2026, 10, 30), id: 2, cardId: 1),
        ],
      ).single;

      expect(p.paidAmount, 0);
      expect(p.isPaid, isFalse);
    });

    test('UT-69 · HU-18 · Identificadores de pagos', () {
      final p = calcular(
        cards: [tarjeta()],
        movements: [
          pago(40, DateTime(2026, 11, 2), id: 7, cardId: 1),
          pago(60, DateTime(2026, 11, 30), id: 8, cardId: 1),
        ],
      ).single;

      expect(p.paidMovementIds, [7, 8]);
      expect(p.paidAmount, 100);
      expect(p.isPaid, isTrue);
    });

    test('PRX-01 · HU-18 · Un día de pago 31 vence el último día de un mes '
        'corto', () {
      final p = computeUpcoming(
        cards: [tarjeta(paymentDay: 31)],
        debts: const [],
        movements: const [],
        now: DateTime(2027, 2, 10),
      ).single;

      expect(p.dueDate, DateTime(2027, 2, 28));
    });

    test('PRX-02 · HU-18 · El vencimiento pasa al año siguiente en '
        'diciembre', () {
      final p = computeUpcoming(
        cards: [tarjeta(paymentDay: 5)],
        debts: const [],
        movements: const [],
        now: DateTime(2026, 12, 20),
      ).single;

      expect(p.dueDate, DateTime(2027, 1, 5));
      expect(p.daysLeft, 16);
    });

    test('PRX-03 · HU-23 · Tarjetas y deudas juntas, por vencimiento y '
        'estado', () {
      final lista = calcular(
        cards: [
          tarjeta(id: 1, name: 'Pagada', paymentDay: 29),
          tarjeta(id: 2, name: 'Pendiente', paymentDay: 29),
        ],
        debts: [deuda(id: 1, name: 'Deuda', dueDate: DateTime(2026, 11, 27))],
        movements: [pago(100, DateTime(2026, 11, 20), cardId: 1)],
      );

      expect(lista.map((p) => p.name), ['Deuda', 'Pendiente', 'Pagada']);
      expect(lista.map((p) => p.isPaid), [false, false, true]);
    });

    test('PRX-04 · HU-23 · Si el saldo es menor que la mensualidad, se pide '
        'el saldo', () {
      final p = calcular(
        debts: [deuda(monthlyPayment: 100, remainingBalance: 40)],
        movements: [pago(40, DateTime(2026, 11, 20), debtId: 1)],
      ).single;

      expect(p.amount, 40);
      expect(p.isPaid, isTrue);
    });
  });

  test('PRX-05 · HU-18 · Una tarjeta sin saldo no aparece y sin mínimo se '
      'pide el saldo', () {
    const base = CardModel(
      id: 50,
      name: 'Base',
      bank: 'B',
      creditLimit: 1000,
      usedBalance: 0,
      cutDay: 5,
      paymentDay: 28,
    );
    final result = computeUpcoming(
      cards: [
        base.copyWith(name: 'Sin saldo', minimumPayment: 100),
        base.copyWith(id: 51, name: 'Sin mínimo', usedBalance: 800),
        base.copyWith(
          id: 52,
          name: 'Saldo menor',
          usedBalance: 40,
          minimumPayment: 100,
        ),
      ],
      debts: const [],
      movements: const [],
      now: DateTime(2026, 11, 26),
    );

    expect(result.map((u) => u.name), ['Saldo menor', 'Sin mínimo']);
    expect(result.firstWhere((u) => u.sourceId == 51).amount, 800);
    expect(result.firstWhere((u) => u.sourceId == 52).amount, 40);
  });
}
