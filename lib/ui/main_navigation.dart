import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import '../services/ad_service.dart';
import 'tabs/youtube_tab.dart';
import 'tabs/browser_tab.dart';
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
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  final List<Widget> _tabs = const [
    YoutubeTab(),
    BrowserTab(),
    LinksTab(),
    DownloadsTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _initBanner();
  }

  void _initBanner() {
    _bannerAd = AdService().createBannerAd(
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isBannerLoaded = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

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
          // إعلان البنر (يظهر إذا تم تحميله بنجاح)
          if (_isBannerLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              margin: const EdgeInsets.only(bottom: 5),
              child: AdWidget(ad: _bannerAd!),
            ),

          // شريط مصغر للتحميل الجاري في الخلفية (يظهر في حال وجود تحميل نشط والمستخدم في تبويب آخر)
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: _backend.activeDownloads,
            builder: (context, tasks, child) {
              if (tasks.isEmpty || _currentIndex == 3) return const SizedBox.shrink();
              final task = tasks.first;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = 3),
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.4), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.downloading_rounded, color: AppColors.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'جارٍ في الخلفية: ${task.title}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(task.progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: task.progress,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // شريط التنقل الزجاجي
          ValueListenableBuilder<String>(
            valueListenable: _backend.langNotifier,
            builder: (context, lang, child) {
              return Container(
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(Icons.play_circle_fill, _backend.t('youtube'), 0),
                          _buildNavItem(Icons.explore_rounded, _backend.t('browser'), 1),
                          _buildNavItem(Icons.link_rounded, _backend.t('link'), 2),
                          _buildNavItem(Icons.download_rounded, _backend.t('downloads'), 3),
                          _buildNavItem(Icons.settings_rounded, _backend.t('settings'), 4),
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.cyan : AppColors.textMuted,
                  size: isSelected ? 24 : 22,
                ),
                if (index == 3)
                  ValueListenableBuilder<List<DownloadTask>>(
                    valueListenable: _backend.activeDownloads,
                    builder: (context, tasks, child) {
                      if (tasks.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
