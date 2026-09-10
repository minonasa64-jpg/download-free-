import 'package:flutter/material.dart';

class AppColors {
  // الخلفية المظلمة الفخمة
  static const Color background = Color(0xFF050509);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1E1E2A);

  // الألوان الرئيسية للـ Glow والـ Gradients
  static const Color cyan = Color(0xFF00D9FF);
  static const Color blue = Color(0xFF4169E1);
  static const Color purple = Color(0xFF8A2BE2);
  static const Color magenta = Color(0xFFB000FF);
  
  // لون ثانوي للمسات (أيقونات محددة أو تنبيهات)
  static const Color orange = Color(0xFFFF8C00);

  // ألوان النصوص
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white38;

  // تدرج لوني رئيسي (Boykta Gradient)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, blue, magenta],
  );
  
  // تدرج لوني للنصوص (Text Gradient)
  static const LinearGradient textGradient = LinearGradient(
    colors: [cyan, magenta],
  );
}
