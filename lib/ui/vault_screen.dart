import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import 'local_video_player_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final BackendService _backend = BackendService();
  List<FileSystemEntity> _vaultFiles = [];
  bool _isLoading = true;

  late AudioPlayer _audioPlayer;
  File? _currentAudio;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _loadVaultFiles();
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

  Future<void> _loadVaultFiles() async {
    setState(() => _isLoading = true);
    final files = await _backend.getVaultFiles();
    if (mounted) {
      setState(() {
        _vaultFiles = files;
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

  Future<void> _restoreFile(File file) async {
    final success = await _backend.restoreFromVault(file);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_backend.t('restored_success')),
            backgroundColor: AppColors.cyan.withOpacity(0.9),
          ),
        );
        _loadVaultFiles();
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تأكيد الحذف من الخزنة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذا الملف نهائياً؟', style: TextStyle(color: Colors.white70)),
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
      await _backend.deleteVaultFile(file.path);
      if (mounted) {
        _loadVaultFiles();
      }
    }
  }

  void _showChangePinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.password_rounded, color: AppColors.cyan, size: 24),
            const SizedBox(width: 8),
            Text(_backend.t('set_pin'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز PIN جديد مكون من 4 أرقام:', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                }
              }
            },
            child: const Text('تحديث الرمز', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.cyan, size: 22),
            const SizedBox(width: 8),
            Text(
              _backend.t('vault'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.password_rounded, color: AppColors.cyan),
            tooltip: _backend.t('set_pin'),
            onPressed: _showChangePinDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
            : _vaultFiles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(35.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 55, color: AppColors.cyan),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _backend.t('vault_empty'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _vaultFiles.length,
                    itemBuilder: (context, index) {
                      final file = _vaultFiles[index] as File;
                      final isAudio = _isAudioFile(file.path);
                      final fileName = file.path.split('/').last;
                      final isPlaying = _currentAudio?.path == file.path && _isPlaying;
                      String sizeStr = '';
                      try {
                        if (file.existsSync()) {
                          final bytes = file.lengthSync();
                          sizeStr = bytes >= 1024 * 1024
                              ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                              : '${(bytes / 1024).toStringAsFixed(1)} KB';
                        }
                      } catch (_) {}

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isAudio
                                          ? AppColors.magenta.withOpacity(0.2)
                                          : AppColors.cyan.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isAudio ? Icons.music_note : Icons.videocam,
                                      color: isAudio ? AppColors.magenta : AppColors.cyan,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (sizeStr.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            sizeStr,
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isAudio
                                          ? (isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill)
                                          : Icons.play_circle_fill,
                                      color: isAudio ? AppColors.magenta : AppColors.cyan,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      if (isAudio) {
                                        _playAudio(file);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LocalVideoPlayerScreen(file: file),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                                    color: AppColors.surface,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    onSelected: (val) {
                                      if (val == 'restore') {
                                        _restoreFile(file);
                                      } else if (val == 'share') {
                                        Share.shareXFiles([XFile(file.path)], text: fileName);
                                      } else if (val == 'delete') {
                                        _deleteFile(file);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.lock_open_rounded, color: AppColors.cyan, size: 20),
                                            const SizedBox(width: 10),
                                            Text(_backend.t('restore_from_vault'), style: const TextStyle(color: Colors.white, fontSize: 13)),
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
                    },
                  ),
      ),
    );
  }
}
