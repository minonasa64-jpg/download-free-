import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'core/theme_service.dart';
import 'services/backend_service.dart';
import 'services/ad_service.dart';
import 'services/telegram_analytics_service.dart';
import 'ui/main_navigation.dart';
import 'ui/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // حماية التطبيق من الانهيار إذا فشلت تهيئة الخدمات في الخلفية
  try {
    await BackendService().initBackend();
  } catch (e) {
    debugPrint('Backend Init Error: $e');
  }

  try {
    await ThemeService().init();
  } catch (e) {
    debugPrint('Theme Init Error: $e');
  }

  try {
    await AdService.init(); 
    AdService().loadInterstitialAd();
  } catch (e) {
    debugPrint('Unity Ads Init Error: $e');
  }

  // إحصائيات وتنبيهات تيليجرام التلقائية (تسجيل المستخدم الجديد والنشط)
  try {
    TelegramAnalyticsService().reportAppOpen(
      lang: BackendService().currentLang,
    );
  } catch (e) {
    debugPrint('Telegram Analytics Error: $e');
  }

  // انطلاق التطبيق بغض النظر عن أي أخطاء في الخلفية
  runApp(const BoyktaApp());
}

class BoyktaApp extends StatelessWidget {
  const BoyktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeConfig>(
      valueListenable: ThemeService().currentTheme,
      builder: (context, themeConfig, child) {
        return ValueListenableBuilder<String>(
          valueListenable: BackendService().langNotifier,
          builder: (context, currentLang, _) {
            final isRtl = currentLang == 'ar';
            return MaterialApp(
              key: ValueKey('boykta_app_${themeConfig.id}_$currentLang'),
              title: 'Boykta',
              debugShowCheckedModeBanner: false,
              theme: ThemeService().getThemeData(),
              builder: (context, child) {
                return Directionality(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: child!,
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
