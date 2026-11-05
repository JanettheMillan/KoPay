import 'package:intl/intl.dart';

/// Formatos de monto y fecha compartidos por las pantallas.
class FormatUtils {
  FormatUtils._();

  static const List<String> monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _moneyCompact = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 0,
  );

  /// `$1,350.50`. Usa el valor absoluto; el signo lo pone la pantalla.
  static String money(double amount) => _money.format(amount.abs());

  /// `$1,351`, sin decimales.
  static String moneyCompact(double amount) =>
      _moneyCompact.format(amount.abs());

  /// Nombre del mes en minúsculas: `noviembre`.
  static String monthName(DateTime date) => monthNames[date.month - 1];

  /// `noviembre 2026`, para el selector de mes.
  static String monthYear(DateTime date) => '${monthName(date)} ${date.year}';

  /// `5 nov`, para las filas de movimientos.
  static String shortDate(DateTime date) =>
      '${date.day} ${monthName(date).substring(0, 3)}';

  /// `05/11/2026`, para formularios.
  static String fullDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Indica si [date] cae en el mismo mes y año que [month].
  static bool isSameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;
}
