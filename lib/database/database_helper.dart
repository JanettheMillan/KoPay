import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/card_model.dart';
import '../models/debt_model.dart';
import '../models/income_model.dart';
import '../models/movement_model.dart';

/// Acceso único a la base SQLite local de KoPay.
///
/// Crea las tablas `movements`, `incomes`, `cards`, `debts` y `settings`
/// la primera vez que se abre y ofrece alta, lectura, edición y borrado
/// de movimientos, ingresos, tarjetas y deudas. Las listas se devuelven de la fecha más reciente a la
/// más antigua.
class DatabaseHelper {
  static const String fileName = 'kopay.db';

  /// 1: movimientos, ingresos y ajustes (S1-08).
  /// 2: tarjetas (S2-07).
  /// 3: deudas (S2-08).
  /// 4: pagos asociados a tarjetas y deudas en `movements` (S2-09).
  static const int version = 4;

  static const String movementsTable = 'movements';
  static const String incomesTable = 'incomes';
  static const String settingsTable = 'settings';
  static const String cardsTable = 'cards';
  static const String debtsTable = 'debts';

  /// Categoría con la que se guardan los pagos de tarjeta y de deuda.
  static const String paymentCategory = 'Pago';

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
      options: OpenDatabaseOptions(
        version: version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
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
    _addPaymentColumns(batch);

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

    _createCardsTable(batch);
    _createDebtsTable(batch);

    await batch.commit(noResult: true);
  }

