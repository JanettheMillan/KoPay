import 'package:flutter/foundation.dart';

import '../services/auth_api.dart';
import '../services/session_store.dart';

/// Estado de la sesión para la navegación (S3-12) y las pantallas.
enum SessionStatus {
  /// Todavía no se leyó la sesión guardada (Splash).
  unknown,

  /// No hay sesión: se abre Iniciar sesión.
  signedOut,

  /// Hay sesión: se abre la vista del rol (HU-37).
  signedIn,
}

/// Conserva y renueva la sesión (S4-08, HU-31 y HU-33), según
/// docs/contrato-api-acceso.md §2, §3.3, §3.4 y §3.5.
///
/// - Al abrir la app, [restore] lee la sesión guardada y la confirma con
///   `GET /api/auth/me`.
/// - [authorized] hace una petición con el token de acceso. Si ya venció o
///   la API responde `401 UNAUTHENTICATED`, renueva con el `refreshToken`
///   (rotación) y repite la petición una sola vez.
/// - Si la sesión ya no se puede renovar, la borra y vuelve a Iniciar
///   sesión con [sessionExpired] en `true`.
/// - Sin red o con la API caída **no** borra la sesión guardada (§2).
///
/// Si varias peticiones encuentran el token vencido a la vez, se hace una
/// sola renovación y todas esperan la misma: con la rotación, una segunda
/// renovación con el mismo `refreshToken` respondería `401` y cerraría la
/// sesión.
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required AuthApi api,
    required SessionStore store,
    DateTime Function()? now,
  }) : _api = api,
       _store = store,
       _now = now ?? DateTime.now;

  final AuthApi _api;
  final SessionStore _store;
  final DateTime Function() _now;

  SessionStatus _status = SessionStatus.unknown;
  StoredSession? _session;
  bool _sessionExpired = false;
  bool _offline = false;
  Future<StoredSession>? _refreshing;

  SessionStatus get status => _status;
  bool get isSignedIn => _status == SessionStatus.signedIn;

  /// Cuenta de la sesión, o `null` sin sesión.
  AuthUser? get user => _session?.user;

  /// `true` si se volvió a Iniciar sesión porque la sesión venció o se
  /// cerró en otro lado (cambio de contraseña, HU-32). La pantalla puede
  /// avisarlo. Se apaga al iniciar sesión otra vez.
  bool get sessionExpired => _sessionExpired;

  /// `true` si la sesión guardada no se pudo confirmar por falta de red o
  /// porque la API no respondía. Se sigue usando la cuenta guardada.
  bool get offline => _offline;

  /// Lee la sesión guardada al abrir la app y la confirma con `me`.
  Future<void> restore() async {
    _session = await _store.read();
    if (_session == null) {
      _setStatus(SessionStatus.signedOut);
      return;
    }
    try {
      final user = await authorized(_api.me);
      await _save(_session!.withUser(user));
      _offline = false;
      _setStatus(SessionStatus.signedIn);
    } on ApiException catch (e) {
      if (_session == null) return; // authorized ya cerró la sesión.
      // 500 o 503: la API no pudo responder; se conserva la sesión.
      _markOffline(e);
    } on NetworkException catch (e) {
      if (_session == null) return;
      _markOffline(e);
    }
  }

  /// Inicia sesión y la guarda (§3.2). Lanza [ApiException] o
  /// [NetworkException] sin cambiar la sesión actual.
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final session = await _api.login(email: email, password: password);
    await _save(StoredSession.fromAuthSession(session, _now()));
    _sessionExpired = false;
    _offline = false;
    _setStatus(SessionStatus.signedIn);
    return session.user;
  }

  /// Cierra la sesión (§3.4). Primero la borra del dispositivo y después
  /// avisa a la API; si la API no responde, la sesión queda cerrada igual.
  Future<void> logout() async {
    final token = _session?.accessToken;
    await _store.clear();
    _session = null;
    _sessionExpired = false;
    _offline = false;
    _setStatus(SessionStatus.signedOut);
    if (token == null) return;
    try {
      await _api.logout(token);
    } catch (_) {
      // Sin red o error de la API: para la persona la sesión ya se cerró.
    }
  }

  /// Hace [call] con el token de acceso vigente. Renueva la sesión si el
  /// token venció o la API responde `401 UNAUTHENTICATED`, y repite [call]
  /// una vez. Si no se puede renovar, cierra la sesión y lanza
  /// [ApiException] `UNAUTHENTICATED`.
  Future<T> authorized<T>(Future<T> Function(String accessToken) call) async {
    var session = _session;
    if (session == null) throw _unauthenticated();
    if (session.accessExpired(_now())) session = await _refresh(session);

    try {
      return await call(session.accessToken);
    } on ApiException catch (e) {
      if (!_isUnauthenticated(e)) rethrow;
      final renewed = await _refresh(session);
      try {
        return await call(renewed.accessToken);
      } on ApiException catch (again) {
        if (_isUnauthenticated(again)) await _expire();
        rethrow;
      }
    }
  }

  /// Renueva la sesión una sola vez aunque la pidan varias peticiones. Si
  /// otra ya la renovó después de que [failed] falló, usa la nueva.
  Future<StoredSession> _refresh(StoredSession failed) {
    final current = _session;
    if (current != null && current.accessToken != failed.accessToken) {
      return Future.value(current);
    }
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<StoredSession> _doRefresh() async {
    final session = _session;
    if (session == null || !session.canRefresh(_now())) {
      await _expire();
      throw _unauthenticated();
    }
    final AuthSession renewed;
    try {
      renewed = await _api.refresh(session.refreshToken!);
    } on ApiException catch (e) {
      // 401: venció, ya se usó o la sesión se cerró (§3.5).
      if (e.status == 401) await _expire();
      rethrow;
    }
    final stored = StoredSession.fromAuthSession(renewed, _now());
    await _save(stored);
    notifyListeners();
    return stored;
  }

  Future<void> _save(StoredSession session) async {
    _session = session;
    await _store.write(session);
  }

  /// La sesión ya no sirve: se borra y se vuelve a Iniciar sesión (§2).
  Future<void> _expire() async {
    if (_session == null && _status == SessionStatus.signedOut) return;
    await _store.clear();
    _session = null;
    _sessionExpired = true;
    _offline = false;
    _setStatus(SessionStatus.signedOut);
  }

  void _markOffline(Object _) {
    _offline = true;
    _setStatus(SessionStatus.signedIn);
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  static bool _isUnauthenticated(ApiException e) =>
      e.status == 401 && e.code == ApiErrorCode.unauthenticated;

  static ApiException _unauthenticated() => const ApiException(
    401,
    ApiErrorCode.unauthenticated,
    'Inicia sesión para continuar',
  );
}
