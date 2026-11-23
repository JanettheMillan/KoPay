import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/income_model.dart';
import '../models/movement_model.dart';
import '../providers/category_provider.dart';
import '../utils/validators.dart';

/// Exportar XLSX e importar CSV (HU-26, HU-27).
///
/// Sigue las reglas de `docs/criterios-respaldo-importacion-borrado.md`.
/// Aquí solo vive la lógica, sin archivos ni interfaz, para poder
/// probarla sin dispositivo.
class BackupService {
  BackupService._();

  /// Columnas del CSV de importación y de la hoja `Respaldo`, en orden.
  static const List<String> csvHeader = [
    'tipo',
    'fecha',
    'importe',
    'descripcion',
    'categoria',
    'nota',
  ];

  static const String movementType = 'movimiento';
  static const String incomeType = 'ingreso';

  static const String movementsSheet = 'Movimientos';
  static const String incomesSheet = 'Ingresos';
  static const String backupSheet = 'Respaldo';

  /// Tamaño máximo del CSV que se acepta: 5 MB.
  static const int maxCsvBytes = 5 * 1024 * 1024;

  /// Cuántos errores se muestran antes de resumir el resto.
  static const int maxShownErrors = 10;

  /// `kopay-respaldo-AAAA-MM-DD.xlsx` con la fecha de [now].
  static String fileName(DateTime now) =>
      'kopay-respaldo-${_isoDate(now)}.xlsx';

  // ── Exportar ─────────────────────────────────────────────────

  /// Crea el libro con las hojas `Movimientos`, `Ingresos` y `Respaldo`.
  /// Las filas van de la fecha más reciente a la más antigua.
  static Uint8List buildXlsx(List<Movement> movements, List<Income> incomes) {
    final ms = [...movements]..sort((a, b) => b.date.compareTo(a.date));
    final ins = [...incomes]..sort((a, b) => b.date.compareTo(a.date));

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    excel.rename(defaultSheet, movementsSheet);

    final m = excel[movementsSheet];
    m.appendRow(
      _texts(['Fecha', 'Descripción', 'Categoría', 'Importe', 'Nota']),
    );
    for (final x in ms) {
      m.appendRow([
        _date(x.date),
        TextCellValue(x.description),
        TextCellValue(x.category),
        DoubleCellValue(x.amount),
        TextCellValue(x.note ?? ''),
      ]);
    }

    final i = excel[incomesSheet];
    i.appendRow(_texts(['Fecha', 'Nombre', 'Importe', 'Nota']));
    for (final x in ins) {
      i.appendRow([
        _date(x.date),
        TextCellValue(x.name),
        DoubleCellValue(x.amount),
        TextCellValue(x.note ?? ''),
      ]);
    }

    // Mismo formato que el CSV de importación. La fecha va como texto
    // AAAA-MM-DD para que al guardarla como CSV no cambie de formato.
    final r = excel[backupSheet];
    r.appendRow(_texts(csvHeader));
    for (final row in backupRows(ms, ins)) {
      r.appendRow([
        TextCellValue(row[0] as String),
        TextCellValue(row[1] as String),
        DoubleCellValue(row[2] as double),
        TextCellValue(row[3] as String),
        TextCellValue(row[4] as String),
        TextCellValue(row[5] as String),
      ]);
    }

    excel.setDefaultSheet(movementsSheet);
    return Uint8List.fromList(excel.encode()!);
  }

  /// Filas del formato de respaldo (sin encabezado): primero los
  /// movimientos y luego los ingresos.
  static List<List<Object>> backupRows(
    List<Movement> movements,
    List<Income> incomes,
  ) => [
    for (final x in movements)
      [
        movementType,
        _isoDate(x.date),
        x.amount,
        x.description,
        x.category,
        x.note ?? '',
      ],
    for (final x in incomes)
      [incomeType, _isoDate(x.date), x.amount, x.name, '', x.note ?? ''],
  ];

  // ── Importar ─────────────────────────────────────────────────

  /// Lee los bytes de un CSV de respaldo. Nunca lanza: los problemas
  /// vuelven en [CsvImportResult.errors].
  static CsvImportResult parseCsvBytes(Uint8List bytes) {
    if (bytes.length > maxCsvBytes) {
      return CsvImportResult.failed(['El archivo pesa más de 5 MB.']);
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return CsvImportResult.failed([
        'El archivo no está en UTF-8. Guárdalo como "CSV UTF-8".',
      ]);
    }
    return parseCsv(text);
  }

  /// Valida todo el texto antes de devolver registros. Si hay un solo
  /// error, no devuelve ninguno.
  static CsvImportResult parseCsv(String text) {
    if (text.startsWith('﻿')) text = text.substring(1);

    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final delimiter = firstLine.contains(';') ? ';' : ',';

    final List<List<dynamic>> rows;
    try {
      rows = Csv(
        fieldDelimiter: delimiter,
        autoDetect: false,
        skipEmptyLines: false,
      ).decode(text);
    } catch (_) {
      return CsvImportResult.failed(['No se pudo leer el archivo como CSV.']);
    }

    final expected = csvHeader.join(delimiter);
    if (rows.isEmpty ||
        rows.first.length != csvHeader.length ||
        !_matchesHeader(rows.first)) {
      return CsvImportResult.failed([
        'Encabezado incorrecto. La primera fila debe ser: $expected',
      ]);
    }

    final movements = <Movement>[];
    final incomes = <Income>[];
    final errors = <String>[];

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index].map((c) => '$c'.trim()).toList();
      if (row.every((c) => c.isEmpty)) continue;
      final line = index + 1;

