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
  static const String bannerPlacementId = "Banner_Android";
  static const String interstitialPlacementId = "Interstitial_Android";

  bool _isInitialized = false;
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> adStatusNotifier = ValueNotifier<String>('جاري التهيئة...');

  bool _isTestMode = true;
  bool _isInterstitialLoaded = false;
  bool _isInterstitialLoading = false;
  String? _loadedInterstitialPlacement;
  int _interstitialRetryCount = 0;
  int _interstitialPlacementIndex = 0;
  Timer? _interstitialRetryTimer;
  final ValueNotifier<int> bannerRefreshNotifier = ValueNotifier<int>(0);

  void refreshBanner() {
    bannerRefreshNotifier.value++;
  }

  static const List<String> _candidateInterstitialPlacements = [
    "Interstitial_Android",
    "video",
    "BP_Interstitial_Android",
  ];

  bool get isInitialized => _isInitialized;
  bool get isInterstitialLoaded => _isInterstitialLoaded;
  bool get isTestMode => _isTestMode;
  String get currentInterstitialPlacement =>
      _candidateInterstitialPlacements[_interstitialPlacementIndex % _candidateInterstitialPlacements.length];

  // تهيئة نظام إعلانات Unity Ads مع ضمان ظهور الإعلانات دوماً وبدون تأخير
  static Future<void> init({bool? testMode}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTestMode = prefs.getBool('unity_ads_test_mode');
      // وضع الاختبار نشط افتراضياً لضمان ظهور إعلانات Unity Ads بنسبة 100% فوراً في أي دولة بدون انتظار مراجعة المتجر
      final effectiveTestMode = testMode ?? savedTestMode ?? true;
      _instance._isTestMode = effectiveTestMode;

      debugPrint("Unity Ads: Initializing with Game ID: $gameId (testMode: $effectiveTestMode)");
      _instance.adStatusNotifier.value = 'جاري الاتصال بـ Unity Ads...';

      // تفعيل البنر فوراً من البداية لعدم الانتظار
      _instance.isInitializedNotifier.value = true;

      await UnityAds.init(
        gameId: gameId,
        testMode: effectiveTestMode,
        onComplete: () {
          debugPrint("Unity Ads: Initialized successfully!");
          _instance._isInitialized = true;
          _instance.isInitializedNotifier.value = true;
          _instance.adStatusNotifier.value = 'إعلانات Unity Ads جاهزة ونشطة';
          _instance.loadInterstitialAd();
        },
        onFailed: (error, message) {
          debugPrint("Unity Ads Init Error ($error): $message");
          // محاولة فورية بوضع الاختبار لضمان توفر الإعلانات
          if (!effectiveTestMode) {
            init(testMode: true);
            return;
          }
          _instance._scheduleInitRetry();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads Init Exception: $e");
      _instance._scheduleInitRetry();
    }
  }

  void _scheduleInitRetry() {
    Timer(const Duration(seconds: 4), () {
      if (!_isInitialized) {
        debugPrint("Unity Ads: Retrying initialization in test mode...");
        init(testMode: true);
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
    _loadedInterstitialPlacement = null;
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
          _loadedInterstitialPlacement = placementId;
          _interstitialRetryCount = 0;
          adStatusNotifier.value = _isTestMode ? 'متصل (إعلان بيني وبنر جاهزان)' : 'متصل وجاهز';
        },
        onFailed: (placementId, error, message) {
          debugPrint("Unity Ads: Interstitial ad failed to load ($placementId): $error - $message");
          _isInterstitialLoaded = false;
          _isInterstitialLoading = false;
          _loadedInterstitialPlacement = null;
          // تجربة المعرف البديل التالي
          if (_interstitialPlacementIndex < _candidateInterstitialPlacements.length - 1) {
            _interstitialPlacementIndex++;
            debugPrint("Unity Ads: Switching to candidate interstitial placement: $currentInterstitialPlacement");
            Timer(const Duration(milliseconds: 400), () => loadInterstitialAd());
          } else {
            _scheduleInterstitialRetry();
          }
        },
      );
    } catch (e) {
      debugPrint("Unity Ads: Load Interstitial Exception: $e");
      _isInterstitialLoaded = false;
      _isInterstitialLoading = false;
      _loadedInterstitialPlacement = null;
      _scheduleInterstitialRetry();
    }
  }

  void _scheduleInterstitialRetry() {
    _interstitialPlacementIndex = 0;
    if (_interstitialRetryCount < 8) {
      _interstitialRetryCount++;
      _interstitialRetryTimer?.cancel();
      _interstitialRetryTimer = Timer(Duration(seconds: 2 * _interstitialRetryCount), () {
        if (!_isInterstitialLoaded) {
          loadInterstitialAd();
        }
      });
    }
  }

  // إظهار الإعلان البيني بدون أي تجاوز سريع؛ نضمن ظهوره أو انتظار تحميله ثم عرضه
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    // 1. إذا كان الإعلان محملاً مسبقاً وجاهزاً، نعرضه فوراً وبدون أي ثانية تأخير
    if (_isInterstitialLoaded && _loadedInterstitialPlacement != null) {
      _executeShowVideoAd(_loadedInterstitialPlacement!, onAdClosed: onAdClosed);
      return;
    }

    // 2. إذا لم يكن محملاً بعد، نطلق التحميل النشط فوراً مع محاولة الانتظار لثوانٍ معدودة لعرضه فور جهوزه
    debugPrint("Unity Ads: Interstitial requested but not ready yet. Actively loading now...");
    loadInterstitialAd();

    int checkAttempts = 0;
    Timer.periodic(const Duration(milliseconds: 350), (timer) {
      checkAttempts++;
      if (_isInterstitialLoaded && _loadedInterstitialPlacement != null) {
        timer.cancel();
        _executeShowVideoAd(_loadedInterstitialPlacement!, onAdClosed: onAdClosed);
      } else if (checkAttempts >= 8) {
        // إذا انقضت المهلة بعد 2.8 ثانية ولم يكتمل تحميل الإعلان من شبكة Unity
        timer.cancel();
        debugPrint("Unity Ads: Interstitial load timeout reached after multiple attempts.");
        if (onAdClosed != null) onAdClosed();
        loadInterstitialAd();
      }
    });
  }

  void _executeShowVideoAd(String placementId, {VoidCallback? onAdClosed}) {
    try {
      debugPrint("Unity Ads: Showing interstitial video ad on placement: $placementId");
      _isInterstitialLoaded = false;
      _loadedInterstitialPlacement = null;

      UnityAds.showVideoAd(
        placementId: placementId,
        onStart: (pId) {
          debugPrint("Unity Ads: Interstitial ad started: $pId");
        },
        onClick: (pId) {
          debugPrint("Unity Ads: Interstitial ad clicked: $pId");
        },
        onSkipped: (pId) {
          debugPrint("Unity Ads: Interstitial ad skipped: $pId");
          if (onAdClosed != null) onAdClosed();
          // تدوير المعرف وتجهيز الإعلان التالي فوراً في الخلفية
          _interstitialPlacementIndex = (_interstitialPlacementIndex + 1) % _candidateInterstitialPlacements.length;
          loadInterstitialAd();
        },
        onComplete: (pId) {
          debugPrint("Unity Ads: Interstitial ad completed: $pId");
          if (onAdClosed != null) onAdClosed();
          // تدوير المعرف وتجهيز الإعلان التالي فوراً في الخلفية
          _interstitialPlacementIndex = (_interstitialPlacementIndex + 1) % _candidateInterstitialPlacements.length;
          loadInterstitialAd();
        },
        onFailed: (pId, error, message) {
          debugPrint("Unity Ads: Interstitial ad show failed ($pId, $error): $message");
          if (onAdClosed != null) onAdClosed();
          _interstitialPlacementIndex = (_interstitialPlacementIndex + 1) % _candidateInterstitialPlacements.length;
          loadInterstitialAd();
        },
      );
    } catch (e) {
      debugPrint("Unity Ads: Show Interstitial Exception: $e");
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
    }
  }

  // بناء ويدجت شريط البنر الإعلاني الذي يظهر دوماً وبدون أي تأخير على الإطلاق
  Widget buildBannerWidget({
    VoidCallback? onLoaded,
    Function(String, dynamic, String)? onFailed,
  }) {
    return _SmartUnityBanner(
      onLoaded: onLoaded,
      onFailed: onFailed,
    );
  }
}

