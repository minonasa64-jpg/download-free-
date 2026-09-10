import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../core/app_colors.dart';

class LocalVideoPlayerScreen extends StatefulWidget {
  final FileSystemEntity file;
  
  const LocalVideoPlayerScreen({super.key, required this.file});

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isAudio = false;

  @override
  void initState() {
    super.initState();
    
    // التحقق مما إذا كان الملف صوتياً
    final fileName = widget.file.path.split('/').last.toLowerCase();
    if (fileName.endsWith('.mp3') || fileName.endsWith('.m4a')) {
      _isAudio = true;
    }

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.file.path));
    await _videoPlayerController.initialize();

    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: !_isAudio, // منع ملء الشاشة للصوتيات
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.cyan,
          handleColor: AppColors.magenta,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
      );
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: Colors.black, // خلفية سينمائية
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 35),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // إذا كان الملف صوتياً، نعرض أيقونة متوهجة بدلاً من الشاشة السوداء
                  if (_isAudio) ...[
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.magenta.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
                    ),
                    const SizedBox(height: 50),
                  ],
                  
                  // مشغل Chewie (سواء للفيديو أو شريط التحكم للصوت)
                  SizedBox(
                    height: _isAudio ? 100 : MediaQuery.of(context).size.height * 0.7,
                    child: Chewie(controller: _chewieController!),
                  ),
                ],
              )
            : const CircularProgressIndicator(color: AppColors.cyan),
      ),
    );
  }
}
