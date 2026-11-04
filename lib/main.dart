import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  SystemChrome.setSystemUIOverlayStyle(AppColors.systemOverlay);

  runApp(const KopayApp());
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
    _PlaceholderPage(title: 'Inicio', icon: Icons.home_outlined),
    _PlaceholderPage(title: 'Movimientos', icon: Icons.receipt_long_outlined),
    _PlaceholderPage(title: 'Ajustes', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.systemOverlay,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(index: _index, children: _pages),
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
