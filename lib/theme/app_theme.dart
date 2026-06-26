import 'package:flutter/material.dart';
import 'app_settings.dart';

class AppTheme {
  static const Color primary = Color(0xFF1a1a1a);
  static const Color success = Color(0xFF1D9E75);
  static const Color warning = Color(0xFFD4537E);
  static const Color neutral = Color(0xFFf7f7f4);
  static const Color highlight = Color(0xFF0D9488);
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFf0f0f0);
  static const Color textPrimary = Color(0xFF1a1a1a);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFFD1D5DB);

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: neutral,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: highlight,
        surface: cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );

    final fontName = AppSettings.instance.fontStyle.value;
    return base.copyWith(
      textTheme: AppSettings.instance.getTextTheme(fontName, base.textTheme),
    );
  }

  static String get rupee => AppSettings.instance.currency.value;

  static const Map<String, Color> calendarTypeColors = {
    'Personal': Color(0xFF1D9E75),
    'Placement': Color(0xFF0D9488),
    'Coding Practice': Color(0xFFD4537E),
  };

  static const Map<String, Color> priorityColors = {
    'high': Color(0xFFEF4444),
    'medium': Color(0xFFEAB308),
    'low': Color(0xFF22C55E),
  };

  static const List<Color> chartColors = [
    Color(0xFF0D9488),
    Color(0xFF1D9E75),
    Color(0xFFD4537E),
    Color(0xFFEAB308),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFF1a1a1a),
    Color(0xFF64748B),
  ];
}
