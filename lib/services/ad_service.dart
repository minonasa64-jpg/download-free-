import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // معرّفات إعلانات Unity Ads (Android Game ID & Placements)
  static const String gameId = "800377154";
  static const String bannerPlacementId = "BP_Banner_Android";
  static const String interstitialPlacementId = "BP_Interstitial_Android";

  bool _isInitialized = false;
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> adStatusNotifier = ValueNotifier<String>('جاري التهيئة...');

  bool _isTestMode = true;
  bool _isInterstitialLoaded = false;
  bool _isInterstitialLoading = false;
  int _interstitialRetryCount = 0;
  int _interstitialPlacementIndex = 0;
  Timer? _interstitialRetryTimer;

  static const List<String> _candidateInterstitialPlacements = [
    interstitialPlacementId, // "BP_Interstitial_Android"
    "Interstitial_Android",
    "video",
    "Interstitial",
  ];

  bool get isInitialized => _isInitialized;
  bool get isInterstitialLoaded => _isInterstitialLoaded;
  bool get isTestMode => _isTestMode;
  String get currentInterstitialPlacement =>
      _candidateInterstitialPlacements[_interstitialPlacementIndex % _candidateInterstitialPlacements.length];

  // تهيئة نظام إعلانات Unity Ads مع قراءة التفضيلات المحفوظة
  static Future<void> init({bool? testMode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTestMode = prefs.getBool('unity_ads_test_mode');
      final effectiveTestMode = testMode ?? savedTestMode ?? true; // الافتراضي هو تفعيل وضع الاختبار لضمان الظهور الفوري
      _instance._isTestMode = effectiveTestMode;

      debugPrint("Unity Ads: Initializing with Game ID: $gameId (testMode: $effectiveTestMode)");
      _instance.adStatusNotifier.value = 'جاري الاتصال بـ Unity Ads...';

      await UnityAds.init(
        gameId: gameId,
        testMode: effectiveTestMode,
        onComplete: () {
          debugPrint("Unity Ads: Initialized successfully!");
          _instance._isInitialized = true;
          _instance.isInitializedNotifier.value = true;
          _instance.adStatusNotifier.value = effectiveTestMode ? 'متصل (وضع الاختبار نشط)' : 'متصل وجاهز (إعلانات حقيقية)';
          // بدء تحميل الإعلان البيني ليكون جاهزاً للاستخدام فوراً
          _instance.loadInterstitialAd();
        },
        onFailed: (error, message) {
          debugPrint("Unity Ads Init Error ($error): $message");
          _instance._isInitialized = false;
          _instance.isInitializedNotifier.value = false;
          _instance.adStatusNotifier.value = 'تعذر الاتصال ($error)';
          // محاولة إعادة التهيئة لاحقاً بعد ثوانٍ قليلة في حال عدم استقرار الاتصال
          _instance._scheduleInitRetry();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads Init Exception: $e");
      _instance._isInitialized = false;
      _instance.isInitializedNotifier.value = false;
      _instance.adStatusNotifier.value = 'خطأ في التهيئة';
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

  /// تبديل وضع الإعلانات وحفظه في الذاكرة
  Future<void> setTestMode(bool enabled) async {
    _isTestMode = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('unity_ads_test_mode', enabled);
    } catch (_) {}
    await init(testMode: enabled);
  }

  /// إعادة تحميل الإعلانات البينية والبنر فوراً
  Future<void> reloadAds() async {
    _isInterstitialLoaded = false;
    _isInterstitialLoading = false;
    _interstitialRetryCount = 0;
    _interstitialPlacementIndex = 0;
    await init(testMode: _isTestMode);
    loadInterstitialAd();
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية مع دعم المعرفات البديلة
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _isInterstitialLoaded) return;
    _isInterstitialLoading = true;

    final targetPlacement = currentInterstitialPlacement;

    try {
      debugPrint("Unity Ads: Loading interstitial ad for placement: $targetPlacement (attempt ${_interstitialRetryCount + 1})...");
      UnityAds.load(
        placementId: targetPlacement,
        onComplete: (placementId) {
          debugPrint("Unity Ads: Interstitial ad loaded successfully and ready! ($placementId)");
          _isInterstitialLoaded = true;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
          adStatusNotifier.value = _isTestMode ? 'متصل (إعلان بيني وبنر جاهزان)' : 'متصل وجاهز';
        },
        onFailed: (placementId, error, message) {
          debugPrint("Unity Ads: Interstitial ad failed to load ($placementId): $error - $message");
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          // تجربة المعرف البديل التالي
          if (_interstitialPlacementIndex < _candidateInterstitialPlacements.length - 1) {
            _interstitialPlacementIndex++;
            debugPrint("Unity Ads: Switching to candidate interstitial placement: $currentInterstitialPlacement");
            Timer(const Duration(milliseconds: 600), () => loadInterstitialAd());
          } else {
            _scheduleInterstitialRetry();
          }
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
    _interstitialPlacementIndex = 0;
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

    final targetPlacement = currentInterstitialPlacement;

    try {
      debugPrint("Unity Ads: Showing interstitial video ad ($targetPlacement)...");
      _isInterstitialLoaded = false;

      UnityAds.showVideoAd(
        placementId: targetPlacement,
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

/// ويدجت شريط البنر الإعلاني لـ Unity Ads بحجم ثابت 320x50 يمنع أخطاء القياس ويضمن ظهور الإعلان
class _SmartUnityBanner extends StatefulWidget {
  final VoidCallback? onLoaded;
  final Function(String, dynamic, String)? onFailed;

  const _SmartUnityBanner({this.onLoaded, this.onFailed});

  @override
  State<_SmartUnityBanner> createState() => _SmartUnityBannerState();
}

class _SmartUnityBannerState extends State<_SmartUnityBanner> {
  static const List<String> _candidatePlacements = [
    AdService.bannerPlacementId, // "BP_Banner_Android"
    "Banner_Android",            // Standard Unity Ads placement
    "banner",                    // Common shortcut placement
    "Banner",
  ];

  int _placementIndex = 0;
  bool _isBannerLoaded = false;
  Key _bannerKey = UniqueKey();
  int _retryCount = 0;
  Timer? _retryTimer;

  String get _currentPlacement => _candidatePlacements[_placementIndex % _candidatePlacements.length];

  void _handleFailure(String failedId, dynamic error, String errorMessage) {
    if (!mounted) return;

    if (widget.onFailed != null) {
      widget.onFailed!(failedId, error, errorMessage);
    }

    // إذا لم ينجح المعرف الحالي، نجرب المعرف التالي بعد مهلة قصيرة لتفادي حظر الطلبات السريعة
    if (_placementIndex < _candidatePlacements.length - 1) {
      _placementIndex++;
      debugPrint("Unity Ads Banner: Switching to candidate placement: $_currentPlacement");
      Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _isBannerLoaded = false;
            _bannerKey = UniqueKey();
          });
        }
      });
    } else {
      debugPrint("Unity Ads Banner: All candidate placements failed. Scheduling retry...");
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _placementIndex = 0;
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
      width: 320,
      height: 50,
      margin: const EdgeInsets.only(bottom: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _isBannerLoaded ? Colors.transparent : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 320,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // مؤشر خفيف يظهر أثناء انتظار رد السيرفر ويختفي تلقائياً عند ظهور الإعلان
              if (!_isBannerLoaded)
                Container(
                  width: 320,
                  height: 50,
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.cyan.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إعلان Unity Ads...',
                        style: TextStyle(
                          color: Colors.grey.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

              // ويدجت الإعلان الرسمي من Unity: قياس ثابت 320x50 يضمن قبول SDK للأبعاد
              SizedBox(
                width: 320,
                height: 50,
                child: UnityBannerAd(
                  key: _bannerKey,
                  placementId: _currentPlacement,
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
                    if (mounted && !_isBannerLoaded) {
                      setState(() {
                        _isBannerLoaded = true;
                      });
                    }
                  },
                  onFailed: (placementId, error, errorMessage) {
                    debugPrint("Unity Ads Banner: Load failed ($placementId): $error - $errorMessage");
                    _handleFailure(placementId, error, errorMessage);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
