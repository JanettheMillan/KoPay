import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/income_model.dart';
import '../services/auth_api.dart';
import '../services/incomes_api.dart';
import '../utils/validators.dart';
import 'session_provider.dart';

/// Estado de los ingresos para las pantallas.
///
/// **Sin sesión** cada alta, edición o borrado se guarda en SQLite mediante
/// [DatabaseHelper], como en los Sprints 1 y 2.
///
/// **Con sesión de usuario** (S5-08, HU-02 y HU-09) los ingresos se leen y
/// guardan en la API (`/api/incomes`, contrato §3.13), igual que los
/// movimientos en `MovementProvider` (S5-07), y SQLite queda como copia
/// para verlos sin red:
/// - Al iniciar sesión sube los ingresos que solo existían en el teléfono
///   y después reemplaza la copia por los de la cuenta, así Inicio no los
///   cuenta dos veces.
/// - Al cerrar sesión o cambiar de cuenta borra la copia de la anterior
///   (HU-34).
/// - Sin red, la lista sigue mostrando la copia ([offline]) y guardar
///   lanza [NetworkException]. La cola sin red y los conflictos entre
///   dispositivos son de la sincronización (S5-19, #105).
///
/// Los errores de la API llegan como [ApiException] o [NetworkException]
/// para que la pantalla muestre su mensaje.
class IncomeProvider extends ChangeNotifier {
  IncomeProvider({DatabaseHelper? database, IncomesApi? api})
    : _db = database ?? DatabaseHelper.instance,
      _api = api;

  final DatabaseHelper _db;
  final IncomesApi? _api;

  List<Income> _incomes = const [];
  bool _isLoading = false;
  bool _loaded = false;
  bool _offline = false;

  SessionProvider? _session;

  /// Cuenta cuya copia está en el teléfono, o `null` sin sesión.
  String? _accountId;
  Future<void>? _syncing;

  /// Todos los ingresos, del más reciente al más antiguo.
  List<Income> get incomes => List.unmodifiable(_incomes);

  /// `true` mientras se lee la base.
  bool get isLoading => _isLoading;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// `true` si con sesión la última lectura de la API falló por red o
  /// porque no respondía: la lista es la copia guardada.
  bool get offline => _offline;

  /// `true` si los ingresos se guardan en la API.
  bool get isRemote => _api != null && _accountId != null && _session != null;

  /// Conecta la sesión (lo hace `main.dart` con un `ProxyProvider`). Al
  /// iniciar sesión con una cuenta de usuario trae sus ingresos; al
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

  /// Lee los ingresos guardados y avisa a la interfaz. Con sesión, además
  /// los trae de la API.
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
    if (isRemote) await sync();
  }

  /// Con sesión: sube los ingresos que solo están en el teléfono y
  /// reemplaza la copia por los de la cuenta. Sin red conserva la copia y
  /// prende [offline]. Si ya hay una sincronización en curso, espera esa.
  Future<void> sync() =>
      _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (!isRemote) return;
    final account = _accountId;
    try {
      for (final local in await _db.getLocalOnlyIncomes()) {
        // Se cambió de cuenta a media subida: no seguir con la anterior
        // (nota de Rubén en #210, anotada en #105) y sincronizar la nueva,
        // que esperaba a esta.
        if (account != _accountId) return await _sync();
        final RemoteIncome created;
        try {
          created = await _authorized((t) => _api!.create(t, local));
        } on ApiException catch (e) {
          // 400: un ingreso viejo que no cumple las reglas de la API (por
          // ejemplo, un nombre de más de 60 caracteres) se queda en el
          // teléfono.
          if (e.status == 400) continue;
          rethrow;
        }
        await _db.setIncomeRemote(
          local.id!,
          remoteId: created.remoteId,
          version: created.version,
        );
      }
      final remote = await _authorized(_api!.list);
      // La sesión cambió mientras se leía: no mezclar cuentas.
      if (account != _accountId) return await _sync();
      await _db.replaceRemoteIncomes(remote);
      _offline = false;
    } on NetworkException {
      _offline = true;
    } on ApiException catch (e) {
      // 401: la sesión ya se cerró y bindSession limpia la copia.
      if (e.status != 401) _offline = true;
    }
    await _reload();
  }

  /// Guarda un ingreso nuevo y devuelve el registro con su `id` local.
  /// Lanza [ValidationException] si no es válido; con sesión también
  /// [ApiException] o [NetworkException].
  Future<Income> add(Income income) async {
    _validate(income);
    if (!isRemote) {
      final saved = await _db.insertIncome(income);
      await _reload();
      return saved;
    }
    final created = await _authorized((t) => _api!.create(t, income));
    final saved = await _db.insertIncome(created.income);
    await _db.setIncomeRemote(
      saved.id!,
      remoteId: created.remoteId,
      version: created.version,
    );
    await _reload();
    return saved;
  }

  /// Guarda los cambios de un ingreso existente.
  /// Lanza [ValidationException] si no es válido; con sesión también
  /// [ApiException] (`409 VERSION_CONFLICT` si cambió en otro dispositivo;
  /// entonces recarga la lista) o [NetworkException].
  Future<void> update(Income income) async {
    _validate(income);
    final link = isRemote && income.id != null
        ? await _db.getIncomeRemote(income.id!)
        : null;
    if (link == null) {
      await _db.updateIncome(income);
      await _reload();
      return;
    }
    try {
      final updated = await _authorized(
        (t) => _api!.update(t, link.remoteId, income, version: link.version),
      );
      await _db.updateIncome(income);
      await _db.setIncomeRemote(
        income.id!,
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

  void _validate(Income income) {
    final error = Validators.checkIncome(income);
    if (error != null) throw ValidationException(error);
  }

  /// Borra el ingreso con ese [id]. Con sesión lo borra en la API; si ya
  /// no existía allá, también se quita del teléfono.
  Future<void> delete(int id) async {
    final link = isRemote ? await _db.getIncomeRemote(id) : null;
    if (link != null) {
      try {
        await _authorized((t) => _api!.delete(t, link.remoteId));
      } on ApiException catch (e) {
        if (e.status != 404) rethrow;
      }
    }
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

  Future<T> _authorized<T>(Future<T> Function(String token) call) =>
      _session!.authorized(call);

  Future<void> _clearRemoteCopy() async {
    await _db.clearRemoteIncomes();
    _offline = false;
    await _reload();
  }

  Future<void> _reload() async {
    _incomes = await _db.getIncomes();
    _loaded = true;
    notifyListeners();
  }
}