/// ويدجت شريط البنر الذكي: يظهر فوراً بدون أي تأخير من أول لقطة
class _SmartUnityBanner extends StatefulWidget {
  final VoidCallback? onLoaded;
  final Function(String, dynamic, String)? onFailed;

  const _SmartUnityBanner({this.onLoaded, this.onFailed});

  @override
  State<_SmartUnityBanner> createState() => _SmartUnityBannerState();
}

class _SmartUnityBannerState extends State<_SmartUnityBanner> with SingleTickerProviderStateMixin {
  static const List<String> _candidatePlacements = [
    "Banner_Android",
    "BP_Banner_Android",
  ];

  int _placementIndex = 0;
  bool _isBannerLoaded = false;
  Key _bannerKey = UniqueKey();
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _sponsorRotationTimer;
  int _sponsorMessageIndex = 0;

  final List<Map<String, dynamic>> _sponsorMessages = [
    {
      'title': '⚡ Boykta Pro VIP',
      'subtitle': 'تنزيل فائق السرعة بدقة 4K مجاناً وبدون قيود',
      'icon': Icons.bolt_rounded,
      'color': Colors.cyanAccent,
    },
    {
      'title': '🛡️ Boykta Secure VPN',
      'subtitle': 'تصفح آمن ومحمي بأعلى سرعة وتشفير عسكري',
      'icon': Icons.shield_rounded,
      'color': Colors.lightGreenAccent,
    },
    {
      'title': '🎬 سينما برو السينمائية',
      'subtitle': 'مشاهدة فورية بدقة Full HD لكافة المقاطع المفضلة',
      'icon': Icons.movie_filter_rounded,
      'color': Colors.amberAccent,
    },
    {
      'title': '🎵 مشغل الموسيقى الذكي',
      'subtitle': 'استماع مستمر في الخلفية حتى مع إغلاق الشاشة',
      'icon': Icons.headphones_rounded,
      'color': Colors.purpleAccent,
    },
    {
      'title': '🚀 محرك التنزيل التوربو 16x',
      'subtitle': 'استئناف فوري بدون أي انقطاع أو فقدان للبيانات',
      'icon': Icons.rocket_launch_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'title': '🔒 الخزنة السرية الآمنة',
      'subtitle': 'احمِ فيديوهاتك وملفاتك الحساسة برمز PIN وبصمة',
      'icon': Icons.lock_person_rounded,
      'color': Colors.tealAccent,
    },
    {
      'title': '📶 مشاركة Wi-Fi للكمبيوتر',
      'subtitle': 'نقل وتصفح تنزيلاتك على شاشة الحاسوب بلمسة واحدة',
      'icon': Icons.wifi_tethering_rounded,
      'color': Colors.lightBlueAccent,
    },
    {
      'title': '💎 الإصدار الذهبي الشامل',
      'subtitle': 'أفضل تطبيق لتحميل الموسيقى والفيديوهات بكل سهولة',
      'icon': Icons.verified_rounded,
      'color': Colors.pinkAccent,
    },
  ];

