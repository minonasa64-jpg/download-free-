import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// سيتم إنشاء هذه الملفات في الخطوة القادمة
import 'tabs/youtube_tab.dart';
import 'tabs/links_tab.dart';
import 'tabs/downloads_tab.dart';
import 'tabs/settings_tab.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  // الصفحات الأربعة الرئيسية
  final List<Widget> _pages = const [
    YoutubeTab(),
    LinksTab(),
    DownloadsTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // مهم جداً لجعل المحتوى يمتد خلف شريط التنقل العائم
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // تأثير الزجاج
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.play_circle_fill, Icons.play_circle_outline, 'يوتيوب'),
                _buildNavItem(1, Icons.link, Icons.link, 'الروابط'),
                _buildNavItem(2, Icons.download, Icons.download_outlined, 'التنزيلات'),
                _buildNavItem(3, Icons.settings, Icons.settings_outlined, 'إعدادات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? AppColors.cyan : AppColors.textMuted,
                size: isSelected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? AppColors.cyan : AppColors.textMuted,
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Cairo',
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
