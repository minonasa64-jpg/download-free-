import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:unity_ads_plugin/unity_ads_plugin.dart";

/// خدمة إدارة وتنسيق إعلانات Unity Ads الرسمية لتطبيق Boykta
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // رقم تعريف اللعبة الرسمي من Unity Ads لأجهزة Android
  static const String gameId = "800377154";

  // المعرف الأساسي للمنظمة (Unity Organization ID)
  static const String organizationId = "11270715503405";

  // معرّفات الوحدات الإعلانية الرسمية المطابقة للوحة تحكم Unity
  // معرّف إعلان البنر (اللافتة): BP_Banner_Android
  static const String primaryBannerPlacementId = "BP_Banner_Android";
  static const String fallbackBannerPlacementId = "Banner_Android";

  // معرّف الإعلان الخلالي (الشاشة الكاملة): BP_Interstitial_Android
  static const String primaryInterstitialPlacementId = "BP_Interstitial_Android";
  static const String fallbackInterstitialPlacementId = "Interstitial_Android";

  bool _isInitialized = false;
  bool _isInterstitialLoading = false;
  bool _isInterstitialLoaded = false;
  String _activeInterstitialPlacement = primaryInterstitialPlacementId;

  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);

  bool get isInitialized => _isInitialized;
  bool get isInterstitialLoaded => _isInterstitialLoaded;
  String get activeInterstitialPlacement => _activeInterstitialPlacement;

  // تهيئة نظام Unity Ads
  static Future<void> init({bool? testMode}) async {
    final bool useTestMode = testMode ?? kDebugMode;
    try {
      debugPrint("Unity Ads: Initializing with Game ID: $gameId (testMode: $useTestMode)...");
      await UnityAds.init(
        gameId: gameId,
        testMode: useTestMode,
        onComplete: () {
          _instance._isInitialized = true;
          _instance.isInitializedNotifier.value = true;
          debugPrint("Unity Ads: Initialized successfully with Game ID: $gameId (testMode: $useTestMode)");
          _instance.loadInterstitialAd();
        },
        onFailed: (error, message) {
          _instance._isInitialized = false;
          _instance.isInitializedNotifier.value = false;
          debugPrint("Unity Ads: Initialization failed: $error - $message");
          
          // إذا فشلت التهيئة بالوضع العادي (مثلاً لأن المشروع جديد في لوحة Unity)، نجرب بوضع الاختبار
          if (!useTestMode) {
            debugPrint("Unity Ads: Retrying initialization with testMode: true...");
            UnityAds.init(
              gameId: gameId,
              testMode: true,
              onComplete: () {
                _instance._isInitialized = true;
                _instance.isInitializedNotifier.value = true;
                debugPrint("Unity Ads: Fallback testMode initialized successfully!");
                _instance.loadInterstitialAd();
              },
              onFailed: (err, msg) {
                debugPrint("Unity Ads: Fallback testMode also failed: $err - $msg");
              },
            );
          }
        },
      );
    } catch (e) {
      debugPrint("Unity Ads Init Exception: $e");
    }
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية مع دعم المعرّف الأساسي والاحتياطي
  void loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    _loadInterstitialWithPlacement(_activeInterstitialPlacement);
  }

  void _loadInterstitialWithPlacement(String placementId) {
    try {
      debugPrint("Unity Ads: Loading interstitial on placement: $placementId");
      UnityAds.load(
        placementId: placementId,
        onComplete: (loadedId) {
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          _activeInterstitialPlacement = loadedId;
          debugPrint("Unity Ads: Interstitial loaded successfully on: $loadedId");
        },
        onFailed: (failedId, error, message) {
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          debugPrint("Unity Ads: Interstitial failed to load on $failedId ($error: $message)");

          // محاولة استخدام المعرف البديل إذا فشل المعرف الأساسي
          if (failedId == primaryInterstitialPlacementId) {
            debugPrint("Unity Ads: Retrying with fallback placement: $fallbackInterstitialPlacementId");
            _activeInterstitialPlacement = fallbackInterstitialPlacementId;
            _isInterstitialLoading = true;
            _loadInterstitialWithPlacement(fallbackInterstitialPlacementId);
          } else {
            // إعادة ضبط للمعرف الأساسي للمرة القادمة
            _activeInterstitialPlacement = primaryInterstitialPlacementId;
          }
        },
      );
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint("Unity Ads: Interstitial load exception: $e");
    }
  }

  // إظهار الإعلان البيني عند التنزيل أو التنقل
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (!_isInitialized) {
      debugPrint("Unity Ads not initialized yet. Proceeding without ad.");
      if (onAdClosed != null) onAdClosed();
      return;
    }

    try {
      final placementToShow = _activeInterstitialPlacement;
      debugPrint("Unity Ads: Showing video ad on placement: $placementToShow");
      UnityAds.showVideoAd(
        placementId: placementToShow,
        onStart: (placementId) => debugPrint("Unity Video Ad Started: $placementId"),
        onClick: (placementId) => debugPrint("Unity Video Ad Clicked: $placementId"),
        onSkipped: (placementId) {
          debugPrint("Unity Video Ad Skipped: $placementId");
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
        onComplete: (placementId) {
          debugPrint("Unity Video Ad Completed: $placementId");
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
        onFailed: (placementId, error, message) {
          debugPrint("Unity Video Ad Show Failed: $placementId ($error: $message)");
          _isInterstitialLoaded = false;
          loadInterstitialAd();
          if (onAdClosed != null) onAdClosed();
        },
      );
    } catch (e) {
      debugPrint("Unity Show Video Ad Exception: $e");
      loadInterstitialAd();
      if (onAdClosed != null) onAdClosed();
    }
  }

  // بناء ويدجت شريط البنر الإعلاني الذكي مع التبديل التلقائي إلى المعرف الاحتياطي
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
        return _SmartUnityBanner(
          onLoaded: onLoaded,
          onFailed: onFailed,
        );
      },
    );
  }
}

