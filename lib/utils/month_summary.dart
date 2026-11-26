import '../models/income_model.dart';
import '../models/movement_model.dart';

/// Totales de un mes para el resumen de Inicio (HU-09).
///
/// Los ingresos suman la tabla `incomes` y las entradas positivas de
/// `movements` (HU-03). Los gastos son los movimientos negativos que no
/// son pagos. Los pagos de tarjeta o deuda se guardan aparte para no
/// contarlos dos veces (UT-38). El saldo es ingresos − gastos − pagos.
class MonthSummary {
  /// Ingresos del mes: tabla `incomes` más entradas positivas.
  final double income;

  /// Gastos ordinarios del mes, en positivo. No incluye pagos.
  final double expenses;

  /// Pagos de tarjeta o deuda del mes, en positivo. No se suman a
  /// [expenses] (UT-38).
  final double cardPayments;

  /// Gastos ordinarios agrupados por categoría, de mayor a menor.
  final Map<String, double> expensesByCategory;

  const MonthSummary({
    required this.income,
    required this.expenses,
    required this.cardPayments,
    required this.expensesByCategory,
  });

  /// Ingresos menos gastos y pagos del mes.
  double get balance => income - expenses - cardPayments;

  /// Lo que sale del bolsillo: gastos más pagos.
  double get totalSpending => expenses + cardPayments;

  /// Calcula el resumen de [month] a partir de las listas completas.
  ///
  /// Un movimiento con importe cero no altera ningún total (UT-45). Los
  /// registros de otros meses se ignoran (UT-41 y UT-46).
  factory MonthSummary.of(
    List<Movement> movements,
    List<Income> incomes,
    DateTime month,
  ) {
    var income = 0.0;
    var expenses = 0.0;
    var cardPayments = 0.0;
    final categories = <String, double>{};

    for (final entry in incomes) {
      if (!_isInMonth(entry.date, month)) continue;
      income += entry.amount;
    }

    for (final movement in movements) {
      if (!_isInMonth(movement.date, month)) continue;
      if (movement.amount == 0) continue;

      if (movement.isPayment) {
        cardPayments += movement.absAmount;
      } else if (movement.isExpense) {
        expenses += movement.absAmount;
        categories.update(
          movement.category,
          (value) => value + movement.absAmount,
          ifAbsent: () => movement.absAmount,
        );
      } else {
        // Entrada positiva: se cuenta una sola vez como ingreso (HU-03
        // y UT-44 ajustado en el plan).
        income += movement.amount;
      }
    }

    final sorted = categories.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
      });

    return MonthSummary(
      income: income,
      expenses: expenses,
      cardPayments: cardPayments,
      expensesByCategory: Map.unmodifiable(Map.fromEntries(sorted)),
    );
  }

  static bool _isInMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;
}
