import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. المتغيرات العالمية ونظام اللغات
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> langNotifier = ValueNotifier('ar');

const Map<String, Map<String, String>> langMap = {
  'ar': {
    'search': 'بحث',
    'link': 'رابط',
    'downloads': 'تنزيلاتي',
    'settings': 'الإعدادات',
    'discover': 'اكتشف فيديوهات جديدة',
    'search_hint': 'ابحث في يوتيوب...',
    'start_search': 'ابدأ البحث الآن',
    'have_link': 'لديك رابط مباشر؟',
    'paste_here': 'ألصق الرابط هنا للتحميل',
    'downloaded': 'تم التنزيل',
    'general': 'عام',
    'dl_settings': 'إعدادات التنزيل',
    'notif': 'الإشعارات',
    'theme': 'السمة',
    'language': 'اللغة',
    'more_tools': 'أدوات إضافية',
    'share_app': 'مشاركة التطبيق',
    'clean_cache': 'تنظيف الملفات المؤقتة',
    'about': 'حول التطبيق',
    'formats_title': 'المزيد من التنسيقات',
    'audio': 'موسيقى',
    'video': 'فيديو',
    'download_btn': 'تنزيل',
    'related': 'فيديوهات ذات صلة',
  },
  'en': {
    'search': 'Search',
    'link': 'Link',
    'downloads': 'Downloads',
    'settings': 'Settings',
    'discover': 'Discover new videos',
    'search_hint': 'Search YouTube...',
    'start_search': 'Start searching now',
    'have_link': 'Have a direct link?',
    'paste_here': 'Paste link here to download',
    'downloaded': 'Downloaded',
    'general': 'General',
    'dl_settings': 'Download Settings',
    'notif': 'Notifications',
    'theme': 'Theme',
    'language': 'Language',
    'more_tools': 'More Tools',
    'share_app': 'Share App',
    'clean_cache': 'Clear Cache',
    'about': 'About App',
    'formats_title': 'More Formats',
    'audio': 'Audio',
    'video': 'Video',
    'download_btn': 'Download',
    'related': 'Related Videos',
  },
};

String t(String key) {
  return langMap[langNotifier.value]?[key] ?? langMap['ar']![key] ?? key;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  final savedTheme = prefs.getString('theme') ?? 'dark';
  if (savedTheme == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else {
    themeNotifier.value = ThemeMode.dark;
  }
  
  final savedLang = prefs.getString('lang') ?? 'ar';
  langNotifier.value = savedLang;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProDownloaderApp());
}

// ==========================================
// 2. الجذر الأساسي للتطبيق
// ==========================================
class ProDownloaderApp extends StatelessWidget {
  const ProDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, currentLang, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentTheme, child) {
            return MaterialApp(
              title: 'Pro Downloader',
              debugShowCheckedModeBanner: false,
              builder: (context, childWidget) {
                return Directionality(
                  textDirection: currentLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: childWidget!,
                );
              },
              themeMode: currentTheme,
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                colorScheme: const ColorScheme.light(
                  primary: Colors.redAccent,
                  background: Color(0xFFF5F5F5),
                  surface: Colors.white,
                ),
                fontFamily: 'Cairo',
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: const ColorScheme.dark(
                  primary: Colors.redAccent,
                  background: Color(0xFF121212),
                  surface: Color(0xFF1E1E1E),
                ),
                fontFamily: 'Cairo',
              ),
              home: const SplashScreen(),
            );
          },
        );
      }
    );
  }
}

