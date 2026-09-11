import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';

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
  
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _urlController.text = clipboardData.text!;
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

  String _getThumbnailUrl(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final RegExp regExp = RegExp(
          r'(?:(?:https?:)?\/\/)?(?:(?:www|m)\.)?(?:(?:youtube\.com|youtu.be))(?:\/(?:[\w\-]+\?v=|embed\/|v\/)?)([\w\-]+)(\S+)?');
      final match = regExp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        final videoId = match.group(1);
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }
    return 'https://via.placeholder.com/400x225/12121A/00D9FF?text=Video+Thumbnail';
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
      child: ClipRRect(
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
    final videoList = List<Map<String, dynamic>>.from(_mediaData?['video'] ?? []);
    final audioList = List<Map<String, dynamic>>.from(_mediaData?['audio'] ?? []);

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
              _getThumbnailUrl(_urlController.text),
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
                    // إغلاق النافذة للمتابعة
                    setState(() {
                      _hasResult = false;
                      _urlController.clear();
                    });
                    
                    // تحديد ما إذا كان الملف صوتاً أم لا
                    bool isAudio = _selectedFormat!['ext'] == 'mp3' || _selectedFormat!['ext'] == 'm4a';
                    
                    // بدء التنزيل في الخلفية مع الإشعارات
                    BackendService().startDownloadProcess(
                      downloadUrl: _selectedFormat!['url'],
                      title: title,
                      extension: _selectedFormat!['ext'],
                      isAudio: isAudio,
                    );

                    // رسالة تأكيد لبدء العملية
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('بدأ التنزيل في الخلفية... يمكنك متابعة التصفح 🚀'),
                        backgroundColor: AppColors.cyan,
                        duration: Duration(seconds: 3),
                      )
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
