import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../../services/ad_service.dart';
import '../widgets/download_dialogs.dart';

class LinksTab extends StatefulWidget {
  const LinksTab({super.key});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  final TextEditingController _urlController = TextEditingController();
  final BackendService _backend = BackendService();

  bool _isAnalyzing = false;
  bool _hasResult = false;
  Map<String, dynamic>? _mediaData;
  Map<String, dynamic>? _selectedFormat;
  String? _detectedClipboardUrl;

  @override
  void initState() {
    super.initState();
    _checkClipboardForMedia();
  }

  Future<void> _checkClipboardForMedia() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        if ((text.startsWith('http://') || text.startsWith('https://')) && text.length > 10) {
          if (mounted) {
            setState(() {
              _detectedClipboardUrl = text;
            });
          }
        }
      }
    } catch (_) {}
  }
  
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _urlController.text = clipboardData.text!.trim();
        _detectedClipboardUrl = null;
      });
    }
  }

  Future<void> _analyzeLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الرابط أولاً')),
      );
      return;
    }

    FocusScope.of(context).unfocus(); 
    
    setState(() {
      _isAnalyzing = true;
      _hasResult = false;
      _selectedFormat = null;
    });

    try {
      final result = await _backend.extractMediaLinks(url);
      
      final List videoList = result['video'] ?? [];
      final List audioList = result['audio'] ?? [];

      if (mounted) {
        if (videoList.isEmpty && audioList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_backend.t('file_not_found'))),
          );
          setState(() {
            _isAnalyzing = false;
          });
        } else {
          setState(() {
            _mediaData = result;
            _hasResult = true;
            _isAnalyzing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120), 
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.magenta.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link, size: 50, color: AppColors.magenta),
            ),
            const SizedBox(height: 15),
            Text(
              _backend.t('have_link'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 30),
            _buildInputSection(),
            const SizedBox(height: 30),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isAnalyzing
                  ? _buildLoadingState()
                  : _hasResult
                      ? _buildResultCard()
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (_detectedClipboardUrl != null) ...[
            GestureDetector(
              onTap: () {
                _urlController.text = _detectedClipboardUrl!;
                setState(() => _detectedClipboardUrl = null);
                _analyzeLink();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _backend.t('clipboard_detected'),
                        style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 12),
                  ],
                ),
              ),
            ),
          ],
          ClipRRect(
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
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'https://...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste, size: 18),
                            label: const Text('لصق', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _analyzeLink,
                              child: Text(
                                _backend.t('download_btn'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildQuickPlatforms(),
        ],
      ),
    );
  }

  Widget _buildQuickPlatforms() {
    final platforms = [
      {'name': 'YouTube', 'icon': Icons.smart_display_rounded, 'color': Colors.redAccent},
      {'name': 'TikTok', 'icon': Icons.music_note_rounded, 'color': AppColors.cyan},
      {'name': 'Instagram', 'icon': Icons.camera_alt_rounded, 'color': AppColors.magenta},
      {'name': 'Facebook', 'icon': Icons.facebook_rounded, 'color': Colors.blueAccent},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: platforms.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(p['icon'] as IconData, size: 14, color: p['color'] as Color),
              const SizedBox(width: 5),
              Text(
                p['name'] as String,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      key: const ValueKey('loading'),
      children: [
        const CircularProgressIndicator(
          color: AppColors.cyan,
          strokeWidth: 3,
        ),
        const SizedBox(height: 15),
        Text(
          _backend.t('extracting'),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        )
      ],
    );
  }

  Widget _buildResultCard() {
    final title = _mediaData?['title'] ?? 'فيديو بدون عنوان';
    final thumbnail = _mediaData?['thumbnail'] ?? 'https://via.placeholder.com/400x225/12121A/00D9FF?text=Video';
    final highestAudioUrl = _mediaData?['highestAudioUrl'] ?? '';
    
    // فلترة وتجنب التكرار الذكي
    final videoList = _processFormats(List<Map<String, dynamic>>.from(_mediaData?['video'] ?? []));
    final audioList = _processFormats(List<Map<String, dynamic>>.from(_mediaData?['audio'] ?? []));

    return Container(
      key: const ValueKey('result'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              thumbnail,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: AppColors.surfaceLight, height: 1),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  indicatorColor: AppColors.cyan,
                  labelColor: AppColors.cyan,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    Tab(icon: const Icon(Icons.video_library), text: _backend.t('video')),
                    Tab(icon: const Icon(Icons.library_music), text: _backend.t('audio')),
                  ],
                ),
                SizedBox(
                  height: 220, 
                  child: TabBarView(
                    children: [
                      _buildFormatList(videoList, Icons.play_circle_outline),
                      _buildFormatList(audioList, Icons.music_note),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedFormat != null)
            Padding(
              padding: const EdgeInsets.all(15),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    AdService().showInterstitialAd();
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => DownloadProgressDialog(
                        selectedUrl: _selectedFormat!['url'],
                        title: title,
                        ext: _selectedFormat!['ext'],
                        needsMerge: _selectedFormat!['needs_merge'],
                        highestAudioUrl: highestAudioUrl,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    '⬇️ تحميل الآن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // دالة ذكية لإزالة الجودات المكررة وترتيبها
  List<Map<String, dynamic>> _processFormats(List<Map<String, dynamic>> formats) {
    if (formats.isEmpty) return [];
    var uniqueFormats = <String, Map<String, dynamic>>{};
    for (var f in formats) {
      uniqueFormats[f['quality_name']] = f; 
    }
    var sortedList = uniqueFormats.values.toList();
    
    sortedList.sort((a, b) {
      double sizeA = double.tryParse(a['size'].toString()) ?? 0.0;
      double sizeB = double.tryParse(b['size'].toString()) ?? 0.0;
      return sizeB.compareTo(sizeA); // الأكبر أولاً
    });
    return sortedList;
  }

  Widget _buildFormatList(List<Map<String, dynamic>> formats, IconData icon) {
    if (formats.isEmpty) {
      return const Center(
        child: Text('هذه الصيغة غير متوفرة', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: formats.length,
      itemBuilder: (context, index) {
        final format = formats[index];
        final isSelected = _selectedFormat == format;
        
        return InkWell(
          onTap: () {
            setState(() {
              _selectedFormat = format;
            });
          },
          child: Container(
            color: isSelected ? AppColors.cyan.withOpacity(0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.cyan : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format['quality_name'],
                      style: TextStyle(
                        color: isSelected ? AppColors.cyan : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MB ${format['size']}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                if (format['needs_merge'] == true)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('عالية الجودة', style: TextStyle(color: AppColors.orange, fontSize: 9)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    format['ext'].toString().toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
