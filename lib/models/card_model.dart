/// Tarjeta de crédito del usuario (HU-13, HU-14).
///
/// Guarda el límite, el saldo usado y los días de corte y de pago. El
/// crédito disponible se calcula a partir de esos datos; no se guarda.
class CardModel {
  /// Identificador asignado por la base de datos. Es `null` mientras
  /// la tarjeta no se ha guardado.
  final int? id;

  /// Nombre con el que el usuario reconoce la tarjeta, por ejemplo "Oro".
  final String name;

  /// Banco emisor, por ejemplo "BBVA".
  final String bank;

  /// Límite de crédito. No es negativo.
  final double creditLimit;

  /// Saldo usado a la fecha. No es negativo.
  final double usedBalance;

  /// Día del mes en que corta la tarjeta (1 a 31).
  final int cutDay;

  /// Día del mes en que vence el pago (1 a 31).
  final int paymentDay;

  /// Pago mínimo del periodo. Cero si no se conoce.
  final double minimumPayment;

  const CardModel({
    this.id,
    required this.name,
    required this.bank,
    required this.creditLimit,
    required this.usedBalance,
    required this.cutDay,
    required this.paymentDay,
    this.minimumPayment = 0,
  });

  /// Crédito disponible: límite menos saldo usado, con mínimo cero.
  double get available {
    final rest = creditLimit - usedBalance;
    return rest < 0 ? 0 : rest;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'bank': bank,
      'credit_limit': creditLimit,
      'used_balance': usedBalance,
      'cut_day': cutDay,
      'payment_day': paymentDay,
      'minimum_payment': minimumPayment,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      bank: map['bank'] as String,
      creditLimit: (map['credit_limit'] as num).toDouble(),
      usedBalance: (map['used_balance'] as num).toDouble(),
      cutDay: map['cut_day'] as int,
      paymentDay: map['payment_day'] as int,
      minimumPayment: (map['minimum_payment'] as num? ?? 0).toDouble(),
    );
  }

  /// Copia la tarjeta cambiando solo los campos indicados.
  CardModel copyWith({
    int? id,
    String? name,
    String? bank,
    double? creditLimit,
    double? usedBalance,
    int? cutDay,
    int? paymentDay,
    double? minimumPayment,
  }) {
    return CardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bank: bank ?? this.bank,
      creditLimit: creditLimit ?? this.creditLimit,
      usedBalance: usedBalance ?? this.usedBalance,
      cutDay: cutDay ?? this.cutDay,
      paymentDay: paymentDay ?? this.paymentDay,
      minimumPayment: minimumPayment ?? this.minimumPayment,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CardModel &&
      other.id == id &&
      other.name == name &&
      other.bank == bank &&
      other.creditLimit == creditLimit &&
      other.usedBalance == usedBalance &&
      other.cutDay == cutDay &&
      other.paymentDay == paymentDay &&
      other.minimumPayment == minimumPayment;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bank,
    creditLimit,
    usedBalance,
    cutDay,
    paymentDay,
    minimumPayment,
  );

  @override
  String toString() =>
      'CardModel(id: $id, name: $name, bank: $bank, '
      'creditLimit: $creditLimit, usedBalance: $usedBalance, '
      'cutDay: $cutDay, paymentDay: $paymentDay, '
      'minimumPayment: $minimumPayment)';
}
