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

  const DownloadProgressDialog({
    super.key,
    required this.selectedUrl,
    required this.title,
    required this.ext,
    required this.needsMerge,
    required this.highestAudioUrl,
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
              ]
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('إغلاق', style: TextStyle(color: Colors.white))
                  )
                ] else if (_isFinished) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2), 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2)
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
                      minimumSize: const Size(double.infinity, 45)
                    ),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('رائع', style: TextStyle(fontWeight: FontWeight.bold))
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
                  if (_statusText.contains('دمج') == false) ...[ // إخفاء الشريط أثناء الدمج
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
                      style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 16)
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
