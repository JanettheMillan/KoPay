import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late DatabaseHelper helper;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_db_test');
    dbPath = '${tempDir.path}/${DatabaseHelper.fileName}';
    helper = DatabaseHelper.withFactory(databaseFactoryFfi, dbPath);
  });

  tearDown(() async {
    await helper.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<List<String>> columnsOf(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((c) => c['name'] as String).toList();
  }

  test('crea las tablas movements, incomes y settings', () async {
    final db = await helper.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    expect(
      tables.map((t) => t['name']).toSet(),
      {'movements', 'incomes', 'settings'},
    );
    expect(await db.getVersion(), DatabaseHelper.version);
  });

  test('las columnas coinciden con los modelos', () async {
    final db = await helper.database;
    final sample = DateTime(2026, 11, 5);

    final movementKeys = Movement(
      id: 1,
      amount: -1,
      description: 'd',
      category: 'c',
      date: sample,
    ).toMap().keys;
    final incomeKeys =
        Income(id: 1, name: 'n', amount: 1, date: sample).toMap().keys;

    expect(await columnsOf(db, 'movements'), unorderedEquals(movementKeys));
    expect(await columnsOf(db, 'incomes'), unorderedEquals(incomeKeys));
    expect(await columnsOf(db, 'settings'), unorderedEquals(['key', 'value']));
  });

  test('settings arranca con moneda, idioma y categorías', () async {
    final db = await helper.database;
    final rows = await db.query('settings');
    final settings = {for (final r in rows) r['key']: r['value']};

    expect(settings['currency'], 'MXN');
    expect(settings['language'], 'es');
    expect(
      jsonDecode(settings['categories'] as String),
      DatabaseHelper.defaultCategories,
    );
  });

  test('los modelos se guardan y leen sin perder campos', () async {
    final db = await helper.database;
    final movement = Movement(
      amount: -1350.5,
      description: 'Súper',
      category: 'Comida',
      date: DateTime(2026, 11, 3),
      note: 'Despensa',
    );
    final income = Income(
      name: 'Salario',
      amount: 12000,
      date: DateTime(2026, 11, 1),
    );

    final movementId = await db.insert('movements', movement.toMap());
    final incomeId = await db.insert('incomes', income.toMap());

    final storedMovement =
        Movement.fromMap((await db.query('movements')).single);
    final storedIncome = Income.fromMap((await db.query('incomes')).single);

    expect(storedMovement, movement.copyWith(id: movementId));
    expect(storedIncome, income.copyWith(id: incomeId));
  });

  test('un ingreso con monto negativo se rechaza', () async {
    final db = await helper.database;
    expect(
      () => db.insert('incomes', {
        'name': 'Error',
        'amount': -5,
        'date': DateTime(2026, 11, 1).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('la base se vuelve a abrir con los datos guardados', () async {
    final db = await helper.database;
    await db.insert('incomes', {
      'name': 'Salario',
      'amount': 12000,
      'date': DateTime(2026, 11, 1).toIso8601String(),
    });
    await helper.close();

    expect(File(dbPath).existsSync(), isTrue);

    final reopened = await helper.database;
    expect(await reopened.query('incomes'), hasLength(1));
    expect(await reopened.query('settings'), hasLength(3));
  });
}
