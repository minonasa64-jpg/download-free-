import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
// import '../local_video_player_screen.dart'; // لتشغيل الفيديو محلياً (سننشئه لاحقاً)

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
  final BackendService _backend = BackendService();
  List<FileSystemEntity> _downloadedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // تحميل الملفات من التخزين المحلي
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });
    
    final files = await _backend.getDownloadedFiles();
    
    if (mounted) {
      setState(() {
        _downloadedFiles = files;
        _isLoading = false;
      });
    }
  }

  // حذف ملف مع التحديث
  Future<void> _deleteFile(String path, int index) async {
    // إزالة العنصر من الواجهة أولاً لسرعة الاستجابة (Optimistic UI update)
    final removedFile = _downloadedFiles[index];
    setState(() {
      _downloadedFiles.removeAt(index);
    });

    try {
      await _backend.deleteFile(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الملف بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // استرجاع العنصر إذا فشل الحذف
      if (mounted) {
        setState(() {
          _downloadedFiles.insert(index, removedFile);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في حذف الملف')),
        );
      }
    }
  }

  // الحصول على حجم الملف ليعرض في البطاقة
  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      return (bytes / (1024 * 1024)).toStringAsFixed(1);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان العلوي
          const Padding(
            padding: EdgeInsets.fromLTRB(25, 30, 25, 20),
            child: Text(
              'تنزيلاتي 📥',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          
          // عرض حالة التحميل أو الملفات أو حالة الفراغ
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                : _downloadedFiles.isEmpty
                    ? _buildEmptyState()
                    : _buildFilesList(),
          ),
        ],
      ),
    );
  }

  // حالة الفراغ الإبداعية (Empty State)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة صندوق فارغ مع Glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 80, color: AppColors.surfaceLight),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Icon(Icons.search_off_rounded, size: 30, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // النص المخصص
          const Text(
            'مازال ما هبطت والو 😎',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          
          const Text(
            'استخدم تبويب البحث أو الروابط\nللبدء في تحميل مقاطعك المفضلة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // قائمة الملفات
  Widget _buildFilesList() {
    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: AppColors.surface,
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 120, top: 10), // مسافة لشريط التنقل
        itemCount: _downloadedFiles.length,
        itemBuilder: (context, index) {
          final file = _downloadedFiles[index] as File;
          final fileName = file.path.split('/').last;
          final isAudio = fileName.endsWith('.mp3') || fileName.endsWith('.m4a');
          
          return _buildDownloadCard(file, fileName, isAudio, index);
        },
      ),
    );
  }

  // بطاقة الملف الزجاجية
  Widget _buildDownloadCard(File file, String fileName, bool isAudio, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                // أيقونة نوع الملف مع خلفية متدرجة
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withOpacity(0.3),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                
                // تفاصيل الملف
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isAudio ? 'صوت' : 'فيديو',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_getFileSize(file)} MB',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // أزرار التحكم (تشغيل / حذف)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: AppColors.cyan, size: 28),
                      onPressed: () {
                        // فتح صفحة المشاهدة المحلية
                        /*
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(file: file))
                        );
                        */
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.orange, size: 24),
                      onPressed: () => _showDeleteConfirmDialog(file.path, index, fileName),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // نافذة تأكيد الحذف
  void _showDeleteConfirmDialog(String path, int index, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الملف؟', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف "$fileName" نهائياً؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(path, index);
            },
            child: const Text('نعم، احذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
