import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/movement_model.dart';
import '../utils/validators.dart';

/// Estado de los movimientos para las pantallas.
///
/// Cada alta, edición o borrado se guarda en SQLite mediante
/// [DatabaseHelper], después recarga la lista desde la base y avisa a
/// los widgets que escuchan con `notifyListeners`.
class MovementProvider extends ChangeNotifier {
  MovementProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<Movement> _movements = const [];
  bool _isLoading = false;
  bool _loaded = false;

  /// Todos los movimientos, del más reciente al más antiguo.
  List<Movement> get movements => List.unmodifiable(_movements);

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee los movimientos guardados y avisa a la interfaz.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _movements = await _db.getMovements();
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda un movimiento nuevo y devuelve el registro con su `id`.
  /// Lanza [ValidationException] si el movimiento no es válido.
  Future<Movement> add(Movement movement) async {
    _validate(movement);
    final saved = await _db.insertMovement(movement);
    await _reload();
    return saved;
  }

  /// Guarda los cambios de un movimiento existente.
  /// Lanza [ValidationException] si el movimiento no es válido.
  Future<void> update(Movement movement) async {
    _validate(movement);
    await _db.updateMovement(movement);
    await _reload();
  }

  void _validate(Movement movement) {
    final error = Validators.checkMovement(movement);
    if (error != null) throw ValidationException(error);
  }

  /// Borra el movimiento con ese [id].
  Future<void> delete(int id) async {
    await _db.deleteMovement(id);
    await _reload();
  }

  /// Movimientos de un mes, del más reciente al más antiguo.
  List<Movement> forMonth(DateTime month) => _movements
      .where((m) => m.date.year == month.year && m.date.month == month.month)
      .toList();

  /// Suma de gastos del mes, en positivo.
  double expensesForMonth(DateTime month) => forMonth(
    month,
  ).where((m) => m.isExpense).fold(0.0, (sum, m) => sum + m.absAmount);

  /// Suma de movimientos positivos (entradas) del mes.
  double entriesForMonth(DateTime month) => forMonth(
    month,
  ).where((m) => !m.isExpense).fold(0.0, (sum, m) => sum + m.amount);

  Future<void> _reload() async {
    _movements = await _db.getMovements();
    _loaded = true;
    notifyListeners();
  }
}
