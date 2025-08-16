import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandBlueDark = Color(0xFF1D4ED8);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brandBlue),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlueDark,
        brightness: Brightness.dark,
      ),
    );
  }
}
