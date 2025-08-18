import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandBlueDark = Color(0xFF1D4ED8);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brandBlue),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
    return base.copyWith(textTheme: GoogleFonts.notoSansTextTheme(base.textTheme));
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: brandBlueDark, brightness: Brightness.dark),
    );
    return base.copyWith(textTheme: GoogleFonts.notoSansTextTheme(base.textTheme));
  }
}
