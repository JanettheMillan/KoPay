/// Origen de un compromiso próximo.
enum UpcomingKind {
  /// Pago de una tarjeta de crédito (HU-18).
  card,

  /// Mensualidad de una deuda (HU-23).
  debt,
}

/// Compromiso de pago próximo de una tarjeta o una deuda (HU-18, HU-23).
///
/// Lo arma `computeUpcoming` a partir de las tarjetas, las deudas y los
/// pagos registrados. No se guarda en la base.
class UpcomingPayment {
  /// Días restantes con los que un compromiso pendiente se marca urgente.
  static const int urgentDays = 5;

  /// Tarjeta o deuda.
  final UpcomingKind kind;

  /// `id` de la tarjeta o de la deuda de origen.
  final int? sourceId;

  /// Nombre de la tarjeta o de la deuda.
  final String name;

  /// Fecha de vencimiento del periodo vigente.
  final DateTime dueDate;

  /// Días que faltan para [dueDate]; cero si vence hoy.
  final int daysLeft;

  /// Importe que corresponde pagar en el periodo: pago mínimo de la
  /// tarjeta o mensualidad de la deuda.
  final double amount;

  /// Suma de los pagos registrados en el periodo vigente.
  final double paidAmount;

  /// `true` si los pagos del periodo ya cubren [amount].
  final bool isPaid;

  /// `id` de los movimientos de pago que se contaron en [paidAmount].
  final List<int> paidMovementIds;

  const UpcomingPayment({
    required this.kind,
    this.sourceId,
    required this.name,
    required this.dueDate,
    required this.daysLeft,
    required this.amount,
    this.paidAmount = 0,
    this.isPaid = false,
    this.paidMovementIds = const [],
  });

  /// Pendiente y a [urgentDays] días o menos de vencer.
  bool get isUrgent => !isPaid && daysLeft <= urgentDays;

  /// Importe para mostrar: lo que se pagó si ya está cubierto y hay un
  /// pago registrado; si no, lo que corresponde pagar.
  double get displayAmount => isPaid && paidAmount > 0 ? paidAmount : amount;

  @override
  String toString() =>
      'UpcomingPayment(${kind.name} $sourceId, $name, daysLeft: $daysLeft, '
      'amount: $amount, paid: $paidAmount, isPaid: $isPaid)';
}
