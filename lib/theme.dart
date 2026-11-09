import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors for the glass UI, one set for dark and one for light.
class AppPalette {
  final Color bg, text, textDim, glassFill, glassBorder, blob1, blob2, blob3;

  const AppPalette({
    required this.bg,
    required this.text,
    required this.textDim,
    required this.glassFill,
    required this.glassBorder,
    required this.blob1,
    required this.blob2,
    required this.blob3,
  });

  static const dark = AppPalette(
    bg: Color(0xFF0B1020),
    text: Colors.white,
    textDim: Color(0xB8FFFFFF),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    blob1: Color(0xFF5B5BFF),
    blob2: Color(0xFF19C3B1),
    blob3: Color(0xFFFF6AA2),
  );

  static const light = AppPalette(
    bg: Color(0xFFEEF1FB),
    text: Color(0xFF121528),
    textDim: Color(0xFF4A4F6A),
    glassFill: Color(0x8CFFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    blob1: Color(0xFF8E8EFF),
    blob2: Color(0xFF6FE0D2),
    blob3: Color(0xFFFFA3C6),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Global theme switch (dark / light).
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: p.text, displayColor: p.text),
  );
}