  /// Migra una base creada con una versión anterior sin borrar datos.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();
    if (oldVersion < 2) _createCardsTable(batch);
    if (oldVersion < 3) _createDebtsTable(batch);
    if (oldVersion < 4) _addPaymentColumns(batch);
    await batch.commit(noResult: true);
  }

  /// Tabla de tarjetas (S2-07). Los importes no pueden ser negativos y
  /// los días de corte y pago van del 1 al 31.
  static void _createCardsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        bank TEXT NOT NULL,
        credit_limit REAL NOT NULL CHECK (credit_limit >= 0),
        used_balance REAL NOT NULL CHECK (used_balance >= 0),
        cut_day INTEGER NOT NULL CHECK (cut_day BETWEEN 1 AND 31),
        payment_day INTEGER NOT NULL CHECK (payment_day BETWEEN 1 AND 31),
        minimum_payment REAL NOT NULL DEFAULT 0 CHECK (minimum_payment >= 0)
      )
    ''');
  }

  /// Tabla de deudas (S2-08). Los importes no pueden ser negativos, la
  /// fecha va en texto ISO 8601 y el estado es `pending` o `paid`.
  static void _createDebtsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE $debtsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        monthly_payment REAL NOT NULL CHECK (monthly_payment >= 0),
        remaining_balance REAL NOT NULL CHECK (remaining_balance >= 0),
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'paid'))
      )
    ''');
    batch.execute('CREATE INDEX idx_debts_due_date ON $debtsTable (due_date)');
  }

  /// Columnas de `movements` que asocian un pago con su tarjeta o deuda
  /// (S2-09). Los movimientos que ya existían quedan como `regular`.
  static void _addPaymentColumns(Batch batch) {
    batch.execute(
      "ALTER TABLE $movementsTable ADD COLUMN type TEXT NOT NULL "
      "DEFAULT 'regular' CHECK (type IN ('regular', 'payment'))",
    );
    batch.execute('ALTER TABLE $movementsTable ADD COLUMN card_id INTEGER');
    batch.execute('ALTER TABLE $movementsTable ADD COLUMN debt_id INTEGER');
    batch.execute(
      'CREATE INDEX idx_movements_card ON $movementsTable (card_id)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_debt ON $movementsTable (debt_id)',
    );
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

  // ── Tarjetas ─────────────────────────────────────────────────

  /// Guarda una tarjeta nueva y la devuelve con su `id`.
  Future<CardModel> insertCard(CardModel card) async {
    final db = await database;
    final id = await db.insert(cardsTable, card.toMap()..remove('id'));
    return card.copyWith(id: id);
  }

  /// Tarjetas en el orden en que se registraron.
  Future<List<CardModel>> getCards() async {
    final db = await database;
    final rows = await db.query(cardsTable, orderBy: 'id ASC');
    return rows.map(CardModel.fromMap).toList();
  }

  /// Tarjeta con ese [id], o `null` si no existe.
  Future<CardModel?> getCard(int id) async {
    final db = await database;
    final rows = await db.query(
      cardsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CardModel.fromMap(rows.first);
  }

  /// Reemplaza los campos de la tarjeta guardada. Devuelve cuántas filas
  /// cambiaron (0 si el `id` no existe).
  Future<int> updateCard(CardModel card) async {
    final id = _requireId(card.id);
    final db = await database;
    return db.update(
      cardsTable,
      card.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra la tarjeta. Devuelve cuántas filas se borraron.
  Future<int> deleteCard(int id) async {
    final db = await database;
    return db.delete(cardsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Deudas ───────────────────────────────────────────────────

  /// Guarda una deuda nueva y la devuelve con su `id`.
  Future<DebtModel> insertDebt(DebtModel debt) async {
    final db = await database;
    final id = await db.insert(debtsTable, debt.toMap()..remove('id'));
    return debt.copyWith(id: id);
  }

  /// Deudas de la que vence antes a la que vence después.
  Future<List<DebtModel>> getDebts() async {
    final db = await database;
    final rows = await db.query(debtsTable, orderBy: 'due_date ASC, id ASC');
    return rows.map(DebtModel.fromMap).toList();
  }

  /// Deuda con ese [id], o `null` si no existe.
  Future<DebtModel?> getDebt(int id) async {
    final db = await database;
    final rows = await db.query(
      debtsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : DebtModel.fromMap(rows.first);
  }

  /// Reemplaza los campos de la deuda guardada. Devuelve cuántas filas
  /// cambiaron (0 si el `id` no existe).
  Future<int> updateDebt(DebtModel debt) async {
    final id = _requireId(debt.id);
    final db = await database;
    return db.update(
      debtsTable,
      debt.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra la deuda. Devuelve cuántas filas se borraron.
  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.delete(debtsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ── Pagos (S2-09) ────────────────────────────────────────────

  /// Registra un pago de [amount] a la tarjeta [cardId] (HU-16): guarda
  /// un movimiento de tipo `payment` asociado a la tarjeta y descuenta el
  /// importe de su saldo usado, todo en una sola transacción.
  ///
  /// Lanza [ArgumentError] si el importe no es positivo, si la tarjeta no
  /// existe o si el pago supera el saldo usado. En ese caso no cambia
  /// nada.
  Future<Movement> insertCardPayment({
    required int cardId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    _requirePositive(amount);
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        cardsTable,
        where: 'id = ?',
        whereArgs: [cardId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError.value(cardId, 'cardId', 'La tarjeta no existe');
      }
      final card = CardModel.fromMap(rows.first);
      // En centavos enteros: con double, 0.30 - 0.10 da 0.1999… (D-06).
      final paid = _cents(amount);
      final used = _cents(card.usedBalance);
      if (paid > used) {
        throw ArgumentError.value(
          amount,
          'amount',
          'El pago supera el saldo usado de la tarjeta',
        );
      }

      final payment = Movement(
        amount: -paid / 100,
        description: 'Pago ${card.name}',
        category: paymentCategory,
        date: date,
        note: note,
        type: MovementType.payment,
        cardId: cardId,
      );
      final id = await txn.insert(
        movementsTable,
        payment.toMap()..remove('id'),
      );
      await txn.update(
        cardsTable,
        {'used_balance': (used - paid) / 100},
        where: 'id = ?',
        whereArgs: [cardId],
      );
      return payment.copyWith(id: id);
    });
  }

  /// Registra un pago de [amount] a la deuda [debtId] (HU-20): guarda un
  /// movimiento de tipo `payment` asociado a la deuda y descuenta el
  /// importe del saldo restante, todo en una sola transacción. Si el
  /// saldo llega a cero, la deuda pasa a pagada (HU-21).
  ///
  /// Lanza [ArgumentError] si el importe no es positivo, si la deuda no
  /// existe o si el pago supera el saldo restante. En ese caso no cambia
  /// nada.
  Future<Movement> insertDebtPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    _requirePositive(amount);
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        debtsTable,
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError.value(debtId, 'debtId', 'La deuda no existe');
      }
      final debt = DebtModel.fromMap(rows.first);
      final paid = _cents(amount);
      final balance = _cents(debt.remainingBalance);
      if (paid > balance) {
        throw ArgumentError.value(
          amount,
          'amount',
          'El pago supera el saldo restante de la deuda',
        );
      }

      final payment = Movement(
        amount: -paid / 100,
        description: 'Pago ${debt.name}',
        category: paymentCategory,
        date: date,
        note: note,
        type: MovementType.payment,
        debtId: debtId,
      );
      final id = await txn.insert(
        movementsTable,
        payment.toMap()..remove('id'),
      );
      final remaining = balance - paid;
      await txn.update(
        debtsTable,
        {
          'remaining_balance': remaining / 100,
          if (remaining == 0) 'status': DebtStatus.paid.name,
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
      return payment.copyWith(id: id);
    });
  }

  /// Pagos asociados a la tarjeta [cardId], del más reciente al más
  /// antiguo.
  Future<List<Movement>> getCardPayments(int cardId) =>
      _payments('card_id', cardId);

  /// Pagos asociados a la deuda [debtId], del más reciente al más
  /// antiguo.
  Future<List<Movement>> getDebtPayments(int debtId) =>
      _payments('debt_id', debtId);

  Future<List<Movement>> _payments(String column, int id) async {
    final db = await database;
    final rows = await db.query(
      movementsTable,
      where: "type = 'payment' AND $column = ?",
      whereArgs: [id],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Movement.fromMap).toList();
  }

  // ── Ajustes ──────────────────────────────────────────────────

  /// Valor guardado en `settings` para [key], o `null` si no existe.
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  /// Guarda [value] en `settings`; reemplaza el valor anterior de [key].
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(settingsTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Respaldo ─────────────────────────────────────────────────

  /// Reemplaza todos los movimientos e ingresos por [movements] e
  /// [incomes] en una sola transacción (HU-27). Si algo falla, SQLite
  /// revierte y quedan los datos anteriores. Los `id` de los registros
  /// nuevos los asigna la base.
  Future<void> replaceFinancialData(
    List<Movement> movements,
    List<Income> incomes,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(movementsTable);
      await txn.delete(incomesTable);
      for (final m in movements) {
        await txn.insert(movementsTable, m.toMap()..remove('id'));
      }
      for (final i in incomes) {
        await txn.insert(incomesTable, i.toMap()..remove('id'));
      }
    });
  }

  // ── Borrado de datos (HU-28) ─────────────────────────────────

  /// Tablas con datos financieros del usuario. Todas se borran juntas.
  static const List<String> financialTables = [
    movementsTable,
    incomesTable,
    cardsTable,
    debtsTable,
  ];

  /// Borra todos los registros de [financialTables] en una sola
  /// transacción: si una tabla falla, no se borra ninguna. Conserva
  /// `settings` (categorías, moneda e idioma).
  Future<void> deleteFinancialData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in financialTables) {
        await txn.delete(table);
      }
    });
  }

  // ── Utilidades ───────────────────────────────────────────────

  /// Límites `[inicio, fin)` del mes en el mismo formato ISO que la
  /// columna `date`, para comparar texto con texto.
  static List<String> _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return [start.toIso8601String(), end.toIso8601String()];
  }

  /// Importe en centavos enteros, para sumar y comparar sin el error de
  /// redondeo de `double` (D-06).
  static int _cents(double amount) => (amount * 100).round();

  /// Rechaza importes que no llegan a un centavo.
  static void _requirePositive(double amount) {
    if (!amount.isFinite || _cents(amount) <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Debe ser mayor que cero');
    }
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
