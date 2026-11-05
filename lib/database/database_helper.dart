import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/income_model.dart';
import '../models/movement_model.dart';

/// Acceso único a la base SQLite local de KoPay.
///
/// Crea las tablas `movements`, `incomes` y `settings` la primera vez
/// que se abre y ofrece alta, lectura, edición y borrado de movimientos
/// e ingresos. Las listas se devuelven de la fecha más reciente a la
/// más antigua.
class DatabaseHelper {
  static const String fileName = 'kopay.db';
  static const int version = 1;

  static const String movementsTable = 'movements';
  static const String incomesTable = 'incomes';
  static const String settingsTable = 'settings';

  /// Ajustes con los que arranca una instalación nueva.
  static const Map<String, String> defaultSettings = {
    'currency': 'MXN',
    'language': 'es',
  };

  /// Categorías de gasto iniciales; se guardan en `settings` como JSON.
  static const List<String> defaultCategories = [
    'Comida',
    'Transporte',
    'Servicios',
    'Vivienda',
    'Entretenimiento',
    'Salud',
    'Otros',
  ];

  /// Instancia compartida que usa la app.
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  /// Instancia con otra fábrica y otra ruta, para pruebas.
  @visibleForTesting
  DatabaseHelper.withFactory(DatabaseFactory factory, String path)
    : _factory = factory,
      _path = path;

  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _db;

  /// Abre la base (y la crea si no existe). Las llamadas siguientes
  /// devuelven la misma conexión.
  Future<Database> get database => _db ??= _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? '${await factory.getDatabasesPath()}/$fileName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: version, onCreate: _onCreate),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Monto con signo: negativo = gasto, positivo = entrada.
    // La fecha va en texto ISO 8601 para poder ordenarla.
    batch.execute('''
      CREATE TABLE $movementsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_movements_date ON $movementsTable (date)');

    batch.execute('''
      CREATE TABLE $incomesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount >= 0),
        date TEXT NOT NULL,
        note TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_incomes_date ON $incomesTable (date)');

    batch.execute('''
      CREATE TABLE $settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    for (final entry in defaultSettings.entries) {
      batch.insert(settingsTable, {'key': entry.key, 'value': entry.value});
    }
    batch.insert(settingsTable, {
      'key': 'categories',
      'value': jsonEncode(defaultCategories),
    });

    await batch.commit(noResult: true);
  }

  // ── Movimientos ──────────────────────────────────────────────

  /// Guarda un movimiento nuevo y lo devuelve con su `id`.
  Future<Movement> insertMovement(Movement movement) async {
    final db = await database;
    final map = movement.toMap()..remove('id');
    final id = await db.insert(movementsTable, map);
    return movement.copyWith(id: id);
  }

  /// Movimientos del más reciente al más antiguo. Con [month] devuelve
  /// solo los de ese mes y año.
  Future<List<Movement>> getMovements({DateTime? month}) async {
    final db = await database;
    final range = month == null ? null : _monthRange(month);
    final rows = await db.query(
      movementsTable,
      where: range == null ? null : 'date >= ? AND date < ?',
      whereArgs: range,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Movement.fromMap).toList();
  }

  /// Movimiento con ese [id], o `null` si no existe.
  Future<Movement?> getMovement(int id) async {
    final db = await database;
    final rows = await db.query(
      movementsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Movement.fromMap(rows.first);
  }

  /// Reemplaza los campos del movimiento guardado. Devuelve cuántas
  /// filas cambiaron (0 si el `id` no existe).
  Future<int> updateMovement(Movement movement) async {
    final id = _requireId(movement.id);
    final db = await database;
    return db.update(
      movementsTable,
      movement.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el movimiento. Devuelve cuántas filas se borraron.
  Future<int> deleteMovement(int id) async {
    final db = await database;
    return db.delete(movementsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Ingresos ─────────────────────────────────────────────────

  /// Guarda un ingreso nuevo y lo devuelve con su `id`.
  Future<Income> insertIncome(Income income) async {
    final db = await database;
    final map = income.toMap()..remove('id');
    final id = await db.insert(incomesTable, map);
    return income.copyWith(id: id);
  }

  /// Ingresos del más reciente al más antiguo. Con [month] devuelve
  /// solo los de ese mes y año.
  Future<List<Income>> getIncomes({DateTime? month}) async {
    final db = await database;
    final range = month == null ? null : _monthRange(month);
    final rows = await db.query(
      incomesTable,
      where: range == null ? null : 'date >= ? AND date < ?',
      whereArgs: range,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Income.fromMap).toList();
  }

  /// Ingreso con ese [id], o `null` si no existe.
  Future<Income?> getIncome(int id) async {
    final db = await database;
    final rows = await db.query(
      incomesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Income.fromMap(rows.first);
  }

  /// Reemplaza los campos del ingreso guardado. Devuelve cuántas filas
  /// cambiaron (0 si el `id` no existe).
  Future<int> updateIncome(Income income) async {
    final id = _requireId(income.id);
    final db = await database;
    return db.update(
      incomesTable,
      income.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el ingreso. Devuelve cuántas filas se borraron.
  Future<int> deleteIncome(int id) async {
    final db = await database;
    return db.delete(incomesTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Utilidades ───────────────────────────────────────────────

  /// Límites `[inicio, fin)` del mes en el mismo formato ISO que la
  /// columna `date`, para comparar texto con texto.
  static List<String> _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return [start.toIso8601String(), end.toIso8601String()];
  }

  static int _requireId(int? id) {
    if (id == null) {
      throw ArgumentError('No se puede editar un registro sin id.');
    }
    return id;
  }

  /// Cierra la conexión. La siguiente lectura de [database] la reabre.
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }
}
