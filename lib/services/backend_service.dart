import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
// تم تعديل الاستيراد هنا
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:permission_handler/permission_handler.dart';

class BackendService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

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
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true; 
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
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('لم يتم منح صلاحيات التخزين');
    }

    String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    Directory tempDir = await getTemporaryDirectory();
    
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
         downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }
    
    String finalOutputPath = '${downloadsDir!.path}/$safeTitle.$ext';

    try {
      if (!needsMerge) {
        onStatusChanged('جاري تحميل الملف...');
        await _downloadFile(
          selectedUrl,
          finalOutputPath,
          onReceiveProgress: onReceiveProgress,
        );
        return finalOutputPath;
      } else {
        String tempVideoPath = '${tempDir.path}/$safeTitle\_video.mp4';
        String tempAudioPath = '${tempDir.path}/$safeTitle\_audio.m4a';

        onStatusChanged('جاري تحميل الفيديو عالي الجودة...');
        await _downloadFile(
          selectedUrl,
          tempVideoPath,
          onReceiveProgress: onReceiveProgress,
        );

        onStatusChanged('جاري تحميل الصوت الأصلي للدمج...');
        await _downloadFile(
          highestAudioUrl,
          tempAudioPath,
          onReceiveProgress: (received, total) {}, 
        );

        onStatusChanged('جاري المعالجة والدمج (قد يستغرق بعض الوقت)...');
        String command = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$finalOutputPath"';
        
        var session = await FFmpegKit.execute(command);
        var returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          onStatusChanged('تم الدمج بنجاح!');
          File(tempVideoPath).deleteSync();
          File(tempAudioPath).deleteSync();
          return finalOutputPath;
        } else {
          var failLog = await session.getFailStackTrace();
          throw Exception('فشل الدمج: $failLog');
        }
      }
    } catch (e) {
      throw Exception('حدث خطأ أثناء العملية: $e');
    }
  }

  Future<void> _downloadFile(
    String url,
    String savePath, {
    required Function(int, int) onReceiveProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          }
        )
      );
    } catch (e) {
      throw Exception('خطأ في تحميل الملف: $e');
    }
  }

  String t(String key) {
    Map<String, String> translations = {
      'have_link': 'لديك رابط؟',
      'download_btn': 'بحث وتحليل',
      'extracting': 'جاري جلب الجودات محلياً...',
      'file_not_found': 'لم يتم العثور على ملفات مدعومة',
      'video': 'فيديو',
      'audio': 'صوت',
    };
    return translations[key] ?? key;
  }
}
