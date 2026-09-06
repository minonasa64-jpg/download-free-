import 'dart:io';
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

  // المحرك المستقل والمجاني تماماً (بدون سيرفر)
  Future<Map<String, dynamic>> extractMediaLinks(String url) async {
    List<Map<String, dynamic>> videoList = [];
    String videoTitle = 'فيديو مستخرج';

    try {
      // 1. استخراج يوتيوب (محلياً بالكامل عبر مكتبة التطبيق)
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final ytEngine = yt.YoutubeExplode();
        try {
          var video = await ytEngine.videos.get(url);
          videoTitle = video.title;
          var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
          
          // الاعتماد فقط على الفيديوهات المدمجة (Muxed) لضمان وجود الصوت والصورة معاً
          // وأقصى جودة مدمجة مجانية يتيحها يوتيوب هي 720p HD
          var muxedStreams = manifest.muxed.toList();
          muxedStreams.sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));

          for (var stream in muxedStreams) {
            String quality = '${stream.videoResolution.height}p';
            String desc = quality == '720p' ? 'جودة عالية HD (صوت وصورة)' : 'جودة قياسية (صوت وصورة)';
            videoList.add({
              'quality_name': 'يوتيوب ($quality)',
              'desc': desc,
              'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
              'url': stream.url.toString(),
              'ext': stream.container.name,
            });
          }
        } finally {
          ytEngine.close();
        }
      } 
      // 2. استخراج فيسبوك وتيك توك (عبر APIs عامة مجانية أو اختراق الواجهة محلياً)
      else {
        final dio = Dio();
        
        // المحاولة الأولى: سيرفرات Cobalt العامة والمفتوحة المصدر (لا تتطلب مفاتيح أو اشتراك)
        try {
          var response = await dio.post(
            'https://co.wuk.sh/api/json',
            data: {
              'url': url,
              'vQuality': '720', // نطلب الجودة المدمجة لتجنب الفيديوهات الصامتة
            },
            options: Options(
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              }
            )
          );
          
          if (response.statusCode == 200 && response.data['url'] != null) {
            videoList.add({
              'quality_name': 'تنزيل مباشر (مضمون)',
              'desc': 'جودة ممتازة (صوت وصورة)',
              'size': 'تلقائي',
              'url': response.data['url'],
              'ext': 'mp4'
            });
          }
        } catch (e) {
          // المحاولة الثانية (خطة طوارئ): استخراج رابط الفيسبوك من الكود المصدري محلياً!
          if (url.contains('facebook.com') || url.contains('fb.watch')) {
            var fbResponse = await dio.get(
              url,
              options: Options(headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
              })
            );
            String html = fbResponse.data.toString();
            
            // تهكير الواجهة البرمجية للفيسبوك للوصول إلى الرابط المخفي
            RegExp hdRegex = RegExp(r'"playable_url_quality_hd":"([^"]+)"');
            RegExp sdRegex = RegExp(r'"playable_url":"([^"]+)"');
            
            var hdMatch = hdRegex.firstMatch(html);
            var sdMatch = sdRegex.firstMatch(html);
            
            if (hdMatch != null) {
              videoList.add({
                'quality_name': 'فيسبوك (HD)',
                'desc': 'استخراج محلي مباشر',
                'size': 'تلقائي',
                'url': hdMatch.group(1)!.replaceAll('\\/', '/'),
                'ext': 'mp4'
              });
            }
            if (sdMatch != null) {
              videoList.add({
                'quality_name': 'فيسبوك (SD)',
                'desc': 'استخراج محلي مباشر',
                'size': 'تلقائي',
                'url': sdMatch.group(1)!.replaceAll('\\/', '/'),
                'ext': 'mp4'
              });
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
    String? audioUrl, // لم نعد بحاجة إليه
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
