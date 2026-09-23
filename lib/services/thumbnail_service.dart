import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, Uint8List?> _memoryCache = {};
  final Map<String, Future<Uint8List?>> _pendingTasks = {};

  Future<Uint8List?> getVideoThumbnail(String videoPath) async {
    if (_memoryCache.containsKey(videoPath)) {
      return _memoryCache[videoPath];
    }

    if (_pendingTasks.containsKey(videoPath)) {
      return _pendingTasks[videoPath];
    }

    final future = _loadThumbnail(videoPath);
    _pendingTasks[videoPath] = future;
    try {
      final result = await future;
      _memoryCache[videoPath] = result;
      return result;
    } finally {
      _pendingTasks.remove(videoPath);
    }
  }

  Future<Uint8List?> _loadThumbnail(String videoPath) async {
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) return null;

      // 1. فحص ما إذا كان هناك ملف غلاف أو صورة مصغرة محفوظة بنفس الاسم
      final baseName = videoPath.contains('.') ? videoPath.substring(0, videoPath.lastIndexOf('.')) : videoPath;
      final localThumbJpg = File('$baseName.jpg');
      final localThumbPng = File('$baseName.png');

      if (await localThumbJpg.exists()) {
        final bytes = await localThumbJpg.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
      if (await localThumbPng.exists()) {
        final bytes = await localThumbPng.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }

      // 2. استخدام video_thumbnail لاستخراج إطار سريع
      final thumbBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 60,
        timeMs: 1500, // إطار بعد ثانية ونصف لضمان عدم التقاط شاشة سوداء
      );

      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        return thumbBytes;
      }

      // إعادة المحاولة عند بداية الفيديو timeMs: 0
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
        timeMs: 0,
      );
    } catch (e) {
      debugPrint('Error generating video thumbnail for $videoPath: $e');
      return null;
    }
  }

  void clearCache() {
    _memoryCache.clear();
  }
}
