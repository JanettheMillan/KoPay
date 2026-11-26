import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/card_model.dart';
import '../models/movement_model.dart';
import '../utils/validators.dart';

/// Estado de las tarjetas de crédito para las pantallas (HU-13 a HU-15).
///
/// Cada alta, edición o borrado se guarda en SQLite mediante
/// [DatabaseHelper], después recarga la lista desde la base y avisa a
/// los widgets que escuchan. El crédito disponible se calcula a partir
/// de las tarjetas guardadas, así que siempre refleja el último cambio.
class CardProvider extends ChangeNotifier {
  CardProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  List<CardModel> _cards = const [];
  bool _isLoading = false;
  bool _loaded = false;

  /// Tarjetas en el orden en que se registraron.
  List<CardModel> get cards => List.unmodifiable(_cards);

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee las tarjetas guardadas y avisa a la interfaz.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cards = await _db.getCards();
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda una tarjeta nueva y la devuelve con su `id`.
  /// Lanza [ValidationException] si la tarjeta no es válida.
  Future<CardModel> add(CardModel card) async {
    _validate(card);
    final saved = await _db.insertCard(card);
    await _reload();
    return saved;
  }

  /// Guarda los cambios de una tarjeta existente.
  /// Lanza [ValidationException] si la tarjeta no es válida.
  Future<void> update(CardModel card) async {
    _validate(card);
    await _db.updateCard(card);
    await _reload();
  }

  /// Borra la tarjeta con ese [id].
  Future<void> delete(int id) async {
    await _db.deleteCard(id);
    await _reload();
  }

  /// Registra un pago de [amount] a la tarjeta [cardId] (HU-16).
  ///
  /// Guarda un movimiento de tipo `payment` y descuenta el importe del
  /// saldo usado en una sola transacción, así que sube el crédito
  /// disponible. Devuelve el movimiento guardado.
  ///
  /// El pago también es un movimiento: quien lo registra debe recargar
  /// `MovementProvider` para que aparezca en Movimientos.
  ///
  /// Lanza [ValidationException] si el importe no es mayor que cero o
  /// supera el saldo usado (HU-17), y [ArgumentError] si la tarjeta no
  /// existe. En esos casos no cambia nada.
  Future<Movement> pay(
    int cardId,
    double amount, {
    DateTime? date,
    String? note,
  }) async {
    final card = byId(cardId);
    if (card == null) {
      throw ArgumentError.value(cardId, 'cardId', 'La tarjeta no existe');
    }
    final error = Validators.checkCardPayment(amount, card.usedBalance);
    if (error != null) throw ValidationException(error);

    final payment = await _db.insertCardPayment(
      cardId: cardId,
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
    );
    await _reload();
    return payment;
  }

  /// Anula el pago [paymentId] de la tarjeta (D-10).
  ///
  /// Borra el movimiento de tipo `payment` y devuelve su importe al saldo
  /// usado en una sola transacción, así que baja el crédito disponible.
  /// Después recarga las tarjetas. El pago también es un movimiento: quien
  /// lo anula debe recargar `MovementProvider`.
  ///
  /// Lanza [ArgumentError] si el pago no existe o ya no está ligado a su
  /// tarjeta. En ese caso no cambia nada.
  Future<void> cancelPayment(int paymentId) async {
    await _db.cancelPayment(paymentId);
    await _reload();
  }

  /// Pagos registrados a la tarjeta [cardId], del más reciente al más
  /// antiguo.
  Future<List<Movement>> paymentsOf(int cardId) => _db.getCardPayments(cardId);

  /// Tarjeta con ese [id], o `null` si no está en la lista.
  CardModel? byId(int id) {
    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// Suma de los límites de crédito.
  double get totalLimit => _cards.fold(0.0, (sum, c) => sum + c.creditLimit);

  /// Suma de los saldos usados.
  double get totalUsed => _cards.fold(0.0, (sum, c) => sum + c.usedBalance);

  /// Suma del crédito disponible de cada tarjeta. Una tarjeta excedida
  /// aporta cero, no resta del disponible de las demás.
  double get totalAvailable => _cards.fold(0.0, (sum, c) => sum + c.available);

  void _validate(CardModel card) {
    final error = Validators.checkCard(card);
    if (error != null) throw ValidationException(error);
  }

  Future<void> _reload() async {
    _cards = await _db.getCards();
    _loaded = true;
    notifyListeners();
  }
}
