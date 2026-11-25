// S2-20 · Borrado local de datos en SQLite (HU-28).
//
// Casos BOR de docs/criterios-respaldo-importacion-borrado.md (S2-03).
// Usa una base real en archivo temporal para poder cerrarla y reabrirla.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String path;
  late DatabaseHelper helper;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_delete_test');
    path = '${tempDir.path}/${DatabaseHelper.fileName}';
    helper = DatabaseHelper.withFactory(databaseFactoryFfi, path);
  });

  tearDown(() async {
    await helper.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> seed() async {
    await helper.insertMovement(
      Movement(
        amount: -250.5,
        description: 'Súper',
        category: 'Comida',
        date: DateTime(2026, 11, 2),
      ),
    );
    await helper.insertMovement(
      Movement(
        amount: -80,
        description: 'Camión',
        category: 'Transporte',
        date: DateTime(2026, 11, 3),
      ),
    );
    await helper.insertIncome(
      Income(name: 'Quincena', amount: 12000, date: DateTime(2026, 11, 1)),
    );
  }

  test('BOR-02 · HU-28 · Confirmar borra movimientos e ingresos', () async {
    await seed();
    expect(await helper.getMovements(), hasLength(2));
    expect(await helper.getIncomes(), hasLength(1));

    await helper.deleteFinancialData();

    expect(await helper.getMovements(), isEmpty);
    expect(await helper.getIncomes(), isEmpty);
  });

  test('BOR-02 · HU-28 · Se conservan categorías, moneda e idioma', () async {
    await seed();
    await helper.setSetting('currency', 'USD');
    await helper.setSetting('language', 'en');
    final categorias = [...DatabaseHelper.defaultCategories, 'Mascotas'];
    await helper.setSetting(
      CategoryProvider.settingsKey,
      jsonEncode(categorias),
    );

    await helper.deleteFinancialData();

    expect(await helper.getSetting('currency'), 'USD');
    expect(await helper.getSetting('language'), 'en');
    expect(
      jsonDecode((await helper.getSetting(CategoryProvider.settingsKey))!),
      categorias,
    );
  });

  test('BOR-02 · HU-28 · El borrado sigue al reabrir la app', () async {
    await seed();
    await helper.deleteFinancialData();
    await helper.close();

    final reabierta = DatabaseHelper.withFactory(databaseFactoryFfi, path);
    addTearDown(reabierta.close);
    expect(await reabierta.getMovements(), isEmpty);
    expect(await reabierta.getIncomes(), isEmpty);
  });

  test('BOR-02 · HU-28 · Con la base vacía no falla', () async {
    await helper.deleteFinancialData();
    expect(await helper.getMovements(), isEmpty);
    expect(await helper.getIncomes(), isEmpty);
  });

  test('BOR-04 · HU-28 · Si una tabla falla no se borra nada', () async {
    await seed();
    // Forzar un fallo a mitad del borrado: la segunda tabla de la
    // transacción ya no existe, así que su DELETE lanza un error.
    final db = await helper.database;
    final ultima = DatabaseHelper.financialTables.last;
    await db.execute('ALTER TABLE $ultima RENAME TO ${ultima}_tmp');

    await expectLater(helper.deleteFinancialData(), throwsA(anything));

    await db.execute('ALTER TABLE ${ultima}_tmp RENAME TO $ultima');
    // La transacción se revirtió: la primera tabla conserva sus filas.
    expect(await helper.getMovements(), hasLength(2));
    expect(await helper.getIncomes(), hasLength(1));
  });

  test('BOR-03 · HU-28 · El borrado cubre todas las tablas financieras', () {
    // Movimientos, ingresos, tarjetas (S2-07) y deudas (S2-08), según
    // los criterios S2-03, §4.
    expect(
      DatabaseHelper.financialTables,
      containsAll([
        DatabaseHelper.movementsTable,
        DatabaseHelper.incomesTable,
        DatabaseHelper.cardsTable,
        DatabaseHelper.debtsTable,
      ]),
    );
    expect(
      DatabaseHelper.financialTables,
      isNot(contains(DatabaseHelper.settingsTable)),
    );
  });
}
