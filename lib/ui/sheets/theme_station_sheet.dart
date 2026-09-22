import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/theme_service.dart';
import '../../services/backend_service.dart';

class ThemeStationSheet extends StatelessWidget {
  const ThemeStationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendService();
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = backend.langNotifier.value;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 20, right: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101018) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.cyan.withOpacity(0.2) : Colors.black12,
        ),
      ),
      child: ValueListenableBuilder<ThemeConfig>(
        valueListenable: themeService.currentTheme,
        builder: (context, activeConfig, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [activeConfig.primary, activeConfig.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette_rounded, color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backend.t('theme_station'),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          backend.t('theme_station_desc'),
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: ThemeService.themes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final theme = ThemeService.themes[index];
                    final isSelected = activeConfig.id == theme.id;
                    final displayName = lang == 'fr'
                        ? theme.nameFr
                        : (lang == 'en' ? theme.nameEn : theme.nameAr);

                    return InkWell(
                      onTap: () async {
                        await themeService.setTheme(theme);
                        if (theme.isDark) {
                          await backend.changeTheme('dark');
                        } else {
                          await backend.changeTheme('light');
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.primary.withOpacity(0.15)
                              : (isDark ? const Color(0xFF181824) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? theme.primary
                                : Colors.grey.withOpacity(0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // دائرة استعراض ألوان الثيم
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [theme.primary, theme.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: theme.background,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: theme.primary.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.black, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.isDark ? Colors.black38 : Colors.black12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          theme.isDark ? 'Dark Mode' : 'Light Mode',
                                          style: TextStyle(
                                            color: isDark ? Colors.white60 : Colors.black54,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'مفعل',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
