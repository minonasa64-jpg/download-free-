import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset {
  cyberCyan,      // السايبر الأزرق الكلاسيكي (الافتراضي)
  amoledPitch,    // الأسود الفاحم الموفر للبطارية والشاشات
  emeraldGreen,   // الأخضر الزمردي الراقي
  sunsetAmber,    // الذهبي والعنبر الفاخر
  neonViolet,     // البنفسجي الساحر النيون
  lightFrost,     // الأبيض الثلجي المضيء
}

class ThemeConfig {
  final String id;
  final String nameAr;
  final String nameEn;
  final String nameFr;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final bool isDark;

  const ThemeConfig({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.nameFr,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    this.isDark = true,
  });
}

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const List<ThemeConfig> themes = [
    ThemeConfig(
      id: 'cyber_cyan',
      nameAr: 'سايبر سايان (الافتراضي)',
      nameEn: 'Cyber Cyan (Default)',
      nameFr: 'Cyber Cyan (Défaut)',
      primary: Color(0xFF00D9FF),
      secondary: Color(0xFFB000FF),
      background: Color(0xFF050509),
      surface: Color(0xFF12121A),
      surfaceLight: Color(0xFF1E1E2A),
      isDark: true,
    ),
    ThemeConfig(
      id: 'amoled_pitch',
      nameAr: 'أسود فاحم (AMOLED مقتصد للطاقة)',
      nameEn: 'Pure AMOLED (Battery Saver)',
      nameFr: 'AMOLED Pur (Économie)',
      primary: Color(0xFF00F0FF),
      secondary: Color(0xFF3B82F6),
      background: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      surfaceLight: Color(0xFF141414),
      isDark: true,
    ),
    ThemeConfig(
      id: 'emerald_green',
      nameAr: 'أخضر زمردي فاخر (Emerald Matrix)',
      nameEn: 'Emerald Green (Luxury)',
      nameFr: 'Émeraude Sombre',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
      background: Color(0xFF040D09),
      surface: Color(0xFF0B1F16),
      surfaceLight: Color(0xFF133224),
      isDark: true,
    ),
    ThemeConfig(
      id: 'sunset_amber',
      nameAr: 'عنبر وذهب (Sunset Gold)',
      nameEn: 'Sunset Amber & Gold',
      nameFr: 'Ambre Doré',
      primary: Color(0xFFFFB020),
      secondary: Color(0xFFFF5722),
      background: Color(0xFF0D0A05),
      surface: Color(0xFF1F180A),
      surfaceLight: Color(0xFF2E2412),
      isDark: true,
    ),
    ThemeConfig(
      id: 'neon_violet',
      nameAr: 'نيون أرجواني (Neon Violet)',
      nameEn: 'Neon Violet & Purple',
      nameFr: 'Violet Néon',
      primary: Color(0xFFC084FC),
      secondary: Color(0xFFEC4899),
      background: Color(0xFF0A0512),
      surface: Color(0xFF180D26),
      surfaceLight: Color(0xFF26163C),
      isDark: true,
    ),
    ThemeConfig(
      id: 'light_frost',
      nameAr: 'أبيض ثلجي مشرق (Frost Light)',
      nameEn: 'Frost White (Light Mode)',
      nameFr: 'Blanc Givré (Clair)',
      primary: Color(0xFF0284C7),
      secondary: Color(0xFF7C3AED),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      surfaceLight: Color(0xFFF1F5F9),
      isDark: false,
    ),
  ];

  final ValueNotifier<ThemeConfig> currentTheme = ValueNotifier<ThemeConfig>(themes[0]);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString('theme_preset_id') ?? 'cyber_cyan';
    final found = themes.firstWhere(
      (t) => t.id == savedThemeId,
      orElse: () => themes[0],
    );
    currentTheme.value = found;
  }

  Future<void> setTheme(ThemeConfig config) async {
    currentTheme.value = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset_id', config.id);
  }

  ThemeData getThemeData() {
    final cfg = currentTheme.value;
    if (!cfg.isDark) {
      return ThemeData.light().copyWith(
        scaffoldBackgroundColor: cfg.background,
        primaryColor: cfg.primary,
        colorScheme: ColorScheme.light(
          primary: cfg.primary,
          secondary: cfg.secondary,
          surface: cfg.surface,
        ),
      );
    } else {
      return ThemeData.dark().copyWith(
        scaffoldBackgroundColor: cfg.background,
        primaryColor: cfg.primary,
        colorScheme: ColorScheme.dark(
          primary: cfg.primary,
          secondary: cfg.secondary,
          surface: cfg.surface,
        ),
      );
    }
  }
}
