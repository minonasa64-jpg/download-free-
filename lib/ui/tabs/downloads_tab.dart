import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../../services/biometric_service.dart';
import '../local_video_player_screen.dart'; 
import '../vault_screen.dart';
import '../audio_trimmer_screen.dart';
import '../web_share_screen.dart'; 
import '../fullscreen_music_player_screen.dart';
import '../../services/thumbnail_service.dart';

enum DownloadSortMode {
  dateDesc, // الأحدث أولاً
  dateAsc,  // الأقدم أولاً
  sizeDesc, // الأكبر حجماً
  nameAsc,  // أبجدياً (أ-ي)
}

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

  // تنظيم التنزيلات: البحث، الفرز، والتجميع
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  String _searchQuery = '';
  DownloadSortMode _sortMode = DownloadSortMode.dateDesc;

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

  void _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    
    // إعداد AudioContext لضمان استمرار عمل المشغل حتى خارج التطبيق وقفل الشاشة
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: null,
          options: const {},
        ),
      ));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('Error configuring audio player context: $e');
    }
    
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
        _playNextAudioTrack();
      }
    });
  }

  void _playNextAudioTrack() {
    if (_audioFiles.isEmpty || _currentAudio == null) return;
    final idx = _audioFiles.indexWhere((f) => f.path == _currentAudio!.path);
    if (idx != -1 && idx + 1 < _audioFiles.length) {
      _playAudio(_audioFiles[idx + 1]);
    } else if (_audioFiles.isNotEmpty) {
      _playAudio(_audioFiles.first);
    }
  }

  void _playPreviousAudioTrack() {
    if (_audioFiles.isEmpty || _currentAudio == null) return;
    final idx = _audioFiles.indexWhere((f) => f.path == _currentAudio!.path);
    if (idx > 0) {
      _playAudio(_audioFiles[idx - 1]);
    } else if (_audioFiles.isNotEmpty) {
      _playAudio(_audioFiles.last);
    }
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

  void _openVault() async {
    final bioService = BiometricService();
    if (await bioService.isBiometricEnabled() && await bioService.isBiometricSupported()) {
      final authenticated = await bioService.authenticate();
      if (authenticated && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VaultScreen()),
        ).then((_) => _loadFiles());
        return;
      }
    }

    final hasPin = await _backend.isVaultPinSet();
    if (!mounted) return;
    if (!hasPin) {
      _showSetVaultPinDialog();
    } else {
      _showEnterVaultPinDialog();
    }
  }

  void _showSetVaultPinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.cyan, size: 24),
            const SizedBox(width: 8),
            Text(_backend.t('set_pin'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_backend.t('vault_desc'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () async {
              if (pinCtrl.text.trim().length == 4) {
                await _backend.setVaultPin(pinCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_backend.t('pin_set_success')), backgroundColor: AppColors.cyan.withOpacity(0.9)),
                  );
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())).then((_) => _loadFiles());
                }
              }
            },
            child: const Text('حفظ والدخول', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEnterVaultPinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.cyan, size: 24),
            const SizedBox(width: 8),
            Text(_backend.t('enter_pin'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () async {
              final isCorrect = await _backend.verifyVaultPin(pinCtrl.text.trim());
              if (isCorrect) {
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())).then((_) => _loadFiles());
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_backend.t('wrong_pin')), backgroundColor: AppColors.orange),
                  );
                }
              }
            },
            child: const Text('دخول', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _lockFileInVault(File file) async {
    final hasPin = await _backend.isVaultPinSet();
    if (!hasPin) {
      _showSetVaultPinDialog();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.cyan, size: 22),
            const SizedBox(width: 8),
            Text(_backend.t('move_to_vault'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل تريد نقل هذا الملف إلى الخزنة الآمنة المحمية برمز PIN؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نقل وقفل', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _backend.moveToVault(file);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_backend.t('moved_to_vault_success')), backgroundColor: AppColors.cyan.withOpacity(0.9)),
          );
          _loadFiles();
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              // الهيدر الرئيسي
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _backend.t('downloads'), 
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_videoFiles.length + _audioFiles.length} عنصر محفوظ (${_videoFiles.length} فيديو • ${_audioFiles.length} صوت)',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // زر البحث السريع
                        IconButton(
                          icon: Icon(
                            _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded, 
                            color: _isSearchVisible ? AppColors.magenta : AppColors.cyan
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchVisible = !_isSearchVisible;
                              if (!_isSearchVisible) {
                                _searchController.clear();
                                _searchQuery = '';
                              }
                            });
                          },
                          tooltip: 'بحث في التنزيلات',
                        ),
                        // قائمة فرز وترتيب الملفات
                        PopupMenuButton<DownloadSortMode>(
                          icon: Icon(Icons.sort_rounded, color: AppColors.cyan),
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          tooltip: 'ترتيب وتصنيف',
                          initialValue: _sortMode,
                          onSelected: (mode) {
                            setState(() => _sortMode = mode);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: DownloadSortMode.dateDesc,
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, color: _sortMode == DownloadSortMode.dateDesc ? AppColors.cyan : Colors.white70, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'الأحدث أولاً', 
                                    style: TextStyle(
                                      color: _sortMode == DownloadSortMode.dateDesc ? AppColors.cyan : Colors.white, 
                                      fontWeight: _sortMode == DownloadSortMode.dateDesc ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13
                                    )
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: DownloadSortMode.dateAsc,
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, color: _sortMode == DownloadSortMode.dateAsc ? AppColors.cyan : Colors.white70, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'الأقدم أولاً', 
                                    style: TextStyle(
                                      color: _sortMode == DownloadSortMode.dateAsc ? AppColors.cyan : Colors.white, 
                                      fontWeight: _sortMode == DownloadSortMode.dateAsc ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13
                                    )
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: DownloadSortMode.sizeDesc,
                              child: Row(
                                children: [
                                  Icon(Icons.data_usage_rounded, color: _sortMode == DownloadSortMode.sizeDesc ? AppColors.cyan : Colors.white70, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'الأكبر حجماً', 
                                    style: TextStyle(
                                      color: _sortMode == DownloadSortMode.sizeDesc ? AppColors.cyan : Colors.white, 
                                      fontWeight: _sortMode == DownloadSortMode.sizeDesc ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13
                                    )
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: DownloadSortMode.nameAsc,
                              child: Row(
                                children: [
                                  Icon(Icons.sort_by_alpha_rounded, color: _sortMode == DownloadSortMode.nameAsc ? AppColors.cyan : Colors.white70, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'أبجدياً (أ - ي)', 
                                    style: TextStyle(
                                      color: _sortMode == DownloadSortMode.nameAsc ? AppColors.cyan : Colors.white, 
                                      fontWeight: _sortMode == DownloadSortMode.nameAsc ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13
                                    )
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.wifi_tethering_rounded, color: AppColors.cyan),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WebShareScreen()),
                            );
                          },
                          tooltip: 'مشاركة عبر الـ Wi-Fi للكمبيوتر',
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: AppColors.cyan),
                          onPressed: _loadFiles,
                          tooltip: 'تحديث',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // حقل البحث في التنزيلات
              if (_isSearchVisible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim().toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: 'بحث في اسم الملف...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.cyan, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              
              // قائمة التنزيلات الجارية حالياً
              ValueListenableBuilder<List<DownloadTask>>(
                valueListenable: _backend.activeDownloads,
                builder: (context, tasks, child) {
                  if (tasks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: tasks.map((t) {
                      final bool isFailed = t.isFailed;
                      final double prog = t.progress;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isFailed 
                              ? Colors.red.withOpacity(0.12)
                              : AppColors.surfaceLight.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isFailed ? Colors.redAccent : AppColors.cyan.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isFailed ? Colors.red : AppColors.cyan).withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isFailed ? Colors.red : AppColors.cyan).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isFailed 
                                        ? Icons.error_outline_rounded 
                                        : (t.isAudio ? Icons.music_note_rounded : Icons.video_collection_rounded),
                                    color: isFailed ? Colors.redAccent : AppColors.cyan,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.status,
                                        style: TextStyle(
                                          color: isFailed ? Colors.redAccent : AppColors.cyan,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (t.speed.isNotEmpty && !isFailed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      t.speed,
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (prog > 0.0 && prog <= 1.0) ? prog : null,
                                backgroundColor: Colors.white12,
                                color: isFailed ? Colors.redAccent : AppColors.cyan,
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  prog > 0 ? "${(prog * 100).toStringAsFixed(1)}%" : "جاري التجهيز...",
                                  style: TextStyle(
                                    color: isFailed ? Colors.redAccent : AppColors.cyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  t.total != "--" && t.total != "0.0"
                                      ? "${t.downloaded} MB / ${t.total} MB"
                                      : "${t.downloaded} MB",
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              // تبويبات الفيديو والصوت
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_library, size: 18),
                          const SizedBox(width: 8),
                          Text('${_backend.t('video')} (${_videoFiles.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.library_music, size: 18),
                          const SizedBox(width: 8),
                          Text('${_backend.t('audio')} (${_audioFiles.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: AppColors.cyan))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFilesList(_videoFiles, isAudio: false),
                        _buildFilesList(_audioFiles, isAudio: true),
                      ],
                    ),
              )
            ],
          ),

          // مشغل الصوت المصغر
          if (_currentAudio != null)
            Positioned(
              left: 15,
              right: 15,
              bottom: 100, 
              child: GestureDetector(
                onTap: () {
                  if (_currentAudio != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullscreenMusicPlayerScreen(
                          file: _currentAudio!,
                          audioPlayer: _audioPlayer,
                          initialPosition: _position,
                          initialDuration: _duration,
                          isInitiallyPlaying: _isPlaying,
                          onStateChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.magenta.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.magenta.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.music_note_rounded, color: AppColors.magenta, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentAudio!.path.split('/').last, 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis, 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'اضغط هنا لفتح المشغل بملء الشاشة ↗',
                                      style: TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 24),
                                onPressed: _playPreviousAudioTrack,
                              ),
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, 
                                  color: AppColors.cyan, 
                                  size: 36,
                                ),
                                onPressed: () => _playAudio(_currentAudio!),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 24),
                                onPressed: _playNextAudioTrack,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                                onPressed: () {
                                  _audioPlayer.stop();
                                  setState(() => _currentAudio = null);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 18,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
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
            ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fileDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(fileDate).inDays;

    if (diffDays == 0) return 'اليوم';
    if (diffDays == 1) return 'أمس';
    if (diffDays < 7) return 'هذا الأسبوع';
    if (diffDays < 30) return 'هذا الشهر';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildFilesList(List<FileSystemEntity> files, {required bool isAudio}) {
    if (files.isEmpty) return _buildEmptyState(isAudio);

    // تطبيق فلتر البحث
    List<File> filtered = files
        .whereType<File>()
        .where((f) {
          if (_searchQuery.isEmpty) return true;
          final name = f.path.split('/').last.toLowerCase();
          return name.contains(_searchQuery);
        })
        .toList();

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('لا توجد نتائج مطابقة لـ "$_searchQuery"', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('جرب البحث باسم ملف آخر', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    // تطبيق الترتيب المختار
    switch (_sortMode) {
      case DownloadSortMode.dateDesc:
        filtered.sort((a, b) {
          try {
            return b.statSync().modified.compareTo(a.statSync().modified);
          } catch (_) {
            return 0;
          }
        });
        break;
      case DownloadSortMode.dateAsc:
        filtered.sort((a, b) {
          try {
            return a.statSync().modified.compareTo(b.statSync().modified);
          } catch (_) {
            return 0;
          }
        });
        break;
      case DownloadSortMode.sizeDesc:
        filtered.sort((a, b) {
          try {
            return b.lengthSync().compareTo(a.lengthSync());
          } catch (_) {
            return 0;
          }
        });
        break;
      case DownloadSortMode.nameAsc:
        filtered.sort((a, b) {
          final na = a.path.split('/').last.toLowerCase();
          final nb = b.path.split('/').last.toLowerCase();
          return na.compareTo(nb);
        });
        break;
    }

    // إذا كان الترتيب حسب التاريخ (dateDesc)، نقوم بتنظيم وتجميع الملفات في أقسام زمنية أنيقة
    if (_sortMode == DownloadSortMode.dateDesc) {
      final Map<String, List<File>> grouped = {};
      for (final file in filtered) {
        DateTime mod;
        try {
          mod = file.statSync().modified;
        } catch (_) {
          mod = DateTime.now();
        }
        final groupKey = _formatDateHeader(mod);
        grouped.putIfAbsent(groupKey, () => []).add(file);
      }

      int runningIndex = 0;
      return RefreshIndicator(
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        onRefresh: _loadFiles,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.only(bottom: _currentAudio != null ? 120 : 20, top: 10),
          itemCount: grouped.keys.length,
          itemBuilder: (context, sectionIndex) {
            final groupKey = grouped.keys.elementAt(sectionIndex);
            final groupFiles = grouped[groupKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (groupKey == 'اليوم' || groupKey == 'أمس')
                              ? (isAudio ? AppColors.magenta.withOpacity(0.25) : AppColors.cyan.withOpacity(0.25))
                              : AppColors.surfaceLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (groupKey == 'اليوم' || groupKey == 'أمس')
                                ? (isAudio ? AppColors.magenta.withOpacity(0.5) : AppColors.cyan.withOpacity(0.5))
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              groupKey == 'اليوم' ? Icons.fiber_new_rounded : Icons.schedule_rounded, 
                              size: 14, 
                              color: isAudio ? AppColors.magenta : AppColors.cyan
                            ),
                            const SizedBox(width: 6),
                            Text(
                              groupKey,
                              style: TextStyle(
                                color: isAudio ? AppColors.magenta : AppColors.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${groupFiles.length})',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.06), thickness: 1),
                      ),
                    ],
                  ),
                ),
                ...groupFiles.map((file) {
                  final idx = runningIndex++;
                  return _buildDownloadCard(file, isAudio, idx);
                }),
              ],
            );
          },
        ),
      );
    }

    // في حالات الترتيب الأخرى (بالحجم أو الأبجدي)، عرض القائمة مع إمكانية التمرير والتحديث
    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: AppColors.surface,
      onRefresh: _loadFiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(bottom: _currentAudio != null ? 120 : 20, top: 10), 
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final file = filtered[index];
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                  width: 75,
                  height: 55,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(file, isAudio, isCurrentlyPlaying),
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (sizeStr.isNotEmpty)
                            Text(
                              sizeStr,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAudio ? AppColors.magenta.withOpacity(0.2) : AppColors.cyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAudio ? 'صوت' : 'فيديو',
                              style: TextStyle(
                                color: isAudio ? AppColors.magenta : AppColors.cyan,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // زر التشغيل السريع
                IconButton(
                  icon: Icon(
                    isAudio 
                      ? (isCurrentlyPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill) 
                      : Icons.play_circle_fill, 
                    color: isAudio && isCurrentlyPlaying ? AppColors.magenta : AppColors.cyan, 
                    size: 32
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

                // قائمة الخيارات الإضافية (تحويل MP3، قفل بالخزنة، مشاركة، حذف) بدون أي Overflow
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  onSelected: (val) {
                    if (val == 'convert') {
                      _convertVideo(file);
                    } else if (val == 'trim') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AudioTrimmerScreen(file: file)),
                      ).then((_) => _loadFiles());
                    } else if (val == 'vault') {
                      _lockFileInVault(file);
                    } else if (val == 'share') {
                      Share.shareXFiles([XFile(file.path)], text: fileName);
                    } else if (val == 'delete') {
                      _deleteFile(file.path, file, isAudio);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isAudio)
                      PopupMenuItem(
                        value: 'convert',
                        child: Row(
                          children: [
                            Icon(Icons.audiotrack_rounded, color: AppColors.magenta, size: 20),
                            const SizedBox(width: 10),
                            Text(_backend.t('convert_to_mp3'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'trim',
                      child: Row(
                        children: [
                          Icon(Icons.content_cut_rounded, color: AppColors.magenta, size: 20),
                          SizedBox(width: 10),
                          Text('قص وتعديل الصوت (صانع النغمات)', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'vault',
                      child: Row(
                        children: [
                          Icon(Icons.shield_rounded, color: AppColors.cyan, size: 20),
                          const SizedBox(width: 10),
                          Text(_backend.t('move_to_vault'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
                          const SizedBox(width: 10),
                          Text(_backend.t('share'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.orange, size: 20),
                          SizedBox(width: 10),
                          Text('حذف', style: TextStyle(color: AppColors.orange, fontSize: 13)),
                        ],
                      ),
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
      final baseName = file.path.contains('.') ? file.path.substring(0, file.path.lastIndexOf('.')) : file.path;
      final localThumbJpg = File('$baseName.jpg');
      final localThumbPng = File('$baseName.png');

      if (localThumbJpg.existsSync() || localThumbPng.existsSync()) {
        final imgFile = localThumbJpg.existsSync() ? localThumbJpg : localThumbPng;
        return Image.file(
          imgFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAudioIcon(isPlaying),
        );
      }

      return _buildAudioIcon(isPlaying);
    }
    
    return FutureBuilder<Uint8List?>(
      future: ThumbnailService().getVideoThumbnail(file.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildVideoPlaceholder(),
          );
        }
        return _buildVideoPlaceholder();
      },
    );
  }

  Widget _buildAudioIcon(bool isPlaying) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.magenta.withOpacity(0.35),
            AppColors.purple.withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
          color: AppColors.magenta,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(Icons.videocam_rounded, color: AppColors.cyan, size: 28),
      ),
    );
  }

  Future<void> _deleteFile(String path, File file, bool isAudio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الملف نهائياً؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
        setState(() {
          if (isAudio) {
            _audioFiles.removeWhere((f) => f.path == path);
            if (_currentAudio?.path == path) {
              _audioPlayer.stop();
              _currentAudio = null;
            }
          } else {
            _videoFiles.removeWhere((f) => f.path == path);
          }
        });
      } catch (e) {
        debugPrint('Delete error: $e');
      }
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAudio ? AppColors.magenta.withOpacity(0.1) : AppColors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAudio ? Icons.music_off_rounded : Icons.videocam_off_rounded, 
              size: 60, 
              color: isAudio ? AppColors.magenta : AppColors.cyan
            ),
          ),
          const SizedBox(height: 15),
          Text(
            isAudio ? _backend.t('no_audio') : _backend.t('no_video'), 
            style: TextStyle(color: AppColors.textMuted, fontSize: 16)
          ),
          const SizedBox(height: 8),
          Text(
            'حمّل مقاطع جديدة من تبويب يوتيوب أو الروابط لتظهر هنا',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
