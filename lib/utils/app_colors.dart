import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppPalette {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHi;
  final Color hair;
  final Color hair2;
  final Color text;
  final Color text2;
  final Color text3;
  final Color green;
  final Color red;
  final Color redSoft;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.hair,
    required this.hair2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.green,
    required this.red,
    required this.redSoft,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceHi: Color(0xFF1A1A1A),
    hair: Color(0xFF1F1F1F),
    hair2: Color(0xFF262626),
    text: Color(0xFFFAFAFA),
    text2: Color(0xFF8A8A8A),
    text3: Color(0xFF4F4F4F),
    green: Color(0xFF00C896),
    red: Color(0xFFFF4D6D),
    redSoft: Color(0xFF1A0A0E),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF4F4F2),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFEDEDEA),
    hair: Color(0xFFE6E6E2),
    hair2: Color(0xFFD6D6D1),
    text: Color(0xFF111111),
    text2: Color(0xFF5F5F5F),
    text3: Color(0xFF8F8F8F),
    green: Color(0xFF00A67D),
    red: Color(0xFFD92D4C),
    redSoft: Color(0xFFFCE8EC),
  );
}

/// Colores del tema activo. Se leen al construir cada widget; al cambiar de
/// tema hay que volver a construir la app.
class AppColors {
  static AppPalette palette = AppPalette.dark;

  static bool get isDark => palette.brightness == Brightness.dark;

  static Color get bg => palette.bg;
  static Color get surface => palette.surface;
  static Color get surfaceHi => palette.surfaceHi;
  static Color get hair => palette.hair;
  static Color get hair2 => palette.hair2;
  static Color get text => palette.text;
  static Color get text2 => palette.text2;
  static Color get text3 => palette.text3;
  static Color get green => palette.green;
  static Color get red => palette.red;
  static Color get redSoft => palette.redSoft;

  /// Barra de estado y de navegación acordes al tema.
  static SystemUiOverlayStyle get systemOverlay => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      );
}
