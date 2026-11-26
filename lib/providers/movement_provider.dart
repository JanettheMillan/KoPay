import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/movement_model.dart';
import '../services/auth_api.dart';
import '../services/movements_api.dart';
import '../utils/validators.dart';
import 'session_provider.dart';

/// Estado de los movimientos para las pantallas.
///
/// **Sin sesión** cada alta, edición o borrado se guarda en SQLite mediante
/// [DatabaseHelper], como en los Sprints 1 y 2.
///
/// **Con sesión de usuario** (S5-07, HU-01, HU-05 y HU-06) los movimientos
/// se leen y guardan en la API (`/api/movements`, contrato §3.12) con el
/// token de [SessionProvider], y SQLite queda como copia para verlos sin
/// red:
/// - Al iniciar sesión sube los movimientos que solo existían en el
///   teléfono, para no perderlos, y después trae los de la cuenta.
/// - Al cerrar sesión o cambiar de cuenta borra la copia de la cuenta
///   anterior, para que otra persona en el mismo teléfono no la vea.
/// - Sin red, la lista sigue mostrando la copia ([offline]) y guardar
///   lanza [NetworkException]. La cola sin red y los conflictos entre
///   dispositivos son de la sincronización (S5-19, #105).
/// - Los pagos se leen pero no se crean, cambian ni borran por la API: se
///   manejan desde su tarjeta o deuda (S5-05). Hasta entonces siguen solo
///   en el teléfono.
///
/// Los errores de la API llegan como [ApiException] o [NetworkException]
/// para que la pantalla muestre su mensaje.
class MovementProvider extends ChangeNotifier {
  MovementProvider({DatabaseHelper? database, MovementsApi? api})
    : _db = database ?? DatabaseHelper.instance,
      _api = api;

  final DatabaseHelper _db;
  final MovementsApi? _api;

  List<Movement> _movements = const [];
  bool _isLoading = false;
  bool _loaded = false;
  bool _offline = false;

  SessionProvider? _session;

  /// Cuenta cuya copia está en el teléfono, o `null` sin sesión.
  String? _accountId;
  Future<void>? _syncing;

  /// Todos los movimientos, del más reciente al más antiguo.
  List<Movement> get movements => List.unmodifiable(_movements);

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// `true` si con sesión la última lectura de la API falló por red o
  /// porque no respondía: la lista es la copia guardada.
  bool get offline => _offline;

  /// `true` si los movimientos se guardan en la API.
  bool get isRemote => _api != null && _accountId != null && _session != null;

  /// Conecta la sesión (lo hace `main.dart` con un `ProxyProvider`). Al
  /// iniciar sesión con una cuenta de usuario trae sus movimientos; al
  /// cerrarla o cambiar de cuenta borra la copia de la anterior.
  void bindSession(SessionProvider? session) {
    _session = session;
    final user = session?.isSignedIn == true ? session!.user : null;
    final accountId = user != null && !user.isAccountant ? user.id : null;
    if (accountId == _accountId) return;
    final previous = _accountId;
    _accountId = accountId;
    // Fuera del build del ProxyProvider: avisar aquí lanzaría un error.
    scheduleMicrotask(() async {
      if (previous != null) await _clearRemoteCopy();
      if (accountId != null && _api != null) await sync();
    });
  }

  /// Lee los movimientos guardados y avisa a la interfaz. Con sesión,
  /// además los trae de la API.
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
    if (isRemote) await sync();
  }

  /// Con sesión: sube los movimientos que solo están en el teléfono y
  /// reemplaza la copia por los de la cuenta. Sin red conserva la copia y
  /// prende [offline]. Si ya hay una sincronización en curso, espera esa.
  Future<void> sync() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (!isRemote) return;
    final account = _accountId;
    try {
      for (final local in await _db.getLocalOnlyMovements()) {
        // Se cambió de cuenta a media subida: no seguir con la anterior
        // (nota de Rubén en #210 y #212) y sincronizar la nueva, que
        // esperaba a esta.
        if (account != _accountId) return await _sync();
        final RemoteMovement created;
        try {
          created = await _authorized((t) => _api!.create(t, local));
        } on ApiException catch (e) {
          // 400: un movimiento viejo que no cumple las reglas de la API
          // (por ejemplo, una descripción larga) se queda en el teléfono.
          if (e.status == 400) continue;
          rethrow;
        }
        await _db.setMovementRemote(
          local.id!,
          remoteId: created.remoteId,
          version: created.version,
        );
      }
      final remote = await _authorized(_api!.list);
      // La sesión cambió mientras se leía: no mezclar cuentas.
      if (account != _accountId) return await _sync();
      await _db.replaceRemoteMovements(
        remote.where((r) => !r.movement.isPayment).toList(),
      );
      _offline = false;
    } on NetworkException {
      _offline = true;
    } on ApiException catch (e) {
      // 401: la sesión ya se cerró y bindSession limpia la copia.
      if (e.status != 401) _offline = true;
    }
    await _reload();
  }

  /// Guarda un movimiento nuevo y devuelve el registro con su `id` local.
  /// Lanza [ValidationException] si no es válido; con sesión también
  /// [ApiException] o [NetworkException].
  Future<Movement> add(Movement movement) async {
    _validate(movement);
    if (!isRemote || movement.isPayment) {
      final saved = await _db.insertMovement(movement);
      await _reload();
      return saved;
    }
    final created = await _authorized((t) => _api!.create(t, movement));
    final saved = await _db.insertMovement(
      created.movement.copyWith(note: movement.note),
    );
    await _db.setMovementRemote(
      saved.id!,
      remoteId: created.remoteId,
      version: created.version,
    );
    await _reload();
    return saved;
  }

  /// Guarda los cambios de un movimiento existente.
  /// Lanza [ValidationException] si no es válido; con sesión también
  /// [ApiException] (`409 VERSION_CONFLICT` si cambió en otro dispositivo;
  /// entonces recarga la lista) o [NetworkException].
  Future<void> update(Movement movement) async {
    _validate(movement);
    final link = isRemote && !movement.isPayment && movement.id != null
        ? await _db.getMovementRemote(movement.id!)
        : null;
    if (link == null) {
      await _db.updateMovement(movement);
      await _reload();
      return;
    }
    try {
      final updated = await _authorized(
        (t) => _api!.update(t, link.remoteId, movement, version: link.version),
      );
      await _db.updateMovement(movement);
      await _db.setMovementRemote(
        movement.id!,
        remoteId: updated.remoteId,
        version: updated.version,
      );
      await _reload();
    } on ApiException catch (e) {
      // Cambió o se borró en otro dispositivo: mostrar lo que hay ahora.
      if (e.status == 409 || e.status == 404) await sync();
      rethrow;
    }
  }

  void _validate(Movement movement) {
    final error = Validators.checkMovement(movement);
    if (error != null) throw ValidationException(error);
  }

  /// Borra el movimiento con ese [id]. Con sesión lo borra en la API; si
  /// ya no existía allá, también se quita del teléfono.
  Future<void> delete(int id) async {
    final link = isRemote ? await _db.getMovementRemote(id) : null;
    if (link != null) {
      try {
        await _authorized((t) => _api!.delete(t, link.remoteId));
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }
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

  Future<T> _authorized<T>(Future<T> Function(String token) call) =>
      _session!.authorized(call);

  Future<void> _clearRemoteCopy() async {
    await _db.clearRemoteMovements();
    _offline = false;
    await _reload();
  }

  Future<void> _reload() async {
    _movements = await _db.getMovements();
    _loaded = true;
    notifyListeners();
  }
}
