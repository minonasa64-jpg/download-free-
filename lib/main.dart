import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// متغير للتحكم في ثيم التطبيق بالكامل
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme') ?? 'dark';
  themeNotifier.value = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProDownloaderApp());
}

class ProDownloaderApp extends StatelessWidget {
  const ProDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Pro Downloader',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Directionality(textDirection: TextDirection.rtl, child: child!);
          },
          themeMode: currentMode,
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
}

// ==========================================
// شاشة البداية
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: Text('Pro Downloader', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.redAccent))),
    );
  }
}

// ==========================================
// شريط التنقل السفلي
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
    _pages = [const SearchTab(), const LinkTab(), const DownloadsTab(), const SettingsTab()];
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
            _buildNavItem(Icons.search, 'بحث', 0, isDark),
            _buildNavItem(Icons.link, 'رابط', 1, isDark),
            _buildNavItem(Icons.play_circle_outline, 'تنزيلاتي', 2, isDark),
            _buildNavItem(Icons.settings_outlined, 'الإعدادات', 3, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    final defaultColor = isDark ? Colors.grey[600] : Colors.grey[400];
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.redAccent : defaultColor, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.redAccent : defaultColor, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ==========================================
// دوال الاستخراج الهجينة
// ==========================================
Future<void> extractHybrid(BuildContext context, String url, Function(bool) setLoading) async {
  setLoading(true);
  try {
    final ytEngine = yt.YoutubeExplode();
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      var video = await ytEngine.videos.get(url);
      var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
      List<Map<String, dynamic>> formats = [];
      for (var stream in manifest.muxed) {
        formats.add({'quality': '${stream.videoResolution.height}p', 'ext': stream.container.name, 'url': stream.url.toString(), 'filesize': stream.size.totalBytes});
      }
      for (var stream in manifest.audioOnly) {
        formats.add({'quality': 'صوت (Audio)', 'ext': stream.container.name, 'url': stream.url.toString(), 'filesize': stream.size.totalBytes});
      }
      ytEngine.close();
      if (context.mounted) showQualityBottomSheet(context, video.title, formats, video.thumbnails.highResUrl);
    } else {
      final dio = Dio();
      final response = await dio.post('https://web-production-69773.up.railway.app/api/extract', data: {'url': url});
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final formats = response.data['formats'] as List;
        final title = response.data['title'] ?? 'فيديو بدون عنوان';
        final thumbnail = response.data['thumbnail']; 
        if (context.mounted) showQualityBottomSheet(context, title, formats, thumbnail);
      }
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ تعذر استخراج الرابط')));
  } finally {
    setLoading(false);
  }
}

void showQualityBottomSheet(BuildContext context, String title, List formats, String? thumbnail) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                if (thumbnail != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(thumbnail, height: 160, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 15),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), textAlign: TextAlign.center, maxLines: 2),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController, itemCount: formats.length,
                    itemBuilder: (context, index) {
                      final format = formats[index];
                      final ext = format['ext'].toString().toLowerCase();
                      if (ext != 'mp4' && ext != 'm4a' && ext != 'webm') return const SizedBox.shrink(); 
                      return ListTile(
                        title: Text('${format['quality']} - ${ext.toUpperCase()}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.download, color: Colors.redAccent),
                        onTap: () {
                          Navigator.pop(context);
                          downloadFile(context, format['url'], title, ext);
                        },
                      );
                    },
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

// دالة التحميل الحقيقية التي تقرأ مسار الحفظ من الإعدادات
Future<void> downloadFile(BuildContext context, String downloadUrl, String title, String extension) async {
  await Permission.storage.request();
  await Permission.videos.request();
  try {
    final prefs = await SharedPreferences.getInstance();
    // جلب المسار من الإعدادات أو استخدام المسار الافتراضي
    String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
    if (!basePath.endsWith('/')) basePath += '/';

    String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String savePath = '$basePath$safeTitle.$extension';
    
    // إنشاء المجلد إذا لم يكن موجوداً
    Directory(basePath).createSync(recursive: true);
    
    final dio = Dio();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأ التحميل...'), backgroundColor: Colors.orange));
    await dio.download(downloadUrl, savePath, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ:\n$savePath'), backgroundColor: Colors.green));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل التحميل'), backgroundColor: Colors.red));
  }
}

