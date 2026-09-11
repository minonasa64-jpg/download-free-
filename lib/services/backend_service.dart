import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// كلاس جديد لتتبع التنزيلات النشطة
class DownloadTask {
  final int id;
  final String title;
  final bool isAudio;
  double progress;
  String downloaded;
  String total;

  DownloadTask({
    required this.id,
    required this.title,
    required this.isAudio,
    this.progress = 0.0,
    this.downloaded = "0.0",
    this.total = "0.0",
  });
}

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final ValueNotifier<String> langNotifier = ValueNotifier<String>('ar');
  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  
  // قائمة التنزيلات النشطة لمراقبتها في واجهة المستخدم
  final ValueNotifier<List<DownloadTask>> activeDownloads = ValueNotifier([]);

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://Download-free-online-production.up.railway.app', 
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  Future<void> initBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang') ?? 'ar';
    final savedTheme = prefs.getString('app_theme') ?? 'dark';
    
    langNotifier.value = savedLang;
    themeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;

    // تهيئة الإشعارات
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> changeLanguage(String lang) async {
    langNotifier.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
  }

  Future<void> changeTheme(String theme) async {
    themeNotifier.value = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
  }

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
      final formData = FormData.fromMap({'url': url});
      final response = await _dio.post('/api/extract', data: formData);
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'success') {
           List<Map<String, dynamic>> videoList = [];
           List<Map<String, dynamic>> audioList = [];

           for (var f in data['formats'] ?? []) {
             bool isAudioOnly = (f['vcodec'] == 'none' || f['vcodec'] == null) && f['acodec'] != 'none';
             
             String sizeStr = 'Unknown';
             if (f['filesize'] != null) {
               try {
                 double sizeMb = (double.parse(f['filesize'].toString()) / (1024 * 1024));
                 sizeStr = sizeMb.toStringAsFixed(1);
               } catch (_) {}
             }

             Map<String, dynamic> formatData = {
               'quality_name': f['format_note'] ?? f['resolution'] ?? f['format_id'] ?? 'Unknown',
               'url': f['url'],
               'ext': f['ext'] ?? 'mp4',
               'size': sizeStr
             };

             if (isAudioOnly) {
               if (formatData['ext'] == 'mp3' || formatData['ext'] == 'm4a') {
                 audioList.add(formatData);
               }
             } else {
               videoList.add(formatData);
             }
           }
           
           return {
             'title': data['title'],
             'video': videoList,
             'audio': audioList,
           };
        } else {
          throw Exception(data['message'] ?? 'Unknown error from server');
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        String serverErrorMsg = 'Server Rejected: ${e.response?.statusCode}';
        try {
          if (e.response?.data != null && e.response?.data is Map) {
            final data = e.response?.data as Map;
            if (data.containsKey('message')) {
              serverErrorMsg = data['message'].toString();
            }
          }
        } catch (_) {}
        throw Exception(serverErrorMsg);
      } else {
        throw Exception('Connection Timeout or Server Offline');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> startDownloadProcess({
    required String downloadUrl,
    required String title,
    required String extension,
    required bool isAudio,
  }) async {
    try {
      if (Platform.isAndroid) {
        final sdkInt = int.tryParse(Platform.version.split('.')[0]) ?? 0;
        if (sdkInt >= 13) {
          await Permission.photos.request();
          await Permission.videos.request();
          await Permission.audio.request();
          await Permission.notification.request(); // طلب صلاحية الإشعارات
        } else {
          await Permission.storage.request();
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      if (dir == null) throw Exception("Could not find storage directory");

      final boyktaDir = Directory('${dir.path}/Boykta');
      if (!await boyktaDir.exists()) {
        await boyktaDir.create(recursive: true);
      }

      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final savePath = '${boyktaDir.path}/$cleanTitle.$extension';

      // إعداد التنزيل في الخلفية
      int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      DownloadTask task = DownloadTask(id: notifId, title: cleanTitle, isAudio: isAudio);
      
      // إضافة التنزيل لقائمة الانتظار في واجهة المستخدم
      List<DownloadTask> currentList = List.from(activeDownloads.value);
      currentList.add(task);
      activeDownloads.value = currentList;

      int lastUpdate = 0; // لعدم إرهاق الهاتف بكثرة الإشعارات

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final downloadedStr = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalStr = (total / (1024 * 1024)).toStringAsFixed(1);
            
            task.progress = progress;
            task.downloaded = downloadedStr;
            task.total = totalStr;

            int now = DateTime.now().millisecondsSinceEpoch;
            // تحديث الإشعار كل ثانية واحدة فقط لضمان السلاسة
            if (now - lastUpdate > 1000) {
              lastUpdate = now;
              activeDownloads.value = List.from(activeDownloads.value); // تحديث الشاشة
              
              _notificationsPlugin.show(
                notifId,
                'جاري التنزيل: $cleanTitle',
                '$downloadedStr MB / $totalStr MB',
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'download_channel',
                    'تنزيلات Boykta',
                    channelDescription: 'يظهر تقدم التنزيل',
                    importance: Importance.low,
                    priority: Priority.low,
                    showProgress: true,
                    maxProgress: 100,
                    progress: (progress * 100).toInt(),
                    ongoing: true,
                    onlyAlertOnce: true,
                  ),
                ),
              );
            }
          }
        },
      );
      
      // تحديث الإعدادات
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_path', boyktaDir.path);
      
      // عند الانتهاء: مسح الإشعار القديم وعرض إشعار النجاح وحذف من القائمة
      activeDownloads.value = activeDownloads.value.where((t) => t.id != notifId).toList();
      _notificationsPlugin.cancel(notifId);
      
      _notificationsPlugin.show(
        notifId + 1,
        'اكتمل التنزيل بنجاح 🎉',
        cleanTitle,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'download_channel',
            'تنزيلات Boykta',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

    } catch (e) {
      // في حالة الخطأ، إزالة من القائمة
      activeDownloads.value = activeDownloads.value.where((t) => t.title != title).toList();
    }
  }

  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedPath = prefs.getString('download_path');
      
      Directory? dir;
      if (savedPath != null) {
        dir = Directory(savedPath);
      } else {
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory();
          if (dir != null) dir = Directory('${dir.path}/Boykta');
        } else {
          dir = await getApplicationDocumentsDirectory();
          dir = Directory('${dir.path}/Boykta');
        }
      }

      if (dir != null && await dir.exists()) {
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
      'download_path': prefs.getString('download_path') ?? 'المسار الآمن (Boykta)',
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
