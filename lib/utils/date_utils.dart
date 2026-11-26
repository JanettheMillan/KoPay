// Lectura estricta de fechas guardadas en SQLite (D-03).
//
// `DateTime.parse` acepta fechas imposibles y las corre sin avisar:
// `2026-13-45` se vuelve `2027-02-14` y `2026-02-30` se vuelve
// `2026-03-02`. Un registro así quedaría en otro mes del resumen.
// [parseStoredDate] lanza [FormatException] en esos casos.

/// Año, mes, día y, si los trae, hora, minuto y segundo del texto ISO.
final RegExp _isoParts = RegExp(
  r'^([+-]?\d{4,6})-?(\d{2})-?(\d{2})'
  r'(?:[T ](\d{2})(?::?(\d{2})(?::?(\d{2}))?)?)?',
);

/// Lee una fecha ISO 8601, como la que escribe `DateTime.toIso8601String`.
///
/// Lanza [FormatException] si el texto no es una fecha o si el mes, el
/// día, la hora, el minuto o el segundo están fuera de rango.
DateTime parseStoredDate(String text) {
  // Primero valida el formato completo (zona horaria, milisegundos...).
  final date = DateTime.parse(text);

  final parts = _isoParts.firstMatch(text.trim());
  if (parts == null) {
    throw FormatException('Fecha no válida', text);
  }
  int part(int i) => parts[i] == null ? 0 : int.parse(parts[i]!);
  final year = part(1);
  final month = part(2);
  final day = part(3);
  final daysInMonth = month >= 1 && month <= 12
      ? DateTime.utc(year, month + 1, 0).day
      : 0;

  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > daysInMonth ||
      part(4) > 23 ||
      part(5) > 59 ||
      part(6) > 59) {
    throw FormatException('Fecha imposible', text);
  }
  return date;
}
