import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'services/backend_service.dart';
import 'ui/splash_screen.dart';

void main() async {
  // 1. التأكد من تهيئة واجهة فلاتر الأساسية قبل تشغيل أي شيء
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة خدمات الباك-إند (مثل جلب اللغة المحفوظة والسمة)
  await BackendService().initBackend();

  // 3. جعل شريط الحالة (Status Bar) شفافاً ليتناسب مع التصميم الفخم
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 4. قفل اتجاه الشاشة على الوضع العمودي للحفاظ على تناسق التصميم
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const BoyktaApp());
}

class BoyktaApp extends StatelessWidget {
  const BoyktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boykta',
      debugShowCheckedModeBanner: false, // إخفاء شريط Debug
      
      // نعتمد على الثيم الداكن الفخم الذي صممناه في مجلد core
      themeMode: ThemeMode.dark, 
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      
      // تحديد اتجاه النص (عربي افتراضياً لدعم RTL)
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      
      // الشاشة الأولى التي سيتم تشغيلها هي شاشة الأنيميشن
      home: const SplashScreen(),
    );
  }
}
