// S2-06 · Exportar XLSX e importar CSV (HU-26, HU-27).
//
// Casos de `docs/criterios-respaldo-importacion-borrado.md`. Solo
// lógica: el XLSX se vuelve a leer con la misma librería `excel`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
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
  final cards = [
    const CardModel(
      id: 1,
      name: 'Oro',
      bank: 'BBVA',
      creditLimit: 30000,
      usedBalance: 4500.5,
      cutDay: 15,
      paymentDay: 5,
      minimumPayment: 900,
    ),
  ];
  final debts = [
    DebtModel(
      id: 2,
      name: 'Préstamo auto',
      monthlyPayment: 3200,
      remainingBalance: 45000,
      dueDate: DateTime(2026, 12, 10),
    ),
    DebtModel(
      id: 3,
      name: 'Tarjeta departamental',
      monthlyPayment: 500,
      remainingBalance: 0,
      dueDate: DateTime(2026, 11, 20),
      status: DebtStatus.paid,
    ),
  ];

  Excel decode(Uint8List bytes) => Excel.decodeBytes(bytes);

  List<List<CellValue?>> rowsOf(Excel book, String sheet) => [
    for (final row in book[sheet].rows) [for (final c in row) c?.value],
  ];

  String text(CellValue? v) => v is TextCellValue ? v.value.text ?? '' : '$v';

  /// Un importe o un día se lee igual si Excel lo guardó como entero o
  /// como decimal.
  num number(CellValue? v) => switch (v) {
    DoubleCellValue(:final value) => value,
    IntCellValue(:final value) => value,
    _ => throw TestFailure('No es un número: $v'),
  };

  group('Exportar XLSX', () {
    test('RES-01 · HU-26 · cinco hojas con columnas en orden y todos los '
        'registros', () {
      final book = decode(
        BackupService.buildXlsx(movements, incomes, cards: cards, debts: debts),
      );

      expect(book.tables.keys, [
        BackupService.movementsSheet,
        BackupService.incomesSheet,
        BackupService.cardsSheet,
        BackupService.debtsSheet,
        BackupService.backupSheet,
      ]);

      final m = rowsOf(book, BackupService.movementsSheet);
      expect(m.first.map(text), BackupService.movementsHeader);
      expect(m.length, 1 + movements.length);
      // Más reciente primero.
      expect(text(m[1][1]), 'Camión, ida y vuelta');
      expect(text(m[2][1]), 'Súper');

      final i = rowsOf(book, BackupService.incomesSheet);
      expect(i.first.map(text), BackupService.incomesHeader);
      expect(text(i[1][1]), 'Quincena');

      final c = rowsOf(book, BackupService.cardsSheet);
      expect(c.first.map(text), BackupService.cardsHeader);
      expect(c.length, 1 + cards.length);
      expect(c[1].map(text).take(2), ['Oro', 'BBVA']);
      expect(number(c[1][2]), 30000);
      expect(number(c[1][3]), 4500.5);
      expect(number(c[1][4]), 15);
      expect(number(c[1][5]), 5);
      expect(number(c[1][6]), 900);

      final d = rowsOf(book, BackupService.debtsSheet);
      expect(d.first.map(text), BackupService.debtsHeader);
      expect(d.length, 1 + debts.length);
      expect(d[1].map(text).take(1), ['Préstamo auto']);
      expect(number(d[1][1]), 3200);
      expect(number(d[1][2]), 45000);
      expect(d[1][3], isA<DateCellValue>());
      expect(text(d[1][4]), BackupService.pendingLabel);
      expect(text(d[2][4]), BackupService.paidLabel);

      final r = rowsOf(book, BackupService.backupSheet);
      expect(r.first.map(text), BackupService.csvHeader);
      expect(r.length, 1 + movements.length + incomes.length);
    });

    test('RES-02 · HU-26 · sin registros crea el archivo con solo '
        'encabezados', () {
      final book = decode(BackupService.buildXlsx(const [], const []));
      for (final sheet in [
        BackupService.movementsSheet,
        BackupService.incomesSheet,
        BackupService.cardsSheet,
        BackupService.debtsSheet,
        BackupService.backupSheet,
      ]) {
        expect(rowsOf(book, sheet).length, 1, reason: sheet);
      }
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

    test('RES-05 · HU-26 · HU-13 a HU-23 · Movimientos distingue gasto, '
        'entrada y pago con su tarjeta o deuda', () {
      final withPayments = [
        ...movements,
        Movement(
          amount: -1500,
          description: 'Pago Oro',
          category: 'Pago tarjeta',
          date: DateTime(2026, 11, 5),
          type: MovementType.payment,
          cardId: 1,
        ),
        Movement(
          amount: -3200,
          description: 'Pago Préstamo auto',
          category: 'Pago deuda',
          date: DateTime(2026, 11, 6),
          type: MovementType.payment,
          debtId: 2,
        ),
        Movement(
          amount: 12000,
          description: 'Quincena',
          category: 'Ingreso',
          date: DateTime(2026, 11, 7),
        ),
        // Pago cuya tarjeta ya no existe: se exporta sin destino.
        Movement(
          amount: -100,
          description: 'Pago viejo',
          category: 'Pago tarjeta',
          date: DateTime(2026, 11, 8),
          type: MovementType.payment,
        ),
      ];

      final book = decode(
        BackupService.buildXlsx(
          withPayments,
          incomes,
          cards: cards,
          debts: debts,
        ),
      );
      final rows = rowsOf(book, BackupService.movementsSheet).skip(1).toList();

      // Más reciente primero: pago sin tarjeta, entrada, pago de deuda,
      // pago de tarjeta y los dos movimientos de ejemplo.
      expect(rows.map((r) => text(r[5])), [
        BackupService.paymentLabel,
        BackupService.entryLabel,
        BackupService.paymentLabel,
        BackupService.paymentLabel,
        BackupService.expenseLabel,
        BackupService.expenseLabel,
      ]);
      expect(rows.map((r) => text(r[6])), [
        '',
        '',
        'Préstamo auto',
        'Oro',
        '',
        '',
      ]);
    });

    test('RES-04 · HU-26 · HU-27 · la hoja Respaldo guardada como CSV se '
        'importa igual', () {
      // Con pagos incluidos: la hoja Respaldo los omite porque el CSV no
      // los admite (ver criterios, sección 3).
      final withPayments = [
        ...movements,
        Movement(
          amount: -1500,
          description: 'Pago Oro',
          category: 'Pago tarjeta',
          date: DateTime(2026, 11, 5),
          type: MovementType.payment,
          cardId: 1,
        ),
      ];
      final book = decode(
        BackupService.buildXlsx(
          withPayments,
          incomes,
          cards: cards,
          debts: debts,
        ),
      );
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
