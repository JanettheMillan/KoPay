import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../utils/route_policy.dart';

/// Protege una pantalla privada (S4-09, HU-34 y HU-37).
///
/// Escucha [SessionProvider] y muestra [child] solo si [RoutePolicy]
/// permite [screen] con la sesión y el rol actuales. Si no:
/// - mientras se lee la sesión muestra [loading];
/// - sin sesión, o con un rol sin permiso, muestra [denied], que recibe la
///   decisión con la pantalla a la que hay que ir (Iniciar sesión o la
///   vista del rol).
///
/// [child] **no se construye** si no hay permiso, así que sus datos no se
/// piden ni se muestran. Si la sesión cambia (cierre de sesión, sesión
/// vencida o cambio de cuenta), la guarda se vuelve a evaluar sola.
///
/// La navegación (S3-12 y S4-12) decide qué mostrar o a dónde ir en
/// [denied]. La API vuelve a comprobar el permiso en cada consulta.
class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.screen,
    required this.child,
    required this.denied,
    this.loading,
  });

  /// Pantalla que se protege.
  final AppScreen screen;
  final Widget child;

  /// Qué mostrar si no se permite.
  final Widget Function(BuildContext context, GuardDecision decision) denied;

  /// Qué mostrar mientras se lee la sesión. Por defecto, un indicador.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final decision = RoutePolicy.check(
      screen,
      status: session.status,
      user: session.user,
      sessionExpired: session.sessionExpired,
    );
    return switch (decision.outcome) {
      GuardOutcome.allow => child,
      GuardOutcome.wait =>
        loading ??
            const Center(
              child: CircularProgressIndicator(key: Key('role-guard-loading')),
            ),
      GuardOutcome.signIn || GuardOutcome.goHome => denied(context, decision),
    };
  }
}
