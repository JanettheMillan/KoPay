import '../models/income_model.dart';
import '../models/movement_model.dart';

/// Error que lanzan los providers cuando reciben un registro inválido.
class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Reglas de validación de gastos, movimientos e ingresos.
///
/// Los formularios usan los métodos que reciben texto para mostrar el
/// error bajo cada campo. Los providers usan [checkMovement] y
/// [checkIncome] antes de guardar, para que nada inválido llegue a la base.
class Validators {
  Validators._();

  /// Monto máximo aceptado.
  static const double maxAmount = 999999999.99;

  static const String emptyAmount = 'Escribe un monto';
  static const String notANumber =
      'Escribe un monto válido, por ejemplo 150.50';
  static const String notPositive = 'El monto debe ser mayor que cero';
  static const String tooLarge = 'El monto es demasiado grande';
  static const String tooManyDecimals = 'Usa máximo dos decimales';
  static const String emptyDescription = 'Escribe una descripción';
  static const String emptyName = 'Escribe el nombre del ingreso';
  static const String emptyCategory = 'Elige una categoría';

  // Dígitos y, opcionalmente, punto decimal y más dígitos. Se aplica
  // después de quitar comas de miles; los decimales se cuentan aparte.
  static final RegExp _amountPattern = RegExp(r'^\d+(\.\d+)?$');

  /// Limpia el texto del campo de monto: quita espacios, `$` y comas de
  /// miles. `" $1,350.50 "` → `"1350.50"`.
  static String _clean(String text) =>
      text.trim().replaceAll(' ', '').replaceAll(r'$', '').replaceAll(',', '');

  /// Convierte el texto de un monto en número positivo. Devuelve `null`
  /// si el texto no es válido según [amount].
  static double? parseAmount(String? text) {
    if (amount(text) != null) return null;
    return double.parse(_clean(text!));
  }

  /// Error del campo de monto, o `null` si es válido.
  static String? amount(String? text) {
    if (text == null || text.trim().isEmpty) return emptyAmount;
    final clean = _clean(text);
    if (clean.startsWith('-')) return notPositive;
    if (!_amountPattern.hasMatch(clean)) return notANumber;
    final decimals = clean.contains('.') ? clean.split('.').last.length : 0;
    if (decimals > 2) return tooManyDecimals;
    final value = double.parse(clean);
    if (value <= 0) return notPositive;
    if (value > maxAmount) return tooLarge;
    return null;
  }

  /// Error de la descripción de un gasto o movimiento.
  static String? description(String? text) =>
      _required(text) ? null : emptyDescription;

  /// Error del nombre de un ingreso.
  static String? incomeName(String? text) => _required(text) ? null : emptyName;

  /// Error de la categoría elegida.
  static String? category(String? text) =>
      _required(text) ? null : emptyCategory;

  static bool _required(String? text) => text != null && text.trim().isNotEmpty;

  /// Aplica el signo según el tipo: los gastos quedan negativos y las
  /// entradas positivas, sin importar el signo con que llegue [amount].
  static double signedAmount(double amount, {required bool isExpense}) =>
      isExpense ? -amount.abs() : amount.abs();

  /// Primer error de un movimiento ya construido, o `null` si es válido.
  static String? checkMovement(Movement movement) {
    final value = movement.amount.abs();
    if (!movement.amount.isFinite || value == 0) return notPositive;
    if (value > maxAmount) return tooLarge;
    return description(movement.description) ?? category(movement.category);
  }

  /// Primer error de un ingreso ya construido, o `null` si es válido.
  static String? checkIncome(Income income) {
    if (!income.amount.isFinite || income.amount <= 0) return notPositive;
    if (income.amount > maxAmount) return tooLarge;
    return incomeName(income.name);
  }
}
