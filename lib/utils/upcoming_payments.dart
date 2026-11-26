// Cálculo de próximos pagos de tarjetas y deudas (S2-12, HU-18, HU-23).

import '../models/card_model.dart';
import '../models/debt_model.dart';
import '../models/movement_model.dart';
import '../models/upcoming_payment.dart';

/// Arma la lista de compromisos próximos de [cards] y [debts], marcando
/// como cubiertos los que ya tienen pagos en [movements].
///
/// - **Tarjeta:** vence el próximo día de pago a partir de hoy; si el de
///   este mes ya pasó, el del mes siguiente. Si el mes no tiene ese día
///   (31 en febrero), vence el último día del mes. Corresponde pagar el
///   pago mínimo, o el saldo usado si es menor o si no hay mínimo. Las
///   tarjetas sin saldo usado no se incluyen: no hay nada que pagar.
/// - **Deuda:** vence en su `dueDate`, sin inventar otra fecha.
///   Corresponde pagar la mensualidad, o el saldo si es menor. Las deudas
///   pagadas y las ya vencidas no se incluyen.
/// - **Periodo vigente:** desde el día siguiente al vencimiento anterior
///   (un mes antes) hasta el vencimiento, ambos incluidos. Solo cuentan
///   los movimientos de tipo `payment` asociados a esa tarjeta o deuda.
/// - **Cubierto:** hay pagos en el periodo y suman al menos el importe.
///
/// El resultado va del que vence antes al que vence después; el mismo
/// día, primero los pendientes. [now] fija la fecha de hoy en las pruebas.
List<UpcomingPayment> computeUpcoming({
  required List<CardModel> cards,
  required List<DebtModel> debts,
  required List<Movement> movements,
  DateTime? now,
}) {
  final today = _day(now ?? DateTime.now());
  final payments = movements
      .where((m) => m.type == MovementType.payment)
      .toList();
  final result = <UpcomingPayment>[];

  for (final card in cards) {
    final used = (card.usedBalance * 100).round();
    if (used <= 0) continue;
    final minimum = (card.minimumPayment * 100).round();
    final cardAmount = minimum > 0 && minimum < used
        ? card.minimumPayment
        : card.usedBalance;
    var due = _dueInMonth(today.year, today.month, card.paymentDay);
    if (due.isBefore(today)) {
      due = _dueInMonth(today.year, today.month + 1, card.paymentDay);
    }
    final previous = _dueInMonth(due.year, due.month - 1, card.paymentDay);
    result.add(
      _build(
        kind: UpcomingKind.card,
        sourceId: card.id,
        name: card.name,
        due: due,
        previousDue: previous,
        today: today,
        amount: cardAmount,
        payments: payments.where((m) => card.id != null && m.cardId == card.id),
      ),
    );
  }

  for (final debt in debts) {
    if (debt.isPaid) continue;
    final due = _day(debt.dueDate);
    if (due.isBefore(today)) continue;
    final previous = _dueInMonth(due.year, due.month - 1, due.day);
    final monthly = debt.monthlyPayment;
    final balance = debt.remainingBalance;
    result.add(
      _build(
        kind: UpcomingKind.debt,
        sourceId: debt.id,
        name: debt.name,
        due: due,
        previousDue: previous,
        today: today,
        amount: monthly > 0 && monthly < balance ? monthly : balance,
        payments: payments.where((m) => debt.id != null && m.debtId == debt.id),
      ),
    );
  }

  result.sort((a, b) {
    final byDays = a.daysLeft.compareTo(b.daysLeft);
    if (byDays != 0) return byDays;
    if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
    return a.name.compareTo(b.name);
  });
  return result;
}

UpcomingPayment _build({
  required UpcomingKind kind,
  required int? sourceId,
  required String name,
  required DateTime due,
  required DateTime previousDue,
  required DateTime today,
  required double amount,
  required Iterable<Movement> payments,
}) {
  var paidCents = 0;
  final ids = <int>[];
  for (final m in payments) {
    final day = _day(m.date);
    if (!day.isAfter(previousDue) || day.isAfter(due)) continue;
    paidCents += (m.amount.abs() * 100).round();
    if (m.id != null) ids.add(m.id!);
  }
  final amountCents = (amount * 100).round();
  return UpcomingPayment(
    kind: kind,
    sourceId: sourceId,
    name: name,
    dueDate: due,
    daysLeft: _daysBetween(today, due),
    amount: amount,
    paidAmount: paidCents / 100,
    isPaid: paidCents > 0 && paidCents >= amountCents,
    paidMovementIds: List.unmodifiable(ids),
  );
}

/// Fecha sin hora.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Día [day] de ese mes, o el último día si el mes es más corto.
/// [month] puede salirse de 1 a 12; `DateTime` ajusta el año.
DateTime _dueInMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day < lastDay ? day : lastDay);
}

/// Días de calendario entre dos fechas, sin que el horario de verano
/// cambie la cuenta.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