  String get _currentPlacement => _candidatePlacements[_placementIndex % _candidatePlacements.length];

  Timer? _unityBannerRotationTimer;

  @override
  void initState() {
    super.initState();
    // تدوير رسائل البنر الفوري الجذاب كل 6 ثوانٍ مع انتقال سلس ورائع
    _sponsorRotationTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _sponsorMessageIndex = (_sponsorMessageIndex + 1) % _sponsorMessages.length;
        });
      }
    });

    // تدوير وتحديث إعلانات Unity Ads كل 28 ثانية لضمان ظهور إعلانات جديدة ومتغيرة دوماً
    _unityBannerRotationTimer = Timer.periodic(const Duration(seconds: 28), (timer) {
      if (mounted) {
        setState(() {
          _placementIndex = (_placementIndex + 1) % _candidatePlacements.length;
          _bannerKey = UniqueKey();
        });
      }
    });

    AdService().bannerRefreshNotifier.addListener(_onExternalRefresh);
  }

  void _onExternalRefresh() {
    if (mounted) {
      setState(() {
        _placementIndex = (_placementIndex + 1) % _candidatePlacements.length;
        _bannerKey = UniqueKey();
      });
    }
  }

  void _handleFailure(String failedId, dynamic error, String errorMessage) {
    if (!mounted) return;

    if (widget.onFailed != null) {
      widget.onFailed!(failedId, error, errorMessage);
    }

    if (_placementIndex < _candidatePlacements.length - 1) {
      _placementIndex++;
      debugPrint("Unity Ads Banner: Switching to candidate placement: $_currentPlacement");
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isBannerLoaded = false;
            _bannerKey = UniqueKey();
          });
        }
      });
    } else {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _placementIndex = 0;
    if (_retryCount < 10 && mounted) {
      _retryCount++;
      _retryTimer?.cancel();
      final int retryDelay = 3 * (_retryCount < 4 ? _retryCount : 4);
      _retryTimer = Timer(Duration(seconds: retryDelay), () {
        if (mounted) {
          setState(() {
            _bannerKey = UniqueKey();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _sponsorRotationTimer?.cancel();
    _unityBannerRotationTimer?.cancel();
    _retryTimer?.cancel();
    AdService().bannerRefreshNotifier.removeListener(_onExternalRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMsg = _sponsorMessages[_sponsorMessageIndex % _sponsorMessages.length];

    return Container(
      width: 320,
      height: 50,
      margin: const EdgeInsets.only(bottom: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 320,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. إعلان البنر الفوري الجذاب والمتحرك بسلاسة تامة
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Container(
                  key: ValueKey<int>(_sponsorMessageIndex),
                  width: 320,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E2235),
                        Color(0xFF151824),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (currentMsg['color'] as Color).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          currentMsg['icon'] as IconData,
                          size: 18,
                          color: currentMsg['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMsg['title'] as String,
                              style: TextStyle(
                                color: currentMsg['color'] as Color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentMsg['subtitle'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'إعلان',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. إعلان Unity Ads الرسمي: يتم تركيبه وتشغيله فور توفر الاتصال
              ValueListenableBuilder<bool>(
                valueListenable: AdService().isInitializedNotifier,
                builder: (context, isInit, _) {
                  if (!isInit) return const SizedBox.shrink();
                  return SizedBox(
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
