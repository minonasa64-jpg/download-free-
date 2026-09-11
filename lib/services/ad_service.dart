import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  // معرفات الاختبار الرسمية من Google AdMob لأجهزة Android
  // (عندما تنشئ حساب AdMob، استبدلها بوحداتك الإعلانية الحقيقية)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // تهيئة النظام
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // تحميل إعلان بيني مسبقاً في الخلفية
  void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint("Interstitial Ad loaded successfully.");

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd(); // تحميل إعلان آخر للعملية القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          debugPrint("Failed to load Interstitial Ad: ${error.message}");
        },
      ),
    );
  }

  // إظهار الإعلان البيني
  void showInterstitialAd({VoidCallback? onAdClosed}) {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitialAd(); // إعادة التحميل للمرة القادمة
      if (onAdClosed != null) onAdClosed();
    } else {
      loadInterstitialAd();
      if (onAdClosed != null) onAdClosed();
    }
  }

  // إنشاء إعلان بنر جاهز للعرض
  BannerAd createBannerAd({required Function() onAdLoaded}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }
}