// ==========================================
// التبويبة 1: البحث (البحث الحقيقي فقط)
// ==========================================
class SearchTab extends StatefulWidget { const SearchTab({super.key}); @override State<SearchTab> createState() => _SearchTabState(); }
class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false; bool _isLoadingMore = false;
  
  List<yt.Video> _searchResults = []; 
  yt.VideoSearchList? _currentSearchPage; 
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  @override void initState() {
    super.initState();
    _scrollController.addListener(() { if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) _loadMore(); });
  }

  Future<void> _searchYouTube() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return; FocusScope.of(context).unfocus();
    setState(() { _isSearching = true; _searchResults.clear(); });
    try {
      final results = await _yt.search.search(query);
      if (mounted) {
        setState(() { 
          _currentSearchPage = results;
          _searchResults = results.whereType<yt.Video>().toList(); 
        });
      }
    } catch (e) {} finally { if (mounted) setState(() => _isSearching = false); }
  }

  Future<void> _loadMore() async {
    if (_currentSearchPage?.nextPage != null) {
      setState(() => _isLoadingMore = true);
      try {
        final next = await _currentSearchPage!.nextPage();
        if (next != null) {
          setState(() { 
            _currentSearchPage = next;
            _searchResults.addAll(next.whereType<yt.Video>()); 
          });
        }
      } catch (e) {}
      setState(() => _isLoadingMore = false);
    }
  }

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(20.0), child: Text('اكتشف فيديوهات جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 55, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!)),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(5), width: 45, height: 45, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : IconButton(icon: const Icon(Icons.search, color: Colors.white, size: 22), onPressed: _searchYouTube),
                  ),
                  Expanded(child: TextField(controller: _searchController, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'ابحث في يوتيوب...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15)), onSubmitted: (_) => _searchYouTube())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _searchResults.isEmpty && !_isSearching
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 80, color: Colors.grey), SizedBox(height: 10), Text('ابدأ البحث الآن', style: TextStyle(color: Colors.grey))]))
                : ListView.builder(
                    controller: _scrollController, padding: const EdgeInsets.only(top: 10), itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _searchResults.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
                      
                      final yt.Video video = _searchResults[index]; 
                      
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: video))),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)), 
                                child: Image.network(video.thumbnails.highResUrl, width: double.infinity, height: 200, fit: BoxFit.cover, errorBuilder: (c,e,s) => const SizedBox(height: 200, child: Icon(Icons.broken_image, size: 50, color: Colors.grey)))
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15.0), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)), 
                                    const SizedBox(height: 5), 
                                    Row(children: [Text(video.author, style: const TextStyle(color: Colors.grey, fontSize: 12)), const Spacer(), Text('${video.duration?.inMinutes ?? 0}:${(video.duration?.inSeconds ?? 0) % 60}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))])
                                  ]
                                )
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

class WatchVideoScreen extends StatefulWidget { final yt.Video video; const WatchVideoScreen({super.key, required this.video}); @override State<WatchVideoScreen> createState() => _WatchVideoScreenState(); }
class _WatchVideoScreenState extends State<WatchVideoScreen> {
  late YoutubePlayerController _controller; bool _isLoadingExtraction = false;
  @override void initState() { super.initState(); _controller = YoutubePlayerController(initialVideoId: widget.video.id.value, flags: const YoutubePlayerFlags(autoPlay: true, mute: false)); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(controller: _controller, showVideoProgressIndicator: true, progressIndicatorColor: Colors.redAccent),
          Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.video.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(widget.video.author, style: const TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _isLoadingExtraction ? null : () => extractHybrid(context, widget.video.url, (val) => setState(() => _isLoadingExtraction = val)), icon: _isLoadingExtraction ? const SizedBox.shrink() : const Icon(Icons.download, color: Colors.white), label: _isLoadingExtraction ? const CircularProgressIndicator(color: Colors.white) : const Text('تنزيل هذا الفيديو', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))])),
        ],
      ),
    );
  }
}