/// ويدجت داخلي ذكي لبنر Unity Ads يحاول تحميل المعرف الأساسي، وفي حال الفشل ينتقل فوراً للمعرف الاحتياطي
class _SmartUnityBanner extends StatefulWidget {
  final VoidCallback? onLoaded;
  final Function(String, dynamic, String)? onFailed;

  const _SmartUnityBanner({this.onLoaded, this.onFailed});

  @override
  State<_SmartUnityBanner> createState() => _SmartUnityBannerState();
}

class _SmartUnityBannerState extends State<_SmartUnityBanner> {
  String _currentPlacement = AdService.primaryBannerPlacementId;
  bool _hasFailedCompletely = false;

  @override
  Widget build(BuildContext context) {
    if (_hasFailedCompletely) {
      return const SizedBox(height: 50);
    }

    return UnityBannerAd(
      key: ValueKey(_currentPlacement),
      placementId: _currentPlacement,
      onLoad: (placementId) {
        debugPrint("Unity Banner Loaded successfully on: $placementId");
        if (widget.onLoaded != null) widget.onLoaded!();
      },
      onFailed: (placementId, error, message) {
        debugPrint("Unity Banner Failed on $placementId ($error: $message)");
        if (_currentPlacement == AdService.primaryBannerPlacementId) {
          debugPrint("Unity Banner: Switching to fallback placement: ${AdService.fallbackBannerPlacementId}");
          if (mounted) {
            setState(() {
              _currentPlacement = AdService.fallbackBannerPlacementId;
            });
          }
        } else {
          debugPrint("Unity Banner: All placements failed.");
          if (mounted) {
            setState(() {
              _hasFailedCompletely = true;
            });
          }
          if (widget.onFailed != null) {
            widget.onFailed!(placementId, error, message);
          }
        }
      },
      onClick: (placementId) => debugPrint("Unity Banner Clicked: $placementId"),
      onShown: (placementId) => debugPrint("Unity Banner Shown: $placementId"),
    );
  }
}
