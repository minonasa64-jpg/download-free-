import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../local_video_player_screen.dart'; 

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> with SingleTickerProviderStateMixin {
  final BackendService _backend = BackendService();
  late TabController _tabController;
  List<FileSystemEntity> _videoFiles = [];
  List<FileSystemEntity> _audioFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFiles();
  }

  // دالة ذكية للتعرف على جميع صيغ الصوت المحتملة
  bool _isAudioFile(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp3') || 
           p.endsWith('.m4a') || 
           p.endsWith('.opus') || 
           p.endsWith('.wav') || 
           p.endsWith('.weba') || 
           p.endsWith('.aac') || 
           p.endsWith('.ogg') ||
           p.endsWith('.flac');
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final files = await _backend.getDownloadedFiles();
    
    if (mounted) {
      setState(() {
        _videoFiles = files.where((f) => !_isAudioFile(f.path)).toList();
        _audioFiles = files.where((f) => _isAudioFile(f.path)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(25, 30, 25, 10),
            child: Text('تنزيلاتي 📥', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.cyan,
            labelColor: AppColors.cyan,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.video_library), text: 'الفيديوهات'),
              Tab(icon: Icon(Icons.library_music), text: 'الموسيقى'),
            ],
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFilesList(_videoFiles, isAudio: false),
                      _buildFilesList(_audioFiles, isAudio: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<FileSystemEntity> files, {required bool isAudio}) {
    if (files.isEmpty) return _buildEmptyState(isAudio);

    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: AppColors.surface,
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 120, top: 10), 
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index] as File;
          return _buildDownloadCard(file, isAudio, index);
        },
      ),
    );
  }

  Widget _buildDownloadCard(File file, bool isAudio, int index) {
    final fileName = file.path.split('/').last;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(file, isAudio),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: AppColors.cyan, size: 35),
                      onPressed: () {
                        if (file.existsSync()) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(file: file)));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير موجود أو تم حذفه')));
                          _loadFiles();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.orange, size: 22),
                      onPressed: () => _deleteFile(file.path, file, isAudio),
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

  // دالة بناء الصورة المصغرة مع حماية الأخطاء (Error Handling)
  Widget _buildThumbnail(File file, bool isAudio) {
    if (isAudio) {
      return Container(
        color: AppColors.magenta.withOpacity(0.2), 
        child: const Icon(Icons.music_note, color: AppColors.magenta, size: 30)
      );
    } else {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 25,
        ).catchError((e) {
          // منع الانهيار إذا فشل استخراج الصورة
          return null; 
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          // الصورة البديلة في حال فشل الاستخراج
          return Container(
            color: AppColors.surfaceLight, 
            child: const Icon(Icons.videocam, color: AppColors.textMuted, size: 30)
          );
        },
      );
    }
  }

  Future<void> _deleteFile(String path, File file, bool isAudio) async {
    setState(() {
      if (isAudio) {
        _audioFiles.remove(file);
      } else {
        _videoFiles.remove(file);
      }
    });
    try {
      await _backend.deleteFile(path);
    } catch (e) {
      _loadFiles(); 
    }
  }

  Widget _buildEmptyState(bool isAudio) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isAudio ? Icons.library_music_outlined : Icons.video_library_outlined, size: 80, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(isAudio ? 'لا توجد موسيقى محملة' : 'لا توجد فيديوهات محملة', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
