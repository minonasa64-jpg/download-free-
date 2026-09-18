import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../../services/ad_service.dart';
import '../widgets/download_dialogs.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  final BackendService _backend = BackendService();
  final TextEditingController _urlController = TextEditingController();

  late final WebViewController _controller;
  bool _isLoading = false;
  double _progress = 0.0;
  String _currentUrl = 'https://www.google.com';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDesktopMode = false;

  // رصد الفيديو القابل للتحميل
  bool _detectedDownloadableMedia = false;
  String _detectedMediaUrl = '';
  Map<String, dynamic>? _extractedFormats;
  bool _isExtracting = false;

  final List<Map<String, dynamic>> _quickShortcuts = [
    {'name': 'YouTube', 'url': 'https://www.youtube.com', 'icon': Icons.smart_display_rounded, 'color': Colors.redAccent},
    {'name': 'TikTok', 'url': 'https://www.tiktok.com', 'icon': Icons.music_note_rounded, 'color': AppColors.cyan},
    {'name': 'Instagram', 'url': 'https://www.instagram.com', 'icon': Icons.camera_alt_rounded, 'color': Colors.pinkAccent},
    {'name': 'Facebook', 'url': 'https://www.facebook.com', 'icon': Icons.facebook_rounded, 'color': Colors.blueAccent},
    {'name': 'SoundCloud', 'url': 'https://soundcloud.com', 'icon': Icons.cloud_rounded, 'color': Colors.orangeAccent},
    {'name': 'Twitter / X', 'url': 'https://x.com', 'icon': Icons.tag_rounded, 'color': Colors.white},
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                _urlController.text = url;
                _detectedDownloadableMedia = false;
              });
            }
          },
          onPageFinished: (String url) async {
            final canBack = await _controller.canGoBack();
            final canFwd = await _controller.canGoForward();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _canGoBack = canBack;
                _canGoForward = canFwd;
                _currentUrl = url;
              });
              _sniffMediaUrl(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _sniffMediaUrl(String url) {
    // فحص ذكي للروابط المدعومة للتحميل الفوري
    final lower = url.toLowerCase();
    final isSupported = lower.contains('youtube.com/watch') ||
        lower.contains('youtu.be/') ||
        lower.contains('youtube.com/shorts') ||
        lower.contains('tiktok.com') ||
        lower.contains('instagram.com/p/') ||
        lower.contains('instagram.com/reel/') ||
        lower.contains('facebook.com') ||
        lower.contains('.mp4') ||
        lower.contains('.mp3');

    if (isSupported) {
      setState(() {
        _detectedDownloadableMedia = true;
        _detectedMediaUrl = url;
      });
    } else {
      setState(() {
        _detectedDownloadableMedia = false;
      });
    }
  }

  void _navigateToUrl(String input) {
    String finalUrl = input.trim();
    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        // بحث في جوجل
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }

    _urlController.text = finalUrl;
    _controller.loadRequest(Uri.parse(finalUrl));
    FocusScope.of(context).unfocus();
  }

  void _toggleDesktopMode() {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });

    final userAgent = _isDesktopMode
        ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        : '';
    _controller.setUserAgent(userAgent);
    _controller.reload();
  }

  Future<void> _startDownloadFromBrowser() async {
    if (_detectedMediaUrl.isEmpty) return;

    setState(() => _isExtracting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تحليل الرابط واستخراج الجودات... 🔍'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final mediaData = await _backend.extractMediaLinks(_detectedMediaUrl);
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _extractedFormats = mediaData;
        });

        _showFormatsModal(mediaData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استخراج الفيديو: $e'), backgroundColor: AppColors.orange),
        );
      }
    }
  }

  void _showFormatsModal(Map<String, dynamic> mediaData) {
    final title = mediaData['title'] ?? 'فيديو من المتصفح';
    final highestAudioUrl = mediaData['highestAudioUrl'] ?? '';
    final videos = List<Map<String, dynamic>>.from(mediaData['video'] ?? []);
    final audios = List<Map<String, dynamic>>.from(mediaData['audio'] ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (videos.isNotEmpty) ...[
                          const Text('🎬 جودات الفيديو (MP4):', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...videos.map((v) => _buildFormatTile(v, title, highestAudioUrl, false)),
                        ],
                        const SizedBox(height: 15),
                        if (audios.isNotEmpty) ...[
                          const Text('🎵 مقطع صوتي (MP3):', style: TextStyle(color: AppColors.magenta, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...audios.map((a) => _buildFormatTile(a, title, highestAudioUrl, true)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormatTile(Map<String, dynamic> format, String title, String audioUrl, bool isAudio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(isAudio ? Icons.audiotrack_rounded : Icons.videocam_rounded, color: isAudio ? AppColors.magenta : AppColors.cyan, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format['quality_name'] ?? (isAudio ? 'MP3 Audio' : 'Video'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'MB ${format['size']} • ${format['ext'].toString().toUpperCase()}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAudio ? AppColors.magenta : AppColors.cyan,
              foregroundColor: isAudio ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              AdService().showInterstitialAd();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => DownloadProgressDialog(
                  selectedUrl: format['url'],
                  title: title,
                  ext: format['ext'],
                  needsMerge: format['needs_merge'] ?? false,
                  highestAudioUrl: audioUrl,
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('تحميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // شريط العنوان والتحكم بالمتصفح
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: _canGoBack ? Colors.white : Colors.white24),
                        onPressed: _canGoBack ? () => _controller.goBack() : null,
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _canGoForward ? Colors.white : Colors.white24),
                        onPressed: _canGoForward ? () => _controller.goForward() : null,
                      ),
                      IconButton(
                        icon: Icon(_isLoading ? Icons.close_rounded : Icons.refresh_rounded, size: 20, color: Colors.white70),
                        onPressed: () {
                          if (_isLoading) {
                            _controller.runJavaScript('window.stop();');
                          } else {
                            _controller.reload();
                          }
                        },
                      ),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textInputAction: TextInputAction.go,
                            onSubmitted: _navigateToUrl,
                            decoration: InputDecoration(
                              hintText: 'ابحث أو أدخل رابط موقع...',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.cyan),
                              suffixIcon: _urlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                      onPressed: () => _urlController.clear(),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          _isDesktopMode ? Icons.desktop_windows_rounded : Icons.phone_android_rounded,
                          color: _isDesktopMode ? AppColors.cyan : Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'إصدار سطح المكتب',
                        onPressed: _toggleDesktopMode,
                      ),
                    ],
                  ),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // شريط اختصارات المنصات السريعة
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.surfaceLight.withOpacity(0.3),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _quickShortcuts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final s = _quickShortcuts[i];
                  return InkWell(
                    onTap: () => _navigateToUrl(s['url']),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(s['icon'] as IconData, size: 14, color: s['color'] as Color),
                          const SizedBox(width: 6),
                          Text(
                            s['name'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // عرض صفحة الويب
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),

                  // لافتة التقاط الفيديو التلقائية العائمة
                  if (_detectedDownloadableMedia)
                    Positioned(
                      bottom: 85,
                      left: 15,
                      right: 15,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.cyan.withOpacity(0.25),
                                  AppColors.magenta.withOpacity(0.25),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cyan, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.cyan,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.download_done_rounded, color: Colors.black, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '🎬 تم رصد وسائط قابلة للتحميل!',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'اضغط للتحميل المباشر بجودات متعددة',
                                        style: TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.cyan,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _isExtracting ? null : _startDownloadFromBrowser,
                                  child: _isExtracting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.download_rounded, size: 16),
                                            SizedBox(width: 4),
                                            Text('تحميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
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
            ),
          ],
        ),
      ),
    );
  }
}
