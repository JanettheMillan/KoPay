/// Estado de una deuda. Se guarda en la base con su [name].
enum DebtStatus {
  /// Le queda saldo por pagar.
  pending,

  /// Saldo en cero; ya no aparece entre los pagos próximos.
  paid;

  /// Estado guardado en la base, o [pending] si el texto no se reconoce.
  static DebtStatus fromName(String? name) => DebtStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => DebtStatus.pending,
  );
}

/// Deuda del usuario, por ejemplo un préstamo (HU-19, HU-21).
///
/// Guarda la mensualidad, el saldo restante, la fecha del próximo
/// vencimiento y el estado.
class DebtModel {
  /// Identificador asignado por la base de datos. Es `null` mientras
  /// la deuda no se ha guardado.
  final int? id;

  /// Nombre de la deuda, por ejemplo "Préstamo auto".
  final String name;

  /// Pago que corresponde a cada periodo. No es negativo.
  final double monthlyPayment;

  /// Saldo que falta por pagar. No es negativo.
  final double remainingBalance;

  /// Fecha del próximo vencimiento.
  final DateTime dueDate;

  /// Pendiente o pagada.
  final DebtStatus status;

  const DebtModel({
    this.id,
    required this.name,
    required this.monthlyPayment,
    required this.remainingBalance,
    required this.dueDate,
    this.status = DebtStatus.pending,
  });

  /// `true` si la deuda ya se liquidó.
  bool get isPaid => status == DebtStatus.paid;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'monthly_payment': monthlyPayment,
      'remaining_balance': remainingBalance,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      monthlyPayment: (map['monthly_payment'] as num).toDouble(),
      remainingBalance: (map['remaining_balance'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date'] as String),
      status: DebtStatus.fromName(map['status'] as String?),
    );
  }

  /// Copia la deuda cambiando solo los campos indicados.
  DebtModel copyWith({
    int? id,
    String? name,
    double? monthlyPayment,
    double? remainingBalance,
    DateTime? dueDate,
    DebtStatus? status,
  }) {
    return DebtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DebtModel &&
      other.id == id &&
      other.name == name &&
      other.monthlyPayment == monthlyPayment &&
      other.remainingBalance == remainingBalance &&
      other.dueDate == dueDate &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, name, monthlyPayment, remainingBalance, dueDate, status);

  @override
  String toString() =>
      'DebtModel(id: $id, name: $name, monthlyPayment: $monthlyPayment, '
      'remainingBalance: $remainingBalance, dueDate: $dueDate, '
      'status: ${status.name})';
}