// ==========================================
// 3. شاشة البداية (Splash)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const MainNavigation())
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(
        child: Text(
          'Pro Downloader',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. شريط التنقل السفلي
// ==========================================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const SearchTab(),
      const LinkTab(),
      const DownloadsTab(),
      const SettingsTab()
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 5, bottom: 10),
        color: isDark ? const Color(0xFF121212) : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.search, t('search'), 0, isDark),
            _buildNavItem(Icons.link, t('link'), 1, isDark),
            _buildNavItem(Icons.play_circle_outline, t('downloads'), 2, isDark),
            _buildNavItem(Icons.settings_outlined, t('settings'), 3, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    final defaultColor = isDark ? Colors.grey[600] : Colors.grey[400];
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.redAccent : defaultColor,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.redAccent : defaultColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. محرك الاستخراج ونافذة الجودات (مفصل)
// ==========================================
Future<void> extractHybridFast(BuildContext context, String url, Function(bool) setLoading) async {
  setLoading(true);
  try {
    List<Map<String, dynamic>> audioList = [];
    List<Map<String, dynamic>> videoList = [];
    String videoTitle = 'فيديو بدون عنوان';
    String? thumb;

    // الاعتماد الكلي على الهاتف للاستخراج المباشر والسريع
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final ytEngine = yt.YoutubeExplode();
      var video = await ytEngine.videos.get(url);
      videoTitle = video.title;
      thumb = video.thumbnails.highResUrl;
      var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
      
      // 1. استخراج جودات الفيديو (يحتوي على فيديو وصوت معاً - Muxed)
      for (var stream in manifest.muxed) {
        String quality = '${stream.videoResolution.height}p';
        String desc = 'جودة عادية للتشغيل السريع';
        if (stream.videoResolution.height >= 720) {
          desc = 'عرض واضح وتشغيل سريع';
        }
        
        videoList.add({
          'quality_name': 'سريع ($quality)',
          'desc': desc,
          'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
          'url': stream.url.toString(),
          'ext': stream.container.name, // عادة mp4
        });
      }

      // 2. استخراج جودات الصوت فقط (Audio Only)
      for (var stream in manifest.audioOnly) {
        if (stream.container.name == 'mp4' || stream.container.name == 'm4a') {
          audioList.add({
            'quality_name': 'سريع (128K) M4A',
            'desc': 'الأفضل للتشغيل على الهاتف',
            'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
            'url': stream.url.toString(),
            'ext': 'm4a',
          });
        }
      }
      ytEngine.close();
    } else {
      // الروابط الأخرى (فيسبوك، تيك توك، الخ) يتم معالجتها هنا
      final dio = Dio();
      final response = await dio.post(
        'https://web-production-69773.up.railway.app/api/extract',
        data: {'url': url}
      );
      
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        videoTitle = response.data['title'] ?? 'فيديو بدون عنوان';
        thumb = response.data['thumbnail'];
        final formats = response.data['formats'] as List;
        
        for (var f in formats) {
          String ext = f['ext'].toString().toLowerCase();
          String quality = f['quality'].toString();
          String size = 'غير محدد';
          if (f['filesize'] != null) {
            size = (f['filesize'] / (1024 * 1024)).toStringAsFixed(1);
          }
          
          if (ext == 'm4a' || ext == 'mp3') {
            audioList.add({
              'quality_name': 'صوت ($quality)',
              'desc': 'جودة صوت نقية',
              'size': size,
              'url': f['url'],
              'ext': ext
            });
          } else if (ext == 'mp4' || ext == 'webm') {
            videoList.add({
              'quality_name': 'فيديو ($quality)',
              'desc': 'جودة فيديو متوافقة',
              'size': size,
              'url': f['url'],
              'ext': ext
            });
          }
        }
      }
    }

    if (context.mounted && (audioList.isNotEmpty || videoList.isNotEmpty)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        builder: (context) {
          return FormatSelectionSheet(
            title: videoTitle,
            audioFormats: audioList,
            videoFormats: videoList,
          );
        },
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ تعذر استخراج الجودات، الرابط قد يكون محمياً'))
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ حدث خطأ في الاتصال أثناء الاستخراج'))
      );
    }
  } finally {
    setLoading(false);
  }
}

