import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  /// دالة لجلب معلومات الفيديو بناءً على الرابط
  Future<Video> getVideoInfo(String url) async {
    try {
      var video = await _yt.videos.get(url);
      return video;
    } catch (e) {
      throw Exception('فشل في جلب معلومات الفيديو: $e');
    }
  }

  /// دالة لطلب الصلاحيات قبل التحميل
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true; // للايفون (إن وجد مستقبلاً)
  }

  /// الدالة الرئيسية للتحميل (الفيديو والصوت ودمجهما)
  Future<String> downloadAndMerge(
    String url, {
    required Function(int, int) onReceiveProgress,
    required Function(String) onStatusChanged,
  }) async {
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('لم يتم منح صلاحيات التخزين');
    }

    onStatusChanged('جاري تحليل الرابط...');

    try {
      // 1. الحصول على مسارات التحميل
      var manifest = await _yt.videos.streamsClient.getManifest(url);
      var video = await _yt.videos.get(url);
      String safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 2. اختيار أعلى جودة فيديو (بدون صوت عادة)
      var videoStreamInfo = manifest.muxed.withHighestBitrate();
      var videoOnlyStreamInfo = manifest.videoOnly.withHighestBitrate();
      
      // نختار أعلى جودة متوفرة (سواء كانت مدمجة أو مفصولة)
      var selectedVideoStream = videoOnlyStreamInfo.size > videoStreamInfo.size
          ? videoOnlyStreamInfo
          : videoStreamInfo;

      // 3. اختيار أعلى جودة صوت
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      // إعداد مسارات الملفات المؤقتة
      Directory tempDir = await getTemporaryDirectory();
      String tempVideoPath = '${tempDir.path}/$safeTitle\_video.mp4';
      String tempAudioPath = '${tempDir.path}/$safeTitle\_audio.m4a';

      // مسار الملف النهائي في هاتف المستخدم (مجلد التنزيلات)
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
           downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      String finalOutputPath = '${downloadsDir!.path}/$safeTitle.mp4';

      // 4. تحميل ملف الفيديو
      onStatusChanged('جاري تحميل الفيديو...');
      await _downloadFile(
        selectedVideoStream.url.toString(),
        tempVideoPath,
        onReceiveProgress: (received, total) {
          // يمكنك تعديل هذه الدالة لتحديث واجهة المستخدم بنسبة التحميل
          // نحن نمرر تقدم الفيديو هنا كنسبة أساسية
          onReceiveProgress(received, total); 
        },
      );

      // إذا كانت الجودة المختارة تحتوي على صوت مدمج، لا نحتاج للدمج
      if (selectedVideoStream == videoStreamInfo) {
        onStatusChanged('جاري نقل الملف النهائي...');
        File(tempVideoPath).copySync(finalOutputPath);
        File(tempVideoPath).deleteSync(); // تنظيف
        _yt.close();
        return finalOutputPath;
      }

      // 5. تحميل ملف الصوت (لأن الفيديو بجودة عالية وبدون صوت)
      onStatusChanged('جاري تحميل الصوت...');
      await _downloadFile(
        audioStreamInfo.url.toString(),
        tempAudioPath,
        onReceiveProgress: (received, total) {
          // يمكن تتبع تقدم الصوت هنا إذا أردت
        },
      );

      // 6. عملية الدمج باستخدام FFmpeg
      onStatusChanged('جاري دمج الفيديو والصوت (قد يستغرق بعض الوقت)...');
      String command = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$finalOutputPath"';
      
      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onStatusChanged('تم الدمج بنجاح!');
        // 7. تنظيف الملفات المؤقتة
        File(tempVideoPath).deleteSync();
        File(tempAudioPath).deleteSync();
        _yt.close();
        return finalOutputPath;
      } else {
        var failLog = await session.getFailStackTrace();
        throw Exception('فشل الدمج: $failLog');
      }

    } catch (e) {
      _yt.close();
      throw Exception('حدث خطأ أثناء العملية: $e');
    }
  }

  /// دالة مساعدة لتحميل الملفات عبر Dio
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
            // إضافة headers لتبدو كمتصفح حقيقي لتجاوز قيود يوتيوب
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          }
        )
      );
    } catch (e) {
      throw Exception('خطأ في تحميل الملف: $e');
    }
  }
}
