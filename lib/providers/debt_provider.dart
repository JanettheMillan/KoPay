import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/debt_model.dart';
import '../models/movement_model.dart';
import '../utils/validators.dart';

/// Estado de las deudas para las pantallas (HU-19 a HU-21).
///
/// Cada alta, edición, borrado o pago se guarda en SQLite mediante
/// [DatabaseHelper], después recarga la lista desde la base y avisa a
/// los widgets que escuchan.
///
/// El estado sigue al saldo: una deuda con saldo cero queda pagada y una
/// con saldo mayor que cero queda pendiente. Un pago descuenta su importe
/// del saldo y, si lo deja en cero, liquida la deuda (HU-21).
class DebtProvider extends ChangeNotifier {
  DebtProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<DebtModel> _debts = const [];
  bool _isLoading = false;
  bool _loaded = false;

  /// Deudas de la que vence antes a la que vence después.
  List<DebtModel> get debts => List.unmodifiable(_debts);

  /// Deudas con saldo por pagar.
  List<DebtModel> get pendingDebts =>
      List.unmodifiable(_debts.where((d) => !d.isPaid));

  /// Deudas liquidadas.
  List<DebtModel> get paidDebts =>
      List.unmodifiable(_debts.where((d) => d.isPaid));

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee las deudas guardadas y avisa a la interfaz.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _debts = await _db.getDebts();
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda una deuda nueva y la devuelve con su `id` (HU-19).
  /// Lanza [ValidationException] si la deuda no es válida.
  Future<DebtModel> add(DebtModel debt) async {
    _validate(debt);
    final saved = await _db.insertDebt(_withStatus(debt));
    await _reload();
    return saved;
  }

  /// Guarda los cambios de una deuda existente.
  /// Lanza [ValidationException] si la deuda no es válida.
  Future<void> update(DebtModel debt) async {
    _validate(debt);
    await _db.updateDebt(_withStatus(debt));
    await _reload();
  }

  /// Borra la deuda con ese [id].
  Future<void> delete(int id) async {
    await _db.deleteDebt(id);
    await _reload();
  }

  /// Registra un pago de [amount] a la deuda [debtId] (HU-20).
  ///
  /// Guarda un movimiento de tipo `payment` y descuenta el importe del
  /// saldo restante en una sola transacción. Si el saldo llega a cero, la
  /// deuda pasa a pagada (HU-21). Devuelve el movimiento guardado.
  ///
  /// El pago también es un movimiento: quien lo registra debe recargar
  /// `MovementProvider` para que aparezca en Movimientos.
  ///
  /// Lanza [ValidationException] si el importe no es mayor que cero o
  /// supera el saldo restante, y [ArgumentError] si la deuda no existe.
  /// En esos casos no cambia nada.
  Future<Movement> pay(
    int debtId,
    double amount, {
    DateTime? date,
    String? note,
  }) async {
    final debt = byId(debtId) ?? await _db.getDebt(debtId);
    if (debt == null) {
      throw ArgumentError.value(debtId, 'debtId', 'La deuda no existe');
    }
    final error = Validators.checkDebtPayment(amount, debt.remainingBalance);
    if (error != null) throw ValidationException(error);

    final payment = await _db.insertDebtPayment(
      debtId: debtId,
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
    );
    await _reload();
    return payment;
  }

  /// Pagos registrados a la deuda [debtId], del más reciente al más
  /// antiguo.
  Future<List<Movement>> paymentsOf(int debtId) => _db.getDebtPayments(debtId);

  /// Deuda con ese [id], o `null` si no está en la lista.
  DebtModel? byId(int id) {
    for (final debt in _debts) {
      if (debt.id == id) return debt;
    }
    return null;
  }

  /// Suma de los saldos que faltan por pagar.
  double get totalRemaining =>
      _debts.fold(0.0, (sum, d) => sum + d.remainingBalance);

  /// Suma de las mensualidades de las deudas pendientes.
  double get totalMonthlyPayment => _debts
      .where((d) => !d.isPaid)
      .fold(0.0, (sum, d) => sum + d.monthlyPayment);

  void _validate(DebtModel debt) {
    final error = Validators.checkDebt(debt);
    if (error != null) throw ValidationException(error);
  }

  /// Ajusta el estado al saldo: cero es pagada, más de cero es pendiente.
  static DebtModel _withStatus(DebtModel debt) => debt.copyWith(
    status: (debt.remainingBalance * 100).round() == 0
        ? DebtStatus.paid
        : DebtStatus.pending,
  );

  Future<void> _reload() async {
    _debts = await _db.getDebts();
    _loaded = true;
    notifyListeners();
  }
}
