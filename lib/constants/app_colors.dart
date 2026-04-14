import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF37003C);
  static const Color secondary = Color(0xFF00FF87);
  static const Color accent = Color(0xFFE90052);
  
  // Background Colors
  static const Color background = Color(0xFFF4F4F4);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF1E1E1E);
  
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
  static const Color divider = Color(0xFFE0E0E0);
  static const Color surface = Color(0xFFFAFAFA);
  
  // Player Position Colors
  static const Color goalkeeper = Color(0xFFFFEB3B);
  static const Color defender = Color(0xFF00BCD4);
  static const Color midfielder = Color(0xFF4CAF50);
  static const Color forward = Color(0xFFF44336);
  
  // Gradient
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF5A0052)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
