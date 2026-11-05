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

  const Movement({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.note,
  });

  bool get isExpense => amount < 0;

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
  }) {
    return Movement(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
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
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, amount, description, category, date, note);

  @override
  String toString() =>
      'Movement(id: $id, amount: $amount, description: $description, '
      'category: $category, date: $date, note: $note)';
}
