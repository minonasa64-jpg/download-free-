import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import 'audio_trimmer_screen.dart';

class FullscreenMusicPlayerScreen extends StatefulWidget {
  final File file;
  final AudioPlayer audioPlayer;
  final Duration initialPosition;
  final Duration initialDuration;
  final bool isInitiallyPlaying;
  final VoidCallback onStateChanged;

  const FullscreenMusicPlayerScreen({
    super.key,
    required this.file,
    required this.audioPlayer,
    required this.initialPosition,
    required this.initialDuration,
    required this.isInitiallyPlaying,
    required this.onStateChanged,
  });

  @override
  State<FullscreenMusicPlayerScreen> createState() => _FullscreenMusicPlayerScreenState();
}

class _FullscreenMusicPlayerScreenState extends State<FullscreenMusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  final BackendService _backend = BackendService();
  late bool _isPlaying;
  late Duration _position;
  late Duration _duration;
  double _playbackSpeed = 1.0;
  bool _isLooping = false;
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isInitiallyPlaying;
    _position = widget.initialPosition;
    _duration = widget.initialDuration;

    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    if (_isPlaying) {
      _discAnimController.repeat();
    }

    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _discAnimController.repeat();
          } else {
            _discAnimController.stop();
          }
        });
        widget.onStateChanged();
      }
    });

    widget.audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    widget.audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _discAnimController.stop();
        });
        widget.onStateChanged();
      }
    });
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await widget.audioPlayer.pause();
    } else {
      await widget.audioPlayer.resume();
    }
  }

  void _seekRelative(int seconds) {
    final newSec = (_position.inSeconds + seconds).clamp(0, _duration.inSeconds);
    widget.audioPlayer.seek(Duration(seconds: newSec));
  }

  void _cycleSpeed() async {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];
    await widget.audioPlayer.setPlaybackRate(nextSpeed);
    setState(() => _playbackSpeed = nextSpeed);
  }

  void _toggleLoop() async {
    final nextMode = !_isLooping;
    await widget.audioPlayer.setReleaseMode(nextMode ? ReleaseMode.loop : ReleaseMode.release);
    setState(() => _isLooping = nextMode);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;
    final cleanName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // خلفية ديناميكية مشعة وناعمة
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.magenta.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: SafeArea(
              child: Column(
                children: [
                  // شريط علوي
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 36),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Column(
                          children: [
                            Text(
                              _backend.t('audio').toUpperCase(),
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Boykta Hi-Res Player',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (val) {
                            if (val == 'trim') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AudioTrimmerScreen(file: widget.file)),
                              );
                            } else if (val == 'share') {
                              Share.shareXFiles([XFile(widget.file.path)], text: fileName);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'trim',
                              child: Row(
                                children: [
                                  Icon(Icons.content_cut_rounded, color: AppColors.magenta, size: 20),
                                  const SizedBox(width: 10),
                                  Text(_backend.t('audio_trimmer'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, color: AppColors.cyan, size: 20),
                                  const SizedBox(width: 10),
                                  Text(_backend.t('share'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // أسطوانة الموسيقى الدائرية الفاخرة مع الأنماط الدائرية
                  Center(
                    child: RotationTransition(
                      turns: _discAnimController,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.cyan.withOpacity(0.4), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.magenta.withOpacity(0.35),
                              blurRadius: 35,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: AppColors.cyan.withOpacity(0.25),
                              blurRadius: 25,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // تفاصيل مسارات أسطوانة الفينيل
                            for (double r = 40; r <= 110; r += 20)
                              Container(
                                width: r * 2,
                                height: r * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.04),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            // القرص الداخلي
                            Container(
                              width: 85,
                              height: 85,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.magenta.withOpacity(0.5),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.music_note_rounded, color: Colors.white, size: 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // اسم الأغنية ومعلوماتها
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(
                          cleanName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq_rounded, color: AppColors.cyan, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_position.inSeconds > 0 ? "HQ Audio" : "Pure Audio"} • ${_playbackSpeed}x',
                                style: TextStyle(
                                  color: AppColors.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // شريط التقدم الزمني
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: AppColors.cyan,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: Colors.white,
                            overlayColor: AppColors.cyan.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                            max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                            onChanged: (val) {
                              widget.audioPlayer.seek(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // أزرار التحكم الاحترافية الكاملة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // زر تكرار
                        IconButton(
                          icon: Icon(
                            _isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            color: _isLooping ? AppColors.cyan : Colors.white38,
                            size: 24,
                          ),
                          tooltip: 'تكرار المقطع',
                          onPressed: _toggleLoop,
                        ),

                        // زر تقديم 10 ثوان للخلف
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 30),
                          tooltip: 'رجوع 10 ثوانٍ',
                          onPressed: () => _seekRelative(-10),
                        ),

                        // زر التشغيل والإيقاف الكبير
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),

                        // زر تقديم 10 ثوان للأمام
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 30),
                          tooltip: 'تقديم 10 ثوانٍ',
                          onPressed: () => _seekRelative(10),
                        ),

                        // زر السرعة
                        TextButton(
                          onPressed: _cycleSpeed,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(40, 36),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: _playbackSpeed != 1.0 ? AppColors.magenta.withOpacity(0.25) : Colors.white10,
                              border: Border.all(
                                color: _playbackSpeed != 1.0 ? AppColors.magenta : Colors.white24,
                              ),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: TextStyle(
                                color: _playbackSpeed != 1.0 ? AppColors.magenta : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
