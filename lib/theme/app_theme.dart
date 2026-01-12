import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0B0F19);
  static const Color cardBackground = Color(0xFF151B2B);

  // Accents
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color purpleAccent = Color(0xFFBD00FF);
  static const Color neonGreen = Color(0xFF00FF94);
  
  // Inactive
  static const Color inactive = Color(0xFF4A5E8A);
  static const Color textSecondary = Color(0xFF8A9BB8);
  static const Color borderColor = Color(0xFF2A2F3A);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyanAccent,
        secondary: AppColors.purpleAccent,
        surface: AppColors.cardBackground,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
    );
  }
}
