import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';

class AudioTrimmerScreen extends StatefulWidget {
  final File file;
  const AudioTrimmerScreen({super.key, required this.file});

  @override
  State<AudioTrimmerScreen> createState() => _AudioTrimmerScreenState();
}

class _AudioTrimmerScreenState extends State<AudioTrimmerScreen> {
  final BackendService _backend = BackendService();
  late AudioPlayer _audioPlayer;

  bool _isPlaying = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  double _startSeconds = 0.0;
  double _endSeconds = 30.0;
  bool _isProcessing = false;
  String _processStatus = '';
  File? _trimmedResultFile;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _totalDuration = d;
          if (_endSeconds > d.inSeconds.toDouble() && d.inSeconds > 0) {
            _endSeconds = d.inSeconds.toDouble();
          }
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _currentPosition = p);
        if (_isPlaying && p.inSeconds.toDouble() >= _endSeconds) {
          _audioPlayer.pause();
        }
      }
    });

    _audioPlayer.setSource(DeviceFileSource(widget.file.path));
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_currentPosition.inSeconds.toDouble() < _startSeconds ||
          _currentPosition.inSeconds.toDouble() >= _endSeconds) {
        await _audioPlayer.seek(Duration(seconds: _startSeconds.toInt()));
      }
      await _audioPlayer.resume();
    }
  }

  void _seekToStart() async {
    await _audioPlayer.seek(Duration(seconds: _startSeconds.toInt()));
  }

  void _applyPreset(int durationSeconds) {
    setState(() {
      final total = _totalDuration.inSeconds.toDouble();
      _endSeconds = (_startSeconds + durationSeconds).clamp(0.0, total > 0 ? total : 300.0);
    });
  }

  String _formatDuration(double seconds) {
    final int sec = seconds.toInt();
    final int m = sec ~/ 60;
    final int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _trimAudio() async {
    if (_endSeconds <= _startSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من أن وقت النهاية أكبر من وقت البداية')),
      );
      return;
    }

    await _audioPlayer.stop();
    setState(() {
      _isProcessing = true;
      _processStatus = 'جاري قص وتجهيز النغمة...';
    });

    try {
      final fileName = widget.file.path.split('/').last;
      final rawName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      final cleanName = rawName
          .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t\x00-\x1f]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final safeName = cleanName.isEmpty ? "audio" : cleanName;

      final parentDir = widget.file.parent;
      final lowerPath = widget.file.path.toLowerCase();
      final isSourceMp3 = lowerPath.endsWith('.mp3');
      final ext = isSourceMp3 ? 'mp3' : 'm4a';
      final outPath = '${parentDir.path}/${safeName}_ringtone_${_startSeconds.toInt()}s_${_endSeconds.toInt()}s.$ext';

      final startMs = (_startSeconds * 1000).toInt();
      final endMs = (_endSeconds * 1000).toInt();

      const muxerChannel = MethodChannel('com.boykta.app/media_muxer');
      final dynamic res = await muxerChannel.invokeMethod('trimAudio', {
        'inputPath': widget.file.path,
        'outputPath': outPath,
        'startMs': startMs,
        'endMs': endMs,
      });

      if (res == true && await File(outPath).exists()) {
        final resultFile = File(outPath);
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _trimmedResultFile = resultFile;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء النغمة بنجاح عبر MediaMuxer! 🎵'),
              backgroundColor: AppColors.cyan,
            ),
          );
        }
      } else {
        throw Exception('تعذر قص ملف الصوت');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء القص: $e'), backgroundColor: AppColors.orange),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;
    final maxDuration = _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 180.0;
    final clipDuration = (_endSeconds - _startSeconds).clamp(0.0, maxDuration);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.content_cut_rounded, color: AppColors.magenta, size: 22),
            SizedBox(width: 8),
            Text(
              'قص وتعديل الصوت (صانع النغمات)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كرت الملف المختار
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.magenta.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note_rounded, color: AppColors.magenta, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المدة الإجمالية: ${_formatDuration(maxDuration)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // منطقة معاينة المقطع المقصوص
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.magenta.withOpacity(0.15),
                      AppColors.cyan.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.magenta.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('نطاق المقطع:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(_startSeconds)} ➔ ${_formatDuration(_endSeconds)}',
                              style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.magenta.withOpacity(0.4)),
                          ),
                          child: Text(
                            'المدة: ${clipDuration.toStringAsFixed(1)} ثانية',
                            style: const TextStyle(color: AppColors.magenta, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // أزرار التحكم بالمعاينة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 28),
                          onPressed: _seekToStart,
                          tooltip: 'العودة للبداية',
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.magenta.withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // أدوات التحكم بالبداية والنهاية
              Text(
                'وقت البدء: ${_formatDuration(_startSeconds)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Slider(
                value: _startSeconds.clamp(0.0, maxDuration),
                min: 0.0,
                max: maxDuration,
                activeColor: AppColors.cyan,
                inactiveColor: Colors.white12,
                onChanged: (val) {
                  setState(() {
                    _startSeconds = val;
                    if (_endSeconds <= _startSeconds) {
                      _endSeconds = (_startSeconds + 5.0).clamp(0.0, maxDuration);
                    }
                  });
                },
              ),

              const SizedBox(height: 10),

              Text(
                'وقت النهاية: ${_formatDuration(_endSeconds)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Slider(
                value: _endSeconds.clamp(0.0, maxDuration),
                min: 0.0,
                max: maxDuration,
                activeColor: AppColors.magenta,
                inactiveColor: Colors.white12,
                onChanged: (val) {
                  setState(() {
                    _endSeconds = val;
                    if (_startSeconds >= _endSeconds) {
                      _startSeconds = (_endSeconds - 5.0).clamp(0.0, maxDuration);
                    }
                  });
                },
              ),

              const SizedBox(height: 15),

              // قوالب سريعة (Presets)
              const Text(
                'قوالب سريعة:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPresetChip('نغمة رنين (30 ثانية)', 30),
                  const SizedBox(width: 8),
                  _buildPresetChip('إشعار (10 ثوانٍ)', 10),
                  const SizedBox(width: 8),
                  _buildPresetChip('دقيقة كاملة (60 ث)', 60),
                ],
              ),

              const SizedBox(height: 30),

              // زر القص والتصدير
              if (_isProcessing) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.magenta),
                      const SizedBox(height: 12),
                      Text(_processStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _trimAudio,
                    icon: const Icon(Icons.content_cut_rounded, color: Colors.white),
                    label: const Text(
                      'قص وتصدير كـ MP3 ✂️',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

              // إظهار النتيجة عند الاكتمال
              if (_trimmedResultFile != null) ...[
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تم إنشاء النغمة بنجاح!',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _trimmedResultFile!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          Share.shareXFiles([XFile(_trimmedResultFile!.path)], text: 'نغمة من Boykta Pro');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int seconds) {
    return InkWell(
      onTap: () => _applyPreset(seconds),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
