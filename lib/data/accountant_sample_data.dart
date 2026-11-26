import '../models/accountant_client.dart';
import '../models/movement_model.dart';
import '../services/accountant_data.dart';
import '../utils/format_utils.dart';

export '../models/accountant_client.dart' show ClientInfo, PeriodSummary;

/// Datos de ejemplo de la maqueta de contador (S2-19, HU-39 y HU-40).
///
/// **No son datos reales.** Ninguna cuenta existe y nada se lee de la
/// base ni de la API. Desde S5-09 la vista de contador de una sesión real
/// lee la API (`ApiAccountantData`); estos datos solo se usan en la
/// maqueta que se abre desde Ajustes.

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

  /// Datos del cliente como los da la API.
  ClientInfo get info =>
      ClientInfo(id: id, name: name, email: email, grantedAt: authorizedAt);

  /// Movimientos del [month], del más reciente al más antiguo.
  List<Movement> movementsFor(DateTime month) =>
      movements.where((m) => FormatUtils.isSameMonth(m.date, month)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
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

/// [AccountantData] de la maqueta: los [clients] de ejemplo, sin red.
class SampleAccountantData implements AccountantData {
  SampleAccountantData([List<SampleClient>? clients])
    : sampleClients = clients ?? accountantSampleClients();

  final List<SampleClient> sampleClients;

  @override
  bool get isSample => true;

  @override
  Future<List<ClientInfo>> clients() async => [
    for (final c in sampleClients) c.info,
  ];

  @override
  Future<PeriodSummary> summary(String clientId, DateTime month) async =>
      PeriodSummary.of(_client(clientId).movements, month);

  @override
  Future<List<Movement>> movements(String clientId, DateTime month) async =>
      _client(clientId).movementsFor(month);

  SampleClient _client(String id) => sampleClients.firstWhere(
    (c) => c.id == id,
    orElse: () => throw const ClientAccessRevoked(),
  );
}
