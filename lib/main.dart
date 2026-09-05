import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
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
    return MaterialApp(
      title: 'Pro Downloader',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      theme: ThemeData(
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
  }
}

// ==========================================
// 1. شاشة البداية
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
    return const Scaffold(
      body: Center(child: Text('Pro Downloader', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.redAccent))),
    );
  }
}

// ==========================================
// 2. شريط التنقل السفلي
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
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 5, bottom: 10),
        color: const Color(0xFF121212),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.search, 'بحث', 0),
            _buildNavItem(Icons.link, 'رابط', 1),
            _buildNavItem(Icons.play_circle_outline, 'تنزيلاتي', 2),
            _buildNavItem(Icons.settings_outlined, 'الإعدادات', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.redAccent : Colors.grey[600], size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.grey[600], fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ==========================================
// 3. دوال الاستخراج الهجينة
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
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                if (thumbnail != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(thumbnail, height: 160, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 15),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 2),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController, itemCount: formats.length,
                    itemBuilder: (context, index) {
                      final format = formats[index];
                      final ext = format['ext'].toString().toLowerCase();
                      if (ext != 'mp4' && ext != 'm4a' && ext != 'webm') return const SizedBox.shrink(); 
                      return ListTile(
                        title: Text('${format['quality']} - ${ext.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

Future<void> downloadFile(BuildContext context, String downloadUrl, String title, String extension) async {
  await Permission.storage.request();
  await Permission.videos.request();
  try {
    String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String savePath = '/storage/emulated/0/Download/ProDownloader/$safeTitle.$extension';
    Directory('/storage/emulated/0/Download/ProDownloader').createSync(recursive: true);
    final dio = Dio();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأ التحميل...'), backgroundColor: Colors.orange));
    await dio.download(downloadUrl, savePath, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ:\n$savePath'), backgroundColor: Colors.green));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل التحميل'), backgroundColor: Colors.red));
  }
}

// ==========================================
// 4. التبويبات (البحث، الروابط، التنزيلات)
// ==========================================
class SearchTab extends StatefulWidget { const SearchTab({super.key}); @override State<SearchTab> createState() => _SearchTabState(); }
class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false; bool _isLoadingMore = false;
  List<yt.Video> _searchResults = []; yt.SearchList? _currentSearchPage;
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
      _currentSearchPage = await _yt.search.search(query);
      if (mounted) setState(() { _searchResults = _currentSearchPage!.toList(); });
    } catch (e) {} finally { if (mounted) setState(() => _isSearching = false); }
  }

  Future<void> _loadMore() async {
    if (_currentSearchPage?.nextPage != null) {
      setState(() => _isLoadingMore = true);
      try {
        _currentSearchPage = await _currentSearchPage!.nextPage();
        if (_currentSearchPage != null) setState(() { _searchResults.addAll(_currentSearchPage!); });
      } catch (e) {}
      setState(() => _isLoadingMore = false);
    }
  }

  @override Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(20.0), child: Text('اكتشف فيديوهات جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 55, decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF333333))),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(5), width: 45, height: 45, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : IconButton(icon: const Icon(Icons.search, color: Colors.black, size: 22), onPressed: _searchYouTube),
                  ),
                  Expanded(child: TextField(controller: _searchController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'ابحث في يوتيوب...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15)), onSubmitted: (_) => _searchYouTube())),
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
                      final video = _searchResults[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: video))),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)), child: Image.network(video.thumbnails.highResUrl, width: double.infinity, height: 200, fit: BoxFit.cover)),
                              Padding(padding: const EdgeInsets.all(15.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 5), Row(children: [Text(video.author, style: const TextStyle(color: Colors.grey, fontSize: 12)), const Spacer(), Text('${video.duration?.inMinutes ?? 0}:${(video.duration?.inSeconds ?? 0) % 60}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))])])),
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
          Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(widget.video.author, style: const TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _isLoadingExtraction ? null : () => extractHybrid(context, widget.video.url, (val) => setState(() => _isLoadingExtraction = val)), icon: _isLoadingExtraction ? const SizedBox.shrink() : const Icon(Icons.download, color: Colors.white), label: _isLoadingExtraction ? const CircularProgressIndicator(color: Colors.white) : const Text('تنزيل هذا الفيديو', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))])),
        ],
      ),
    );
  }
}

