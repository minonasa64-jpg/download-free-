import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
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
  String _currentTitle = 'Google';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isDesktopMode = false;

  // ==========================================
  // الميزة 1: ملتقط الوسائط الذكي (Smart Video Sniffer)
  // ==========================================
  bool _detectedDownloadableMedia = false;
  String _detectedMediaUrl = '';
  final Set<String> _sniffedMediaUrls = {};
  bool _isExtracting = false;

  // ==========================================
  // الميزة 2: مانع الإعلانات الذكي (AdBlocker)
  // ==========================================
  bool _adBlockerEnabled = true;
  int _blockedAdsCount = 0;
  static const List<String> _adFilterDomains = [
    'doubleclick.net',
    'googlesyndication.com',
    'adservice.google.com',
    'googleads.g.doubleclick.net',
    'popads.net',
    'adroll.com',
    'adnxs.com',
    'scorecardresearch.com',
    'criteo.com',
    'taboola.com',
    'outbrain.com',
    'propellerads.com',
    'bidswitch.net',
    'smartadserver.com',
    'rubiconproject.com',
    'moatads.com',
    'adcolony.com',
    'applovin.com',
    'unityads.unity3d.com',
    'inmobi.com',
    'vungle.com',
    'pubmatic.com',
    'openx.net',
    'advertising.com',
    'revcontent.com',
    'mgid.com',
    'adsterra.com',
    'exoclick.com',
    'trafficjunky.com',
  ];

  // ==========================================
  // الميزة 3: إدارة الإشارات المرجعية (Bookmarks)
  // ==========================================
  List<Map<String, String>> _bookmarks = [];
  bool _isCurrentBookmarked = false;

  // ==========================================
  // الميزة 4: وضع التصفح الخفي (Incognito Mode)
  // ==========================================
  bool _isIncognitoMode = false;

  // ==========================================
  // الميزة 5: اختيار محرك البحث المفضل
  // ==========================================
  String _selectedSearchEngine = 'Google';
  final Map<String, String> _searchEngines = {
    'Google': 'https://www.google.com/search?q=',
    'DuckDuckGo': 'https://duckduckgo.com/?q=',
    'Bing': 'https://www.bing.com/search?q=',
    'Yahoo': 'https://search.yahoo.com/search?p=',
    'Yandex': 'https://yandex.com/search/?text=',
  };

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
    _loadPreferences();
    _initWebView();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // تحميل مانع الإعلانات
    _adBlockerEnabled = prefs.getBool('browser_adblock_enabled') ?? true;
    _blockedAdsCount = prefs.getInt('browser_adblock_count') ?? 0;

    // تحميل محرك البحث المفضل
    _selectedSearchEngine = prefs.getString('browser_search_engine') ?? 'Google';
    if (!_searchEngines.containsKey(_selectedSearchEngine)) {
      _selectedSearchEngine = 'Google';
    }

    // تحميل الإشارات المرجعية
    final bStr = prefs.getString('browser_bookmarks');
    if (bStr != null && bStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(bStr);
        _bookmarks = decoded.map((e) => Map<String, String>.from(e)).toList();
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('browser_bookmarks', jsonEncode(_bookmarks));
    _checkBookmarkStatus();
  }

  void _checkBookmarkStatus() {
    final exists = _bookmarks.any((b) => b['url'] == _currentUrl);
    if (mounted && exists != _isCurrentBookmarked) {
      setState(() => _isCurrentBookmarked = exists);
    }
  }

  void _toggleBookmark() async {
    if (_isCurrentBookmarked) {
      _bookmarks.removeWhere((b) => b['url'] == _currentUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إزالة الصفحة من الإشارات المرجعية 🗑️'), duration: Duration(seconds: 1)),
      );
    } else {
      _bookmarks.add({
        'title': _currentTitle.isNotEmpty ? _currentTitle : _currentUrl,
        'url': _currentUrl,
        'date': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الصفحة للإشارات المرجعية ⭐'), duration: Duration(seconds: 1)),
      );
    }
    await _saveBookmarks();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'MediaSnifferChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleSnifferJsMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // فحص مانع الإعلانات
            if (_adBlockerEnabled) {
              for (final domain in _adFilterDomains) {
                if (url.contains(domain)) {
                  setState(() => _blockedAdsCount++);
                  _incrementBlockedCount();
                  debugPrint('🛡️ تم حظر إعلان: ${request.url}');
                  return NavigationDecision.prevent;
                }
              }
            }

            // فحص روابط الوسائط المباشرة أثناء التنقل
            _checkDirectMediaLink(request.url);

            return NavigationDecision.navigate;
          },
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
                _sniffedMediaUrls.clear();
              });
            }
          },
          onPageFinished: (String url) async {
            final canBack = await _controller.canGoBack();
            final canFwd = await _controller.canGoForward();
            final title = await _controller.getTitle() ?? url;

            if (mounted) {
              setState(() {
                _isLoading = false;
                _canGoBack = canBack;
                _canGoForward = canFwd;
                _currentUrl = url;
                _currentTitle = title;
              });
              _checkBookmarkStatus();
              _sniffMediaUrl(url);
              _injectSnifferScript();
              if (_adBlockerEnabled) {
                _injectAdCleanerScript();
              }
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

  Future<void> _incrementBlockedCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('browser_adblock_count', _blockedAdsCount);
  }

  // حقن سكربت كاشف الوسائط الفائق في الصفحة
  void _injectSnifferScript() {
    const jsCode = '''
      (function() {
        try {
          var found = [];
          var mediaEls = document.querySelectorAll('video, audio, source');
          for (var i = 0; i < mediaEls.length; i++) {
            var src = mediaEls[i].src || mediaEls[i].currentSrc;
            if (src && (src.startsWith('http://') || src.startsWith('https://'))) {
              if (found.indexOf(src) === -1) found.push(src);
            }
          }
          if (found.length > 0 && window.MediaSnifferChannel) {
            window.MediaSnifferChannel.postMessage(JSON.stringify(found));
          }
        } catch(e) {}
      })();
    ''';
    _controller.runJavaScript(jsCode);
  }

  // حقن سكربت تنظيف الإعلانات من الصفحة
  void _injectAdCleanerScript() {
    const jsClean = '''
      (function() {
        try {
          var sel = '.adsbygoogle, [id*="ad-"], [class*="ad-box"], [class*="ad-banner"], [class*="ad_banner"], iframe[src*="ad"]';
          document.querySelectorAll(sel).forEach(function(el) {
            el.style.display = 'none';
          });
        } catch(e) {}
      })();
    ''';
    _controller.runJavaScript(jsClean);
  }

  void _handleSnifferJsMessage(String message) {
    try {
      final List decoded = jsonDecode(message);
      for (var item in decoded) {
        if (item is String && item.isNotEmpty) {
          _sniffedMediaUrls.add(item);
        }
      }
      if (_sniffedMediaUrls.isNotEmpty && mounted) {
        setState(() {
          _detectedDownloadableMedia = true;
          _detectedMediaUrl = _sniffedMediaUrls.first;
        });
      }
    } catch (_) {}
  }

  void _checkDirectMediaLink(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mp3') || lower.endsWith('.m3u8') || lower.endsWith('.webm') || lower.endsWith('.m4a')) {
      _sniffedMediaUrls.add(url);
      if (mounted) {
        setState(() {
          _detectedDownloadableMedia = true;
          _detectedMediaUrl = url;
        });
      }
    }
  }

  void _sniffMediaUrl(String url) {
    final lower = url.toLowerCase();
    final isSupportedPlatform = lower.contains('youtube.com/watch') ||
        lower.contains('youtu.be/') ||
        lower.contains('youtube.com/shorts') ||
        lower.contains('tiktok.com') ||
        lower.contains('instagram.com/p/') ||
        lower.contains('instagram.com/reel/') ||
        lower.contains('facebook.com') ||
        lower.contains('x.com/') ||
        lower.contains('twitter.com/') ||
        lower.contains('soundcloud.com') ||
        lower.contains('.mp4') ||
        lower.contains('.mp3') ||
        lower.contains('.m3u8');

    if (isSupportedPlatform) {
      _sniffedMediaUrls.add(url);
      setState(() {
        _detectedDownloadableMedia = true;
        _detectedMediaUrl = url;
      });
    } else if (_sniffedMediaUrls.isEmpty) {
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
        // استخدام محرك البحث المفضل المختار من المستخدم
        final searchBase = _searchEngines[_selectedSearchEngine] ?? 'https://www.google.com/search?q=';
        finalUrl = '$searchBase${Uri.encodeComponent(finalUrl)}';
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

  // تفعيل/تعطيل التصفح الخفي (Incognito Mode)
  void _toggleIncognitoMode() async {
    setState(() {
      _isIncognitoMode = !_isIncognitoMode;
    });

    if (_isIncognitoMode) {
      // تفريغ الكاش والكوكيز لحماية الخصوصية
      try {
        final cookieManager = WebViewCookieManager();
        await cookieManager.clearCookies();
        await _controller.clearCache();
        await _controller.clearLocalStorage();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🕶️ تم تفعيل الوضع الخفي: لن يتم حفظ السجل أو الكوكيز'),
          backgroundColor: Color(0xFF3F51B5),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعطيل الوضع الخفي'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // تبديل مانع الإعلانات
  void _toggleAdBlocker() async {
    setState(() {
      _adBlockerEnabled = !_adBlockerEnabled;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('browser_adblock_enabled', _adBlockerEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_adBlockerEnabled ? '🛡️ تم تفعيل مانع الإعلانات' : 'تم تعطيل مانع الإعلانات'),
        duration: const Duration(seconds: 1),
      ),
    );
    _controller.reload();
  }

  // اختيار محرك البحث
  void _showSearchEngineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.cyan),
            SizedBox(width: 8),
            Text('محرك البحث الافتراضي', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _searchEngines.keys.map((engine) {
            final isSelected = engine == _selectedSearchEngine;
            return RadioListTile<String>(
              value: engine,
              groupValue: _selectedSearchEngine,
              activeColor: AppColors.cyan,
              title: Text(engine, style: TextStyle(color: isSelected ? AppColors.cyan : Colors.white)),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _selectedSearchEngine = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('browser_search_engine', val);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // عرض الإشارات المرجعية
  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bookmarks_rounded, color: AppColors.cyan),
                        SizedBox(width: 8),
                        Text('الإشارات المرجعية المحفوظة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Text('${_bookmarks.length}', style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                Expanded(
                  child: _bookmarks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_outline_rounded, color: Colors.white24, size: 48),
                              SizedBox(height: 8),
                              Text('لا توجد إشارات مرجعية محفوظة بعد', style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _bookmarks.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                          itemBuilder: (context, idx) {
                            final b = _bookmarks[idx];
                            return ListTile(
                              leading: const Icon(Icons.bookmark_rounded, color: AppColors.cyan),
                              title: Text(
                                b['title'] ?? b['url'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                b['url'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  _bookmarks.removeAt(idx);
                                  _saveBookmarks();
                                  setSheetState(() {});
                                  setState(() {});
                                },
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _navigateToUrl(b['url'] ?? '');
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // قائمة الإجراءات الكاملة (Page Actions Menu)
  void _showPageActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              _currentTitle.isNotEmpty ? _currentTitle : _currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 15),
            const Divider(color: Colors.white12),
            Wrap(
              runSpacing: 10,
              children: [
                ListTile(
                  leading: Icon(_isCurrentBookmarked ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.cyan),
                  title: Text(_isCurrentBookmarked ? 'إزالة من الإشارات المرجعية' : 'إضافة إلى الإشارات المرجعية ⭐', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleBookmark();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmarks_outlined, color: AppColors.cyan),
                  title: const Text('عرض الإشارات المرجعية 🔖', style: TextStyle(color: Colors.white)),
                  trailing: Text('${_bookmarks.length}', style: const TextStyle(color: AppColors.textMuted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBookmarksSheet();
                  },
                ),
                ListTile(
                  leading: Icon(_adBlockerEnabled ? Icons.shield_rounded : Icons.shield_outlined, color: _adBlockerEnabled ? Colors.greenAccent : Colors.white54),
                  title: Text('مانع الإعلانات 🛡️ (${_adBlockerEnabled ? "مفعل" : "معطل"})', style: const TextStyle(color: Colors.white)),
                  trailing: Text('$_blockedAdsCount محجوب', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleAdBlocker();
                  },
                ),
                ListTile(
                  leading: Icon(_isIncognitoMode ? Icons.visibility_off : Icons.visibility, color: _isIncognitoMode ? const Color(0xFF7986CB) : Colors.white70),
                  title: Text('الوضع الخفي 🕶️ (${_isIncognitoMode ? "نشط" : "معطل"})', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleIncognitoMode();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search_rounded, color: AppColors.cyan),
                  title: const Text('محرك البحث المفضل', style: TextStyle(color: Colors.white)),
                  trailing: Text(_selectedSearchEngine, style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSearchEngineDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: const Text('نسخ رابط الصفحة 📋', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: _currentUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الرابط إلى الحافظة!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.white70),
                  title: const Text('مشاركة الصفحة ↗️', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.share(_currentUrl, subject: _currentTitle);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_browser_rounded, color: AppColors.magenta),
                  title: const Text('فتح في متصفح خارجي 🌐', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.tryParse(_currentUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // عرض الوسائط الملتقطة (Smart Sniffer Sheet)
  void _showSniffedMediaSheet() {
    if (_sniffedMediaUrls.isEmpty && _detectedMediaUrl.isNotEmpty) {
      _sniffedMediaUrls.add(_detectedMediaUrl);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.video_camera_back_rounded, color: AppColors.cyan),
                const SizedBox(width: 8),
                Text('الوسائط الملتقطة (${_sniffedMediaUrls.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.separated(
                itemCount: _sniffedMediaUrls.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, idx) {
                  final mUrl = _sniffedMediaUrls.elementAt(idx);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_circle_outline_rounded, color: AppColors.cyan),
                    ),
                    title: Text(
                      mUrl.split('/').last.split('?').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      mUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _detectedMediaUrl = mUrl;
                        _startDownloadFromBrowser();
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('تحميل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        });

        _showFormatsModal(mediaData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        // إذا كان ملفاً مباشراً وليس يوتيوب، نقوم بتحميله فوراً
        _showDirectDownloadOption(_detectedMediaUrl);
      }
    }
  }

  void _showDirectDownloadOption(String directUrl) {
    final fileName = directUrl.split('/').last.split('?').first;
    final ext = fileName.contains('.') ? fileName.split('.').last : 'mp4';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تحميل وسائط مباشرة', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('تم العثور على ملف وسائط مباشر ($fileName). هل ترغب في بدء التنزيل؟', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              _backend.startDownloadInBackground(
                selectedUrl: directUrl,
                title: fileName,
                ext: ext,
                needsMerge: false,
                highestAudioUrl: '',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.downloading_rounded, color: AppColors.cyan),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بدأ التحميل في الخلفية: $fileName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.surface,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('تحميل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFormatsModal(Map<String, dynamic> mediaData) {
    final title = mediaData['title'] ?? 'فيديو من المتصفح';
    final highestAudioUrl = mediaData['highestAudioUrl'] ?? '';
    final int? highestAudioTag = mediaData['highestAudioTag'];
    final String? videoId = mediaData['id'];
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
                          const Text('🎬 جودات الفيديو (مرتبة مع المميزات):', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...videos.map((v) => _buildFormatTile(v, title, highestAudioUrl, highestAudioTag, videoId, false)),
                        ],
                        const SizedBox(height: 15),
                        if (audios.isNotEmpty) ...[
                          const Text('🎵 مقطع صوتي (مرتب مع المميزات):', style: TextStyle(color: AppColors.magenta, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...audios.map((a) => _buildFormatTile(a, title, highestAudioUrl, highestAudioTag, videoId, true)),
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

  Widget _buildFormatTile(Map<String, dynamic> format, String title, String audioUrl, int? audioTag, String? videoId, bool isAudio) {
    final String? badge = format['quality_badge'];
    final String? desc = format['quality_desc'];

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
                Row(
                  children: [
                    Text(
                      format['quality_name'] ?? (isAudio ? 'MP3 Audio' : 'Video'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isAudio ? AppColors.magenta.withOpacity(0.2) : AppColors.cyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(badge, style: TextStyle(color: isAudio ? AppColors.magenta : AppColors.cyan, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (desc != null)
                  Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text(
                  'MB ${format['size']} • ${format['ext'].toString().toUpperCase()}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAudio ? AppColors.magenta : AppColors.cyan,
              foregroundColor: isAudio ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pop(context);
              try {
                AdService().showInterstitialAd();
              } catch (_) {}

              _backend.startDownloadInBackground(
                selectedUrl: format['url'],
                title: title,
                ext: format['ext'],
                needsMerge: format['needs_merge'] ?? false,
                highestAudioUrl: audioUrl,
                videoId: format['video_id'] ?? videoId,
                videoTag: format['tag'],
                highestAudioTag: audioTag,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.downloading_rounded, color: AppColors.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بدأ التحميل في الخلفية: $title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.surface,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            // شريط العنوان والتحكم المطور والمرتب للمتصفح
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: _isIncognitoMode ? const Color(0xFF16162A) : AppColors.surface,
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: _canGoBack ? Colors.white : Colors.white24),
                        onPressed: _canGoBack ? () => _controller.goBack() : null,
                        tooltip: 'رجوع',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _canGoForward ? Colors.white : Colors.white24),
                        onPressed: _canGoForward ? () => _controller.goForward() : null,
                        tooltip: 'تقدم',
                        visualDensity: VisualDensity.compact,
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
                        tooltip: 'تحديث',
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isIncognitoMode ? const Color(0xFF7986CB) : Colors.white12,
                            ),
                          ),
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textInputAction: TextInputAction.go,
                            onSubmitted: _navigateToUrl,
                            decoration: InputDecoration(
                              hintText: _isIncognitoMode ? '🕶️ بحث خفي أو رابط...' : 'ابحث أو أدخل رابط...',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              prefixIcon: Icon(
                                _isIncognitoMode ? Icons.visibility_off_rounded : Icons.search_rounded,
                                size: 18,
                                color: _isIncognitoMode ? const Color(0xFF7986CB) : AppColors.cyan,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_adBlockerEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 12),
                                          const SizedBox(width: 3),
                                          Text('$_blockedAdsCount', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _isCurrentBookmarked ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 18,
                                      color: _isCurrentBookmarked ? AppColors.cyan : Colors.white54,
                                    ),
                                    onPressed: _toggleBookmark,
                                    tooltip: 'إشارة مرجعية',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (_urlController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                      onPressed: () => _urlController.clear(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                        tooltip: 'قائمة المتصفح',
                        onPressed: _showPageActionsMenu,
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
                          minHeight: 2.5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isIncognitoMode ? const Color(0xFF7986CB) : AppColors.cyan,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // شريط اختصارات المنصات الأنيق والمرتب
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.25),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _quickShortcuts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final s = _quickShortcuts[i];
                  return Center(
                    child: InkWell(
                      onTap: () => _navigateToUrl(s['url']),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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

                  // لافتة التقاط الفيديو التلقائية العائمة مع زر كاشف الوسائط (الميزة 1)
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
                                  AppColors.cyan.withOpacity(0.3),
                                  AppColors.magenta.withOpacity(0.3),
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
                                InkWell(
                                  onTap: _showSniffedMediaSheet,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.cyan,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.download_done_rounded, color: Colors.black, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _showSniffedMediaSheet,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              '🎬 ملتقط الوسائط الذكي',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(color: AppColors.magenta, borderRadius: BorderRadius.circular(8)),
                                              child: Text('${_sniffedMediaUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const Text(
                                          'تم رصد ملفات وسائط جاهزة للتنزيل الفوري',
                                          style: TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
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
