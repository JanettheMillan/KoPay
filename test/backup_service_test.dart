// S2-06 · Exportar XLSX e importar CSV (HU-26, HU-27).
//
// Casos de `docs/criterios-respaldo-importacion-borrado.md`. Solo
// lógica: el XLSX se vuelve a leer con la misma librería `excel`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/services/backup_service.dart';

void main() {
  final movements = [
    Movement(
      amount: -250.5,
      description: 'Súper',
      category: 'Comida',
      date: DateTime(2026, 11, 2),
    ),
    Movement(
      amount: -80,
      description: 'Camión, ida y vuelta',
      category: 'Transporte',
      date: DateTime(2026, 11, 3),
      note: 'con "comillas"',
    ),
  ];
  final incomes = [
    Income(name: 'Quincena', amount: 12000, date: DateTime(2026, 11, 1)),
  ];

  Excel decode(Uint8List bytes) => Excel.decodeBytes(bytes);

  List<List<CellValue?>> rowsOf(Excel book, String sheet) => [
    for (final row in book[sheet].rows) [for (final c in row) c?.value],
  ];

  String text(CellValue? v) => v is TextCellValue ? v.value.text ?? '' : '$v';

  group('Exportar XLSX', () {
    test('RES-01 · HU-26 · tres hojas con columnas en orden y todos los '
        'registros', () {
      final book = decode(BackupService.buildXlsx(movements, incomes));

      expect(book.tables.keys, [
        BackupService.movementsSheet,
        BackupService.incomesSheet,
        BackupService.backupSheet,
      ]);

      final m = rowsOf(book, BackupService.movementsSheet);
      expect(m.first.map(text), [
        'Fecha',
        'Descripción',
        'Categoría',
        'Importe',
        'Nota',
      ]);
      expect(m.length, 1 + movements.length);
      // Más reciente primero.
      expect(text(m[1][1]), 'Camión, ida y vuelta');
      expect(text(m[2][1]), 'Súper');

      final i = rowsOf(book, BackupService.incomesSheet);
      expect(i.first.map(text), ['Fecha', 'Nombre', 'Importe', 'Nota']);
      expect(text(i[1][1]), 'Quincena');

      final r = rowsOf(book, BackupService.backupSheet);
      expect(r.first.map(text), BackupService.csvHeader);
      expect(r.length, 1 + movements.length + incomes.length);
    });

    test('RES-02 · HU-26 · sin registros crea el archivo con solo '
        'encabezados', () {
      final book = decode(BackupService.buildXlsx(const [], const []));
      expect(rowsOf(book, BackupService.movementsSheet).length, 1);
      expect(rowsOf(book, BackupService.incomesSheet).length, 1);
      expect(rowsOf(book, BackupService.backupSheet).length, 1);
    });

    test('RES-03 · HU-26 · importe como número con signo y fecha como '
        'fecha', () {
      final book = decode(BackupService.buildXlsx(movements, incomes));
      final row = rowsOf(book, BackupService.movementsSheet)[2];
      expect(row[0], isA<DateCellValue>());
      final date = row[0] as DateCellValue;
      expect([date.year, date.month, date.day], [2026, 11, 2]);
      expect(row[3], isA<DoubleCellValue>());
      expect((row[3] as DoubleCellValue).value, -250.5);
    });

    test('RES-04 · HU-26 · HU-27 · la hoja Respaldo guardada como CSV se '
        'importa igual', () {
      final book = decode(BackupService.buildXlsx(movements, incomes));
      final rows = rowsOf(book, BackupService.backupSheet)
          .map(
            (r) => r
                .map((v) => v is DoubleCellValue ? '${v.value}' : text(v))
                .toList(),
          )
          .toList();

      for (final delimiter in [',', ';']) {
        var csvText = Csv(fieldDelimiter: delimiter).encode(rows);
        if (delimiter == ';') {
          // Excel en español escribe coma decimal con `;`.
          csvText = csvText.replaceAllMapped(
            RegExp(r'(-?\d+)\.(\d+)'),
            (m) => '${m[1]},${m[2]}',
          );
        }
        final result = BackupService.parseCsv(csvText);
        expect(result.errors, isEmpty, reason: 'separador $delimiter');
        expect(
          result.movements.map((m) => [m.description, m.amount, m.date]),
          unorderedEquals(
            movements.map((m) => [m.description, m.amount, m.date]),
          ),
        );
        expect(result.movements.map((m) => m.note), contains('con "comillas"'));
        expect(result.incomes.single.name, 'Quincena');
        expect(result.incomes.single.amount, 12000);
      }
    });

    test('nombre del archivo con la fecha del día', () {
      expect(
        BackupService.fileName(DateTime(2026, 3, 7, 18)),
        'kopay-respaldo-2026-03-07.xlsx',
      );
    });
  });

  group('Importar CSV', () {
    const header = 'tipo,fecha,importe,descripcion,categoria,nota';

    test('IMP-01 · HU-27 · CSV válido con coma', () {
      final result = BackupService.parseCsv(
        '$header\n'
        'movimiento,2026-11-02,-250.50,Súper,Comida,\n'
        'Movimiento , 2026-11-03 ,-80,Camión,Transporte,ida y vuelta\n'
        'ingreso,2026-11-01,12000,Quincena,,\n',
      );
      expect(result.isValid, isTrue, reason: result.errorSummary());
      expect(result.movements.length, 2);
      expect(result.movements.first.amount, -250.5);
      expect(result.movements.first.date, DateTime(2026, 11, 2));
      expect(result.movements.first.note, isNull);
      expect(result.movements.last.note, 'ida y vuelta');
      expect(result.incomes.single.name, 'Quincena');
      expect(result.categories, ['Comida', 'Transporte']);
    });

    test('IMP-02 · HU-27 · CSV con punto y coma, coma decimal, '
        'DD/MM/AAAA y BOM', () {
      final result = BackupService.parseCsv(
        '﻿tipo;fecha;importe;descripcion;categoria;nota\r\n'
        'movimiento;02/11/2026;-250,50;Súper;Comida;\r\n'
        'ingreso;1/11/2026;12000;Quincena;;\r\n',
      );
      expect(result.isValid, isTrue, reason: result.errorSummary());
      expect(result.movements.single.amount, -250.5);
      expect(result.movements.single.date, DateTime(2026, 11, 2));
      expect(result.incomes.single.date, DateTime(2026, 11, 1));
    });

    test('IMP-04 · HU-27 · D-03 · una fecha imposible cancela todo e '
        'indica la fila', () {
      final result = BackupService.parseCsv(
        '$header\n'
        'movimiento,2026-11-02,-250.50,Súper,Comida,\n'
        'movimiento,2026-02-30,-80,Camión,Transporte,\n',
      );
      expect(result.isValid, isFalse);
      expect(result.movements, isEmpty);
      expect(result.incomes, isEmpty);
      expect(result.errors.single, startsWith('Fila 3: fecha imposible'));
      expect(result.errors.single, contains('2026-02-30'));
    });

    test('IMP-05 · HU-27 · importe no numérico o tipo desconocido indican '
        'fila y motivo', () {
      final result = BackupService.parseCsv(
        '$header\n'
        'movimiento,2026-11-02,abc,Súper,Comida,\n'
        'gasto,2026-11-02,-10,Súper,Comida,\n'
        'movimiento,2026-11-02,"1,234.50",Súper,Comida,\n'
        'movimiento,2026-11-02,-10.555,Súper,Comida,\n'
        'ingreso,2026-11-02,-5,Quincena,,\n'
        'ingreso,2026-11-02,5,Quincena,Comida,\n'
        'movimiento,2026-11-02,-10,,Comida,\n'
        'movimiento,2026-11-02,-10,Súper,,\n'
        'movimiento,2026-11-02,-10,Súper\n',
      );
      expect(result.isValid, isFalse);
      expect(result.errors, [
        startsWith('Fila 2: importe no válido "abc"'),
        startsWith('Fila 3: tipo desconocido "gasto"'),
        startsWith('Fila 4: importe no válido "1,234.50"'),
        startsWith('Fila 5: importe no válido'),
        'Fila 6: el monto debe ser mayor que cero.',
        'Fila 7: la categoría debe ir vacía en un ingreso.',
        'Fila 8: escribe una descripción.',
        'Fila 9: elige una categoría.',
        'Fila 10: se esperaban 6 columnas y hay 4.',
      ]);
    });

    test('IMP-06 · HU-27 · encabezado incorrecto indica las columnas '
        'esperadas', () {
      final result = BackupService.parseCsv(
        'fecha,tipo,importe,descripcion,categoria,nota\n'
        'movimiento,2026-11-02,-250.50,Súper,Comida,\n',
      );
      expect(result.errors.single, contains(header));
    });

    test('IMP-07 · HU-27 · solo encabezado se rechaza', () {
      final result = BackupService.parseCsv('$header\n\n');
      expect(result.errors, ['El archivo no tiene registros.']);
    });

    test('archivo vacío se rechaza como encabezado incorrecto', () {
      expect(BackupService.parseCsv('').isValid, isFalse);
    });

    test('más de 10 errores se resumen', () {
      final rows = List.filled(13, 'movimiento,2026-13-01,-1,X,Y,').join('\n');
      final result = BackupService.parseCsv('$header\n$rows');
      expect(result.errors.length, 13);
      final summary = result.errorSummary();
      expect('\n'.allMatches(summary).length, 10);
      expect(summary, endsWith('… y 3 errores más.'));
    });

    test('archivo de más de 5 MB o que no es UTF-8 se rechaza', () {
      final big = Uint8List(BackupService.maxCsvBytes + 1);
      expect(BackupService.parseCsvBytes(big).errors.single, contains('5 MB'));
      final latin1 = Uint8List.fromList([
        ...utf8.encode('$header\nmovimiento,2026-11-02,-1,S'),
        0xFA, // "ú" en Latin-1
        ...utf8.encode('per,Comida,\n'),
      ]);
      expect(
        BackupService.parseCsvBytes(latin1).errors.single,
        contains('UTF-8'),
      );
    });

    test('categoría de más de 30 caracteres se rechaza', () {
      final result = BackupService.parseCsv(
        '$header\nmovimiento,2026-11-02,-1,Súper,${'x' * 31},\n',
      );
      expect(result.errors.single, contains('más de 30 caracteres'));
    });
  });
}