// ------------------------------------------
// واجهة الجودات المطابقة للصورة
// ------------------------------------------
class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> audioFormats;
  final List<Map<String, dynamic>> videoFormats;

  const FormatSelectionSheet({
    super.key,
    required this.title,
    required this.audioFormats,
    required this.videoFormats,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  Map<String, dynamic>? _selectedFormat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_forward, color: textColor),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Text(
                t('formats_title'),
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 48), 
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                if (widget.audioFormats.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15, bottom: 5),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        t('audio'),
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                  ...widget.audioFormats.map((fmt) {
                    return _buildFormatRow(fmt, Icons.music_note, textColor);
                  }),
                ],
                const SizedBox(height: 20),
                if (widget.videoFormats.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 15, right: 15, bottom: 5),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        t('video'),
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                  ...widget.videoFormats.map((fmt) {
                    return _buildFormatRow(fmt, Icons.play_arrow, textColor);
                  }),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: _selectedFormat == null ? null : () {
                  Navigator.pop(context);
                  downloadFileFinal(
                    context,
                    _selectedFormat!['url'],
                    widget.title,
                    _selectedFormat!['ext'],
                  );
                },
                child: Text(
                  t('download_btn'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFormatRow(Map<String, dynamic> format, IconData icon, Color textColor) {
    bool isSelected = _selectedFormat == format;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFFD600) : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 15),
            Text(
              'MB ${format['size']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  format['quality_name'],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  format['desc'],
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Icon(icon, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------
// دالة التحميل النهائية والمستقرة
// ------------------------------------------
Future<void> downloadFileFinal(BuildContext context, String downloadUrl, String title, String extension) async {
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }
  await Permission.storage.request();

  try {
    final prefs = await SharedPreferences.getInstance();
    String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
    if (!basePath.endsWith('/')) {
      basePath += '/';
    }
    Directory(basePath).createSync(recursive: true);

    String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String savePath = '$basePath$safeTitle.$extension';
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بدأ التنزيل... يمكنك التحقق من مجلد التنزيلات'),
        backgroundColor: Colors.orange,
      )
    );
    
    final dio = Dio();
    await dio.download(
      downloadUrl,
      savePath,
      options: Options(
        headers: {'User-Agent': 'Mozilla/5.0'}
      )
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ اكتمل التحميل:\n$savePath'),
          backgroundColor: Colors.green,
        )
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل التنزيل، تحقق من اتصالك ومساحة التخزين'),
          backgroundColor: Colors.red,
        )
      );
    }
  }
}

