import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/accountant_data.dart';
import '../services/clients_api.dart';
import '../utils/app_colors.dart';
import '../utils/route_policy.dart';
import 'accountant_clients_screen.dart';
import 'login_screen.dart';

/// Entrada a la app según la sesión (S3-12, HU-31, HU-34, HU-37).
///
/// Sigue el diagrama de docs/navegacion-usuario-contador.md §2:
/// - Mientras [SessionProvider.restore] lee la sesión guardada: Splash.
/// - Sin sesión: Iniciar sesión (S3-11).
/// - Con sesión de `user`: [home], la vista de usuario (Inicio,
///   Movimientos, Ajustes).
/// - Con sesión de `accountant`: la vista de contador, con los datos de
///   la API (`/api/clients`, S5-09).
/// - Con un rol que la app no reconoce: Iniciar sesión, sin privilegios
///   de nadie (HU-37).
///
/// La primera pantalla de cada rol sale de [RoutePolicy.homeFor] (S4-09),
/// para que la entrada y las guardas usen la misma matriz.
///
/// Cuando la sesión cambia (inicia, se cierra o vence), regresa a la
/// primera pantalla para que no quede abierta una pantalla del estado
/// anterior. Sin [SessionProvider] en el árbol (pruebas de las pantallas
/// financieras), abre [home] directo.
class SessionGate extends StatefulWidget {
  /// Vista de usuario.
  final Widget home;

  /// Vista de contador; por omisión, Clientes autorizados con los datos
  /// de la API ([ClientsApi] del árbol).
  final Widget Function()? accountantHome;

  const SessionGate({super.key, required this.home, this.accountantHome});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  SessionStatus? _lastStatus;
  String? _lastRole;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider?>();
    if (session == null) return widget.home;

    final status = session.status;
    final role = session.user?.role;
    if (_lastStatus != null && (status != _lastStatus || role != _lastRole)) {
      // Cierra lo que estaba abierto sobre la pantalla anterior.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _lastStatus = status;
    _lastRole = role;

    if (status == SessionStatus.unknown) return const SplashScreen();
    if (status == SessionStatus.signedOut || session.user == null) {
      return const LoginScreen();
    }
    return switch (RoutePolicy.homeFor(role)) {
      AppScreen.userHome => widget.home,
      AppScreen.accountantClients =>
        widget.accountantHome?.call() ??
            AccountantClientsScreen(
              // La cuenta en la key: otra sesión de contador empieza con
              // su propia lista.
              key: ValueKey(session.user!.id),
              data: ApiAccountantData(
                session: session,
                api: context.read<ClientsApi>(),
              ),
            ),
      _ => const LoginScreen(),
    };
  }
}

/// Splash: se muestra mientras se lee la sesión guardada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash'),
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: -1,
                ),
                children: [
                  const TextSpan(text: 'kopay'),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
