import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'services/backend_service.dart';
import 'ui/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendService().initBackend();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const BoyktaApp());
}

class BoyktaApp extends StatelessWidget {
  const BoyktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendService();

    // الاستماع لتغييرات اللغة والسمة من الإعدادات لحظياً
    return ValueListenableBuilder<String>(
      valueListenable: backend.langNotifier,
      builder: (context, currentLang, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: backend.themeNotifier,
          builder: (context, currentTheme, child) {
            return MaterialApp(
              title: 'Boykta',
              debugShowCheckedModeBanner: false,
              themeMode: currentTheme, 
              theme: AppTheme.darkTheme, 
              darkTheme: AppTheme.darkTheme,
              builder: (context, childWidget) {
                return Directionality(
                  textDirection: currentLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: childWidget!,
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      }
    );
  }
}
