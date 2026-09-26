import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import '../services/ad_service.dart';
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
  final BackendService _backend = BackendService();
  int _currentIndex = 0;
  bool _isBannerLoaded = false;

  final List<Widget> _tabs = const [
    YoutubeTab(),
    LinksTab(),
    DownloadsTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: ValueListenableBuilder<String>(
        valueListenable: _backend.langNotifier,
        builder: (context, lang, child) {
          return IndexedStack(
            index: _currentIndex,
            children: _tabs,
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط إعلانات Unity Ads (Banner Strip)
          ValueListenableBuilder<bool>(
            valueListenable: AdService().isInitializedNotifier,
            builder: (context, isInit, _) {
              if (!isInit) return const SizedBox.shrink();
              return AdService().buildBannerWidget(
                onLoaded: () {
                  if (mounted && !_isBannerLoaded) {
                    setState(() => _isBannerLoaded = true);
                  }
                },
              );
            },
          ),

          // شريط التنقل الزجاجي العصري والأيقونات التفاعلية الجذابة
          ValueListenableBuilder<String>(
            valueListenable: _backend.langNotifier,
            builder: (context, lang, child) {
              return Container(
                margin: const EdgeInsets.only(left: 14, right: 14, bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.09), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(Icons.smart_display_rounded, Icons.smart_display_outlined, _backend.t('youtube'), 0),
                          _buildNavItem(Icons.hub_rounded, Icons.link_rounded, _backend.t('link'), 1),
                          _buildNavItem(Icons.download_for_offline_rounded, Icons.download_rounded, _backend.t('downloads'), 2),
                          _buildNavItem(Icons.tune_rounded, Icons.settings_suggest_outlined, _backend.t('settings'), 3),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData activeIcon, IconData inactiveIcon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.cyan.withOpacity(0.4), width: 1)
              : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 240),
                  child: Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    color: isSelected ? AppColors.cyan : AppColors.textMuted,
                    size: isSelected ? 24 : 22,
                  ),
                ),
                if (index == 2)
                  ValueListenableBuilder<List<DownloadTask>>(
                    valueListenable: _backend.activeDownloads,
                    builder: (context, tasks, child) {
                      if (tasks.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        top: -3,
                        right: -5,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withOpacity(0.9),
                                blurRadius: 6,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: TextStyle(
                color: isSelected ? AppColors.cyan : AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
