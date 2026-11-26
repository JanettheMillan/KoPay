import '../models/movement_model.dart';
import '../utils/format_utils.dart';

/// Datos de ejemplo de la maqueta de contador (S2-19, HU-39 y HU-40).
///
/// **No son datos reales.** Ninguna cuenta existe y nada se lee de la
/// base ni de la API. Cuando exista la API (S5-03 y S5-09), estas
/// pantallas recibirán los clientes y movimientos del servidor y este
/// archivo se borra.

/// Persona que autorizó al contador, con sus movimientos de ejemplo.
class SampleClient {
  final String id;
  final String name;
  final String email;
  final DateTime authorizedAt;

  /// Gastos (negativos), entradas e ingresos (positivos) y pagos de
  /// tarjeta (negativos, `type = payment`), como en la tabla local.
  final List<Movement> movements;

  const SampleClient({
    required this.id,
    required this.name,
    required this.email,
    required this.authorizedAt,
    required this.movements,
  });

  /// Movimientos del [month], del más reciente al más antiguo.
  List<Movement> movementsFor(DateTime month) =>
      movements.where((m) => FormatUtils.isSameMonth(m.date, month)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
}

/// Totales de un cliente en un mes: lo que muestra el resumen.
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

/// Clientes de ejemplo con movimientos en el mes de [now] y los dos
/// anteriores, para que el selector de periodo cambie los datos.
List<SampleClient> accountantSampleClients({DateTime? now}) {
  final today = now ?? DateTime.now();
  DateTime day(int monthOffset, int d) =>
      DateTime(today.year, today.month + monthOffset, d);

  Movement expense(String text, String category, double amount, DateTime d) =>
      Movement(amount: -amount, description: text, category: category, date: d);
  Movement income(String text, double amount, DateTime d) =>
      Movement(amount: amount, description: text, category: 'Ingreso', date: d);
  Movement payment(String text, double amount, DateTime d) => Movement(
    amount: -amount,
    description: text,
    category: 'Pago de tarjeta',
    date: d,
    type: MovementType.payment,
  );

  return [
    SampleClient(
      id: 'ejemplo-1',
      name: 'Ana Ejemplo',
      email: 'ana@ejemplo.com',
      authorizedAt: day(-2, 3),
      movements: [
        income('Nómina', 15000, day(0, 1)),
        expense('Súper', 'Comida', 1820.50, day(0, 4)),
        expense('Renta', 'Vivienda', 5500, day(0, 5)),
        payment('Pago tarjeta Oro', 2000, day(0, 8)),
        expense('Luz', 'Servicios', 430, day(0, 9)),
        income('Nómina', 15000, day(-1, 1)),
        expense('Renta', 'Vivienda', 5500, day(-1, 5)),
        expense('Transporte', 'Transporte', 640, day(-1, 12)),
        payment('Pago tarjeta Oro', 1500, day(-1, 20)),
        income('Nómina', 15000, day(-2, 1)),
        expense('Cine', 'Entretenimiento', 320, day(-2, 14)),
      ],
    ),
    SampleClient(
      id: 'ejemplo-2',
      name: 'Luis Muestra',
      email: 'luis@ejemplo.com',
      authorizedAt: day(-1, 18),
      movements: [
        income('Honorarios', 9800, day(0, 2)),
        expense('Farmacia', 'Salud', 260, day(0, 6)),
        expense('Internet', 'Servicios', 499, day(0, 7)),
        income('Honorarios', 8700, day(-1, 2)),
        expense('Súper', 'Comida', 1340, day(-1, 9)),
        payment('Pago tarjeta Clásica', 900, day(-1, 25)),
      ],
    ),
  ];
}
