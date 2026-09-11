import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  final List<Widget> _tabs = const [
    YoutubeTab(),
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
          
          // شريط التنقل الزجاجي
          ValueListenableBuilder<String>(
            valueListenable: _backend.langNotifier,
            builder: (context, lang, child) {
              return Container(
                margin: const EdgeInsets.only(left: 15, right: 15, bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(Icons.play_circle_fill, _backend.t('youtube'), 0),
                          _buildNavItem(Icons.link_rounded, _backend.t('link'), 1),
                          _buildNavItem(Icons.download_rounded, _backend.t('downloads'), 2),
                          _buildNavItem(Icons.settings_rounded, _backend.t('settings'), 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.cyan : AppColors.textMuted,
              size: isSelected ? 26 : 24,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 11,
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
