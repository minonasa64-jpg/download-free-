import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
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

  late AudioPlayer _audioPlayer;
  File? _currentAudio;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAudioPlayer();
    _loadFiles();
    
    _backend.activeDownloads.addListener(_onActiveDownloadsChanged);
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  void _onActiveDownloadsChanged() {
    if (_backend.activeDownloads.value.isEmpty) {
      _loadFiles(); 
    }
  }

  bool _isAudioFile(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp3') || 
           p.endsWith('.m4a') || 
           p.endsWith('.opus') || 
           p.endsWith('.wav') || 
           p.endsWith('.aac') || 
           p.endsWith('.ogg');
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

  void _playAudio(File file) async {
    if (_currentAudio?.path == file.path) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } else {
      await _audioPlayer.play(DeviceFileSource(file.path));
      setState(() => _currentAudio = file);
    }
  }

  @override
  void dispose() {
    _backend.activeDownloads.removeListener(_onActiveDownloadsChanged);
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 30, 25, 10),
                // دمج دالة الترجمة هنا
                child: Text(
                  _backend.t('downloads'), 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                ),
              ),
              
              ValueListenableBuilder<List<DownloadTask>>(
                valueListenable: _backend.activeDownloads,
                builder: (context, tasks, child) {
                  if (tasks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: tasks.map((t) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_backend.t('downloading_now')} ${t.title}', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: t.progress, 
                              backgroundColor: Colors.white12, 
                              color: AppColors.cyan, 
                              minHeight: 8
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(t.progress * 100).toInt()}%', 
                                style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)
                              ),
                              Text(
                                '${t.downloaded} MB / ${t.total} MB', 
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)
                              ),
                            ]
                          )
                        ]
                      )
                    )).toList(),
                  );
                }
              ),

              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.cyan,
                labelColor: AppColors.cyan,
                unselectedLabelColor: AppColors.textMuted,
                tabs: [
                  Tab(icon: const Icon(Icons.video_library), text: _backend.t('video')),
                  Tab(icon: const Icon(Icons.library_music), text: _backend.t('audio')),
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
          
          if (_currentAudio != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.85),
                      border: Border(top: BorderSide(color: AppColors.magenta.withOpacity(0.5))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.magenta.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.music_note, color: AppColors.magenta, size: 25),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                _currentAudio!.path.split('/').last, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                              )
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, 
                                color: AppColors.cyan, 
                                size: 40
                              ),
                              onPressed: () => _playAudio(_currentAudio!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 28),
                              onPressed: () {
                                _audioPlayer.stop();
                                setState(() => _currentAudio = null);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              activeColor: AppColors.magenta,
                              inactiveColor: Colors.white24,
                              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                              onChanged: (val) => _audioPlayer.seek(Duration(seconds: val.toInt())),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
        padding: EdgeInsets.only(bottom: _currentAudio != null ? 120 : 20, top: 10), 
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
    final isCurrentlyPlaying = _currentAudio?.path == file.path;

    String sizeStr = '';
    try {
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes >= 1024 * 1024) {
          sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else {
          sizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentlyPlaying ? AppColors.magenta.withOpacity(0.15) : AppColors.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isCurrentlyPlaying ? AppColors.magenta.withOpacity(0.6) : Colors.white.withOpacity(0.05)
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 85,
                  height: 65,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(file, isAudio, isCurrentlyPlaying),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName, 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(
                          color: isCurrentlyPlaying ? AppColors.magenta : AppColors.textPrimary, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 13
                        )
                      ),
                      if (sizeStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          sizeStr,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isAudio)
                      IconButton(
                        icon: const Icon(Icons.audiotrack_rounded, color: AppColors.magenta, size: 22),
                        tooltip: _backend.t('convert_to_mp3'),
                        onPressed: () => _convertVideo(file),
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
                      tooltip: _backend.t('share'),
                      onPressed: () {
                        Share.shareXFiles([XFile(file.path)], text: fileName);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isAudio 
                          ? (isCurrentlyPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill) 
                          : Icons.play_circle_fill, 
                        color: isAudio && isCurrentlyPlaying ? AppColors.magenta : AppColors.cyan, 
                        size: 34
                      ),
                      onPressed: () {
                        if (file.existsSync()) {
                          if (isAudio) {
                            _playAudio(file);
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(file: file)));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_backend.t('file_not_found'))));
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

  Widget _buildThumbnail(File file, bool isAudio, bool isPlaying) {
    if (isAudio) {
      return Container(
        color: AppColors.magenta.withOpacity(0.2), 
        child: Icon(
          isPlaying ? Icons.equalizer_rounded : Icons.music_note, 
          color: AppColors.magenta, 
          size: 35
        )
      );
    } else {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 25,
        ).catchError((e) { return null; }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return Container(color: AppColors.surfaceLight, child: const Icon(Icons.videocam, color: AppColors.textMuted, size: 30));
        },
      );
    }
  }

  Future<void> _deleteFile(String path, File file, bool isAudio) async {
    if (_currentAudio?.path == path) {
      _audioPlayer.stop();
      setState(() => _currentAudio = null);
    }
    setState(() {
      if (isAudio) _audioFiles.remove(file); else _videoFiles.remove(file);
    });
    try {
      await _backend.deleteFile(path);
    } catch (e) {
      _loadFiles(); 
    }
  }

  Future<void> _convertVideo(File file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_backend.t('converting')),
        duration: const Duration(seconds: 2),
      ),
    );

    bool success = await _backend.convertVideoToMp3(
      videoFile: file,
      onStatus: (status) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );

    if (success && mounted) {
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
          Text(isAudio ? _backend.t('no_audio') : _backend.t('no_video'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}
