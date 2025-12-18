import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Dark blue theme
  static const Color primaryDark = Color(0xFF0A1929);
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  
  // Accent colors - Orange theme
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFB74D);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color lowStock = Color(0xFFE53935);
  
  // Neutral colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  
  // Material 3 ColorScheme
  static ColorScheme get colorScheme => ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: accent,
    error: error,
    surface: surface,
  );
}

