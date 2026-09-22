import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_colors.dart';
import '../core/theme_service.dart';
import '../services/backend_service.dart';
import 'local_video_player_screen.dart';

class VaultScreen extends StatefulWidget {
  final bool isDecoy;

  const VaultScreen({super.key, this.isDecoy = false});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final BackendService _backend = BackendService();
  List<FileSystemEntity> _vaultFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all'; // all, video, audio

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
    if (widget.isDecoy) {
      // الخزنة الوهمية تظهر دائماً فارغة أو بدون ملفات المستخدم السرية
      if (mounted) {
        setState(() {
          _vaultFiles = [];
          _isLoading = false;
        });
      }
      return;
    }

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

  Future<void> _importFileManually() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'webm', 'avi', 'mov', 'mp3', 'm4a', 'wav', 'aac', 'opus'],
    );

    if (result != null && result.files.single.path != null) {
      final pickedFile = File(result.files.single.path!);
      final success = await _backend.moveToVault(pickedFile);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تشفير الملف وإضافته إلى الخزنة بنجاح 🔒'),
              backgroundColor: AppColors.cyan,
            ),
          );
          _loadVaultFiles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل نقل الملف إلى الخزنة'),
              backgroundColor: AppColors.orange,
            ),
          );
        }
      }
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
    final primaryColor = ThemeService().currentTheme.value.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredFiles = _vaultFiles.where((entity) {
      if (entity is! File) return false;
      final path = entity.path.toLowerCase();
      final isAudio = _isAudioFile(path);
      if (_filter == 'video' && isAudio) return false;
      if (_filter == 'audio' && !isAudio) return false;
      if (_searchQuery.isNotEmpty) {
        final name = path.split('/').last;
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF101018) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              widget.isDecoy ? 'الخزنة الآمنة' : _backend.t('vault'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.textPrimary : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor),
            tooltip: 'تشفير وإضافة ملف من الجهاز',
            onPressed: _importFileManually,
          ),
          IconButton(
            icon: Icon(Icons.password_rounded, color: primaryColor),
            tooltip: _backend.t('set_pin'),
            onPressed: _showChangePinDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // شريط البحث وفلاتر الوسائط
            if (_vaultFiles.isNotEmpty || _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'بحث في ملفات الخزنة...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildFilterChip('الكل', 'all', primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('فيديوهات', 'video', primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('صوتيات', 'audio', primaryColor, isDark),
                      ],
                    ),
                  ],
                ),
              ),

            // قائمة الملفات
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : filteredFiles.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(35.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                                  ),
                                  child: Icon(Icons.lock_outline_rounded, size: 55, color: primaryColor),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'لا توجد ملفات تطابق بحثك'
                                      : (widget.isDecoy ? 'لا توجد ملفات مخزنة حالياً' : _backend.t('vault_empty')),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? AppColors.textMuted : Colors.black54,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _importFileManually,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('إضافة ملف مشفر للخزنة', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredFiles.length,
                          itemBuilder: (context, index) {
                            final file = filteredFiles[index] as File;
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
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.surfaceLight.withOpacity(0.5)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? primaryColor.withOpacity(0.2)
                                            : Colors.black.withOpacity(0.06),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isAudio
                                                ? AppColors.magenta.withOpacity(0.2)
                                                : primaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isAudio ? Icons.music_note : Icons.videocam,
                                            color: isAudio ? AppColors.magenta : primaryColor,
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
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black87,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (sizeStr.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  sizeStr,
                                                  style: TextStyle(
                                                    color: isDark ? AppColors.textMuted : Colors.black54,
                                                    fontSize: 11,
                                                  ),
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
                                            color: isAudio ? AppColors.magenta : primaryColor,
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
                                          icon: Icon(
                                            Icons.more_vert_rounded,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                            size: 22,
                                          ),
                                          color: isDark ? AppColors.surface : Colors.white,
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
                                                  Icon(Icons.lock_open_rounded, color: primaryColor, size: 20),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _backend.t('restore_from_vault'),
                                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'share',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.share_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _backend.t('share'),
                                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color primaryColor, bool isDark) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.2)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
