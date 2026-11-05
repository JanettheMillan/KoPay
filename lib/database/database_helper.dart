import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Acceso único a la base SQLite local de KoPay.
///
/// Crea las tablas `movements`, `incomes` y `settings` la primera vez
/// que se abre. Las operaciones de alta, lectura, edición y borrado
/// se agregan en S1-09.
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
    batch.execute(
      'CREATE INDEX idx_movements_date ON $movementsTable (date)',
    );

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

  /// Cierra la conexión. La siguiente lectura de [database] la reabre.
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }
}