      if (row.length != csvHeader.length) {
        errors.add(
          'Fila $line: se esperaban ${csvHeader.length} columnas y hay '
          '${row.length}.',
        );
        continue;
      }

      final error = _parseRow(row, delimiter, movements, incomes);
      if (error != null) errors.add('Fila $line: $error');
    }

    if (errors.isNotEmpty) return CsvImportResult.failed(errors);
    if (movements.isEmpty && incomes.isEmpty) {
      return CsvImportResult.failed(['El archivo no tiene registros.']);
    }
    return CsvImportResult.ok(movements, incomes);
  }

  /// Agrega el registro de [row] a su lista, o devuelve el motivo del
  /// error.
  static String? _parseRow(
    List<String> row,
    String delimiter,
    List<Movement> movements,
    List<Income> incomes,
  ) {
    final type = row[0].toLowerCase();
    if (type != movementType && type != incomeType) {
      return 'tipo desconocido "${row[0]}" (usa movimiento o ingreso).';
    }

    final date = parseDate(row[1]);
    if (date == null) {
      return row[1].isEmpty
          ? 'falta la fecha.'
          : 'fecha imposible o con formato no válido "${row[1]}" '
                '(usa AAAA-MM-DD o DD/MM/AAAA).';
    }

    final amount = parseAmount(row[2], allowDecimalComma: delimiter == ';');
    if (amount == null) {
      return 'importe no válido "${row[2]}" (número sin símbolo ni '
          'separador de miles, máximo dos decimales).';
    }

    final description = row[3];
    final category = row[4];
    final note = row[5].isEmpty ? null : row[5];

    if (type == movementType) {
      if (category.length > CategoryProvider.maxLength) {
        return 'la categoría tiene más de ${CategoryProvider.maxLength} '
            'caracteres.';
      }
      final movement = Movement(
        amount: amount,
        description: description,
        category: category,
        date: date,
        note: note,
      );
      final error = Validators.checkMovement(movement);
      if (error != null) return '${_lower(error)}.';
      movements.add(movement);
    } else {
      if (category.isNotEmpty) {
        return 'la categoría debe ir vacía en un ingreso.';
      }
      final income = Income(
        name: description,
        amount: amount,
        date: date,
        note: note,
      );
      final error = Validators.checkIncome(income);
      if (error != null) return '${_lower(error)}.';
      incomes.add(income);
    }
    return null;
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _dmyPattern = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

  /// Fecha de `AAAA-MM-DD` o `DD/MM/AAAA`. Devuelve `null` si el texto
  /// no tiene ese formato o la fecha no existe (`2026-02-30`, D-03).
  static DateTime? parseDate(String text) {
    int y, m, d;
    final iso = _isoPattern.firstMatch(text);
    final dmy = _dmyPattern.firstMatch(text);
    if (iso != null) {
      y = int.parse(iso[1]!);
      m = int.parse(iso[2]!);
      d = int.parse(iso[3]!);
    } else if (dmy != null) {
      d = int.parse(dmy[1]!);
      m = int.parse(dmy[2]!);
      y = int.parse(dmy[3]!);
    } else {
      return null;
    }
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;
    return date;
  }

  static final RegExp _amountPattern = RegExp(r'^-?\d+(\.\d{1,2})?$');

  /// Importe con punto decimal (o coma, si [allowDecimalComma]) y signo
  /// opcional. Sin símbolo ni separador de miles; máximo dos decimales.
  static double? parseAmount(String text, {bool allowDecimalComma = false}) {
    var clean = text.trim();
    if (allowDecimalComma && !clean.contains('.')) {
      clean = clean.replaceAll(',', '.');
    }
    if (!_amountPattern.hasMatch(clean)) return null;
    return double.parse(clean);
  }

  static bool _matchesHeader(List<dynamic> row) {
    for (var i = 0; i < csvHeader.length; i++) {
      if ('${row[i]}'.trim().toLowerCase() != csvHeader[i]) return false;
    }
    return true;
  }

  static List<CellValue> _texts(List<String> values) => [
    for (final v in values) TextCellValue(v),
  ];

  static CellValue _date(DateTime d) =>
      DateCellValue(year: d.year, month: d.month, day: d.day);

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _lower(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}

/// Resultado de leer un CSV: registros listos o la lista de errores.
class CsvImportResult {
  CsvImportResult.ok(this.movements, this.incomes) : errors = const [];

  CsvImportResult.failed(this.errors)
    : movements = const [],
      incomes = const [];

  final List<Movement> movements;
  final List<Income> incomes;

  /// Motivos por los que se rechaza el archivo, en orden de fila.
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  /// Categorías de los movimientos, sin repetir, en orden de aparición.
  List<String> get categories =>
      {for (final m in movements) m.category}.toList();

  /// Texto para mostrar: los primeros errores y cuántos faltan.
  String errorSummary({int max = BackupService.maxShownErrors}) {
    final shown = errors.take(max).join('\n');
    final rest = errors.length - max;
    return rest > 0 ? '$shown\n… y $rest errores más.' : shown;
  }
}
