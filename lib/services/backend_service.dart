import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  // قاموس الترجمة الشامل
  String t(String key) {
    final ar = {
      'search': 'بحث', 'link': 'الروابط', 'downloads': 'تنزيلاتي 📥', 'settings': 'إعدادات',
      'discover': 'اكتشف وحمّل', 'search_hint': 'ابحث في يوتيوب...', 
      'start_search': 'ابحث عن أي فيديو أو مقطع صوتي\nبجودة عالية وبكل سهولة',
      'download_btn': 'تحميل', 'related': 'فيديوهات ذات صلة', 'have_link': 'لديك رابط؟',
      'paste_here': 'الصقه هنا لتحميله مباشرة', 'downloading': 'جاري التنزيل...',
      'completed': 'اكتمل التنزيل', 'formats_title': 'اختر الجودة المطلوبة',
      'video': 'فيديوهات', 'audio': 'موسيقى', 'downloaded': 'الملفات المحملة',
      'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 'notif': 'الإشعارات',
      'theme': 'السمة', 'language': 'اللغة', 'more_tools': 'أدوات إضافية',
      'share_app': 'شارك التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق',
      'no_audio': 'لا توجد موسيقى محملة', 'no_video': 'لا توجد فيديوهات محملة',
      'downloading_now': 'جاري تنزيل:', 'file_not_found': 'الملف غير موجود أو تم حذفه',
      'no_results': 'لم نتمكن من العثور على أي نتائج 😔', 'search_error': 'حدث خطأ أثناء البحث. تحقق من الاتصال.',
    };
    final en = {
      'search': 'Search', 'link': 'Links', 'downloads': 'Downloads 📥', 'settings': 'Settings',
      'discover': 'Discover & Download', 'search_hint': 'Search YouTube...', 
      'start_search': 'Search for any video or audio\nin high quality easily',
      'download_btn': 'Download', 'related': 'Related Videos', 'have_link': 'Have a link?',
      'paste_here': 'Paste it here to download', 'downloading': 'Downloading...',
      'completed': 'Download Completed', 'formats_title': 'Select Quality',
      'video': 'Videos', 'audio': 'Music', 'downloaded': 'Downloaded Files',
      'general': 'General', 'dl_settings': 'Download Settings', 'notif': 'Notifications',
      'theme': 'Theme', 'language': 'Language', 'more_tools': 'More Tools',
      'share_app': 'Share App', 'clean_cache': 'Clean Cache', 'about': 'About',
      'no_audio': 'No music downloaded', 'no_video': 'No videos downloaded',
      'downloading_now': 'Downloading:', 'file_not_found': 'File not found or deleted',
      'no_results': 'No results found 😔', 'search_error': 'Search error. Check your connection.',
    };
    final fr = {
      'search': 'Recherche', 'link': 'Liens', 'downloads': 'Téléchargements 📥', 'settings': 'Paramètres',
      'discover': 'Découvrez et Téléchargez', 'search_hint': 'Rechercher sur YouTube...', 
      'start_search': 'Recherchez des vidéos ou des audios\nen haute qualité facilement',
      'download_btn': 'Télécharger', 'related': 'Vidéos similaires', 'have_link': 'Vous avez un lien ?',
      'paste_here': 'Collez-le ici', 'downloading': 'Téléchargement...',
      'completed': 'Téléchargement terminé', 'formats_title': 'Sélectionnez la qualité',
      'video': 'Vidéos', 'audio': 'Musique', 'downloaded': 'Fichiers téléchargés',
      'general': 'Général', 'dl_settings': 'Paramètres de téléchargement', 'notif': 'Notifications',
      'theme': 'Thème', 'language': 'Langue', 'more_tools': 'Plus d\'outils',
      'share_app': 'Partager l\'appli', 'clean_cache': 'Vider le cache', 'about': 'À propos',
      'no_audio': 'Aucune musique téléchargée', 'no_video': 'Aucune vidéo téléchargée',
      'downloading_now': 'Téléchargement:', 'file_not_found': 'Fichier introuvable ou supprimé',
      'no_results': 'Aucun résultat trouvé 😔', 'search_error': 'Erreur de recherche. Vérifiez votre connexion.',
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
          await Permission.notification.request();
        } else {
          await Permission.storage.request();
        }
      }

      Directory? dir;
      if (Platform.isAndroid) {
        // التعديل الجوهري: إجبار الحفظ في المسار العام لضمان ظهوره في المعرض وعدم حذفه
        dir = Directory('/storage/emulated/0/Download/Boykta');
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        dir = Directory('${docDir.path}/Boykta');
      }
      
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final savePath = '${dir.path}/$cleanTitle.$extension';

      int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      DownloadTask task = DownloadTask(id: notifId, title: cleanTitle, isAudio: isAudio);
      
      List<DownloadTask> currentList = List.from(activeDownloads.value);
      currentList.add(task);
      activeDownloads.value = currentList;

      int lastUpdate = 0; 

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
            if (now - lastUpdate > 1000) {
              lastUpdate = now;
              activeDownloads.value = List.from(activeDownloads.value);
              
              _notificationsPlugin.show(
                notifId,
                '${t('downloading_now')} $cleanTitle',
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
      
      activeDownloads.value = activeDownloads.value.where((t) => t.id != notifId).toList();
      _notificationsPlugin.cancel(notifId);
      
      _notificationsPlugin.show(
        notifId + 1,
        '🎉 ${t('completed')}',
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
      activeDownloads.value = activeDownloads.value.where((t) => t.title != title).toList();
    }
  }

  // التعديل الجوهري للبحث عن الملفات: قراءة المسار العام دائماً
  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/Boykta');
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        dir = Directory('${docDir.path}/Boykta');
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
