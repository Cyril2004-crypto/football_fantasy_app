import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2A145A);
  static const Color secondary = Color(0xFF1ED6A8);
  static const Color accent = Color(0xFFFF5E7A);
  static const Color tertiary = Color(0xFF2B9BFF);

  // Background Colors
  static const Color background = Color(0xFFF6F8FF);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color mutedLavender = Color(0xFFEDE8FF);
  static const Color mutedMint = Color(0xFFE8FFF6);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textLight = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // UI Colors
  static const Color divider = Color(0xFFDADAF5);
  static const Color surface = Color(0xFFFDFDFF);

  // Player Position Colors
  static const Color goalkeeper = Color(0xFFFFEB3B);
  static const Color defender = Color(0xFF00BCD4);
  static const Color midfielder = Color(0xFF4CAF50);
  static const Color forward = Color(0xFFF44336);

  // Gradient
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2A145A), Color(0xFF6A2FE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient pageGradient = LinearGradient(
    colors: [Color(0xFFF6F8FF), Color(0xFFE9FCF6), Color(0xFFFFF0F4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
