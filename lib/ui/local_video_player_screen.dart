import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../core/app_colors.dart';

class LocalVideoPlayerScreen extends StatefulWidget {
  final File file;
  
  const LocalVideoPlayerScreen({super.key, required this.file});

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(widget.file);
      await _videoPlayerController.initialize();
      
      if (mounted) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: true,
            looping: false,
            allowFullScreen: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: AppColors.cyan,
              handleColor: AppColors.magenta,
              backgroundColor: Colors.white24,
              bufferedColor: Colors.white54,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isError = true);
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.file.path.split('/').last,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _isError 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.orange, size: 50),
                const SizedBox(height: 15),
                const Text('تعذر تشغيل هذا الملف', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 5),
                const Text('قد يكون الملف تالفاً أو بصيغة غير مدعومة', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            )
          : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(color: AppColors.cyan),
      ),
    );
  }
}
