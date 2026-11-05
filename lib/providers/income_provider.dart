import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/income_model.dart';
import '../utils/validators.dart';

/// Estado de los ingresos para las pantallas.
///
/// Igual que `MovementProvider`: cada alta, edición o borrado se guarda
/// en SQLite mediante [DatabaseHelper], recarga la lista desde la base
/// y avisa a los widgets suscritos con `notifyListeners`.
class IncomeProvider extends ChangeNotifier {
  IncomeProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<Income> _incomes = const [];
  bool _isLoading = false;
  bool _loaded = false;

  /// Todos los ingresos, del más reciente al más antiguo.
  List<Income> get incomes => List.unmodifiable(_incomes);

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee los ingresos guardados y avisa a la interfaz.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _incomes = await _db.getIncomes();
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda un ingreso nuevo y devuelve el registro con su `id`.
  /// Lanza [ValidationException] si el ingreso no es válido.
  Future<Income> add(Income income) async {
    _validate(income);
    final saved = await _db.insertIncome(income);
    await _reload();
    return saved;
  }

  /// Guarda los cambios de un ingreso existente.
  /// Lanza [ValidationException] si el ingreso no es válido.
  Future<void> update(Income income) async {
    _validate(income);
    await _db.updateIncome(income);
    await _reload();
  }

  void _validate(Income income) {
    final error = Validators.checkIncome(income);
    if (error != null) throw ValidationException(error);
  }

  /// Borra el ingreso con ese [id].
  Future<void> delete(int id) async {
    await _db.deleteIncome(id);
    await _reload();
  }

  /// Ingreso con ese [id] en la lista cargada, o `null`.
  Income? byId(int id) {
    for (final income in _incomes) {
      if (income.id == id) return income;
    }
    return null;
  }

  /// Ingresos de un mes, del más reciente al más antiguo.
  List<Income> forMonth(DateTime month) => _incomes
      .where((i) => i.date.year == month.year && i.date.month == month.month)
      .toList();

  /// Suma de ingresos del mes.
  double totalForMonth(DateTime month) =>
      forMonth(month).fold(0.0, (sum, i) => sum + i.amount);

  Future<void> _reload() async {
    _incomes = await _db.getIncomes();
    _loaded = true;
    notifyListeners();
  }
}