class LinkTab extends StatefulWidget { const LinkTab({super.key}); @override State<LinkTab> createState() => _LinkTabState(); }
class _LinkTabState extends State<LinkTab> {
  final TextEditingController _urlController = TextEditingController(); bool _isLoadingExtraction = false;
  @override Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 1), const Icon(Icons.link, size: 80, color: Colors.redAccent), const SizedBox(height: 20), const Text('لديك رابط مباشر؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 10), const Text('ألصق الرابط هنا لتحميله بسرعة', style: TextStyle(color: Colors.grey)), const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55, decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF333333))),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _urlController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'http://...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20)), onSubmitted: (_) { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractHybrid(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
                  Container(margin: const EdgeInsets.all(5), width: 45, height: 45, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: _isLoadingExtraction ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : IconButton(icon: const Icon(Icons.download, color: Colors.black, size: 22), onPressed: () { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractHybrid(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
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
    try { final dir = Directory('/storage/emulated/0/Download/ProDownloader'); if (await dir.exists()) files.addAll(dir.listSync()); } catch (e) {}
    setState(() => _downloadedFiles = files.where((file) => file.path.endsWith('.mp4') || file.path.endsWith('.m4a') || file.path.endsWith('.mp3')).toList());
  }
  @override Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(15.0), child: Row(children: const [Text('تم التنزيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))])),
          Expanded(
            child: ListView.builder(
              itemCount: _downloadedFiles.length,
              itemBuilder: (context, index) {
                final file = _downloadedFiles[index];
                final fileName = file.path.split('/').last;
                final isAudio = fileName.endsWith('.m4a') || fileName.endsWith('.mp3');
                return ListTile(
                  leading: Icon(isAudio ? Icons.music_note : Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                  title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
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
// 5. قسم الإعدادات (نظام كامل متطابق مع الصور)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _buildSettingItem(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[400], size: 22),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14), // السهم معكوس ليتناسب مع RTL
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
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Expanded(
            child: ListView(
              children: [
                const Padding(padding: EdgeInsets.only(right: 20, bottom: 10), child: Text('عام', style: TextStyle(color: Colors.grey, fontSize: 12))),
                _buildSettingItem(context, 'إعدادات التنزيل', Icons.download_outlined, const DownloadSettingsScreen()),
                _buildSettingItem(context, 'الإشعارات', Icons.notifications_none, const NotificationSettingsScreen()),
                _buildSettingItem(context, 'السمة', Icons.dark_mode_outlined, const ThemeSettingsScreen()),
                _buildSettingItem(context, 'اللغة', Icons.language, const LanguageSettingsScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------
// شاشة إعدادات التنزيل
// ------------------------------------------
class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});
  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  bool _downloadViaMobile = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212), elevation: 0,
        title: const Text('إعدادات التنزيل', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('مسار التنزيل', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('/storage/emulated/0/Download/ProDownloader/', style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
            onTap: () {},
          ),
          const Divider(color: Color(0xFF2A2A2A)),
          ListTile(
            title: const Text('الحد الأقصى لمهام التنزيل', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('Wi-Fi: 4 مهام | بيانات الهاتف المحمول: مهمتان', style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
            onTap: () {},
          ),
          const Divider(color: Color(0xFF2A2A2A)),
          ListTile(
            title: const Text('حد سرعة التنزيل', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('غير محدود', style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
            onTap: () {},
          ),
          const Divider(color: Color(0xFF2A2A2A)),
          SwitchListTile(
            title: const Text('التنزيل عبر بيانات الهاتف المحمول', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('سيتم تنزيل الوسائط باستخدام بيانات الجوال', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _downloadViaMobile,
            activeColor: Colors.redAccent,
            onChanged: (val) => setState(() => _downloadViaMobile = val),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------
// شاشة إعدادات الإشعارات
// ------------------------------------------
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212), elevation: 0,
        title: const Text('الإشعارات', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(15.0), child: Text('إشعارات التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12))),
          SwitchListTile(
            title: const Text('تقدم التنزيل', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني بتقدم التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _progressNotif, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _progressNotif = val),
          ),
          SwitchListTile(
            title: const Text('اكتمل التنزيل', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أعلمني عند اكتمال التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _completeNotif, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _completeNotif = val),
          ),
          
          const Divider(color: Color(0xFF2A2A2A), height: 30),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5), child: Text('إشعارات الدفع', style: TextStyle(color: Colors.grey, fontSize: 12))),
          
          SwitchListTile(
            title: const Text('محتوى موصى به', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني بمقاطع الفيديو والموسيقى التي قد تعجبني', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _recommendNotif, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _recommendNotif = val),
          ),
          SwitchListTile(
            title: const Text('إشعارات الأداة', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أبلغني عند إصدار أدوات جديدة', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _toolNotif, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _toolNotif = val),
          ),
          SwitchListTile(
            title: const Text('شريط الأدوات', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('وصول سريع إلى الأدوات في شريط الإشعارات', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _toolbarNotif, activeColor: Colors.redAccent, onChanged: (val) => setState(() => _toolbarNotif = val),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------
// شاشة إعدادات السمة
// ------------------------------------------
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});
  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = 'dark'; // افتراضياً داكن ليتطابق مع صورك

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212), elevation: 0,
        title: const Text('السمة', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(20.0), child: Text('سمة التطبيق', style: TextStyle(color: Colors.grey, fontSize: 12))),
          _buildThemeOption('استخدام إعدادات النظام', 'system'),
          _buildThemeOption('فاتح', 'light'),
          _buildThemeOption('داكن', 'dark'),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: _selectedTheme == value ? const Icon(Icons.check, color: Colors.redAccent) : null,
      onTap: () => setState(() => _selectedTheme = value),
    );
  }
}

// ------------------------------------------
// شاشة إعدادات اللغة
// ------------------------------------------
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});
  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLang = 'ar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212), elevation: 0,
        title: const Text('اللغة', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        children: [
          _buildLangOption('العربية (Arabic)', 'ar'),
          _buildLangOption('English (الإنجليزية)', 'en'),
          _buildLangOption('Français (الفرنسية)', 'fr'),
        ],
      ),
    );
  }

  Widget _buildLangOption(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: _selectedLang == value ? const Icon(Icons.check, color: Colors.redAccent) : null,
      onTap: () => setState(() => _selectedLang = value),
    );
  }
}
