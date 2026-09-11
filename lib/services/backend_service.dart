import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  // 1. تحويل الكلاس إلى Singleton لضمان التحديث اللحظي
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  // 2. المتغيرات التي يستمع لها التطبيق
  final ValueNotifier<String> langNotifier = ValueNotifier<String>('ar');
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://your-flask-app.railway.app', // ضع رابط سيرفر Flask الخاص بك هنا
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  // تهيئة الإعدادات عند فتح التطبيق
  Future<void> initBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang') ?? 'ar';
    final savedTheme = prefs.getString('app_theme') ?? 'dark';
    
    langNotifier.value = savedLang;
    themeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  // تغيير اللغة لحظياً وحفظها
  Future<void> changeLanguage(String lang) async {
    langNotifier.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
  }

  // تغيير السمة لحظياً وحفظها
  Future<void> changeTheme(String theme) async {
    themeNotifier.value = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
  }

  // قاموس الترجمة البسيط
  String t(String key) {
    final ar = {
      'search': 'بحث', 'link': 'الروابط', 'downloads': 'تنزيلاتي', 'settings': 'إعدادات',
      'discover': 'اكتشف', 'search_hint': 'ابحث في يوتيوب...', 'start_search': 'ابدأ البحث الآن',
      'download_btn': 'تحميل', 'related': 'فيديوهات ذات صلة', 'have_link': 'لديك رابط؟',
      'paste_here': 'الصقه هنا لتحميله مباشرة', 'downloading': 'جاري التنزيل...',
      'completed': 'اكتمل التنزيل', 'formats_title': 'اختر الجودة المطلوبة',
      'video': 'فيديو', 'audio': 'صوت', 'downloaded': 'الملفات المحملة',
      'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 'notif': 'الإشعارات',
      'theme': 'السمة', 'language': 'اللغة', 'more_tools': 'أدوات إضافية',
      'share_app': 'شارك التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق'
    };
    final en = {
      'search': 'Search', 'link': 'Links', 'downloads': 'Downloads', 'settings': 'Settings',
      'discover': 'Discover', 'search_hint': 'Search YouTube...', 'start_search': 'Start searching now',
      'download_btn': 'Download', 'related': 'Related Videos', 'have_link': 'Have a link?',
      'paste_here': 'Paste it here to download', 'downloading': 'Downloading...',
      'completed': 'Download Completed', 'formats_title': 'Select Quality',
      'video': 'Video', 'audio': 'Audio', 'downloaded': 'Downloaded Files',
      'general': 'General', 'dl_settings': 'Download Settings', 'notif': 'Notifications',
      'theme': 'Theme', 'language': 'Language', 'more_tools': 'More Tools',
      'share_app': 'Share App', 'clean_cache': 'Clean Cache', 'about': 'About'
    };
    final fr = {
      'search': 'Recherche', 'link': 'Liens', 'downloads': 'Téléchargements', 'settings': 'Paramètres',
      'discover': 'Découvrir', 'search_hint': 'Rechercher sur YouTube...', 'start_search': 'Commencez la recherche',
      'download_btn': 'Télécharger', 'related': 'Vidéos similaires', 'have_link': 'Vous avez un lien ?',
      'paste_here': 'Collez-le ici', 'downloading': 'Téléchargement...',
      'completed': 'Téléchargement terminé', 'formats_title': 'Sélectionnez la qualité',
      'video': 'Vidéo', 'audio': 'Audio', 'downloaded': 'Fichiers téléchargés',
      'general': 'Général', 'dl_settings': 'Paramètres de téléchargement', 'notif': 'Notifications',
      'theme': 'Thème', 'language': 'Langue', 'more_tools': 'Plus d\'outils',
      'share_app': 'Partager l\'appli', 'clean_cache': 'Vider le cache', 'about': 'À propos'
    };
    
    if (langNotifier.value == 'en') return en[key] ?? key;
    if (langNotifier.value == 'fr') return fr[key] ?? key;
    return ar[key] ?? key;
  }

  Future<Map<String, dynamic>> extractMediaLinks(String url) async {
    try {
      final response = await _dio.post('/extract', data: {'url': url});
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to extract links');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> startDownloadProcess({
    required String downloadUrl,
    required String title,
    required String extension,
    required Function(double progress, String downloaded, String total) onProgress,
    required VoidCallback onComplete,
    required VoidCallback onError,
  }) async {
    try {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        if (int.parse(Platform.version.split('.')[0]) >= 13) {
          await Permission.photos.request();
          await Permission.videos.request();
          await Permission.audio.request();
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/Boykta');
        if (!await dir.exists()) await dir.create(recursive: true);
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final savePath = '${dir.path}/$cleanTitle.$extension';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final downloadedStr = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalStr = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress(progress, downloadedStr, totalStr);
          }
        },
      );
      onComplete();
    } catch (e) {
      onError();
    }
  }

  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/Boykta');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (await dir.exists()) {
        final List<FileSystemEntity> files = dir.listSync();
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        return files.where((f) => f is File).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, dynamic>> getDownloadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'downloadMobile': prefs.getBool('downloadMobile') ?? true,
      'download_path': prefs.getString('download_path') ?? '/storage/emulated/0/Download/Boykta',
      'max_tasks': prefs.getInt('max_tasks') ?? 4,
      'speed_limit': prefs.getString('speed_limit') ?? 'غير محدود',
    };
  }

  Future<void> updateDownloadSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'n_prog': prefs.getBool('n_prog') ?? true,
      'n_comp': prefs.getBool('n_comp') ?? true,
    };
  }

  Future<void> updateNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
