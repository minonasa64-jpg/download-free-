import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
// تم تحديث الاستيراد ليتوافق مع مكتبة min الجديدة
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:permission_handler/permission_handler.dart';

class BackendService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  Future<Video> getVideoInfo(String url) async {
    try {
      var video = await _yt.videos.get(url);
      return video;
    } catch (e) {
      throw Exception('فشل في جلب معلومات الفيديو: $e');
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

  Future<String> downloadAndMerge(
    String url, {
    required Function(String) onStatusChanged,
    required Function(int, int) onReceiveProgress,
  }) async {
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('لم يتم منح صلاحيات التخزين');
    }

    onStatusChanged('جاري تحليل الرابط...');

    try {
      var manifest = await _yt.videos.streamsClient.getManifest(url);
      var video = await _yt.videos.get(url);
      String safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      var videoStreamInfo = manifest.muxed.withHighestBitrate();
      var videoOnlyStreamInfo = manifest.videoOnly.withHighestBitrate();
      
      var selectedVideoStream = videoOnlyStreamInfo.size > videoStreamInfo.size
          ? videoOnlyStreamInfo
          : videoStreamInfo;

      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      Directory tempDir = await getTemporaryDirectory();
      String tempVideoPath = '${tempDir.path}/$safeTitle\_video.mp4';
      String tempAudioPath = '${tempDir.path}/$safeTitle\_audio.m4a';

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

      onStatusChanged('جاري تحميل الفيديو...');
      await _downloadFile(
        selectedVideoStream.url.toString(),
        tempVideoPath,
        onReceiveProgress: (received, total) {
          onReceiveProgress(received, total); 
        },
      );

      if (selectedVideoStream == videoStreamInfo) {
        onStatusChanged('جاري نقل الملف النهائي...');
        File(tempVideoPath).copySync(finalOutputPath);
        File(tempVideoPath).deleteSync();
        _yt.close();
        return finalOutputPath;
      }

      onStatusChanged('جاري تحميل الصوت...');
      await _downloadFile(
        audioStreamInfo.url.toString(),
        tempAudioPath,
        onReceiveProgress: (received, total) {},
      );

      onStatusChanged('جاري دمج الفيديو والصوت (قد يستغرق بعض الوقت)...');
      String command = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$finalOutputPath"';
      
      var session = await FFmpegKit.execute(command);
      var returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        onStatusChanged('تم الدمج بنجاح!');
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
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          }
        )
      );
    } catch (e) {
      throw Exception('خطأ في تحميل الملف: $e');
    }
  }
}
