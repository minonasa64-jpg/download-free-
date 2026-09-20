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

  // تهيئة نظام إعلانات Start.io
  static Future<void> init() async {
    try {
      debugPrint("Start.io Ads: Initializing with App ID: $appId");
      // وضع الإعلانات الحقيقية (إيقاف وضع الاختبار)
      await _instance._sdk.setTestAdsEnabled(false);
      _instance._isInitialized = true;
      _instance.isInitializedNotifier.value = true;
      debugPrint("Start.io Ads: Initialized successfully!");

      // تحميل إعلان بيني مسبقاً في الخلفية
      _instance.loadInterstitialAd();
    } catch (e) {
      debugPrint("Start.io Ads Init Exception: $e");
      _instance._isInitialized = false;
      _instance.isInitializedNotifier.value = false;
    }
  }

  // تحميل الإعلان البيني مسبقاً في الخلفية
  void loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    try {
      debugPrint("Start.io: Loading interstitial ad...");
      _sdk.loadInterstitialAd(
        onAdDisplayed: () {
          debugPrint("Start.io: Interstitial ad displayed");
        },
        onAdNotDisplayed: () {
          debugPrint("Start.io: Interstitial ad not displayed");
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
        onAdHidden: () {
          debugPrint("Start.io: Interstitial ad hidden");
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isInterstitialLoading = false;
          // إعادة تحميل إعلان جديد بعد الإغلاق ليكون جاهزاً للمرة القادمة
          loadInterstitialAd();
        },
        onAdClicked: () {
          debugPrint("Start.io: Interstitial ad clicked");
        },
      ).then((ad) {
        _interstitialAd = ad;
        _isInterstitialLoading = false;
        debugPrint("Start.io: Interstitial ad loaded successfully!");
      }).catchError((err) {
        _isInterstitialLoading = false;
        debugPrint("Start.io: Failed to load interstitial ad: $err");
      });
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint("Start.io: Interstitial load exception: $e");
    }
  }

  // إظهار الإعلان البيني عند التنزيل أو التنقل
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (!_isInitialized || _interstitialAd == null) {
      debugPrint("Start.io: No interstitial ad ready. Proceeding without delay.");
      if (onAdClosed != null) onAdClosed();
      loadInterstitialAd();
      return;
    }

    try {
      debugPrint("Start.io: Showing interstitial ad...");
      _interstitialAd!.show().then((shown) {
        debugPrint("Start.io: Interstitial show returned: $shown");
        if (onAdClosed != null) onAdClosed();
        _interstitialAd = null;
        loadInterstitialAd();
      }).catchError((err) {
        debugPrint("Start.io: Error showing interstitial ad: $err");
        if (onAdClosed != null) onAdClosed();
        _interstitialAd = null;
        loadInterstitialAd();
      });
    } catch (e) {
      debugPrint("Start.io: Show Interstitial Exception: $e");
      if (onAdClosed != null) onAdClosed();
      _interstitialAd = null;
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

/// ويدجت شريط البنر الإعلاني لـ Start.io
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
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    try {
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
          });
          if (widget.onLoaded != null) widget.onLoaded!();
        }
      }).catchError((err) {
        debugPrint("Start.io Banner: Load failed: $err");
        if (mounted) {
          setState(() => _hasFailed = true);
          if (widget.onFailed != null) {
            widget.onFailed!("banner", err, err.toString());
          }
        }
      });
    } catch (e) {
      debugPrint("Start.io Banner: Exception during load: $e");
      if (mounted) {
        setState(() => _hasFailed = true);
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: 320,
        height: 50,
        child: StartAppBanner(_bannerAd!),
      ),
    );
  }
}
