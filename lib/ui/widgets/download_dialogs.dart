import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';

// ==========================================
// 1. شريط عرض الجودات الزجاجي أسفل الشاشة
// ==========================================
class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> videoFormats;
  final List<Map<String, dynamic>> audioFormats;

  const FormatSelectionSheet({
    super.key,
    required this.title,
    required this.videoFormats,
    required this.audioFormats,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  Map<String, dynamic>? _selectedFormat;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.8),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // مقبض السحب (Drag Handle)
                Container(
                  margin: const EdgeInsets.only(top: 15, bottom: 5),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                
                // العنوان
                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'اختر الجودة المطلوبة',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                
                // التبويبات (فيديو / صوت)
                const TabBar(
                  indicatorColor: AppColors.cyan,
                  labelColor: AppColors.cyan,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    Tab(icon: Icon(Icons.video_library), text: 'فيديو'),
                    Tab(icon: Icon(Icons.library_music), text: 'صوت'),
                  ],
                ),
                
                // القوائم
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(widget.videoFormats),
                      _buildList(widget.audioFormats),
                    ],
                  ),
                ),
                
                // زر التحميل
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _selectedFormat == null ? null : () {
                        Navigator.pop(context); // إغلاق القائمة
                        // فتح نافذة التقدم
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => DownloadProgressDialog(
                            downloadUrl: _selectedFormat!['url'],
                            title: widget.title,
                            extension: _selectedFormat!['ext'],
                          )
                        );
                      },
                      child: const Text('بدء التنزيل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> formats) {
    if (formats.isEmpty) return const Center(child: Text('غير متوفر', style: TextStyle(color: AppColors.textMuted)));
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: formats.length,
      itemBuilder: (context, index) {
        final format = formats[index];
        final isSelected = _selectedFormat == format;
        return InkWell(
          onTap: () => setState(() => _selectedFormat = format),
          child: Container(
            color: isSelected ? AppColors.cyan.withOpacity(0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.cyan : AppColors.textMuted,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(format['quality_name'], style: TextStyle(color: isSelected ? AppColors.cyan : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('MB ${format['size']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// 2. نافذة تقدم التنزيل (Download Progress)
// ==========================================
class DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String title;
  final String extension;

  const DownloadProgressDialog({
    super.key,
    required this.downloadUrl,
    required this.title,
    required this.extension,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  final BackendService _backend = BackendService();
  double _progress = 0.0;
  String _downloadedSize = "0.0";
  String _totalSize = "0.0";
  bool _isFinished = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    await _backend.startDownloadProcess(
      downloadUrl: widget.downloadUrl,
      title: widget.title,
      extension: widget.extension,
      onProgress: (progress, downloaded, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _downloadedSize = downloaded;
            _totalSize = total;
          });
        }
      },
      onComplete: () {
        if (mounted) setState(() => _isFinished = true);
      },
      onError: () {
        if (mounted) setState(() => _hasError = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // لجعل التأثير الزجاجي يعمل
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasError) ...[
                  const Icon(Icons.error_outline_rounded, color: AppColors.orange, size: 60),
                  const SizedBox(height: 15),
                  const Text('فشل التنزيل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('تأكد من مساحة التخزين أو صلاحيات الوصول.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('إغلاق', style: TextStyle(color: Colors.white))
                  )
                ] else if (_isFinished) ...[
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.green, size: 50),
                  ),
                  const SizedBox(height: 15),
                  const Text('تم التنزيل بنجاح! 🎉', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('رائع', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                  )
                ] else ...[
                  const Text('جاري التنزيل...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  // شريط التقدم الفخم
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${(_progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                      Text('$_downloadedSize MB / $_totalSize MB', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
