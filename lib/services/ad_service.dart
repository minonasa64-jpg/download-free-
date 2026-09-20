import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // معرّفات إعلانات Unity Ads (Android Game ID & Placements)
  static const String gameId = "800377154";
  static const String bannerPlacementId = "BP_Banner_Android34ab2d22-4cb2-45e9-bc8e-61fa749fbb8d";
  static const String interstitialPlacementId = "BP_Interstitial_Android34ab2d22-4cb2-45e9-bc8e-61fa749fbb8d";

  bool _isInitialized = false;
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);

  bool _isTestMode = false;
  bool _isInterstitialLoaded = false;
  bool _isInterstitialLoading = false;
  int _interstitialRetryCount = 0;
  Timer? _interstitialRetryTimer;

  bool get isInitialized => _isInitialized;
  bool get isInterstitialLoaded => _isInterstitialLoaded;

  // تهيئة نظام إعلانات Unity Ads
  static Future<void> init({bool testMode = false}) async {
    try {
      debugPrint("Unity Ads: Initializing with Game ID: $gameId (testMode: $testMode)");
      _instance._isTestMode = testMode;

      await UnityAds.init(
        gameId: gameId,
        testMode: testMode,
        onComplete: () {
          debugPrint("Unity Ads: Initialized successfully!");
          _instance._isInitialized = true;
          _instance.isInitializedNotifier.value = true;
          // بدء تحميل الإعلان البيني ليكون جاهزاً للاستخدام فوراً
          _instance.loadInterstitialAd();
        },
        onFailed: (error, message) {
          debugPrint("Unity Ads Init Error ($error): $message");
          _instance._isInitialized = false;
          _instance.isInitializedNotifier.value = false;
          // محاولة إعادة التهيئة لاحقاً بعد ثوانٍ قليلة في حال عدم استقرار الاتصال
          _instance._scheduleInitRetry();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads Init Exception: $e");
      _instance._isInitialized = false;
      _instance.isInitializedNotifier.value = false;
      _instance._scheduleInitRetry();
    }
  }

  void _scheduleInitRetry() {
    Timer(const Duration(seconds: 5), () {
      if (!_isInitialized) {
        debugPrint("Unity Ads: Retrying initialization...");
        init(testMode: _isTestMode);
      }
    });
  }

  /// تبديل وضع الإعلانات (اختبار أو إعلانات حقيقية)
  Future<void> setTestMode(bool enabled) async {
    _isTestMode = enabled;
    await init(testMode: enabled);
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية مع إعادة محاولة ذكية
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _isInterstitialLoaded) return;
    _isInterstitialLoading = true;

    try {
      debugPrint("Unity Ads: Loading interstitial ad for placement: $interstitialPlacementId (attempt ${_interstitialRetryCount + 1})...");
      UnityAds.load(
        placementId: interstitialPlacementId,
        onComplete: (placementId) {
          debugPrint("Unity Ads: Interstitial ad loaded successfully and ready! ($placementId)");
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
        },
        onFailed: (placementId, error, message) {
          debugPrint("Unity Ads: Interstitial ad failed to load ($placementId): $error - $message");
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          _scheduleInterstitialRetry();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads: Load Interstitial Exception: $e");
      _isInterstitialLoaded = false;
      _isInterstitialLoading = false;
      _scheduleInterstitialRetry();
    }
  }

  void _scheduleInterstitialRetry() {
    if (_interstitialRetryCount < 6) {
      _interstitialRetryCount++;
      _interstitialRetryTimer?.cancel();
      _interstitialRetryTimer = Timer(Duration(seconds: 3 * _interstitialRetryCount), () {
        if (!_isInterstitialLoaded) {
          loadInterstitialAd();
        }
      });
    }
  }

  // إظهار الإعلان البيني عند التنزيل أو التنقل مع حماية كاملة من تعليق واجهة المستخدم
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (!_isInitialized || !_isInterstitialLoaded) {
      debugPrint("Unity Ads: Interstitial not ready yet or SDK not initialized. Proceeding smoothly.");
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
      return;
    }

    try {
      debugPrint("Unity Ads: Showing interstitial video ad...");
      _isInterstitialLoaded = false;

      UnityAds.showVideoAd(
        placementId: interstitialPlacementId,
        onStart: (placementId) {
          debugPrint("Unity Ads: Interstitial ad started: $placementId");
        },
        onClick: (placementId) {
          debugPrint("Unity Ads: Interstitial ad clicked: $placementId");
        },
        onSkipped: (placementId) {
          debugPrint("Unity Ads: Interstitial ad skipped by user: $placementId");
          if (onAdClosed != null) onAdClosed();
          loadInterstitialAd();
        },
        onComplete: (placementId) {
          debugPrint("Unity Ads: Interstitial ad completed playback: $placementId");
          if (onAdClosed != null) onAdClosed();
          loadInterstitialAd();
        },
        onFailed: (placementId, error, message) {
          debugPrint("Unity Ads: Interstitial ad show failed ($error): $message");
          if (onAdClosed != null) onAdClosed();
          loadInterstitialAd();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads: Show Interstitial Exception: $e");
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
    }
  }

  // بناء ويدجت شريط البنر الإعلاني الذكي
  Widget buildBannerWidget({
    VoidCallback? onLoaded,
    Function(String, dynamic, String)? onFailed,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isInitializedNotifier,
      builder: (context, initialized, _) {
        if (!initialized) {
          return const SizedBox.shrink();
        }
        return _SmartUnityBanner(
          onLoaded: onLoaded,
          onFailed: onFailed,
        );
      },
    );
  }
}

/// ويدجت شريط البنر الإعلاني لـ Unity Ads مع إعادة المحاولة التلقائية والحماية من الفشل
class _SmartUnityBanner extends StatefulWidget {
  final VoidCallback? onLoaded;
  final Function(String, dynamic, String)? onFailed;

  const _SmartUnityBanner({this.onLoaded, this.onFailed});

  @override
  State<_SmartUnityBanner> createState() => _SmartUnityBannerState();
}

class _SmartUnityBannerState extends State<_SmartUnityBanner> {
  bool _isBannerLoaded = false;
  Key _bannerKey = UniqueKey();
  int _retryCount = 0;
  Timer? _retryTimer;

  void _scheduleRetry() {
    if (_retryCount < 8 && mounted) {
      _retryCount++;
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: 4 * _retryCount), () {
        if (mounted && !_isBannerLoaded) {
          setState(() {
            _bannerKey = UniqueKey();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 50,
      color: Colors.transparent,
      child: UnityBannerAd(
        key: _bannerKey,
        placementId: AdService.bannerPlacementId,
        size: BannerSize.standard,
        onLoad: (placementId) {
          debugPrint("Unity Ads Banner: Ad loaded successfully ($placementId)");
          if (mounted) {
            setState(() {
              _isBannerLoaded = true;
              _retryCount = 0;
            });
            if (widget.onLoaded != null) widget.onLoaded!();
          }
        },
        onClick: (placementId) {
          debugPrint("Unity Ads Banner: Ad clicked ($placementId)");
        },
        onShown: (placementId) {
          debugPrint("Unity Ads Banner: Ad shown ($placementId)");
        },
        onFailed: (placementId, error, errorMessage) {
          debugPrint("Unity Ads Banner: Load failed ($placementId): $error - $errorMessage");
          if (mounted) {
            if (widget.onFailed != null) {
              widget.onFailed!("banner", error, errorMessage);
            }
            _scheduleRetry();
          }
        },
      ),
    );
  }
}
