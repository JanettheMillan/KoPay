import 'movement_model.dart';

/// Ingreso recibido, por ejemplo el salario.
///
/// Los ingresos tienen su propia tabla, pero se muestran junto a los
/// movimientos mediante [toMovement].
class Income {
  /// Categoría con la que un ingreso aparece en la lista de movimientos.
  static const String category = 'Ingreso';

  /// Identificador asignado por la base de datos. Es `null` mientras
  /// el ingreso no se ha guardado.
  final int? id;

  /// Nombre del ingreso, por ejemplo "Salario".
  final String name;

  /// Monto recibido, siempre positivo.
  final double amount;

  /// Fecha en que se recibió.
  final DateTime date;

  /// Nota opcional.
  final String? note;

  const Income({
    this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }

  /// Copia el ingreso cambiando solo los campos indicados.
  /// Para quitar la nota usa `clearNote: true`.
  Income copyWith({
    int? id,
    String? name,
    double? amount,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return Income(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  /// Convierte el ingreso en un movimiento positivo para mostrarlo en
  /// la lista junto a los gastos.
  Movement toMovement() {
    return Movement(
      id: id,
      amount: amount.abs(),
      description: name,
      category: category,
      date: date,
      note: note,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Income &&
      other.id == id &&
      other.name == name &&
      other.amount == amount &&
      other.date == date &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, name, amount, date, note);

  @override
  String toString() =>
      'Income(id: $id, name: $name, amount: $amount, date: $date, note: $note)';
}
