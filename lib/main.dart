import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/income_provider.dart';
import 'providers/movement_provider.dart';
import 'screens/home_screen.dart';
import 'screens/movements_screen.dart';
import 'utils/app_colors.dart';
import 'widgets/add_income_sheet.dart';
import 'widgets/add_movement_sheet.dart';
import 'widgets/ui_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  SystemChrome.setSystemUIOverlayStyle(AppColors.systemOverlay);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MovementProvider()..load()),
        ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
      ],
      child: const KopayApp(),
    ),
  );
}

class KopayApp extends StatelessWidget {
  const KopayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kopay',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: buildKopayTheme(),
      home: const MainShell(),
    );
  }
}

ThemeData buildKopayTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: AppColors.palette.brightness,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.surface,
    dividerColor: AppColors.hair,
    splashFactory: InkRipple.splashFactory,
    colorScheme: AppColors.isDark
        ? ColorScheme.dark(
            primary: AppColors.green,
            error: AppColors.red,
            surface: AppColors.surface,
          )
        : ColorScheme.light(
            primary: AppColors.green,
            error: AppColors.red,
            surface: AppColors.surface,
          ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.green,
      selectionColor: AppColors.green,
      selectionHandleColor: AppColors.green,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHi,
      hintStyle: TextStyle(color: AppColors.text3, fontSize: 14),
      labelStyle: TextStyle(color: AppColors.text2, fontSize: 13),
      floatingLabelStyle: TextStyle(color: AppColors.green, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.green, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.red, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: const Color(0xFF001A13),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.hair2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text2,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      showDragHandle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.hair2,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.text2, fontSize: 12),
      ),
    ),
  );
}

/// Contenedor principal con la navegación inferior entre Inicio,
/// Movimientos y Ajustes.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    MovementsScreen(),
    _PlaceholderPage(title: 'Ajustes', icon: Icons.settings_outlined),
  ];

  /// El botón + pregunta qué registrar y abre el formulario elegido.
  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showKopaySheet<String>(context, const _AddChooser());
    if (!mounted || choice == null) return;

    String? message;
    if (choice == 'movement') {
      final saved = await showAddMovementSheet(context);
      if (saved != null) {
        message = saved.isExpense ? 'Gasto guardado' : 'Entrada guardada';
      }
    } else {
      final saved = await showAddIncomeSheet(context);
      if (saved != null) message = 'Ingreso guardado';
    }
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemOverlay,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(index: _index, children: _pages),
        floatingActionButton: _index == 2
            ? null
            : FloatingActionButton(
                key: const Key('add-button'),
                tooltip: 'Agregar',
                backgroundColor: AppColors.green,
                foregroundColor: const Color(0xFF001A13),
                onPressed: _add,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.text3),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.green),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: AppColors.text3),
              selectedIcon: Icon(Icons.receipt_long, color: AppColors.green),
              label: 'Movimientos',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: AppColors.text3),
              selectedIcon: Icon(Icons.settings, color: AppColors.green),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja que abre el botón +: elegir entre gasto o ingreso.
class _AddChooser extends StatelessWidget {
  const _AddChooser();

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String emoji, String title, String subtitle) {
      return ListTile(
        key: Key('add-$value'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(title, style: TextStyle(color: AppColors.text)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.text3)),
        onTap: () => Navigator.of(context).pop(value),
      );
    }

    return KopaySheet(
      title: '¿Qué quieres registrar?',
      child: Column(
        children: [
          option('movement', '🧾', 'Gasto o movimiento', 'Compras, pagos'),
          option('income', '💼', 'Ingreso', 'Salario, bonos, ventas'),
        ],
      ),
    );
  }
}

/// Pantalla provisional hasta que se implemente cada sección.
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.text3, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
