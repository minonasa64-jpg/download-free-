import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'services/backend_service.dart';
import 'services/ad_service.dart';
import 'ui/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الخدمات
  await BackendService().initBackend();
  await AdService.init(); // تهيئة إعلانات AdMob
  AdService().loadInterstitialAd(); // تحميل أول إعلان بيني في الذاكرة

  runApp(const BoyktaApp());
}

class BoyktaApp extends StatelessWidget {
  const BoyktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: BackendService().themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Boykta',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5FA),
            primaryColor: AppColors.cyan,
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.cyan,
          ),
          home: const MainNavigation(),
        );
      },
    );
  }
}
