import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String selectedUrl;
  final String title;
  final String ext;
  final bool needsMerge;
  final String highestAudioUrl;
  final String? videoId;
  final int? videoTag;
  final int? highestAudioTag;

  const DownloadProgressDialog({
    super.key,
    required this.selectedUrl,
    required this.title,
    required this.ext,
    required this.needsMerge,
    required this.highestAudioUrl,
    this.videoId,
    this.videoTag,
    this.highestAudioTag,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  final BackendService _backend = BackendService();
  double _progress = 0.0;
  String _statusText = "جاري التحضير...";
  bool _isFinished = false;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _startDownloadProcess();
  }

  Future<void> _startDownloadProcess() async {
    try {
      await _backend.downloadAndMerge(
        selectedUrl: widget.selectedUrl,
        title: widget.title,
        ext: widget.ext,
        needsMerge: widget.needsMerge,
        highestAudioUrl: widget.highestAudioUrl,
        videoId: widget.videoId,
        videoTag: widget.videoTag,
        highestAudioTag: widget.highestAudioTag,
        onStatusChanged: (status) {
          if (mounted) {
            setState(() {
              _statusText = status;
            });
          }
        },
        onReceiveProgress: (received, total) {
          if (mounted && total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isFinished = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasError) ...[
                  const Icon(Icons.error_outline_rounded, color: AppColors.orange, size: 60),
                  const SizedBox(height: 15),
                  const Text('حدث خطأ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
                  )
                ] else if (_isFinished) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.green, size: 50),
                  ),
                  const SizedBox(height: 15),
                  const Text('اكتمل التنزيل بنجاح! 🎉', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('الملف متوفر الآن في مجلد التنزيلات بجهازك.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('رائع', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ] else ...[
                  const CircularProgressIndicator(color: AppColors.cyan),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),
                  if (_statusText.contains('دمج') == false) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: Colors.black.withOpacity(0.5),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ]
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BatchDownloadProgressDialog extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool isAudio;

  const BatchDownloadProgressDialog({
    super.key,
    required this.items,
    required this.isAudio,
  });

  @override
  State<BatchDownloadProgressDialog> createState() => _BatchDownloadProgressDialogState();
}

class _BatchDownloadProgressDialogState extends State<BatchDownloadProgressDialog> {
  final BackendService _backend = BackendService();

  int _currentIndex = 0;
  double _currentItemProgress = 0.0;
  String _currentStatus = 'جاري بدء التحميل الدُفعي...';
  bool _isFinished = false;
  bool _isCancelled = false;
  int _successCount = 0;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _startBatchDownload();
  }

  Future<void> _startBatchDownload() async {
    for (int i = 0; i < widget.items.length; i++) {
      if (_isCancelled) break;
      final item = widget.items[i];

      if (mounted) {
        setState(() {
          _currentIndex = i;
          _currentItemProgress = 0.0;
          _currentStatus = 'جاري استخراج: ${item['title']} (${i + 1}/${widget.items.length})';
        });
      }

      try {
        final videoUrl = item['url'] ?? 'https://www.youtube.com/watch?v=${item['id']}';
        final mediaData = await _backend.extractMediaLinks(videoUrl);

        if (_isCancelled) break;

        String selectedUrl = '';
        String ext = widget.isAudio ? 'mp3' : 'mp4';
        bool needsMerge = false;
        String highestAudioUrl = mediaData['highestAudioUrl'] ?? '';
        int? highestAudioTag = mediaData['highestAudioTag'];
        String? targetVideoId = mediaData['id'] ?? item['id'];
        int? targetTag;

        if (widget.isAudio) {
          final audios = List<Map<String, dynamic>>.from(mediaData['audio'] ?? []);
          if (audios.isNotEmpty) {
            selectedUrl = audios.first['url'];
            targetTag = audios.first['tag'];
          } else {
            selectedUrl = highestAudioUrl;
            targetTag = highestAudioTag;
          }
        } else {
          final videos = List<Map<String, dynamic>>.from(mediaData['video'] ?? []);
          // نفضل صيغة muxed لتسريع التنزيل الدفعي
          final directVideo = videos.firstWhere(
            (v) => v['needs_merge'] == false,
            orElse: () => videos.isNotEmpty ? videos.first : {'url': '', 'needs_merge': false},
          );
          selectedUrl = directVideo['url'] ?? '';
          targetTag = directVideo['tag'];
          needsMerge = directVideo['needs_merge'] ?? false;
        }

        if (selectedUrl.isEmpty) {
          _failCount++;
          continue;
        }

        if (mounted) {
          setState(() {
            _currentStatus = 'تحميل (${i + 1}/${widget.items.length}): ${item['title']}';
          });
        }

        await _backend.downloadAndMerge(
          selectedUrl: selectedUrl,
          title: item['title'] ?? 'فيديو بدون عنوان',
          ext: ext,
          needsMerge: needsMerge,
          highestAudioUrl: highestAudioUrl,
          videoId: targetVideoId,
          videoTag: targetTag,
          highestAudioTag: highestAudioTag,
          onStatusChanged: (status) {
            if (mounted) {
              setState(() => _currentStatus = '$status (${i + 1}/${widget.items.length})');
            }
          },
          onReceiveProgress: (received, total) {
            if (mounted && total != -1) {
              setState(() => _currentItemProgress = received / total);
            }
          },
        );

        _successCount++;
      } catch (e) {
        _failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.items.length;
    final overallProgress = totalCount > 0
        ? ((_currentIndex + _currentItemProgress) / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isFinished) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: const Icon(Icons.done_all_rounded, color: Colors.green, size: 45),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'اكتمل التحميل الدُفعي! 🎉',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تم تحميل $_successCount من إجمالي $totalCount ملف بنجاح',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  if (_failCount > 0)
                    Text(
                      'تعذر تحميل $_failCount ملف',
                      style: const TextStyle(color: AppColors.orange, fontSize: 12),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تم بنجاح', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.isAudio ? Icons.library_music_rounded : Icons.video_collection_rounded,
                          color: AppColors.cyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحميل دُفعي (${_currentIndex + 1}/$totalCount)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              widget.isAudio ? 'تحويل وحفظ MP3' : 'تحميل وحفظ MP4',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _currentStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // شريط التقدم الكلي
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('التقدم الإجمالي:', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text(
                            '${(overallProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: overallProgress,
                          minHeight: 8,
                          backgroundColor: Colors.black.withOpacity(0.4),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      _isCancelled = true;
                      Navigator.pop(context);
                    },
                    child: const Text('إلغاء المتبقي', style: TextStyle(color: AppColors.orange)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
