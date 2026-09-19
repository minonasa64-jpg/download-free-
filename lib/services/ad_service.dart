import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // رقم تعريف اللعبة الرسمي من Unity Ads لأجهزة Android
  static const String gameId = '800377154';

  // معرّفات الوحدات الإعلانية (الإعلانات البينية وشريط البنر)
  static const String interstitialPlacementId = 'Interstitial_Android';
  static const String bannerPlacementId = 'Banner_Android';

  bool _isInitialized = false;
  bool _isInterstitialLoading = false;
  bool _isInterstitialLoaded = false;

  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);

  bool get isInitialized => _isInitialized;
  bool get isInterstitialLoaded => _isInterstitialLoaded;

  // تهيئة نظام Unity Ads
  static Future<void> init({bool? testMode}) async {
    final bool useTestMode = testMode ?? kDebugMode;
    try {
      await UnityAds.init(
        gameId: gameId,
        testMode: useTestMode,
        onComplete: () {
          _instance._isInitialized = true;
          _instance.isInitializedNotifier.value = true;
          debugPrint('Unity Ads Initialized Successfully with Game ID: $gameId (testMode: $useTestMode)');
          _instance.loadInterstitialAd();
        },
        onFailed: (error, message) {
          _instance._isInitialized = false;
          _instance.isInitializedNotifier.value = false;
          debugPrint('Unity Ads Initialization Failed: $error - $message');
        },
      );
    } catch (e) {
      debugPrint('Unity Ads Init Exception: $e');
    }
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية
  void loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    try {
      UnityAds.load(
        placementId: interstitialPlacementId,
        onComplete: (placementId) {
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          debugPrint('Unity Interstitial Loaded Successfully: $placementId');
        },
        onFailed: (placementId, error, message) {
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          debugPrint('Unity Interstitial Failed to Load: $placementId ($error: $message)');
        },
      );
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint('Unity Interstitial Load Exception: $e');
    }
  }

  // إظهار الإعلان البيني عند التنزيل أو التنقل
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (!_isInitialized) {
      debugPrint('Unity Ads not initialized yet. Proceeding without ad.');
      if (onAdClosed != null) onAdClosed();
      return;
    }

    try {
      UnityAds.showVideoAd(
        placementId: interstitialPlacementId,
        onStart: (placementId) => debugPrint('Unity Video Ad Started: $placementId'),
        onClick: (placementId) => debugPrint('Unity Video Ad Clicked: $placementId'),
        onSkipped: (placementId) {
          debugPrint('Unity Video Ad Skipped: $placementId');
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
        onComplete: (placementId) {
          debugPrint('Unity Video Ad Completed: $placementId');
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
        onFailed: (placementId, error, message) {
          debugPrint('Unity Video Ad Failed: $placementId ($error: $message)');
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
      );
    } catch (e) {
      debugPrint('Unity Show Video Ad Exception: $e');
      loadInterstitialAd();
      if (onAdClosed != null) onAdClosed();
    }
  }

  // بناء ويدجت شريط البنر الإعلاني (Banner Strip)
  Widget buildBannerWidget({
    VoidCallback? onLoaded,
    Function(String, dynamic, String)? onFailed,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isInitializedNotifier,
      builder: (context, initialized, _) {
        if (!initialized) {
          return const SizedBox(height: 50);
        }
        return UnityBannerAd(
          placementId: bannerPlacementId,
          onLoad: (placementId) {
            debugPrint('Unity Banner Loaded: $placementId');
            if (onLoaded != null) onLoaded();
          },
          onFailed: (placementId, error, message) {
            debugPrint('Unity Banner Failed: $placementId ($error: $message)');
            if (onFailed != null) onFailed(placementId, error, message);
          },
          onClick: (placementId) => debugPrint('Unity Banner Clicked: $placementId'),
          onShown: (placementId) => debugPrint('Unity Banner Shown: $placementId'),
        );
      },
    );
  }
}
