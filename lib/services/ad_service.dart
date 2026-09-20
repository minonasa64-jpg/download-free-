import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // معرّف تطبيق Start.io (StartApp App ID)
  static const String appId = "208601935";

  final StartAppSdk _sdk = StartAppSdk();
  bool _isInitialized = false;
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);

  StartAppInterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _interstitialRetryCount = 0;
  Timer? _interstitialRetryTimer;

  // تهيئة نظام إعلانات Start.io
  static Future<void> init() async {
    try {
      debugPrint("Start.io Ads: Initializing with App ID: $appId");
      // تمكين وضع إعلانات الاختبار افتراضياً لضمان ظهور إعلانات البنر والبيني بنسبة 100% دون حظر أو 0% Fill
      await _instance._sdk.setTestAdsEnabled(true);
      _instance._isInitialized = true;
      _instance.isInitializedNotifier.value = true;
      debugPrint("Start.io Ads: Initialized successfully with test mode enabled!");

      // تحميل إعلان بيني مسبقاً في الخلفية
      _instance.loadInterstitialAd();
    } catch (e) {
      debugPrint("Start.io Ads Init Exception: $e");
      _instance._isInitialized = false;
      _instance.isInitializedNotifier.value = false;
    }
  }

  /// تبديل وضع الإعلانات (اختبار أو إعلانات حقيقية)
  Future<void> setTestMode(bool enabled) async {
    try {
      await _sdk.setTestAdsEnabled(enabled);
      debugPrint("Start.io Ads: Test mode set to $enabled");
      loadInterstitialAd();
    } catch (e) {
      debugPrint("Start.io Ads: Error setting test mode: $e");
    }
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية مع إعادة محاولة ذكية
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    try {
      debugPrint("Start.io: Loading interstitial ad (attempt ${_interstitialRetryCount + 1})...");
      _sdk.loadInterstitialAd(
        onAdDisplayed: () {
          debugPrint("Start.io: Interstitial ad displayed");
        },
        onAdNotDisplayed: () {
          debugPrint("Start.io: Interstitial ad not displayed");
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialLoading = false;
          _scheduleInterstitialRetry();
        },
        onAdHidden: () {
          debugPrint("Start.io: Interstitial ad hidden");
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
          // إعادة تحميل إعلان جديد بعد الإغلاق ليكون جاهزاً للمرة القادمة
          loadInterstitialAd();
        },
        onAdClicked: () {
          debugPrint("Start.io: Interstitial ad clicked");
        },
      ).then((ad) {
        _interstitialAd = ad;
        _isInterstitialLoading = false;
        _interstitialRetryCount = 0;
        debugPrint("Start.io: Interstitial ad loaded successfully and ready!");
      }).catchError((err) {
        _isInterstitialLoading = false;
        debugPrint("Start.io: Failed to load interstitial ad: $err");
        _scheduleInterstitialRetry();
      });
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint("Start.io: Interstitial load exception: $e");
      _scheduleInterstitialRetry();
    }
  }

  void _scheduleInterstitialRetry() {
    if (_interstitialRetryCount < 6) {
      _interstitialRetryCount++;
      _interstitialRetryTimer?.cancel();
      _interstitialRetryTimer = Timer(Duration(seconds: 3 * _interstitialRetryCount), () {
        loadInterstitialAd();
      });
    }
  }

  // إظهار الإعلان البيني عند التنزيل أو التنقل
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (!_isInitialized || _interstitialAd == null) {
      debugPrint("Start.io: No interstitial ad ready yet. Proceeding with user action.");
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
      return;
    }

    try {
      debugPrint("Start.io: Showing interstitial ad...");
      final currentAd = _interstitialAd;
      _interstitialAd = null;

      currentAd!.show().then((shown) {
        debugPrint("Start.io: Interstitial show result: $shown");
        if (onAdClosed != null) onAdClosed();
        loadInterstitialAd();
      }).catchError((err) {
        debugPrint("Start.io: Error showing interstitial ad: $err");
        if (onAdClosed != null) onAdClosed();
        loadInterstitialAd();
      });
    } catch (e) {
      debugPrint("Start.io: Show Interstitial Exception: $e");
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
        return _SmartStartAppBanner(
          onLoaded: onLoaded,
          onFailed: onFailed,
        );
      },
    );
  }
}

/// ويدجت شريط البنر الإعلاني لـ Start.io مع إعادة المحاولة التلقائية
class _SmartStartAppBanner extends StatefulWidget {
  final VoidCallback? onLoaded;
  final Function(String, dynamic, String)? onFailed;

  const _SmartStartAppBanner({this.onLoaded, this.onFailed});

  @override
  State<_SmartStartAppBanner> createState() => _SmartStartAppBannerState();
}

class _SmartStartAppBannerState extends State<_SmartStartAppBanner> {
  StartAppBannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (_isLoading || !mounted) return;
    _isLoading = true;

    try {
      debugPrint("Start.io Banner: Requesting banner ad (attempt ${_retryCount + 1})...");
      StartAppSdk().loadBannerAd(
        StartAppBannerType.BANNER,
        onAdImpression: () {
          debugPrint("Start.io Banner: Impression recorded");
        },
        onAdClicked: () {
          debugPrint("Start.io Banner: Ad clicked");
        },
      ).then((ad) {
        if (mounted) {
          setState(() {
            _bannerAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            _retryCount = 0;
          });
          if (widget.onLoaded != null) widget.onLoaded!();
          debugPrint("Start.io Banner: Banner displayed successfully!");
        }
      }).catchError((err) {
        debugPrint("Start.io Banner: Load failed ($err). Scheduling retry...");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          if (widget.onFailed != null) {
            widget.onFailed!("banner", err, err.toString());
          }
          _scheduleRetry();
        }
      });
    } catch (e) {
      debugPrint("Start.io Banner: Exception during load: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scheduleRetry();
      }
    }
  }

  void _scheduleRetry() {
    if (_retryCount < 8 && mounted) {
      _retryCount++;
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: 3 * _retryCount), () {
        if (mounted && !_isAdLoaded) {
          _loadBanner();
        }
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: 50,
      color: Colors.transparent,
      child: SizedBox(
        width: 320,
        height: 50,
        child: StartAppBanner(_bannerAd!),
      ),
    );
  }
}
