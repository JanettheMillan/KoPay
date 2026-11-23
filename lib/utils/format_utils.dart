import 'package:intl/intl.dart';

/// Formatos de monto y fecha compartidos por las pantallas.
///
/// La moneda y el idioma activos los fija `SettingsProvider` con
/// [configure]; mientras no se configuren se usan MXN y español.
class FormatUtils {
  FormatUtils._();

  /// Monedas que ofrece Ajustes, con su símbolo visible.
  static const Map<String, String> currencySymbols = {
    'MXN': r'$',
    'USD': r'US$',
    'EUR': '€',
  };

  /// Idiomas que ofrece Ajustes.
  static const List<String> languages = ['es', 'en'];

  static const String defaultCurrency = 'MXN';
  static const String defaultLanguage = 'es';

  static const List<String> monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const List<String> monthNamesEn = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];

  static String _currency = defaultCurrency;
  static String _language = defaultLanguage;
  static NumberFormat _money = _build(2);
  static NumberFormat _moneyCompact = _build(0);

  /// Moneda activa (`MXN`, `USD` o `EUR`).
  static String get currency => _currency;

  /// Idioma activo (`es` o `en`).
  static String get language => _language;

  /// Cambia la moneda y el idioma de los formatos. Los valores que no
  /// están en [currencySymbols] o [languages] se ignoran.
  static void configure({String? currency, String? language}) {
    if (currency != null && currencySymbols.containsKey(currency)) {
      _currency = currency;
    }
    if (language != null && languages.contains(language)) {
      _language = language;
    }
    _money = _build(2);
    _moneyCompact = _build(0);
  }

  static NumberFormat _build(int decimals) => NumberFormat.currency(
    locale: _language == 'en' ? 'en_US' : 'es_MX',
    symbol: currencySymbols[_currency],
    decimalDigits: decimals,
  );

  /// `$1,350.50` (o `US$` / `€`). Usa el valor absoluto; el signo lo
  /// pone la pantalla.
  static String money(double amount) => _money.format(amount.abs());

  /// `$1,351`, sin decimales.
  static String moneyCompact(double amount) =>
      _moneyCompact.format(amount.abs());

  /// Nombre del mes en minúsculas en el idioma activo: `noviembre`.
  static String monthName(DateTime date) =>
      (_language == 'en' ? monthNamesEn : monthNames)[date.month - 1];

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
