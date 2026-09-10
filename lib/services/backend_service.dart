import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<String> langNotifier = ValueNotifier('ar');

  // تم تحديث الرابط بالنطاق الجديد مع بروتوكول الأمان HTTPS
  final String serverUrl = 'https://download-free-online-production.up.railway.app';
  
  final Map<String, Map<String, String>> langMap = {
    'ar': {
      'search': 'بحث', 'link': 'رابط', 'downloads': 'تنزيلاتي', 'settings': 'الإعدادات',
      'discover': 'اكتشف فيديوهات جديدة', 'search_hint': 'ابحث في يوتيوب...', 'start_search': 'ابدأ البحث الآن',
      'have_link': 'لديك رابط مباشر؟', 'paste_here': 'ألصق الرابط هنا للتحميل', 'downloaded': 'تم التنزيل',
      'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 'notif': 'الإشعارات', 'theme': 'السمة', 'language': 'اللغة',
      'more_tools': 'أدوات إضافية', 'share_app': 'مشاركة التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق',
      'formats_title': 'تنسيقات الفيديو المتاحة', 'video': 'فيديو', 'download_btn': 'تنزيل',
      'related': 'فيديوهات ذات صلة', 'downloading': 'جاري التنزيل...', 'completed': 'اكتمل التنزيل بنجاح',
    },
    'en': {
      'search': 'Search', 'link': 'Link', 'downloads': 'Downloads', 'settings': 'Settings',
      'discover': 'Discover new videos', 'search_hint': 'Search YouTube...', 'start_search': 'Start searching now',
      'have_link': 'Have a direct link?', 'paste_here': 'Paste link here to download', 'downloaded': 'Downloaded',
      'general': 'General', 'dl_settings': 'Download Settings', 'notif': 'Notifications', 'theme': 'Theme', 'language': 'Language',
      'more_tools': 'More Tools', 'share_app': 'Share App', 'clean_cache': 'Clear Cache', 'about': 'About App',
      'formats_title': 'Available Video Formats', 'video': 'Video', 'download_btn': 'Download',
      'related': 'Related Videos', 'downloading': 'Downloading...', 'completed': 'Download Completed',
    },
    'fr': {
      'search': 'Recherche', 'link': 'Lien', 'downloads': 'Téléchargements', 'settings': 'Paramètres',
      'discover': 'Découvrir des vidéos', 'search_hint': 'Rechercher sur YouTube...', 'start_search': 'Commencez à chercher',
      'have_link': 'Lien direct ?', 'paste_here': 'Collez le lien ici', 'downloaded': 'Téléchargé',
      'general': 'Général', 'dl_settings': 'Téléchargement', 'notif': 'Notifications', 'theme': 'Thème', 'language': 'Langue',
      'more_tools': 'Outils', 'share_app': 'Partager', 'clean_cache': 'Vider le cache', 'about': 'À propos',
      'formats_title': 'Formats disponibles', 'video': 'Vidéo', 'download_btn': 'Télécharger',
      'related': 'Vidéos similaires', 'downloading': 'Téléchargement...', 'completed': 'Terminé',
    }
  };

  String t(String key) {
    return langMap[langNotifier.value]?[key] ?? langMap['ar']![key] ?? key;
  }

  Future<void> initBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme') ?? 'dark';
    themeNotifier.value = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
    final savedLang = prefs.getString('lang') ?? 'ar';
    langNotifier.value = savedLang;
  }

  Future<void> changeTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value);
    themeNotifier.value = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> changeLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', value);
    langNotifier.value = value;
  }

  Future<Map<String, dynamic>> extractMediaLinks(String url) async {
    List<Map<String, dynamic>> videoList = [];
    String videoTitle = 'فيديو بدون عنوان';

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final ytEngine = yt.YoutubeExplode();
      try {
        var video = await ytEngine.videos.get(url);
        videoTitle = video.title;
        var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
        
        for (var stream in manifest.muxed) {
          String quality = '${stream.videoResolution.height}p';
          videoList.add({
            'quality_name': 'يوتيوب داخلي ($quality)',
            'desc': 'جودة قياسية مدمجة',
            'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
            'url': stream.url.toString(),
            'ext': stream.container.name,
          });
        }
      } catch(e) {
        // صمت
      } finally {
        ytEngine.close();
      }
    }

    try {
      final dio = Dio();
      // إرسال الطلب إلى خادم Flask عبر مسار /api/extract
      final response = await dio.post(
        '$serverUrl/api/extract',
        data: {'url': url}
      );
      
      if (response.statusCode == 200) {
        // استخراج البيانات مباشرة لأن Flask يرسلها بصيغة JSON نظيفة
        Map<String, dynamic> responseData = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        if (responseData['status'] == 'success') {
          videoTitle = responseData['title'] ?? videoTitle;
          
          final formats = responseData['formats'] as List?;
          if (formats != null) {
            for (var f in formats) {
              String ext = f['ext']?.toString().toLowerCase() ?? '';
              if (ext != 'mp4' && ext != 'webm') continue;

              String formatNote = f['format_note']?.toString().toLowerCase() ?? '';
              String formatId = f['format_id']?.toString().toLowerCase() ?? '';
              String resolution = f['resolution']?.toString() ?? f['quality']?.toString() ?? '';
              
              String quality = formatNote.isNotEmpty ? formatNote.toUpperCase() : (resolution.isNotEmpty ? resolution : formatId.toUpperCase());
              if (quality.isEmpty) quality = 'متوسطة';

              String acodec = f['acodec']?.toString().toLowerCase() ?? '';
              String vcodec = f['vcodec']?.toString().toLowerCase() ?? '';
              
              bool hasAudio = acodec != 'none' && acodec.isNotEmpty;
              bool hasVideo = vcodec != 'none' && vcodec.isNotEmpty;
              bool isNativeFb = formatId == 'hd' || formatId == 'sd' || formatNote == 'hd' || formatNote == 'sd';
              bool isServerMerged = formatId == '1080p_server_merged';

              if ((hasAudio && hasVideo) || isNativeFb || isServerMerged) {
                String size = f['filesize'] != null ? (f['filesize'] / (1024 * 1024)).toStringAsFixed(1) : 'غير محدد';
                videoList.add({
                  'quality_name': 'فيديو ($quality)',
                  'desc': 'مضمون بصوت وصورة',
                  'size': size,
                  'url': f['url'],
                  'ext': ext
                });
              }
            }
          }
        }
      }
    } catch (e) {
      // صمت
    }

    return {
      'title': videoTitle, 
      'video': videoList,
    };
  }

  Future<bool> checkAndRequestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    bool alreadyGranted = prefs.getBool('permission_granted') ?? false;
    if (alreadyGranted) return true;

    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      var manageStatus = await Permission.manageExternalStorage.request();
      if (status.isGranted || manageStatus.isGranted) {
        await prefs.setBool('permission_granted', true);
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> startDownloadProcess({
    required String downloadUrl,
    required String title,
    required String extension,
    required Function(double progress, String downloaded, String total) onProgress,
    required Function() onComplete,
    required Function() onError,
  }) async {
    bool hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      onError();
      return;
    }

    try {
      final dio = Dio();
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();
      if (safeTitle.length > 50) {
        safeTitle = safeTitle.substring(0, 50);
      }
      if (safeTitle.isEmpty) {
        safeTitle = 'Video_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      String validExt = extension.isNotEmpty ? extension : 'mp4';
      String savePath = '${directory.path}/$safeTitle.$validExt';
      
      // التنزيل المباشر من رابط الخادم الخاص بك 
      // تم إضافة مهلة زمنية إضافية لأن السيرفر يحتاج وقتا لدمج الفيديوهات عالية الجودة
      await dio.download(
        downloadUrl,
        savePath,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0'},
          receiveTimeout: const Duration(minutes: 15), 
        ),
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

  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    List<FileSystemEntity> files = [];
    try {
      Directory directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        files = directory.listSync().where((file) {
          return file.path.endsWith('.mp4') || file.path.endsWith('.webm');
        }).toList();
      }
    } catch (e) {
      // صمت
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

  Future<Map<String, dynamic>> getDownloadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'downloadMobile': prefs.getBool('downloadMobile') ?? true,
      'download_path': prefs.getString('download_path') ?? '/storage/emulated/0/Download',
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