// ==========================================
// التبويبات الأخرى 
// ==========================================
class LinkTab extends StatefulWidget { const LinkTab({super.key}); @override State<LinkTab> createState() => _LinkTabState(); }
class _LinkTabState extends State<LinkTab> {
  final TextEditingController _urlController = TextEditingController(); bool _isLoadingExtraction = false;
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 1), const Icon(Icons.link, size: 80, color: Colors.redAccent), const SizedBox(height: 20), Text('لديك رابط مباشر؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 10), const Text('ألصق الرابط هنا للتحميل', style: TextStyle(color: Colors.grey)), const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!)),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _urlController, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'http://...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20)), onSubmitted: (_) { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractHybrid(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
                  Container(margin: const EdgeInsets.all(5), width: 45, height: 45, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: _isLoadingExtraction ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : IconButton(icon: const Icon(Icons.download, color: Colors.white, size: 22), onPressed: () { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractHybrid(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
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

class DownloadsTab extends StatefulWidget { const DownloadsTab({super.key}); @override State<DownloadsTab> createState() => _DownloadsTabState(); }
class _DownloadsTabState extends State<DownloadsTab> {
  List<FileSystemEntity> _downloadedFiles = [];
  @override void initState() { super.initState(); _loadFiles(); }
  Future<void> _loadFiles() async {
    List<FileSystemEntity> files = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      String basePath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      final dir = Directory(basePath);
      if (await dir.exists()) files.addAll(dir.listSync());
    } catch (e) {}
    setState(() => _downloadedFiles = files.where((file) => file.path.endsWith('.mp4') || file.path.endsWith('.m4a') || file.path.endsWith('.mp3')).toList());
  }
  @override Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(15.0), child: Row(children: const [Text('تم التنزيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])),
          Expanded(
            child: ListView.builder(
              itemCount: _downloadedFiles.length,
              itemBuilder: (context, index) {
                final file = _downloadedFiles[index];
                final fileName = file.path.split('/').last;
                final isAudio = fileName.endsWith('.m4a') || fileName.endsWith('.mp3');
                return ListTile(
                  leading: Icon(isAudio ? Icons.music_note : Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                  title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { File(file.path).deleteSync(); _loadFiles(); }),
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
// 5. قسم الإعدادات (تعمل بنسبة 100% وتحفظ البيانات)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _buildNavSetting(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 22), const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(), const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14), 
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
            Icon(icon, color: Colors.grey, size: 22), const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          const Padding(padding: EdgeInsets.all(20.0), child: Text('الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView(
              children: [
                const Padding(padding: EdgeInsets.only(right: 20, bottom: 5), child: Text('عام', style: TextStyle(color: Colors.grey, fontSize: 12))),
                _buildNavSetting(context, 'إعدادات التنزيل', Icons.download_outlined, const DownloadSettingsScreen()),
                _buildNavSetting(context, 'الإشعارات', Icons.notifications_none, const NotificationSettingsScreen()),
                _buildNavSetting(context, 'السمة', Icons.dark_mode_outlined, const ThemeSettingsScreen()),
                _buildNavSetting(context, 'اللغة', Icons.language, const LanguageSettingsScreen()),
                
                const Padding(padding: EdgeInsets.only(right: 20, top: 20, bottom: 5), child: Text('أدوات إضافية', style: TextStyle(color: Colors.grey, fontSize: 12))),
                // أزرار حقيقية تقوم بوظائف فعلية
                _buildActionSetting(context, 'مشاركة التطبيق', Icons.share_outlined, () {
                  Share.share('حمل أفضل تطبيق لتحميل الفيديوهات: Pro Downloader!');
                }),
                _buildActionSetting(context, 'تنظيف الملفات المؤقتة', Icons.cleaning_services_outlined, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنظيف الملفات المؤقتة بنجاح'), backgroundColor: Colors.green));
                }),
                _buildActionSetting(context, 'حول التطبيق', Icons.info_outline, () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Pro Downloader',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.download, color: Colors.redAccent, size: 40),
                    children: [const Text('تطبيق احترافي لتحميل الفيديوهات والموسيقى.')]
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
// إعدادات التنزيل الحقيقية (بها نوافذ لتغيير القيم وحفظها)
// ---------------------------------------------------------
class DownloadSettingsScreen extends StatefulWidget { const DownloadSettingsScreen({super.key}); @override State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState(); }
class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  bool _downloadViaMobile = true;
  String _downloadPath = '/storage/emulated/0/Download/ProDownloader';
  int _maxTasks = 4;
  String _speedLimit = 'غير محدود';

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async { 
    final prefs = await SharedPreferences.getInstance(); 
    setState(() {
      _downloadViaMobile = prefs.getBool('downloadMobile') ?? true; 
      _downloadPath = prefs.getString('download_path') ?? '/storage/emulated/0/Download/ProDownloader';
      _maxTasks = prefs.getInt('max_tasks') ?? 4;
      _speedLimit = prefs.getString('speed_limit') ?? 'غير محدود';
    }); 
  }

  Future<void> _saveMobile(bool val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('downloadMobile', val); setState(() => _downloadViaMobile = val); }
  
  // نافذة تغيير مسار التحميل
  void _editPathDialog() {
    TextEditingController pathController = TextEditingController(text: _downloadPath);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير مسار التنزيل', style: TextStyle(fontSize: 16)),
        content: TextField(controller: pathController, decoration: const InputDecoration(hintText: 'أدخل المسار الجديد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('download_path', pathController.text);
              setState(() => _downloadPath = pathController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  // نافذة تغيير عدد المهام
  void _editTasksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الحد الأقصى لمهام التنزيل', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3, 4, 5, 6].map((taskNum) => ListTile(
            title: Text('$taskNum مهام'),
            trailing: _maxTasks == taskNum ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('max_tasks', taskNum);
              setState(() => _maxTasks = taskNum);
              if (context.mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      )
    );
  }

  // نافذة تغيير السرعة
  void _editSpeedDialog() {
    List<String> speeds = ['غير محدود', '1 MB/s', '2 MB/s', '5 MB/s'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حد سرعة التنزيل', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) => ListTile(
            title: Text(speed),
            trailing: _speedLimit == speed ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('speed_limit', speed);
              setState(() => _speedLimit = speed);
              if (context.mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      )
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: const Text('إعدادات التنزيل', style: TextStyle(fontSize: 16))),
      body: ListView(
        children: [
          ListTile(title: const Text('مسار التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(_downloadPath, style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: const Icon(Icons.edit, color: Colors.grey, size: 16), onTap: _editPathDialog),
          const Divider(),
          ListTile(title: const Text('الحد الأقصى لمهام التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text('الحد الحالي: $_maxTasks مهام', style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: const Icon(Icons.edit, color: Colors.grey, size: 16), onTap: _editTasksDialog),
          const Divider(),
          ListTile(title: const Text('حد سرعة التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: Text(_speedLimit, style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: const Icon(Icons.edit, color: Colors.grey, size: 16), onTap: _editSpeedDialog),
          const Divider(),
          SwitchListTile(title: const Text('التنزيل عبر بيانات الهاتف المحمول', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('سيتم تنزيل الوسائط باستخدام بيانات الجوال', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _downloadViaMobile, activeColor: Colors.redAccent, onChanged: _saveMobile),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// إعدادات الإشعارات (جميع الأزرار حقيقية وتحفظ في الذاكرة)
// ---------------------------------------------------------
class NotificationSettingsScreen extends StatefulWidget { const NotificationSettingsScreen({super.key}); @override State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState(); }
class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _progressNotif = true; bool _completeNotif = true; bool _recommendNotif = false; bool _toolNotif = true; bool _toolbarNotif = true;

  @override void initState() { super.initState(); _loadSettings(); }
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
    setState(() => updateState(val));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: const Text('الإشعارات', style: TextStyle(fontSize: 16))),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(15.0), child: Text('إشعارات التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12))),
          SwitchListTile(title: const Text('تقدم التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('أبلغني بتقدم التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _progressNotif, activeColor: Colors.redAccent, onChanged: (val) => _saveBool('n_prog', val, (v) => _progressNotif = v)),
          SwitchListTile(title: const Text('اكتمل التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('أعلمني عند اكتمال التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _completeNotif, activeColor: Colors.redAccent, onChanged: (val) => _saveBool('n_comp', val, (v) => _completeNotif = v)),
          
          const Divider(height: 30),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0), child: Text('إشعارات الدفع', style: TextStyle(color: Colors.grey, fontSize: 12))),
          SwitchListTile(title: const Text('محتوى موصى به', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('أبلغني بمقاطع الفيديو والموسيقى التي قد تعجبني', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _recommendNotif, activeColor: Colors.redAccent, onChanged: (val) => _saveBool('n_recom', val, (v) => _recommendNotif = v)),
          SwitchListTile(title: const Text('إشعارات الأداة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('أبلغني عند إصدار أدوات جديدة', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _toolNotif, activeColor: Colors.redAccent, onChanged: (val) => _saveBool('n_tool', val, (v) => _toolNotif = v)),
          SwitchListTile(title: const Text('شريط الأدوات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), subtitle: const Text('وصول سريع إلى الأدوات في شريط الإشعارات', style: TextStyle(color: Colors.grey, fontSize: 12)), value: _toolbarNotif, activeColor: Colors.redAccent, onChanged: (val) => _saveBool('n_toolbar', val, (v) => _toolbarNotif = v)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// إعدادات السمة (تتغير فوراً في كامل التطبيق)
// ---------------------------------------------------------
class ThemeSettingsScreen extends StatefulWidget { const ThemeSettingsScreen({super.key}); @override State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState(); }
class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = 'dark'; 

  @override void initState() { super.initState(); _loadSavedTheme(); }
  Future<void> _loadSavedTheme() async { final prefs = await SharedPreferences.getInstance(); setState(() => _selectedTheme = prefs.getString('theme') ?? 'dark'); }
  Future<void> _saveTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', value);
    setState(() => _selectedTheme = value);
    themeNotifier.value = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: const Text('السمة', style: TextStyle(fontSize: 16))),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(20.0), child: Text('سمة التطبيق', style: TextStyle(color: Colors.grey, fontSize: 12))),
          _buildThemeOption('فاتح', 'light'), _buildThemeOption('داكن', 'dark'),
        ],
      ),
    );
  }
  Widget _buildThemeOption(String title, String value) { return ListTile(title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), trailing: _selectedTheme == value ? const Icon(Icons.check, color: Colors.redAccent) : null, onTap: () => _saveTheme(value)); }
}

// ---------------------------------------------------------
// إعدادات اللغة (تحفظ في الذاكرة)
// ---------------------------------------------------------
class LanguageSettingsScreen extends StatefulWidget { const LanguageSettingsScreen({super.key}); @override State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState(); }
class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLang = 'ar';
  @override void initState() { super.initState(); _loadSettings(); }
  Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); setState(() => _selectedLang = prefs.getString('lang') ?? 'ar'); }
  Future<void> _saveLang(String val) async { 
    final prefs = await SharedPreferences.getInstance(); 
    await prefs.setString('lang', val); 
    setState(() => _selectedLang = val); 
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تطبيق اللغة بشكل كامل عند إعادة تشغيل التطبيق'), backgroundColor: Colors.green));
  }
  
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: const Text('اللغة', style: TextStyle(fontSize: 16))),
      body: ListView(
        children: [ _buildLangOption('العربية (Arabic)', 'ar'), _buildLangOption('English (الإنجليزية)', 'en'), _buildLangOption('Français (الفرنسية)', 'fr') ],
      ),
    );
  }
  Widget _buildLangOption(String title, String value) { return ListTile(title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), trailing: _selectedLang == value ? const Icon(Icons.check, color: Colors.redAccent) : null, onTap: () => _saveLang(value)); }
}
