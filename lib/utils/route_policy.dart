import '../providers/session_provider.dart';
import '../services/auth_api.dart';

/// Pantallas de la app agrupadas por quién puede abrirlas
/// (docs/navegacion-usuario-contador.md §5, S4-09).
enum AppScreen {
  // ── Entrada: se abren sin sesión ──────────────────────────────────
  splash,
  login,
  recover,

  /// Crear cuenta: sin sesión o con cuenta de usuario; nunca un contador.
  register,

  // ── Vista de usuario ──────────────────────────────────────────────
  /// Inicio, Movimientos y Ajustes (la navegación inferior).
  userHome,

  /// Formularios de gasto, ingreso, tarjeta, deuda y pagos.
  userForms,

  /// Contadores autorizados: autorizar y revocar (HU-38, HU-41).
  manageAccountants,

  // ── Vista de contador ─────────────────────────────────────────────
  /// Clientes autorizados (HU-39).
  accountantClients,

  /// Resumen e historial de un cliente, solo lectura (HU-40, HU-42).
  accountantClientData,
}

/// Roles que conoce la app (HU-37). Cualquier otro texto no da acceso.
class AppRole {
  AppRole._();

  static const String user = 'user';
  static const String accountant = 'accountant';
}

/// Qué hacer al intentar abrir una pantalla.
enum GuardOutcome {
  /// Se puede abrir.
  allow,

  /// Todavía no se sabe si hay sesión (se está leyendo): esperar.
  wait,

  /// No hay sesión: ir a Iniciar sesión.
  signIn,

  /// Hay sesión pero el rol no tiene permiso: ir a la vista de su rol.
  goHome,
}

/// Resultado de [RoutePolicy.check].
class GuardDecision {
  final GuardOutcome outcome;

  /// Pantalla a la que hay que ir si no se permite. `null` en [allow] y
  /// [wait].
  final AppScreen? redirectTo;

  /// `true` si se va a Iniciar sesión porque la sesión venció
  /// (`SessionProvider.sessionExpired`), para avisarlo.
  final bool sessionExpired;

  const GuardDecision._(
    this.outcome, {
    this.redirectTo,
    this.sessionExpired = false,
  });

  static const allow = GuardDecision._(GuardOutcome.allow);
  static const wait = GuardDecision._(GuardOutcome.wait);

  bool get allowed => outcome == GuardOutcome.allow;

  @override
  String toString() => 'GuardDecision(${outcome.name}, $redirectTo)';
}

/// Guardas de navegación por rol (S4-09, HU-34 y HU-37).
///
/// Solo decide qué pantalla se puede abrir; **no sustituye a la API**, que
/// vuelve a comprobar el rol y el permiso en cada consulta (S4-04, S4-06).
/// Ocultar o bloquear una pantalla en Flutter no basta por sí solo.
class RoutePolicy {
  RoutePolicy._();

  /// Pantallas que se abren sin sesión.
  static const Set<AppScreen> public = {
    AppScreen.splash,
    AppScreen.login,
    AppScreen.recover,
    AppScreen.register,
  };

  /// Pantallas con sesión, por rol (matriz de la §5).
  static const Map<String, Set<AppScreen>> byRole = {
    AppRole.user: {
      AppScreen.splash,
      AppScreen.login,
      AppScreen.recover,
      AppScreen.register,
      AppScreen.userHome,
      AppScreen.userForms,
      AppScreen.manageAccountants,
    },
    AppRole.accountant: {
      AppScreen.splash,
      AppScreen.login,
      AppScreen.recover,
      AppScreen.accountantClients,
      AppScreen.accountantClientData,
    },
  };

  /// Primera pantalla de cada rol (HU-37), o Iniciar sesión si el rol no
  /// se reconoce.
  static AppScreen homeFor(String? role) => switch (role) {
    AppRole.user => AppScreen.userHome,
    AppRole.accountant => AppScreen.accountantClients,
    _ => AppScreen.login,
  };

  /// Decide si [screen] se puede abrir con la sesión [status] de [user].
  static GuardDecision check(
    AppScreen screen, {
    required SessionStatus status,
    AuthUser? user,
    bool sessionExpired = false,
  }) {
    if (status == SessionStatus.unknown) {
      // El Splash se muestra mientras se lee la sesión; lo demás espera.
      return screen == AppScreen.splash
          ? GuardDecision.allow
          : GuardDecision.wait;
    }
    if (status == SessionStatus.signedOut || user == null) {
      if (public.contains(screen)) return GuardDecision.allow;
      return GuardDecision._(
        GuardOutcome.signIn,
        redirectTo: AppScreen.login,
        sessionExpired: sessionExpired,
      );
    }
    final allowed = byRole[user.role];
    if (allowed == null) {
      // Un rol desconocido no recibe privilegios de nadie (HU-37): solo ve
      // lo mismo que alguien sin sesión, para no quedar en un ciclo.
      if (public.contains(screen)) return GuardDecision.allow;
      return const GuardDecision._(
        GuardOutcome.signIn,
        redirectTo: AppScreen.login,
      );
    }
    if (allowed.contains(screen)) return GuardDecision.allow;
    return GuardDecision._(GuardOutcome.goHome, redirectTo: homeFor(user.role));
  }
}
