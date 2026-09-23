import 'package:flutter/material.dart';
import 'theme_service.dart';

class AppColors {
  // الألوان الديناميكية المرتبطة بالثيم المختار فورياً
  static Color get background => ThemeService().currentTheme.value.background;
  static Color get surface => ThemeService().currentTheme.value.surface;
  static Color get surfaceLight => ThemeService().currentTheme.value.surfaceLight;

  // الألوان الرئيسية للـ Glow والـ Gradients متغيرة بتغير الثيم
  static Color get cyan => ThemeService().currentTheme.value.primary;
  static Color get blue => ThemeService().currentTheme.value.primary;
  static Color get purple => ThemeService().currentTheme.value.secondary;
  static Color get magenta => ThemeService().currentTheme.value.secondary;
  
  // لون ثانوي للمسات والتنبيهات
  static const Color orange = Color(0xFFFF8C00);

  // ألوان النصوص المتجاوبة مع وضع الإضاءة والظلام
  static Color get textPrimary => ThemeService().currentTheme.value.isDark ? Colors.white : const Color(0xFF0F172A);
  static Color get textSecondary => ThemeService().currentTheme.value.isDark ? Colors.white70 : const Color(0xFF334155);
  static Color get textMuted => ThemeService().currentTheme.value.isDark ? Colors.white38 : const Color(0xFF64748B);

  // تدرج لوني رئيسي ديناميكي متفاعل مع الثيم
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      ThemeService().currentTheme.value.primary,
      ThemeService().currentTheme.value.secondary,
    ],
  );
  
  // تدرج لوني للنصوص متفاعل مع الثيم
  static LinearGradient get textGradient => LinearGradient(
    colors: [
      ThemeService().currentTheme.value.primary,
      ThemeService().currentTheme.value.secondary,
    ],
  );
}
