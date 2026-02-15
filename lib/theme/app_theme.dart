import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Colors.black;
  static const Color primary = Color(0xFF00FF88);
  static const Color secondary = Color(0xFF00C8FF);
  static const Color warning = Color(0xFFFFB300);
  static const Color urgent = Color(0xFFFF204E);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);

  static Color surfaceGlass = Colors.white.withOpacity(0.1);
  static Color surfaceGlassDark = Colors.black.withOpacity(0.4);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00FF88), Color(0xFF00C8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient urgentGradient = LinearGradient(
    colors: [Color(0xFFFF204E), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w900,
    fontSize: 32,
    color: textPrimary,
    letterSpacing: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.normal,
    fontSize: 18,
    color: textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 12,
    color: textSecondary,
    letterSpacing: 1.5,
  );

  static RoundedRectangleBorder roundedBorder(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
}
