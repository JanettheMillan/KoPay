import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

/// Sesión guardada en el dispositivo (S4-08, HU-31): los tokens, cuándo
/// vencen y la cuenta, para abrir la app sin volver a iniciar sesión.
class StoredSession {
  final String accessToken;

  /// Hora en que vence [accessToken] (`expiresIn` del login).
  final DateTime accessExpiresAt;

  /// `null` si la API no lo mandó (antes de S4-02).
  final String? refreshToken;
  final DateTime? refreshExpiresAt;
  final AuthUser user;

  const StoredSession({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.user,
    this.refreshToken,
    this.refreshExpiresAt,
  });

  /// Arma la sesión a guardar a partir de la respuesta del login o de la
  /// renovación, recibida en [receivedAt].
  factory StoredSession.fromAuthSession(
    AuthSession session,
    DateTime receivedAt,
  ) => StoredSession(
    accessToken: session.accessToken,
    accessExpiresAt: receivedAt.add(Duration(seconds: session.expiresIn)),
    refreshToken: session.refreshToken,
    refreshExpiresAt: session.refreshExpiresIn == null
        ? null
        : receivedAt.add(Duration(seconds: session.refreshExpiresIn!)),
    user: session.user,
  );

  /// `true` si [accessToken] ya venció en [now].
  bool accessExpired(DateTime now) => !now.isBefore(accessExpiresAt);

  /// `true` si todavía se puede renovar en [now].
  bool canRefresh(DateTime now) =>
      refreshToken != null &&
      (refreshExpiresAt == null || now.isBefore(refreshExpiresAt!));

  /// Copia con la cuenta actualizada (por ejemplo, después de `me`).
  StoredSession withUser(AuthUser user) => StoredSession(
    accessToken: accessToken,
    accessExpiresAt: accessExpiresAt,
    refreshToken: refreshToken,
    refreshExpiresAt: refreshExpiresAt,
    user: user,
  );

  Map<String, dynamic> toMap() => {
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt?.toUtc().toIso8601String(),
    'user': user.toMap(),
  };

  factory StoredSession.fromMap(Map<String, dynamic> map) => StoredSession(
    accessToken: map['accessToken'] as String,
    accessExpiresAt: DateTime.parse(map['accessExpiresAt'] as String),
    refreshToken: map['refreshToken'] as String?,
    refreshExpiresAt: map['refreshExpiresAt'] == null
        ? null
        : DateTime.parse(map['refreshExpiresAt'] as String),
    user: AuthUser.fromMap(map['user'] as Map<String, dynamic>),
  );

  @override
  String toString() => 'StoredSession(${user.email})';
}

/// Dónde se guarda la sesión. La app usa [SecureSessionStore]; las
/// pruebas, [MemorySessionStore].
abstract class SessionStore {
  /// Sesión guardada, o `null` si no hay o no se puede leer.
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  Future<void> clear();
}

/// Guarda la sesión cifrada con `flutter_secure_storage` (autorizado para
/// S4-08): Keystore en Android y Keychain en iOS. Nunca en SQLite ni en
/// texto plano.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Clave única: toda la sesión va junta para no dejarla a medias.
  static const String key = 'kopay.session';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: key);
    } catch (_) {
      // El almacén del sistema no se pudo leer: es como no tener sesión.
      return null;
    }
    if (raw == null) return null;
    try {
      return StoredSession.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Una sesión dañada no se puede usar; se borra para empezar limpio.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: key, value: jsonEncode(session.toMap()));

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Si no se pudo borrar, la siguiente lectura la descarta de todos modos.
    }
  }
}

/// Sesión en memoria, para pruebas.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this._session]);

  StoredSession? _session;

  /// Lo guardado ahora mismo.
  StoredSession? get current => _session;

  @override
  Future<StoredSession?> read() async => _session;

  @override
  Future<void> write(StoredSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
