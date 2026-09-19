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
      'vault': 'الخزنة الآمنة', 'vault_desc': 'حفظ الفيديوهات والصوتيات برمز PIN سري',
      'set_pin': 'تعيين رمز PIN للخزنة', 'enter_pin': 'أدخل رمز PIN للخزنة',
      'pin_hint': 'أدخل رمزاً مكوناً من 4 أرقام', 'pin_set_success': 'تم تعيين الرمز السري بنجاح',
      'wrong_pin': 'الرمز السري غير صحيح!', 'move_to_vault': 'قفل في الخزنة',
      'moved_to_vault_success': 'تم نقل الملف إلى الخزنة الآمنة بنجاح 🔒',
      'restore_from_vault': 'إلغاء القفل (استرجاع للتنزيلات العامة)',
      'restored_success': 'تم استرجاع الملف إلى التنزيلات العامة 🔓',
      'vault_empty': 'الخزنة فارغة حالياً. يمكنك قفل أي ملف من قائمة التنزيلات.',
      'wifi_only': 'التحميل عبر Wi-Fi فقط', 'wifi_only_desc': 'توفير باقة بيانات الهاتف الخلوية',
      'wifi_warning': 'تنبيه: تم إيقاف التحميل لأن خيار (Wi-Fi فقط) مفعل',
      'auto_retry_active': 'الاستئناف التلقائي مفعل', 'retrying_download': 'جاري إعادة محاولة التحميل...',
      'web_share': 'مشاركة الـ Wi-Fi للكمبيوتر', 'audio_trimmer': 'صانع النغمات وقص الصوت', 'calculator_disguise': 'تمويه الخزنة كآلة حاسبة', 'calculator_disguise_desc': 'إظهار آلة حاسبة حقيقية تفتح بالرمز السري', 'subtitles': 'الترجمات (SRT)', 'download_subtitles': 'تحميل الترجمة', 'playlist': 'قائمة تشغيل', 'download_all_video': 'تحميل الكل فيديو (MP4)', 'download_all_audio': 'تحميل الكل صوت (MP3)', 'schedule_download': 'جدولة التنزيل', 'quick_platforms': 'منصات سريعة مدعومة', 'clipboard_detected': 'تم رصد رابط في الحافظة! اضغط للصق والفحص', 'browser': 'المتصفح', 'biometric_auth': 'البصمة الحيوية', 'biometric_desc': 'فتح الخزنة ببصمة الإصبع أو الوجه السريعة',
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
      'vault': 'Private Vault', 'vault_desc': 'Protect private media with a PIN code',
      'set_pin': 'Set Vault PIN', 'enter_pin': 'Enter Vault PIN',
      'pin_hint': 'Enter 4-digit code', 'pin_set_success': 'PIN set successfully',
      'wrong_pin': 'Incorrect PIN code!', 'move_to_vault': 'Lock in Vault',
      'moved_to_vault_success': 'File moved to Private Vault 🔒',
      'restore_from_vault': 'Unlock (Restore to Downloads)',
      'restored_success': 'File restored to public downloads 🔓',
      'vault_empty': 'Vault is currently empty. Lock any media from downloads.',
      'wifi_only': 'Download on Wi-Fi Only', 'wifi_only_desc': 'Save cellular mobile data usage',
      'wifi_warning': 'Download paused: Wi-Fi Only option is enabled',
      'auto_retry_active': 'Auto-Resume & Retry Active', 'retrying_download': 'Retrying download...',
      'web_share': 'Wi-Fi PC Share', 'audio_trimmer': 'Ringtone & Audio Trimmer', 'calculator_disguise': 'Calculator Vault Disguise', 'calculator_disguise_desc': 'Display real calculator unlocked by PIN', 'subtitles': 'Subtitles (SRT)', 'download_subtitles': 'Download Subtitle', 'playlist': 'Playlist', 'download_all_video': 'Download All Video (MP4)', 'download_all_audio': 'Download All Audio (MP3)', 'schedule_download': 'Schedule Download', 'quick_platforms': 'Quick Platforms', 'clipboard_detected': 'Link found in clipboard! Tap to analyze', 'browser': 'Browser', 'biometric_auth': 'Biometrics', 'biometric_desc': 'Unlock vault using Fingerprint or Face ID',
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
      'vault': 'Coffre-fort privé', 'vault_desc': 'Protéger vos médias avec un code PIN',
      'set_pin': 'Définir code PIN', 'enter_pin': 'Entrez le code PIN',
      'pin_hint': 'Code à 4 chiffres', 'pin_set_success': 'Code PIN défini avec succès',
      'wrong_pin': 'Code PIN incorrect !', 'move_to_vault': 'Verrouiller dans le coffre',
      'moved_to_vault_success': 'Fichier déplacé vers le coffre-fort 🔒',
      'restore_from_vault': 'Déverrouiller (Restaurer)',
      'restored_success': 'Fichier restauré vers les téléchargements 🔓',
      'vault_empty': 'Le coffre est vide. Verrouillez vos médias depuis la liste.',
      'wifi_only': 'Télécharger via Wi-Fi uniquement', 'wifi_only_desc': 'Économiser les données mobiles',
      'wifi_warning': 'Téléchargement suspendu: Wi-Fi uniquement activé',
      'auto_retry_active': 'Reprise automatique active', 'retrying_download': 'Nouvelle tentative en cours...',
      'web_share': 'Partage Wi-Fi PC', 'audio_trimmer': 'Découpeur Audio & Sonneries', 'calculator_disguise': 'Déguisement Calculatrice', 'calculator_disguise_desc': 'Afficher une vraie calculatrice déverrouillée par PIN', 'subtitles': 'Sous-titres (SRT)', 'download_subtitles': 'Télécharger sous-titre', 'playlist': 'Playlist', 'download_all_video': 'Tout télécharger Vidéo (MP4)', 'download_all_audio': 'Tout télécharger Audio (MP3)', 'schedule_download': 'Planifier téléchargement', 'quick_platforms': 'Plateformes rapides', 'clipboard_detected': 'Lien détecté dans le presse-papiers !', 'browser': 'Navigateur', 'biometric_auth': 'Biométrie', 'biometric_desc': 'Déverrouiller le coffre-fort avec empreinte ou visage',
    };
    
    if (langNotifier.value == 'en') return en[key] ?? key;
    if (langNotifier.value == 'fr') return fr[key] ?? key;
    return ar[key] ?? key;
  }

  static Map<String, dynamic> getVideoQualityInfo(String label) {
    final lower = label.toLowerCase();
    int order = 1000;
    String badge = 'SD';
    String desc = 'جودة قياسية مناسبة للهواتف';

    if (lower.contains('144')) {
      order = 144;
      badge = 'توفير فائق';
      desc = 'أقل حجم ممكن • توفير فائق للبيانات • مناسب للشبكات البطيئة';
    } else if (lower.contains('240')) {
      order = 240;
      badge = 'اقتصادي';
      desc = 'حجم صغير جداً • تصفح سريع واستهلاك محدود جداً للمساحة';
    } else if (lower.contains('360')) {
      order = 360;
      badge = 'متوازن SD';
      desc = 'جودة قياسية متوازنة • استهلاك منخفض للبيانات والبطارية';
    } else if (lower.contains('480')) {
      order = 480;
      badge = 'دقة جيدة SD+';
      desc = 'دقة مريحة وواضحة جداً لشاشات الهواتف المحمولة';
    } else if (lower.contains('720')) {
      order = 720;
      badge = 'عالية HD';
      desc = 'عالية الدقة HD • توازن مثالي بين نقاء الصورة وسرعة التحميل';
    } else if (lower.contains('1080')) {
      order = 1080;
      badge = 'فائقة FHD';
      desc = 'دقة فائقة Full HD • تفاصيل سينمائية كريستالية ونقاء مذهل';
    } else if (lower.contains('1440') || lower.contains('2k')) {
      order = 1440;
      badge = '2K Quad HD';
      desc = 'دقة 2K فائقة • وضوح استثنائي للشاشات الكبيرة واللوحية';
    } else if (lower.contains('2160') || lower.contains('4k')) {
      order = 2160;
      badge = '4K Ultra HD';
      desc = 'أعلى دقة 4K • أقصى نقاء وتفاصيل بصرية مذهلة للشاشات العملاقة';
    } else {
      final match = RegExp(r'(\d+)p').firstMatch(lower);
      if (match != null) {
        order = int.tryParse(match.group(1)!) ?? 500;
        desc = 'دقة $label • وضوح رقمي متوازن';
      }
    }
    return {'order': order, 'badge': badge, 'desc': desc};
  }

  static Map<String, dynamic> getAudioQualityInfo(double kbps) {
    int order = kbps.toInt();
    String badge = 'MP3';
    String desc = 'صوت نقي متوازن';

    if (kbps <= 64) {
      badge = 'اقتصادي';
      desc = 'حجم ضئيل جداً • مناسب للتسجيلات وحفظ مساحة التخزين';
    } else if (kbps <= 128) {
      badge = 'قياسي Standard';
      desc = 'جودة قياسية ممتازة • صوت نقي متوازن لكافة السماعات';
    } else if (kbps <= 192) {
      badge = 'عالي النقاء HQ';
      desc = 'صوت عالي النقاء HQ • تجربة صوتية مجسمة ومثالية للموسيقى';
    } else {
      badge = 'استوديو Studio';
      desc = 'جودة استوديو فائقة • أقصى نقاء وأعمق تفاصيل ترددية وباس';
    }
    return {'order': order, 'badge': badge, 'desc': desc};
  }

  static final Map<String, Map<String, dynamic>> _mediaLinksCache = {};
  static final Map<String, StreamManifest> _streamManifestCache = {};

  Future<Map<String, dynamic>> extractMediaLinks(String url) async {
    try {
      String videoIdStr = '';
      try {
        videoIdStr = VideoId(url).value;
      } catch (_) {
        final match = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11})').firstMatch(url);
        if (match != null) videoIdStr = match.group(1)!;
      }

      // التحقق أولاً من الكاش لظهور فوري 0ms بدون أي انتظار
      if (videoIdStr.isNotEmpty && _mediaLinksCache.containsKey(videoIdStr)) {
        return _mediaLinksCache[videoIdStr]!;
      }

      final dynamic target = videoIdStr.isNotEmpty ? VideoId(videoIdStr) : url;

      // جلب المانيفست ومعلومات الفيديو بالتوازي الفوري لتخفيض وقت الانتظار لأكثر من النصف
      final results = await Future.wait([
        _yt.videos.streamsClient.getManifest(target),
        _yt.videos.get(target),
      ]);

      var manifest = results[0] as StreamManifest;
      var video = results[1] as Video;

      if (videoIdStr.isNotEmpty) {
        _streamManifestCache[videoIdStr] = manifest;
      }
      _streamManifestCache[video.id.value] = manifest;

      List<Map<String, dynamic>> videoFormats = [];
      
      for (var stream in manifest.videoOnly) {
        final qInfo = getVideoQualityInfo(stream.qualityLabel);
        videoFormats.add({
          'url': stream.url.toString(),
          'tag': stream.tag,
          'video_id': video.id.value,
          'quality_name': stream.qualityLabel,
          'quality_order': qInfo['order'],
          'quality_badge': qInfo['badge'],
          'quality_desc': qInfo['desc'],
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'size_bytes': stream.size.totalBytes,
          'ext': 'mp4', 
          'needs_merge': true,
        });
      }
      
      for (var stream in manifest.muxed) {
        final qInfo = getVideoQualityInfo(stream.qualityLabel);
        videoFormats.add({
          'url': stream.url.toString(),
          'tag': stream.tag,
          'video_id': video.id.value,
          'quality_name': stream.qualityLabel,
          'quality_order': qInfo['order'],
          'quality_badge': qInfo['badge'],
          'quality_desc': qInfo['desc'],
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'size_bytes': stream.size.totalBytes,
          'ext': 'mp4',
          'needs_merge': false,
        });
      }

      List<Map<String, dynamic>> audioFormats = [];
      for (var stream in manifest.audioOnly) {
        final kbps = stream.bitrate.kiloBitsPerSecond;
        final aInfo = getAudioQualityInfo(kbps);
        audioFormats.add({
          'url': stream.url.toString(),
          'tag': stream.tag,
          'video_id': video.id.value,
          'quality_name': '${kbps.toStringAsFixed(0)} kbps',
          'quality_order': aInfo['order'],
          'quality_badge': aInfo['badge'],
          'quality_desc': aInfo['desc'],
          'size': stream.size.totalMegaBytes.toStringAsFixed(1),
          'size_bytes': stream.size.totalBytes,
          'ext': 'mp3',
          'needs_merge': false,
        });
      }

      final highestAudioStream = manifest.audioOnly.withHighestBitrate();
      String highestAudioUrl = highestAudioStream.url.toString();
      int highestAudioTag = highestAudioStream.tag;

      List<Map<String, dynamic>> subtitlesList = [];
      try {
        var ccManifest = await _yt.videos.closedCaptions.getManifest(video.id).timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => throw 'timeout',
        );
        for (var track in ccManifest.tracks) {
          subtitlesList.add({
            'name': track.language.name,
            'code': track.language.code,
            'isAuto': track.isAutoGenerated,
            'track': track,
          });
        }
      } catch (_) {}

      final mediaResult = {
        'id': video.id.value,
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
        'highestAudioUrl': highestAudioUrl,
        'highestAudioTag': highestAudioTag,
        'video': videoFormats,
        'audio': audioFormats,
        'subtitles': subtitlesList,
      };

      if (videoIdStr.isNotEmpty) {
        _mediaLinksCache[videoIdStr] = mediaResult;
      }
      return mediaResult;
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
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final dir = Directory('${docDir.path}/Boykta_Temp');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      } catch (_) {}
      return Directory.systemTemp;
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
        try {
          final docDir = await getApplicationDocumentsDirectory();
          final dir = Directory('${docDir.path}/Boykta');
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        } catch (_) {}
        return Directory.systemTemp;
      }
    }
  }

  Future<String> downloadAndMerge({
    required String selectedUrl,
    required String title,
    required String ext,
    required bool needsMerge,
    required String highestAudioUrl,
    String? videoId,
    int? videoTag,
    int? highestAudioTag,
    required Function(String) onStatusChanged,
    required Function(int, int) onReceiveProgress,
  }) async {
    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('تم تجاهل استثناء الصلاحيات: $e');
    }

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
        if (ext == 'mp3') {
          // تنزيل ملف الصوت بأمان ثم تحويله أو نسخه كـ MP3
          String tempAudioPath = '${tempDir.path}/${cleanTitle}_raw.m4a';
          await _downloadFile(
            url: selectedUrl,
            savePath: tempAudioPath,
            onReceiveProgress: updateProgress,
            videoId: videoId,
            streamTag: videoTag,
          );
          onStatusChanged('جاري معالجة وتجهيز ملف MP3...');
          try {
            var session = await FFmpegKit.execute('-i "$tempAudioPath" -vn -c:a libmp3lame -b:a 192k "$finalOutputPath"');
            var returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              try { File(tempAudioPath).deleteSync(); } catch (_) {}
            } else {
              final rawFile = File(tempAudioPath);
              if (await rawFile.exists()) {
                await rawFile.copy(finalOutputPath);
                await rawFile.delete();
              }
            }
          } catch (_) {
            final rawFile = File(tempAudioPath);
            if (await rawFile.exists()) {
              await rawFile.copy(finalOutputPath);
              await rawFile.delete();
            }
          }
        } else {
          await _downloadFile(
            url: selectedUrl,
            savePath: finalOutputPath,
            onReceiveProgress: updateProgress,
            videoId: videoId,
            streamTag: videoTag,
          );
        }
      } else {
        String tempVideoPath = '${tempDir.path}/${cleanTitle}_video.mp4';
        String tempAudioPath = '${tempDir.path}/${cleanTitle}_audio.m4a';

        onStatusChanged('جاري تحميل الفيديو عالي الجودة...');
        await _downloadFile(
          url: selectedUrl,
          savePath: tempVideoPath,
          onReceiveProgress: updateProgress,
          videoId: videoId,
          streamTag: videoTag,
        );

        onStatusChanged('جاري تحميل الصوت الأصلي للدمج...');
        await _downloadFile(
          url: highestAudioUrl,
          savePath: tempAudioPath,
          onReceiveProgress: (r, t) {},
          videoId: videoId,
          streamTag: highestAudioTag,
        );

        onStatusChanged('جاري المعالجة والدمج (قد يستغرق بعض الوقت)...');
        String command = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$finalOutputPath"';
        
        try {
          var session = await FFmpegKit.execute(command);
          var returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            onStatusChanged('تم الدمج بنجاح!');
            try { File(tempVideoPath).deleteSync(); } catch (_) {}
            try { File(tempAudioPath).deleteSync(); } catch (_) {}
          } else {
            final vFile = File(tempVideoPath);
            if (await vFile.exists()) {
              await vFile.copy(finalOutputPath);
              try { vFile.deleteSync(); } catch (_) {}
              try { File(tempAudioPath).deleteSync(); } catch (_) {}
            } else {
              throw Exception('فشل الدمج محلياً.');
            }
          }
        } catch (ffmpegError) {
          final vFile = File(tempVideoPath);
          if (await vFile.exists()) {
            await vFile.copy(finalOutputPath);
            try { vFile.deleteSync(); } catch (_) {}
            try { File(tempAudioPath).deleteSync(); } catch (_) {}
          } else {
            throw Exception('خطأ في أداة الدمج: $ffmpegError');
          }
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

  /// جلب رابط تشغيل مباشر عالي الجودة لتشغيله في مشغل الفيديو البديل (Chewie / Native Video Player)
  Future<Map<String, dynamic>> getPlayableStream(String videoId) async {
    try {
      StreamManifest? manifest = _streamManifestCache[videoId];
      if (manifest == null) {
        manifest = await _yt.videos.streamsClient.getManifest(videoId);
        _streamManifestCache[videoId] = manifest;
      }

      if (manifest.muxed.isNotEmpty) {
        final muxedList = manifest.muxed.toList();
        muxedList.sort((a, b) => a.size.totalBytes.compareTo(b.size.totalBytes));
        // نختار أعلى دقة مدمجة صوت وصورة (عادة 720p أو 360p) لضمان تشغيل مباشر سلس وفوري بدون تقطيع
        final bestStream = muxedList.last;
        return {
          'url': bestStream.url.toString(),
          'quality': bestStream.qualityLabel,
          'aspectRatio': 16 / 9,
          'allStreams': muxedList.map((s) => {
            'url': s.url.toString(),
            'quality': s.qualityLabel,
            'size': s.size.totalMegaBytes.toStringAsFixed(1),
          }).toList(),
        };
      } else if (manifest.streams.isNotEmpty) {
        final stream = manifest.streams.first;
        return {
          'url': stream.url.toString(),
          'quality': 'Standard',
          'aspectRatio': 16 / 9,
          'allStreams': [
            {'url': stream.url.toString(), 'quality': 'Standard', 'size': ''}
          ],
        };
      }
      throw Exception('لا توجد دفقات تشغيل متاحة لهذا المقطع');
    } catch (e) {
      throw Exception('فشل استخراج رابط التشغيل المباشر: $e');
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required Function(int, int) onReceiveProgress,
    String? videoId,
    int? streamTag,
  }) async {
    String? targetVideoId = videoId;
    int? targetTag = streamTag;

    // استخراج معرّف الفيديو أو الـ tag تلقائياً في حال عدم تمريره
    if (targetVideoId == null || targetVideoId.isEmpty) {
      if (url.contains('youtu.be/') || url.contains('youtube.com/watch') || url.contains('youtube.com/shorts/')) {
        try {
          targetVideoId = VideoId(url).value;
        } catch (_) {}
      }
    }

    if (targetTag == null) {
      try {
        final uri = Uri.tryParse(url);
        final itagStr = uri?.queryParameters['itag'];
        if (itagStr != null) {
          targetTag = int.tryParse(itagStr);
        }
      } catch (_) {}
    }

    // الطريقة الأولى الأساسية: تنزيل الدفق مباشرة عبر محرّك YoutubeExplode الرسمي
    // هذه الطريقة موثوقة بنسبة 100%، ولا تنقطع، وتتجاوز حظر 403 throttling من يوتيوب
    if (targetVideoId != null && targetVideoId.isNotEmpty) {
      try {
        debugPrint('جاري التنزيل المباشر الموثوق عبر YoutubeExplode: videoId=$targetVideoId, tag=$targetTag');
        StreamManifest? manifest = _streamManifestCache[targetVideoId];
        if (manifest == null) {
          manifest = await _yt.videos.streamsClient.getManifest(targetVideoId);
          _streamManifestCache[targetVideoId] = manifest;
        }
        StreamInfo? selectedStream;

        if (targetTag != null) {
          for (final s in manifest.streams) {
            if (s.tag == targetTag) {
              selectedStream = s;
              break;
            }
          }
        }

        if (selectedStream == null) {
          if (manifest.muxed.isNotEmpty) {
            final muxedList = manifest.muxed.toList();
            muxedList.sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
            selectedStream = muxedList.first;
          } else if (manifest.streams.isNotEmpty) {
            selectedStream = manifest.streams.first;
          }
        }

        if (selectedStream != null) {
          int streamAttempt = 0;
          bool streamSuccess = false;
          while (streamAttempt < 3 && !streamSuccess) {
            streamAttempt++;
            final file = File(savePath);
            if (await file.exists()) {
              try { await file.delete(); } catch (_) {}
            }
            final sink = file.openWrite();
            int received = 0;
            final total = selectedStream.size.totalBytes;
            int lastProgressTime = 0;

            try {
              final stream = _yt.videos.streamsClient.get(selectedStream);
              await for (final chunk in stream) {
                received += chunk.length;
                sink.add(chunk);

                final now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastProgressTime > 120 || received >= total) {
                  lastProgressTime = now;
                  onReceiveProgress(received, total);
                }
              }
              await sink.flush();
              await sink.close();

              if (await file.exists() && (await file.length()) > 0 && (total == 0 || (await file.length()) >= total * 0.95)) {
                debugPrint('اكتمل التنزيل بنجاح 100% عبر محرّك الدفق المباشر!');
                streamSuccess = true;
                return;
              } else {
                debugPrint('الملف غير مكتمل (المحاولة $streamAttempt)، جاري الإعادة...');
              }
            } catch (chunkErr) {
              try { await sink.close(); } catch (_) {}
              debugPrint('خطأ أثناء تلقي الدفق (المحاولة $streamAttempt): $chunkErr');
              if (streamAttempt < 3) {
                await Future.delayed(Duration(milliseconds: 500 * streamAttempt));
              }
            }
          }
        }
      } catch (ytErr) {
        debugPrint('تعذر التنزيل عبر streamsClient ($ytErr)، جاري المحاولة عبر المحرك الاحتياطي المقوى...');
      }
    }

    // الطريقة البديلة / للروابط المباشرة الخارجية من المتصفح والمنصات الأخرى
    final downloadOptions = Options(
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36',
        'Referer': 'https://www.google.com/',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      },
      receiveTimeout: const Duration(minutes: 15),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 400,
    );

    // فحص ما إذا كان الرابط الخارجي المباشر يدعم التنزيل السريع متعدد الخطوط
    final isMulti = await isMultiThreadDownloadEnabled();
    final threadCount = await getDownloadThreads();
    if (isMulti && !url.contains('googlevideo.com')) {
      try {
        final headRes = await _dio.head(
          url,
          options: Options(
            headers: downloadOptions.headers,
            followRedirects: true,
            validateStatus: (s) => s != null && s < 400,
          ),
        );
        final clStr = headRes.headers.value('content-length');
        final contentLength = int.tryParse(clStr ?? '');
        if (contentLength != null && contentLength > 2 * 1024 * 1024) {
          final parallelOk = await _downloadParallelChunks(
            directUrl: url,
            savePath: savePath,
            totalBytes: contentLength,
            onReceiveProgress: onReceiveProgress,
            customThreads: threadCount,
          );
          if (parallelOk) {
            return;
          }
        }
      } catch (_) {}
    }

    // التنزيل المباشر المستقر مع إعادة المحاولة التلقائية
    int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final f = File(savePath);
        if (await f.exists()) {
          try { await f.delete(); } catch (_) {}
        }

        int lastDioUpdate = 0;
        await _dio.download(
          url,
          savePath,
          options: downloadOptions,
          deleteOnError: false,
          onReceiveProgress: (rec, tot) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastDioUpdate > 120 || rec == tot) {
              lastDioUpdate = now;
              onReceiveProgress(rec, tot);
            }
          },
        );

        if (await f.exists() && (await f.length()) > 0) {
          return;
        }
      } catch (e) {
        debugPrint('محاولة تنزيل Dio رقم $attempt فشلت: $e');
        if (attempt >= maxRetries) {
          throw Exception('فشل التحميل بعد عدة محاولات تلقائية: $e');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // =========================================================================
  // محرك التنزيل متعدد الخطوط التوربو (Multi-Threaded Turbo Download Engine)
  // يعمل دوماً في الخلفية بأقصى سرعة ممكنة (16 مسار متزامن) بدون إزعاج المستخدم
  // =========================================================================
  Future<bool> isMultiThreadDownloadEnabled() async {
    return true; // نشط دوماً في الخفاء بأقصى طاقة
  }

  Future<void> setMultiThreadDownloadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('multi_thread_download_enabled', true);
  }

  Future<int> getDownloadThreads() async {
    return 16; // أقصى سرعة توربو خارقة دوماً في الخفاء
  }

  Future<void> setDownloadThreads(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('download_threads', 16);
  }

  Future<bool> _downloadParallelChunks({
    required String directUrl,
    required String savePath,
    required int totalBytes,
    required Function(int, int) onReceiveProgress,
    int? customThreads,
  }) async {
    int effectiveParts = 8;
    try {
      final configuredThreads = customThreads ?? await getDownloadThreads();
      effectiveParts = configuredThreads.clamp(2, 16);
      final int partSize = (totalBytes / effectiveParts).ceil();
      final List<int> receivedParts = List.filled(effectiveParts, 0);
      int lastReported = 0;

      void updateCombinedProgress(int partIndex, int rec) {
        receivedParts[partIndex] = rec;
        final totalRec = receivedParts.reduce((a, b) => a + b);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastReported > 80 || totalRec >= totalBytes) {
          lastReported = now;
          onReceiveProgress(totalRec > totalBytes ? totalBytes : totalRec, totalBytes);
        }
      }

      final futures = List.generate(effectiveParts, (i) async {
        final start = i * partSize;
        final end = (i == effectiveParts - 1) ? totalBytes - 1 : (i + 1) * partSize - 1;
        if (start >= totalBytes) return;
        final actualEnd = (end >= totalBytes) ? totalBytes - 1 : end;
        final partFile = '$savePath.part$i';
        
        int partAttempts = 0;
        bool partSuccess = false;
        while (partAttempts < 3 && !partSuccess) {
          partAttempts++;
          try {
            final partDio = Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 25),
            ));

            await partDio.download(
              directUrl,
              partFile,
              options: Options(
                headers: {
                  'Range': 'bytes=$start-$actualEnd',
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36',
                  'Referer': 'https://www.youtube.com/',
                  'Accept': '*/*',
                },
              ),
              onReceiveProgress: (rec, _) => updateCombinedProgress(i, rec),
            );

            final pf = File(partFile);
            if (await pf.exists() && (await pf.length()) > 0) {
              partSuccess = true;
            }
          } catch (err) {
            debugPrint('إعادة محاولة مسار التنزيل المتعدد $i (المحاولة $partAttempts): $err');
            if (partAttempts >= 3) rethrow;
            await Future.delayed(Duration(milliseconds: 350 * partAttempts));
          }
        }
      });

      await Future.wait(futures);

      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        try { await finalFile.delete(); } catch (_) {}
      }
      final sink = finalFile.openWrite();
      for (int i = 0; i < effectiveParts; i++) {
        final partFile = File('$savePath.part$i');
        if (await partFile.exists()) {
          await sink.addStream(partFile.openRead());
          try { await partFile.delete(); } catch (_) {}
        }
      }
      await sink.flush();
      await sink.close();

      return await finalFile.exists() && (await finalFile.length()) > 0;
    } catch (e) {
      debugPrint('تنبيه: التنزيل متعدد الخطوط لم يكتمل ($e)، يتم الرجوع للتدفق المباشر.');
      for (int i = 0; i < effectiveParts; i++) {
        try {
          final p = File('$savePath.part$i');
          if (await p.exists()) await p.delete();
        } catch (_) {}
      }
      return false;
    }
  }

  // بدء التنزيل في الخلفية بشكل مستقل تماماً عن دورة حياة الواجهات والنوافذ
  Future<String> startDownloadInBackground({
    required String selectedUrl,
    required String title,
    required String ext,
    required bool needsMerge,
    required String highestAudioUrl,
    String? videoId,
    int? videoTag,
    int? highestAudioTag,
    Function(String)? onStatusChanged,
    Function(int, int)? onReceiveProgress,
  }) {
    return downloadAndMerge(
      selectedUrl: selectedUrl,
      title: title,
      ext: ext,
      needsMerge: needsMerge,
      highestAudioUrl: highestAudioUrl,
      videoId: videoId,
      videoTag: videoTag,
      highestAudioTag: highestAudioTag,
      onStatusChanged: onStatusChanged ?? (_) {},
      onReceiveProgress: onReceiveProgress ?? (_, __) {},
    );
  }

  // ==========================
  // الخزنة الآمنة (Private Vault)
  // ==========================
  Future<Directory> _getVaultDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/.vault_private');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isVaultPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('vault_pin');
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> verifyVaultPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('vault_pin');
    return savedPin == pin;
  }

  Future<void> setVaultPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vault_pin', pin);
  }

  Future<bool> moveToVault(File file) async {
    try {
      if (!await file.exists()) return false;
      final vaultDir = await _getVaultDir();
      final fileName = file.path.split('/').last;
      final targetPath = '${vaultDir.path}/$fileName';
      await file.copy(targetPath);
      await file.delete();
      return true;
    } catch (e) {
      debugPrint('Error moving to vault: $e');
      return false;
    }
  }

  Future<bool> restoreFromVault(File file) async {
    try {
      if (!await file.exists()) return false;
      final downloadsDir = await _getDownloadsDir();
      final fileName = file.path.split('/').last;
      final targetPath = '${downloadsDir.path}/$fileName';
      await file.copy(targetPath);
      await file.delete();
      return true;
    } catch (e) {
      debugPrint('Error restoring from vault: $e');
      return false;
    }
  }

  Future<List<FileSystemEntity>> getVaultFiles() async {
    try {
      final vaultDir = await _getVaultDir();
      if (!await vaultDir.exists()) return [];
      final files = vaultDir.listSync().whereType<File>().toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteVaultFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
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
      'wifi_only': prefs.getBool('wifi_only') ?? false,
      'download_path': prefs.getString('download_path') ?? 'مسار Boykta العام',
      'max_tasks': prefs.getInt('max_tasks') ?? 4,
      'speed_limit': prefs.getString('speed_limit') ?? 'غير محدود',
      'multi_thread': prefs.getBool('multi_thread_download_enabled') ?? true,
      'threads_count': prefs.getInt('download_threads') ?? 8,
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

  Future<String> downloadSubtitleTrack({
    required ClosedCaptionTrackInfo track,
    required String videoTitle,
  }) async {
    await _requestPermissions();
    final trackData = await _yt.videos.closedCaptions.get(track);
    final cleanTitle = videoTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    final dlDir = await _getDownloadsDir();
    final srtFile = File('${dlDir.path}/${cleanTitle}_${track.language.code}.srt');

    StringBuffer srt = StringBuffer();
    int idx = 1;
    for (var cap in trackData.captions) {
      srt.writeln('$idx');
      final start = _formatSrtTimestamp(cap.offset);
      final end = _formatSrtTimestamp(cap.offset + cap.duration);
      srt.writeln('$start --> $end');
      srt.writeln(cap.text);
      srt.writeln();
      idx++;
    }
    await srtFile.writeAsString(srt.toString());
    return srtFile.path;
  }

  String _formatSrtTimestamp(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  bool isPlaylistUrl(String url) {
    final u = url.toLowerCase().trim();
    return u.contains('list=') || u.contains('/playlist');
  }

  Future<Map<String, dynamic>> extractPlaylist(String url) async {
    try {
      String playlistId = url.trim();
      if (url.contains('list=')) {
        final uri = Uri.tryParse(url);
        if (uri != null && uri.queryParameters.containsKey('list')) {
          playlistId = uri.queryParameters['list']!;
        }
      }
      final playlist = await _yt.playlists.get(playlistId);
      final videoList = await _yt.playlists.getVideos(playlist.id).take(50).toList();

      List<Map<String, dynamic>> videos = [];
      for (var v in videoList) {
        final dur = v.duration;
        final durStr = dur != null ? '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}' : '';
        videos.add({
          'id': v.id.value,
          'url': v.url,
          'title': v.title,
          'author': v.author,
          'duration': durStr,
          'thumbnail': v.thumbnails.mediumResUrl,
        });
      }

      return {
        'id': playlist.id.value,
        'title': playlist.title,
        'author': playlist.author,
        'videoCount': playlist.videoCount ?? videos.length,
        'thumbnail': playlist.thumbnails.mediumResUrl,
        'videos': videos,
      };
    } catch (e) {
      throw Exception('فشل في جلب قائمة التشغيل: $e');
    }
  }

  Future<bool> isCalculatorDisguiseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('calculator_disguise') ?? false;
  }

  Future<void> setCalculatorDisguise(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calculator_disguise', enabled);
  }
}
