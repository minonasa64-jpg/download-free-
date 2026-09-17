import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

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
  
  final YoutubeExplode _yt = YoutubeExplode();

  final Dio _dio = Dio(BaseOptions(
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
    
    try {
      await _notificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
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
      'youtube': 'يوتيوب', 'link': 'الروابط', 'downloads': 'تنزيلاتي', 'settings': 'إعدادات',
      'search': 'بحث', 'discover': 'اكتشف وحمّل', 'search_hint': 'ابحث في يوتيوب...', 
      'start_search': 'ابحث عن أي فيديو أو مقطع صوتي\nبجودة عالية وبكل سهولة',
      'download_btn': 'تحميل', 'related': 'فيديوهات ذات صلة', 
      'have_link': 'لديك رابط؟', 'paste_here': 'الصق رابط الفيديو هنا لتحميله مباشرة',
      'downloading': 'جاري التنزيل...', 'completed': 'اكتمل التنزيل', 
      'formats_title': 'اختر الجودة المطلوبة', 'video': 'فيديوهات', 'audio': 'موسيقى', 
      'downloaded': 'الملفات المحملة', 'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 
      'notif': 'الإشعارات', 'theme': 'السمة', 'language': 'اللغة', 'more_tools': 'أدوات إضافية',
      'share_app': 'شارك التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق',
      'no_audio': 'لا توجد موسيقى محملة', 'no_video': 'لا توجد فيديوهات محملة',
      'downloading_now': 'جاري تنزيل:', 'file_not_found': 'الملف غير موجود أو تم حذفه',
      'no_results': 'لم نتمكن من العثور على أي نتائج 😔', 'search_error': 'حدث خطأ أثناء البحث. تحقق من الاتصال.',
      'invalid_link': 'الرابط غير صالح', 'extracting': 'جاري استخراج الجودات محلياً...',
      'share': 'مشاركة', 'convert_to_mp3': 'تحويل إلى صوت (MP3)', 'converting': 'جاري استخراج الصوت...',
      'converted_success': 'تم استخراج الصوت بنجاح!', 'convert_failed': 'فشل استخراج الصوت', 'size': 'الحجم',
    };
    final en = {
      'youtube': 'YouTube', 'link': 'Links', 'downloads': 'Downloads', 'settings': 'Settings',
      'search': 'Search', 'discover': 'Discover & Download', 'search_hint': 'Search YouTube...', 
      'start_search': 'Search for any video or audio\nin high quality easily',
      'download_btn': 'Download', 'related': 'Related Videos', 
      'have_link': 'Have a link?', 'paste_here': 'Paste the video link here to download',
      'downloading': 'Downloading...', 'completed': 'Download Completed', 
      'formats_title': 'Select Quality', 'video': 'Videos', 'audio': 'Music', 
      'downloaded': 'Downloaded Files', 'general': 'General', 'dl_settings': 'Download Settings', 
      'notif': 'Notifications', 'theme': 'Theme', 'language': 'Language', 'more_tools': 'More Tools',
      'share_app': 'Share App', 'clean_cache': 'Clean Cache', 'about': 'About',
      'no_audio': 'No music downloaded', 'no_video': 'No videos downloaded',
      'downloading_now': 'Downloading:', 'file_not_found': 'File not found or deleted',
      'no_results': 'No results found 😔', 'search_error': 'Search error. Check connection.',
      'invalid_link': 'Invalid link', 'extracting': 'Extracting local formats...',
      'share': 'Share', 'convert_to_mp3': 'Convert to MP3', 'converting': 'Extracting audio...',
      'converted_success': 'Audio extracted successfully!', 'convert_failed': 'Failed to extract audio', 'size': 'Size',
    };
    final fr = {
      'youtube': 'YouTube', 'link': 'Liens', 'downloads': 'Téléchargements', 'settings': 'Paramètres',
      'search': 'Recherche', 'discover': 'Découvrez et Téléchargez', 'search_hint': 'Rechercher sur YouTube...', 
      'start_search': 'Recherchez des vidéos ou des audios\nen haute qualité facilement',
      'download_btn': 'Télécharger', 'related': 'Vidéos similaires', 
      'have_link': 'Vous avez un lien ?', 'paste_here': 'Collez le lien ici pour télécharger',
      'downloading': 'Téléchargement...', 'completed': 'Téléchargement terminé', 
      'formats_title': 'Sélectionnez la qualité', 'video': 'Vidéos', 'audio': 'Musique', 
      'downloaded': 'Fichiers téléchargés', 'general': 'Général', 'dl_settings': 'Paramètres de téléchargement', 
      'notif': 'Notifications', 'theme': 'Thème', 'language': 'Langue', 'more_tools': 'Plus d\'outils',
      'share_app': 'Partager l\'appli', 'clean_cache': 'Vider le cache', 'about': 'À propos',
      'no_audio': 'Aucune musique téléchargée', 'no_video': 'Aucune vidéo téléchargée',
      'downloading_now': 'Téléchargement:', 'file_not_found': 'Fichier introuvable',
      'no_results': 'Aucun résultat 😔', 'search_error': 'Erreur de recherche.',
      'invalid_link': 'Lien invalide', 'extracting': 'Extraction des formats...',
      'share': 'Partager', 'convert_to_mp3': 'Convertir en MP3', 'converting': 'Extraction audio...',
      'converted_success': 'Audio extrait avec succès !', 'convert_failed': 'Échec de l\'extraction audio', 'size': 'Taille',
    };
    
    if (langNotifier.value == 'en') return en[key] ?? key;
    if (langNotifier.value == 'fr') return fr[key] ?? key;
    return ar[key] ?? key;
  }

  Future<Map<String, dynamic>> extractMediaLinks(String url) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(url);
      var video = await _yt.videos.get(url);

      List<Map<String, dynamic>> videoFormats = [];
      
      for (var stream in manifest.videoOnly) {
        videoFormats.add({
          'url': stream.url.toString(),
          'quality_name': stream.qualityLabel,
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'ext': 'mp4', 
          'needs_merge': true,
        });
      }
      
      for (var stream in manifest.muxed) {
        videoFormats.add({
          'url': stream.url.toString(),
          'quality_name': stream.qualityLabel,
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'ext': 'mp4',
          'needs_merge': false,
        });
      }

      List<Map<String, dynamic>> audioFormats = [];
      for (var stream in manifest.audioOnly) {
        audioFormats.add({
          'url': stream.url.toString(),
          'quality_name': '${stream.bitrate.kiloBitsPerSecond.toStringAsFixed(0)} kbps',
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'ext': 'mp3',
          'needs_merge': false,
        });
      }

      String highestAudioUrl = manifest.audioOnly.withHighestBitrate().url.toString();

      return {
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
        'highestAudioUrl': highestAudioUrl,
        'video': videoFormats,
        'audio': audioFormats,
      };
    } catch (e) {
      throw Exception('فشل في جلب البيانات: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        await [
          Permission.storage,
          Permission.videos,
          Permission.audio,
          Permission.manageExternalStorage,
          Permission.notification,
        ].request();
      } catch (e) {
        debugPrint('تم تجاهل خطأ الصلاحيات: $e');
      }
    }
    return true; 
  }

  Future<Directory> _getTempDir() async {
    try {
      Directory temp = Directory('/storage/emulated/0/Download/Boykta_Temp');
      if (!await temp.exists()) await temp.create(recursive: true);
      return temp;
    } catch (_) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final dir = Directory('${extDir.path}/Boykta_Temp');
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}
      final docDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docDir.path}/Boykta_Temp');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  Future<Directory> _getDownloadsDir() async {
    try {
      Directory moviesDir = Directory('/storage/emulated/0/Movies/Boykta');
      if (!await moviesDir.exists()) await moviesDir.create(recursive: true);
      return moviesDir;
    } catch (_) {
      try {
        Directory dlDir = Directory('/storage/emulated/0/Download/Boykta');
        if (!await dlDir.exists()) await dlDir.create(recursive: true);
        return dlDir;
      } catch (_) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final dir = Directory('${extDir.path}/Boykta');
            if (!await dir.exists()) await dir.create(recursive: true);
            return dir;
          }
        } catch (_) {}
        final docDir = await getApplicationDocumentsDirectory();
        final dir = Directory('${docDir.path}/Boykta');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
  }

  Future<String> downloadAndMerge({
    required String selectedUrl,
    required String title,
    required String ext,
    required bool needsMerge,
    required String highestAudioUrl,
    required Function(String) onStatusChanged,
    required Function(int, int) onReceiveProgress,
  }) async {
    await _requestPermissions();

    final cleanTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    
    // مسارات مرنة ومتوافقة مع كافة إصدارات الأندرويد
    Directory tempDir = await _getTempDir();
    Directory downloadsDir = await _getDownloadsDir();
    
    String finalOutputPath = '${downloadsDir.path}/$cleanTitle.$ext';

    int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    DownloadTask task = DownloadTask(id: notifId, title: cleanTitle, isAudio: ext == 'mp3');
    
    List<DownloadTask> currentList = List.from(activeDownloads.value);
    currentList.add(task);
    activeDownloads.value = currentList;
    int lastUpdate = 0;

    void updateProgress(int received, int total) {
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
          
          try {
            _notificationsPlugin.show(
              notifId,
              '${t('downloading_now')} $cleanTitle',
              '$downloadedStr MB / $totalStr MB',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'download_channel',
                  'تنزيلات Boykta',
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
          } catch (e) {
            // تجاهل
          }
        }
      }
      onReceiveProgress(received, total);
    }

    try {
      if (!needsMerge) {
        onStatusChanged('جاري تحميل الملف...');
        await _downloadFile(selectedUrl, finalOutputPath, updateProgress);
      } else {
        String tempVideoPath = '${tempDir.path}/${cleanTitle}_video.mp4';
        String tempAudioPath = '${tempDir.path}/${cleanTitle}_audio.m4a';

        onStatusChanged('جاري تحميل الفيديو عالي الجودة...');
        await _downloadFile(selectedUrl, tempVideoPath, updateProgress);

        onStatusChanged('جاري تحميل الصوت الأصلي للدمج...');
        await _downloadFile(highestAudioUrl, tempAudioPath, (r, t) {});

        onStatusChanged('جاري المعالجة والدمج (قد يستغرق بعض الوقت)...');
        String command = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$finalOutputPath"';
        
        try {
          var session = await FFmpegKit.execute(command);
          var returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            onStatusChanged('تم الدمج بنجاح!');
            File(tempVideoPath).deleteSync();
            File(tempAudioPath).deleteSync();
          } else {
            throw Exception('فشل الدمج محلياً.');
          }
        } catch (ffmpegError) {
          throw Exception('خطأ في أداة الدمج (قد لا تكون مدعومة على هذا الجهاز).');
        }
      }

      activeDownloads.value = activeDownloads.value.where((t) => t.id != notifId).toList();
      try {
        _notificationsPlugin.cancel(notifId);
        _notificationsPlugin.show(
          notifId + 1,
          '🎉 ${t('completed')}',
          cleanTitle,
          const NotificationDetails(
            android: AndroidNotificationDetails('download_channel', 'تنزيلات Boykta', importance: Importance.high, priority: Priority.high),
          ),
        );
      } catch (e) {
        // تجاهل
      }
      return finalOutputPath;
    } catch (e) {
      activeDownloads.value = activeDownloads.value.where((t) => t.id != notifId).toList();
      try { _notificationsPlugin.cancel(notifId); } catch (_) {}
      throw Exception('حدث خطأ: $e');
    }
  }

  Future<void> _downloadFile(String url, String savePath, Function(int, int) onReceiveProgress) async {
    try {
      await _dio.download(url, savePath, onReceiveProgress: onReceiveProgress);
    } catch (e) {
      throw Exception('خطأ في التحميل: $e');
    }
  }

  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      List<FileSystemEntity> allFiles = [];
      Set<String> visitedPaths = {};

      List<Directory> targetDirs = [];
      try { targetDirs.add(Directory('/storage/emulated/0/Movies/Boykta')); } catch (_) {}
      try { targetDirs.add(Directory('/storage/emulated/0/Download/Boykta')); } catch (_) {}
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) targetDirs.add(Directory('${extDir.path}/Boykta'));
      } catch (_) {}
      try {
        final docDir = await getApplicationDocumentsDirectory();
        targetDirs.add(Directory('${docDir.path}/Boykta'));
      } catch (_) {}

      for (var dir in targetDirs) {
        if (await dir.exists()) {
          for (var f in dir.listSync()) {
            if (f is File && !visitedPaths.contains(f.path)) {
              visitedPaths.add(f.path);
              allFiles.add(f);
            }
          }
        }
      }

      allFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return allFiles;
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

  Future<bool> convertVideoToMp3({
    required File videoFile,
    required Function(String) onStatus,
  }) async {
    try {
      Directory downloadsDir = await _getDownloadsDir();
      String rawName = videoFile.path.split('/').last;
      String nameWithoutExt = rawName.contains('.') 
          ? rawName.substring(0, rawName.lastIndexOf('.')) 
          : rawName;
      String outputMp3Path = '${downloadsDir.path}/${nameWithoutExt}_audio.mp3';

      onStatus(t('converting'));
      String command = '-y -i "${videoFile.path}" -vn -c:a aac "$outputMp3Path"';
      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        onStatus(t('converted_success'));
        return true;
      } else {
        onStatus(t('convert_failed'));
        return false;
      }
    } catch (e) {
      onStatus(t('convert_failed'));
      return false;
    }
  }

  Future<Map<String, dynamic>> getDownloadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'downloadMobile': prefs.getBool('downloadMobile') ?? true,
      'download_path': prefs.getString('download_path') ?? 'مسار Boykta العام',
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
