// S2-06 · Reemplazo de datos al importar CSV (HU-27).
//
// SQLite real en un archivo temporal (sqflite_common_ffi).

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;

  final old = Movement(
    amount: -10,
    description: 'Viejo',
    category: 'Otros',
    date: DateTime(2026, 1, 1),
  );
  final oldIncome = Income(
    name: 'Viejo',
    amount: 5,
    date: DateTime(2026, 1, 1),
  );

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kopay_backup_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    await db.insertMovement(old);
    await db.insertIncome(oldIncome);
    await db.setSetting('currency', 'USD');
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('IMP-01 · HU-27 · importar reemplaza movimientos e ingresos y '
      'conserva ajustes', () async {
    await db.replaceFinancialData(
      [
        Movement(
          amount: -250.5,
          description: 'Súper',
          category: 'Comida',
          date: DateTime(2026, 11, 2),
        ),
      ],
      [Income(name: 'Quincena', amount: 12000, date: DateTime(2026, 11, 1))],
    );

    final movements = await db.getMovements();
    final incomes = await db.getIncomes();
    expect(movements.map((m) => m.description), ['Súper']);
    expect(movements.single.id, isNotNull);
    expect(incomes.map((i) => i.name), ['Quincena']);
    expect(await db.getSetting('currency'), 'USD');
  });

  test('IMP-09 · HU-27 · si falla la escritura se revierte y quedan los '
      'datos anteriores', () async {
    // Un ingreso negativo viola el CHECK de la tabla a mitad de la
    // transacción, después de haber borrado e insertado movimientos.
    await expectLater(
      db.replaceFinancialData(
        [
          Movement(
            amount: -1,
            description: 'Nuevo',
            category: 'Otros',
            date: DateTime(2026, 11, 2),
          ),
        ],
        [Income(name: 'Malo', amount: -1, date: DateTime(2026, 11, 1))],
      ),
      throwsA(anything),
    );

    expect((await db.getMovements()).map((m) => m.description), ['Viejo']);
    expect((await db.getIncomes()).map((i) => i.name), ['Viejo']);
  });

  test('RES-01 · RES-05 · HU-26 · los datos guardados exportan tarjetas, '
      'deudas y pagos con su destino', () async {
    final card = await db.insertCard(
      const CardModel(
        name: 'Oro',
        bank: 'BBVA',
        creditLimit: 30000,
        usedBalance: 5000,
        cutDay: 15,
        paymentDay: 5,
        minimumPayment: 900,
      ),
    );
    final debt = await db.insertDebt(
      DebtModel(
        name: 'Préstamo auto',
        monthlyPayment: 3200,
        remainingBalance: 45000,
        dueDate: DateTime(2026, 12, 10),
      ),
    );
    await db.insertCardPayment(
      cardId: card.id!,
      amount: 1500,
      date: DateTime(2026, 11, 5),
    );
    await db.insertDebtPayment(
      debtId: debt.id!,
      amount: 3200,
      date: DateTime(2026, 11, 6),
    );

    final book = Excel.decodeBytes(
      BackupService.buildXlsx(
        await db.getMovements(),
        await db.getIncomes(),
        cards: await db.getCards(),
        debts: await db.getDebts(),
      ),
    );
    String text(CellValue? v) => v is TextCellValue ? v.value.text ?? '' : '$v';

    final movementsSheet = book[BackupService.movementsSheet];
    // Encabezado, dos pagos y el movimiento "Viejo" del setUp.
    expect(movementsSheet.rows.length, 4);
    final rows = movementsSheet.rows.skip(1).toList();
    expect(rows.map((r) => text(r[5]?.value)), [
      BackupService.paymentLabel,
      BackupService.paymentLabel,
      BackupService.expenseLabel,
    ]);
    expect(rows.map((r) => text(r[6]?.value)), ['Préstamo auto', 'Oro', '']);

    expect(book[BackupService.cardsSheet].rows.length, 2);
    expect(text(book[BackupService.cardsSheet].rows[1][0]?.value), 'Oro');
    expect(book[BackupService.debtsSheet].rows.length, 2);
    expect(
      text(book[BackupService.debtsSheet].rows[1][4]?.value),
      BackupService.pendingLabel,
    );
    // Los pagos no van a la hoja que se puede importar como CSV: quedan el
    // encabezado, el movimiento "Viejo" y el ingreso del setUp.
    final backupSheet = book[BackupService.backupSheet];
    expect(backupSheet.rows.length, 3);
    expect(backupSheet.rows.skip(1).map((r) => text(r[0]?.value)), [
      BackupService.movementType,
      BackupService.incomeType,
    ]);
  });
}
