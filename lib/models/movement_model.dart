/// Tipo de movimiento. Se guarda en la base con su [name].
enum MovementType {
  /// Gasto o entrada normal.
  regular,

  /// Pago a una tarjeta o a una deuda (S2-09). Va asociado a su
  /// entidad con `cardId` o `debtId`.
  payment;

  /// Tipo guardado en la base, o [regular] si el texto no se reconoce.
  static MovementType fromName(String? name) => MovementType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => MovementType.regular,
  );
}

/// Movimiento de dinero: un gasto (monto negativo) o una entrada
/// (monto positivo).
///
/// Las fechas se guardan en el mapa como texto ISO 8601 para que la
/// tabla SQLite de S1-08 pueda ordenarlas sin conversión.
class Movement {
  /// Identificador asignado por la base de datos. Es `null` mientras
  /// el movimiento no se ha guardado.
  final int? id;

  /// Monto con signo: negativo = gasto, positivo = entrada.
  final double amount;

  /// Texto que describe el movimiento, por ejemplo "Súper".
  final String description;

  /// Categoría elegida, por ejemplo "Comida".
  final String category;

  /// Fecha en que ocurrió el movimiento.
  final DateTime date;

  /// Nota opcional.
  final String? note;

  /// Normal o pago.
  final MovementType type;

  /// Tarjeta a la que se abonó este pago, si aplica.
  final int? cardId;

  /// Deuda a la que se abonó este pago, si aplica.
  final int? debtId;

  const Movement({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.note,
    this.type = MovementType.regular,
    this.cardId,
    this.debtId,
  });

  bool get isExpense => amount < 0;

  /// `true` si es un pago a una tarjeta o a una deuda.
  bool get isPayment => type == MovementType.payment;

  /// Monto sin signo, para mostrarlo en pantalla.
  double get absAmount => amount.abs();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'type': type.name,
      'card_id': cardId,
      'debt_id': debtId,
    };
  }

  factory Movement.fromMap(Map<String, dynamic> map) {
    return Movement(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      type: MovementType.fromName(map['type'] as String?),
      cardId: map['card_id'] as int?,
      debtId: map['debt_id'] as int?,
    );
  }

  /// Copia el movimiento cambiando solo los campos indicados.
  /// Para quitar la nota usa `clearNote: true`.
  Movement copyWith({
    int? id,
    double? amount,
    String? description,
    String? category,
    DateTime? date,
    String? note,
    bool clearNote = false,
    MovementType? type,
    int? cardId,
    int? debtId,
  }) {
    return Movement(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      type: type ?? this.type,
      cardId: cardId ?? this.cardId,
      debtId: debtId ?? this.debtId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Movement &&
      other.id == id &&
      other.amount == amount &&
      other.description == description &&
      other.category == category &&
      other.date == date &&
      other.note == note &&
      other.type == type &&
      other.cardId == cardId &&
      other.debtId == debtId;

  @override
  int get hashCode => Object.hash(
    id,
    amount,
    description,
    category,
    date,
    note,
    type,
    cardId,
    debtId,
  );

  @override
  String toString() =>
      'Movement(id: $id, amount: $amount, description: $description, '
      'category: $category, date: $date, note: $note, type: ${type.name}, '
      'cardId: $cardId, debtId: $debtId)';
}
