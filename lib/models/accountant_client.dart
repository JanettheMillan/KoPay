import '../utils/format_utils.dart';
import 'movement_model.dart';

/// Persona que autorizó al contador (HU-39): lo que da
/// `GET /api/clients` (contrato §3.10).
class ClientInfo {
  final String id;
  final String name;
  final String email;

  /// Cuándo autorizó al contador.
  final DateTime grantedAt;

  const ClientInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.grantedAt,
  });

  factory ClientInfo.fromMap(Map<String, dynamic> map) => ClientInfo(
    id: map['id'] as String,
    name: map['name'] as String,
    email: map['email'] as String,
    grantedAt: DateTime.parse(map['grantedAt'] as String).toLocal(),
  );
}

/// Totales de un cliente en un mes: lo que muestra el resumen (HU-40).
class PeriodSummary {
  final double income;
  final double expenses;
  final double cardPayments;

  const PeriodSummary({
    required this.income,
    required this.expenses,
    required this.cardPayments,
  });

  /// Ingresos menos gastos menos pagos de tarjeta.
  double get balance => income - expenses - cardPayments;

  /// Respuesta de `GET /api/clients/:userId/summary` (S5-03). El balance
  /// se vuelve a calcular con la misma regla.
  factory PeriodSummary.fromMap(Map<String, dynamic> map) => PeriodSummary(
    income: (map['income'] as num).toDouble(),
    expenses: (map['expenses'] as num).toDouble(),
    cardPayments: (map['payments'] as num).toDouble(),
  );

  /// Suma los movimientos del [month]. Los pagos se cuentan aparte de
  /// los gastos para no contarlos dos veces.
  factory PeriodSummary.of(List<Movement> movements, DateTime month) {
    var income = 0.0;
    var expenses = 0.0;
    var payments = 0.0;
    for (final m in movements) {
      if (!FormatUtils.isSameMonth(m.date, month)) continue;
      if (m.isPayment) {
        payments += m.absAmount;
      } else if (m.isExpense) {
        expenses += m.absAmount;
      } else {
        income += m.amount;
      }
    }
    return PeriodSummary(
      income: income,
      expenses: expenses,
      cardPayments: payments,
    );
  }
}