// ==========================================
// 6. تبويبة البحث 
// ==========================================
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;
  bool _isLoadingMore = false;
  
  List<yt.Video> _searchResults = []; 
  yt.VideoSearchList? _currentSearchPage; 
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
        _loadMore();
      }
    });
  }

  Future<void> _searchYouTube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });
    
    try {
      final results = await _yt.search.search(query);
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = results.whereType<yt.Video>().toList();
        });
      }
    } catch (e) {
      // معالجة الخطأ بصمت
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_currentSearchPage?.nextPage != null) {
      setState(() {
        _isLoadingMore = true;
      });
      try {
        final next = await _currentSearchPage!.nextPage();
        if (next != null) {
          setState(() {
            _currentSearchPage = next;
            _searchResults.addAll(next.whereType<yt.Video>());
          });
        }
      } catch (e) {
        // معالجة الخطأ
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              t('discover'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(5),
                    width: 45,
                    height: 45,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search, color: Colors.white, size: 22),
                            onPressed: _searchYouTube,
                          ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: t('search_hint'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                      onSubmitted: (_) {
                        _searchYouTube();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _searchResults.isEmpty && !_isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, size: 80, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          t('start_search'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _searchResults.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.redAccent),
                          ),
                        );
                      }
                      
                      final yt.Video video = _searchResults[index]; 
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WatchVideoScreen(video: video)
                            )
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ), 
                                child: Image.network(
                                  video.thumbnails.highResUrl,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15.0), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ), 
                                    const SizedBox(height: 5), 
                                    Row(
                                      children: [
                                        Text(
                                          video.author,
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${video.duration?.inMinutes ?? 0}:${(video.duration?.inSeconds ?? 0) % 60}',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. شاشة المشاهدة والفيديوهات ذات الصلة (بدون اختصار)
// ==========================================
class WatchVideoScreen extends StatefulWidget { 
  final yt.Video video; 
  
  const WatchVideoScreen({
    super.key,
    required this.video,
  }); 
  
  @override
  State<WatchVideoScreen> createState() => _WatchVideoScreenState(); 
}

class _WatchVideoScreenState extends State<WatchVideoScreen> {
  late YoutubePlayerController _controller; 
  bool _isLoadingExtraction = false;
  
  // متغيرات الفيديوهات ذات الصلة
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  List<yt.Video> _relatedVideos = [];
  bool _isLoadingRelated = true;
  
  @override
  void initState() { 
    super.initState(); 
    // تهيئة مشغل iframe الجديد
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id.value,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        mute: false,
      ),
    );
    
    // جلب الفيديوهات المرتبطة
    _fetchRelatedVideos();
  }

  Future<void> _fetchRelatedVideos() async {
    try {
      final results = await _yt.search.search(widget.video.title);
      if (mounted) {
        setState(() {
          // جلب 10 فيديوهات مشابهة بعد تخطي النتيجة الأولى
          _relatedVideos = results.whereType<yt.Video>().skip(1).take(10).toList();
          _isLoadingRelated = false;
        });
      }
    } catch(e) {
      if (mounted) {
        setState(() {
          _isLoadingRelated = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(
            controller: _controller,
            aspectRatio: 16 / 9,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(
                      widget.video.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ), 
                    const SizedBox(height: 10), 
                    Text(
                      widget.video.author,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ), 
                    const SizedBox(height: 25), 
                    
                    // زر التحميل الرئيسي
                    SizedBox(
                      width: double.infinity,
                      height: 55, 
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ), 
                        onPressed: _isLoadingExtraction ? null : () {
                          extractHybridFast(
                            context,
                            widget.video.url,
                            (val) {
                              setState(() {
                                _isLoadingExtraction = val;
                              });
                            },
                          );
                        }, 
                        icon: _isLoadingExtraction
                            ? const SizedBox.shrink()
                            : const Icon(Icons.download, color: Colors.black), 
                        label: _isLoadingExtraction
                            ? const CircularProgressIndicator(color: Colors.black)
                            : Text(
                                t('download_btn'),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 15),
                    
                    // قسم الفيديوهات ذات الصلة
                    Text(
                      t('related'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    if (_isLoadingRelated)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.redAccent),
                      )
                    else if (_relatedVideos.isEmpty)
                      const Text(
                        'لا توجد فيديوهات ذات صلة.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _relatedVideos.length,
                        itemBuilder: (context, index) {
                          final v = _relatedVideos[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                v.thumbnails.lowResUrl,
                                width: 80,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              v.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              v.author,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onTap: () {
                              _controller.close();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WatchVideoScreen(video: v),
                                ),
                              );
                            },
                          );
                        },
                      )
                  ]
                )
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 8. تبويبة الروابط 
// ==========================================
class LinkTab extends StatefulWidget {
  const LinkTab({super.key});

  @override
  State<LinkTab> createState() => _LinkTabState();
}

class _LinkTabState extends State<LinkTab> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoadingExtraction = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 1),
          const Icon(Icons.link, size: 80, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text(
            t('have_link'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('paste_here'),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: const InputDecoration(
                        hintText: 'http://...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        if (_urlController.text.isNotEmpty) {
                          extractHybridFast(
                            context,
                            _urlController.text,
                            (val) {
                              setState(() {
                                _isLoadingExtraction = val;
                              });
                            },
                          );
                        }
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(5),
                    width: 45,
                    height: 45,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoadingExtraction
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download, color: Colors.white, size: 22),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              if (_urlController.text.isNotEmpty) {
                                extractHybridFast(
                                  context,
                                  _urlController.text,
                                  (val) {
                                    setState(() {
                                      _isLoadingExtraction = val;
                                    });
                                  },
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ==========================================
// 9. تبويبة التنزيلات
// ==========================================
class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
  List<FileSystemEntity> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    List<FileSystemEntity> files = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      final dir = Directory(basePath);
      if (await dir.exists()) {
        files.addAll(dir.listSync());
      }
    } catch (e) {
      // تجاهل الخطأ في حال عدم وجود المجلد
    }
    setState(() {
      _downloadedFiles = files.where((file) {
        return file.path.endsWith('.mp4') || file.path.endsWith('.m4a') || file.path.endsWith('.webm') || file.path.endsWith('.mp3');
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Text(
                  t('downloaded'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _downloadedFiles.length,
              itemBuilder: (context, index) {
                final file = _downloadedFiles[index];
                final fileName = file.path.split('/').last;
                final isAudio = fileName.endsWith('.m4a') || fileName.endsWith('.mp3');
                return ListTile(
                  leading: Icon(
                    isAudio ? Icons.music_note : Icons.play_circle_fill,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                  title: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      File(file.path).deleteSync();
                      _loadFiles();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 10. قسم الإعدادات (كامل ومفصل)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _buildNavSetting(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 22),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14), 
          ],
        ),
      ),
    );
  }

  Widget _buildActionSetting(BuildContext context, String title, IconData icon, VoidCallback action) {
    return InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 22),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              t('settings'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20, left: 20, bottom: 5),
                  child: Text(
                    t('general'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                _buildNavSetting(context, t('dl_settings'), Icons.download_outlined, const DownloadSettingsScreen()),
                _buildNavSetting(context, t('notif'), Icons.notifications_none, const NotificationSettingsScreen()),
                _buildNavSetting(context, t('theme'), Icons.dark_mode_outlined, const ThemeSettingsScreen()),
                _buildNavSetting(context, t('language'), Icons.language, const LanguageSettingsScreen()),
                
                Padding(
                  padding: const EdgeInsets.only(right: 20, left: 20, top: 20, bottom: 5),
                  child: Text(
                    t('more_tools'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                _buildActionSetting(context, t('share_app'), Icons.share_outlined, () {
                  Share.share('قم بتجربة Pro Downloader الأفضل لتحميل المقاطع');
                }),
                _buildActionSetting(context, t('clean_cache'), Icons.cleaning_services_outlined, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تنظيف الملفات المؤقتة بنجاح'),
                      backgroundColor: Colors.green,
                    )
                  );
                }),
                _buildActionSetting(context, t('about'), Icons.info_outline, () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Pro Downloader',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.download, color: Colors.redAccent, size: 40),
                    children: [
                      const Text('تطبيق احترافي لتحميل الفيديوهات والموسيقى.')
                    ]
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// إعدادات التنزيل
// ---------------------------------------------------------
class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  bool _downloadViaMobile = true;
  String _downloadPath = '/storage/emulated/0/Download/ProDownloader';
  int _maxTasks = 4;
  String _speedLimit = 'غير محدود';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadViaMobile = prefs.getBool('downloadMobile') ?? true;
      _downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      _maxTasks = prefs.getInt('max_tasks') ?? 4;
      _speedLimit = prefs.getString('speed_limit') ?? 'غير محدود';
    });
  }

  Future<void> _saveMobile(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('downloadMobile', val);
    setState(() {
      _downloadViaMobile = val;
    });
  }
  
  void _editPathDialog() {
    TextEditingController pathController = TextEditingController(text: _downloadPath);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تغيير مسار التنزيل', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: pathController,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('download_path', pathController.text);
                setState(() {
                  _downloadPath = pathController.text;
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            )
          ]
        );
      }
    );
  }

  void _editTasksDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('الحد الأقصى لمهام التنزيل', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [1, 2, 3, 4, 5, 6].map((taskNum) {
              return ListTile(
                title: Text('$taskNum مهام'),
                trailing: _maxTasks == taskNum ? const Icon(Icons.check, color: Colors.redAccent) : null,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('max_tasks', taskNum);
                  setState(() {
                    _maxTasks = taskNum;
                  });
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }).toList(),
          )
        );
      }
    );
  }

  void _editSpeedDialog() {
    List<String> speeds = ['غير محدود', '1 MB/s', '2 MB/s', '5 MB/s'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حد سرعة التنزيل', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds.map((speed) {
              return ListTile(
                title: Text(speed),
                trailing: _speedLimit == speed ? const Icon(Icons.check, color: Colors.redAccent) : null,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('speed_limit', speed);
                  setState(() {
                    _speedLimit = speed;
                  });
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }).toList(),
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(t('dl_settings'), style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('مسار التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(_downloadPath, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.edit, color: Colors.grey, size: 16),
            onTap: _editPathDialog,
          ),
          const Divider(),
          ListTile(
            title: const Text('الحد الأقصى لمهام التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('الحد الحالي: $_maxTasks مهام', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.edit, color: Colors.grey, size: 16),
            onTap: _editTasksDialog,
          ),
          const Divider(),
          ListTile(
            title: const Text('حد سرعة التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(_speedLimit, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.edit, color: Colors.grey, size: 16),
            onTap: _editSpeedDialog,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('التنزيل عبر بيانات الهاتف المحمول', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('سيتم تنزيل الوسائط باستخدام بيانات الجوال', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _downloadViaMobile,
            activeColor: Colors.redAccent,
            onChanged: _saveMobile,
          )
        ],
      )
    );
  }
}

// ---------------------------------------------------------
// إعدادات الإشعارات
// ---------------------------------------------------------
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _progressNotif = true;
  bool _completeNotif = true;
  bool _recommendNotif = false;
  bool _toolNotif = true;
  bool _toolbarNotif = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _progressNotif = prefs.getBool('n_prog') ?? true;
      _completeNotif = prefs.getBool('n_comp') ?? true;
      _recommendNotif = prefs.getBool('n_recom') ?? false;
      _toolNotif = prefs.getBool('n_tool') ?? true;
      _toolbarNotif = prefs.getBool('n_toolbar') ?? true;
    });
  }

  Future<void> _saveBool(String key, bool val, Function(bool) updateState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() {
      updateState(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(t('notif'), style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text('إشعارات التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          SwitchListTile(
            title: const Text('تقدم التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني بتقدم التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _progressNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              _saveBool('n_prog', val, (v) => _progressNotif = v);
            }
          ),
          SwitchListTile(
            title: const Text('اكتمل التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أعلمني عند اكتمال التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _completeNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              _saveBool('n_comp', val, (v) => _completeNotif = v);
            }
          ),
          const Divider(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.0),
            child: Text('إشعارات الدفع', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          SwitchListTile(
            title: const Text('محتوى موصى به', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني بمقاطع الفيديو والموسيقى التي قد تعجبني', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _recommendNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              _saveBool('n_recom', val, (v) => _recommendNotif = v);
            }
          ),
          SwitchListTile(
            title: const Text('إشعارات الأداة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني عند إصدار أدوات جديدة', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _toolNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              _saveBool('n_tool', val, (v) => _toolNotif = v);
            }
          ),
          SwitchListTile(
            title: const Text('شريط الأدوات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('وصول سريع إلى الأدوات في شريط الإشعارات', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _toolbarNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              _saveBool('n_toolbar', val, (v) => _toolbarNotif = v);
            }
          )
        ],
      )
    );
  }
}

// ---------------------------------------------------------
// إعدادات السمة 
// ---------------------------------------------------------
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = 'dark'; 

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('theme') ?? 'dark';
    });
  }

  Future<void> _saveTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value);
    setState(() {
      _selectedTheme = value;
    });
    if (value == 'light') {
      themeNotifier.value = ThemeMode.light;
    } else {
      themeNotifier.value = ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(t('theme'), style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('سمة التطبيق', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ListTile(
            title: const Text('فاتح', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            trailing: _selectedTheme == 'light' ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              _saveTheme('light');
            }
          ),
          ListTile(
            title: const Text('داكن', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            trailing: _selectedTheme == 'dark' ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () {
              _saveTheme('dark');
            }
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// إعدادات اللغة 
// ---------------------------------------------------------
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLang = 'ar';

  @override
  void initState() {
    super.initState();
    _selectedLang = langNotifier.value;
  }

  Future<void> _saveLang(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', val);
    setState(() {
      _selectedLang = val;
    });
    langNotifier.value = val;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(t('language'), style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          _buildLangOption('العربية (Arabic)', 'ar'),
          _buildLangOption('English (الإنجليزية)', 'en'),
          _buildLangOption('Français (الفرنسية)', 'fr')
        ],
      ),
    );
  }

  Widget _buildLangOption(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: _selectedLang == value ? const Icon(Icons.check, color: Colors.redAccent) : null,
      onTap: () {
        _saveLang(value);
      }
    );
  }
}
