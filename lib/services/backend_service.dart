import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  // تصميم النمط المفرد (Singleton) لضمان وجود نسخة واحدة من الباك إند تعمل في الخلفية
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  // ==========================================
  // 1. نواقل الحالة (State Notifiers) للغة والسمة
  // ==========================================
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<String> langNotifier = ValueNotifier('ar');

  // قاموس اللغات (مخزن في الباك إند لترتيب الكود)
  final Map<String, Map<String, String>> langMap = {
    'ar': {
      'search': 'بحث', 'link': 'رابط', 'downloads': 'تنزيلاتي', 'settings': 'الإعدادات',
      'discover': 'اكتشف فيديوهات جديدة', 'search_hint': 'ابحث في يوتيوب...', 'start_search': 'ابدأ البحث الآن',
      'have_link': 'لديك رابط مباشر؟', 'paste_here': 'ألصق الرابط هنا للتحميل', 'downloaded': 'تم التنزيل',
      'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 'notif': 'الإشعارات', 'theme': 'السمة', 'language': 'اللغة',
      'more_tools': 'أدوات إضافية', 'share_app': 'مشاركة التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق',
      'formats_title': 'المزيد من التنسيقات', 'audio': 'موسيقى', 'video': 'فيديو', 'download_btn': 'تنزيل',
      'related': 'فيديوهات ذات صلة', 'downloading': 'جاري التنزيل...', 'completed': 'اكتمل التنزيل بنجاح',
    },
    'en': {
      'search': 'Search', 'link': 'Link', 'downloads': 'Downloads', 'settings': 'Settings',
      'discover': 'Discover new videos', 'search_hint': 'Search YouTube...', 'start_search': 'Start searching now',
      'have_link': 'Have a direct link?', 'paste_here': 'Paste link here to download', 'downloaded': 'Downloaded',
      'general': 'General', 'dl_settings': 'Download Settings', 'notif': 'Notifications', 'theme': 'Theme', 'language': 'Language',
      'more_tools': 'More Tools', 'share_app': 'Share App', 'clean_cache': 'Clear Cache', 'about': 'About App',
      'formats_title': 'More Formats', 'audio': 'Audio', 'video': 'Video', 'download_btn': 'Download',
      'related': 'Related Videos', 'downloading': 'Downloading...', 'completed': 'Download Completed',
    },
    'fr': {
      'search': 'Recherche', 'link': 'Lien', 'downloads': 'Téléchargements', 'settings': 'Paramètres',
      'discover': 'Découvrir des vidéos', 'search_hint': 'Rechercher sur YouTube...', 'start_search': 'Commencez à chercher',
      'have_link': 'Lien direct ?', 'paste_here': 'Collez le lien ici', 'downloaded': 'Téléchargé',
      'general': 'Général', 'dl_settings': 'Téléchargement', 'notif': 'Notifications', 'theme': 'Thème', 'language': 'Langue',
      'more_tools': 'Outils', 'share_app': 'Partager', 'clean_cache': 'Vider le cache', 'about': 'À propos',
      'formats_title': 'Plus de formats', 'audio': 'Audio', 'video': 'Vidéo', 'download_btn': 'Télécharger',
      'related': 'Vidéos similaires', 'downloading': 'Téléchargement...', 'completed': 'Terminé',
    }
  };

  // دالة الترجمة السريعة
  String t(String key) {
    return langMap[langNotifier.value]?[key] ?? langMap['ar']![key] ?? key;
  }

  // ==========================================
  // 2. دالة التهيئة الأساسية (تُستدعى عند فتح التطبيق)
  // ==========================================
  Future<void> initBackend() async {
    final prefs = await SharedPreferences.getInstance();
    
    // تحميل السمة المحفوظة
    final savedTheme = prefs.getString('theme') ?? 'dark';
    themeNotifier.value = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
    
    // تحميل اللغة المحفوظة
    final savedLang = prefs.getString('lang') ?? 'ar';
    langNotifier.value = savedLang;
  }

  // دالة تغيير السمة
  Future<void> changeTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value);
    themeNotifier.value = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  // دالة تغيير اللغة
  Future<void> changeLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', value);
    langNotifier.value = value;
  }

  // ==========================================
  // 3. محرك الاستخراج الدقيق (الفصل بين الصوت والفيديو)
  // ==========================================
  Future<Map<String, List<Map<String, dynamic>>>> extractMediaLinks(String url) async {
    List<Map<String, dynamic>> audioList = [];
    List<Map<String, dynamic>> videoList = [];
    String videoTitle = 'فيديو بدون عنوان';

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final ytEngine = yt.YoutubeExplode();
      try {
        var video = await ytEngine.videos.get(url);
        videoTitle = video.title;
        var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
        
        // استخراج الفيديوهات (التي تحتوي على صوت مدمج)
        for (var stream in manifest.muxed) {
          String quality = '${stream.videoResolution.height}p';
          videoList.add({
            'quality_name': 'سريع ($quality)',
            'desc': 'جودة متوافقة مع الصوت',
            'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
            'url': stream.url.toString(),
            'ext': stream.container.name,
          });
        }

        // استخراج الصوتيات فقط
        for (var stream in manifest.audioOnly) {
          if (stream.container.name == 'mp4' || stream.container.name == 'm4a') {
            audioList.add({
              'quality_name': 'صوت (128K) M4A',
              'desc': 'الأفضل للتشغيل على الهاتف',
              'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
              'url': stream.url.toString(),
              'ext': 'm4a',
            });
          }
        }
      } finally {
        ytEngine.close();
      }
    } else {
      // للمنصات الأخرى عبر السيرفر الخارجي
      final dio = Dio();
      final response = await dio.post(
        'https://web-production-69773.up.railway.app/api/extract',
        data: {'url': url}
      );
      
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        videoTitle = response.data['title'] ?? 'فيديو بدون عنوان';
        final formats = response.data['formats'] as List;
        
        for (var f in formats) {
          String ext = f['ext'].toString().toLowerCase();
          String quality = f['quality'].toString();
          String size = f['filesize'] != null ? (f['filesize'] / (1024 * 1024)).toStringAsFixed(1) : 'غير محدد';
          
          if (ext == 'm4a' || ext == 'mp3') {
            audioList.add({
              'quality_name': 'صوت ($quality)',
              'desc': 'جودة صوت نقية',
              'size': size,
              'url': f['url'],
              'ext': ext
            });
          } else if (ext == 'mp4' || ext == 'webm') {
            videoList.add({
              'quality_name': 'فيديو ($quality)',
              'desc': 'جودة فيديو متوافقة',
              'size': size,
              'url': f['url'],
              'ext': ext
            });
          }
        }
      }
    }

    return {
      'title': [videoTitle], // تخزين العنوان في القائمة لتمريره للواجهة
      'audio': audioList,
      'video': videoList,
    };
  }

  // ==========================================
  // 4. نظام إدارة التحميل والصلاحيات الحقيقي
  // ==========================================
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      var manageStatus = await Permission.manageExternalStorage.request();
      var storageStatus = await Permission.storage.request();
      
      if (manageStatus.isGranted || storageStatus.isGranted) {
        return true;
      } else {
        return false;
      }
    }
    return true; // للأنظمة الأخرى
  }

  Future<void> startDownloadProcess({
    required String downloadUrl,
    required String title,
    required String extension,
    required Function(double progress, String downloaded, String total) onProgress,
    required Function() onComplete,
    required Function() onError,
  }) async {
    bool hasPermission = await requestStoragePermissions();
    if (!hasPermission) {
      onError();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      if (!basePath.endsWith('/')) {
        basePath += '/';
      }
      
      Directory(basePath).createSync(recursive: true);
      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = '$basePath$safeTitle.$extension';
      
      final dio = Dio();
      await dio.download(
        downloadUrl,
        savePath,
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            String downloadedStr = (received / (1024 * 1024)).toStringAsFixed(1);
            String totalStr = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress(progress, downloadedStr, totalStr);
          }
        },
      );
      
      onComplete();
    } catch (e) {
      onError();
    }
  }

  // ==========================================
  // 5. إدارة الملفات المكتملة
  // ==========================================
  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    List<FileSystemEntity> files = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      final dir = Directory(basePath);
      if (await dir.exists()) {
        files = dir.listSync().where((file) {
          return file.path.endsWith('.mp4') || 
                 file.path.endsWith('.m4a') || 
                 file.path.endsWith('.webm') || 
                 file.path.endsWith('.mp3');
        }).toList();
      }
    } catch (e) {
      // صمت (في حال عدم وجود المجلد بعد)
    }
    return files;
  }

  Future<void> deleteFile(String path) async {
    try {
      File(path).deleteSync();
    } catch (e) {
      // صمت
    }
  }

  // ==========================================
  // 6. دوال الإعدادات (قراءة وكتابة البيانات)
  // ==========================================
  // إعدادات التنزيل
  Future<Map<String, dynamic>> getDownloadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'downloadMobile': prefs.getBool('downloadMobile') ?? true,
      'download_path': prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader',
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

  // إعدادات الإشعارات
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'n_prog': prefs.getBool('n_prog') ?? true,
      'n_comp': prefs.getBool('n_comp') ?? true,
      'n_recom': prefs.getBool('n_recom') ?? false,
      'n_tool': prefs.getBool('n_tool') ?? true,
      'n_toolbar': prefs.getBool('n_toolbar') ?? true,
    };
  }

  Future<void> updateNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
