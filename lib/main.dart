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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
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
    return const Scaffold(
      body: Center(
        child: Text('Pro Downloader', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.redAccent)),
      ),
    );
  }
}

// ==========================================
// شريط التنقل السفلي المحدث
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
// التبويبة 1: البحث والمشاهدة
// ==========================================
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<yt.Video> _searchResults = [];
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

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
          _searchResults = results.toList();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل البحث، تحقق من اتصالك!')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('اكتشف فيديوهات جديدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(5),
                    width: 45, height: 45,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: _isSearching
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : IconButton(icon: const Icon(Icons.search, color: Colors.black, size: 22), onPressed: _searchYouTube),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'ابحث في يوتيوب...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 15),
                      ),
                      onSubmitted: (_) => _searchYouTube(),
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
                      children: const [
                        Icon(Icons.search, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('ابدأ البحث عن فيديوهاتك المفضلة', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final video = _searchResults[index];
                      return GestureDetector(
                        onTap: () {
                          // فتح شاشة المشاهدة
                          Navigator.push(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: video)));
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                                child: Image.network(video.thumbnails.highResUrl, width: double.infinity, height: 200, fit: BoxFit.cover),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, color: Colors.grey, size: 14),
                                        const SizedBox(width: 5),
                                        Text(video.author, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        const Spacer(),
                                        Text('${video.duration?.inMinutes ?? 0}:${(video.duration?.inSeconds ?? 0) % 60}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
// شاشة مشاهدة الفيديو (تفتح عند اختيار نتيجة بحث)
// ==========================================
class WatchVideoScreen extends StatefulWidget {
  final yt.Video video;
  const WatchVideoScreen({super.key, required this.video});

  @override
  State<WatchVideoScreen> createState() => _WatchVideoScreenState();
}

class _WatchVideoScreenState extends State<WatchVideoScreen> {
  late YoutubePlayerController _controller;
  bool _isLoadingExtraction = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id.value,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _extractAndDownload() async {
    setState(() => _isLoadingExtraction = true);
    try {
      final dio = Dio();
      final response = await dio.post('https://web-production-69773.up.railway.app/api/extract', data: {'url': widget.video.url});

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final formats = response.data['formats'] as List;
        if (mounted) _showQualityBottomSheet(context, widget.video.title, formats);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء استخراج روابط التحميل')));
    } finally {
      if (mounted) setState(() => _isLoadingExtraction = false);
    }
  }

  void _showQualityBottomSheet(BuildContext context, String title, List formats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text('اختر الجودة للتحميل', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: formats.length,
                      itemBuilder: (context, index) {
                        final format = formats[index];
                        final quality = format['quality'];
                        final ext = format['ext'].toString().toLowerCase();
                        // فلترة الخيارات الأساسية فقط (MP4 و MP3)
                        if (ext != 'mp4' && ext != 'm4a') return const SizedBox.shrink();

                        return ListTile(
                          title: Text('$quality - ${ext.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.download, color: Colors.redAccent),
                          onTap: () {
                            Navigator.pop(context);
                            _downloadFile(format['url'], title, ext);
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

  Future<void> _downloadFile(String downloadUrl, String title, String extension) async {
    await Permission.storage.request();
    await Permission.videos.request();
    try {
      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = '/storage/emulated/0/Download/$safeTitle.$extension';
      final dio = Dio();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأ التحميل... يعود بك للخلف'), backgroundColor: Colors.orange));
      Navigator.pop(context); // العودة للصفحة السابقة بعد بدء التحميل
      await dio.download(downloadUrl, savePath, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ:\n$savePath'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل التحميل'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.redAccent,
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(widget.video.author, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    onPressed: _isLoadingExtraction ? null : _extractAndDownload,
                    icon: _isLoadingExtraction ? const SizedBox.shrink() : const Icon(Icons.download, color: Colors.white),
                    label: _isLoadingExtraction 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('تنزيل هذا الفيديو', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// التبويبة 2: الروابط المباشرة
// ==========================================
class LinkTab extends StatefulWidget {
  const LinkTab({super.key});

  @override
  State<LinkTab> createState() => _LinkTabState();
}

class _LinkTabState extends State<LinkTab> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoadingExtraction = false;

  Future<void> _extractVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط صحيح!')));
      return;
    }
    setState(() => _isLoadingExtraction = true);
    FocusScope.of(context).unfocus();
    
    try {
      final dio = Dio();
      final response = await dio.post('https://web-production-69773.up.railway.app/api/extract', data: {'url': url});

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final formats = response.data['formats'] as List;
        final title = response.data['title'] ?? 'فيديو بدون عنوان';
        final thumbnail = response.data['thumbnail']; 
        if (mounted) _showQualityBottomSheet(context, title, formats, thumbnail);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الاستخراج')));
    } finally {
      if (mounted) setState(() => _isLoadingExtraction = false);
    }
  }

  void _showQualityBottomSheet(BuildContext context, String title, List formats, String? thumbnail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
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
                      controller: scrollController,
                      itemCount: formats.length,
                      itemBuilder: (context, index) {
                        final format = formats[index];
                        final quality = format['quality'];
                        final ext = format['ext'].toString().toLowerCase();
                        if (ext != 'mp4' && ext != 'm4a') return const SizedBox.shrink(); // خيارات أساسية فقط
                        
                        return ListTile(
                          title: Text('$quality - ${ext.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.download, color: Colors.redAccent),
                          onTap: () {
                            Navigator.pop(context);
                            _downloadFile(format['url'], title, ext);
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

  Future<void> _downloadFile(String downloadUrl, String title, String extension) async {
    await Permission.storage.request();
    await Permission.videos.request();
    try {
      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = '/storage/emulated/0/Download/$safeTitle.$extension';
      final dio = Dio();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأ التحميل...'), backgroundColor: Colors.orange));
      await dio.download(downloadUrl, savePath, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ:\n$savePath'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل التحميل'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 1),
          const Icon(Icons.link, size: 80, color: Colors.redAccent),
          const SizedBox(height: 20),
          const Text('لديك رابط مباشر؟', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text('ألصق الرابط هنا لتحميله بسرعة', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'http://...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) => _extractVideo(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(5),
                    width: 45, height: 45,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: _isLoadingExtraction
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : IconButton(icon: const Icon(Icons.download, color: Colors.black, size: 22), onPressed: _extractVideo),
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
// التبويبة 3: التنزيلات (نفس الكود السابق)
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
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) files.addAll(dir.listSync());
    } catch (e) {}

    setState(() {
      _downloadedFiles = files.where((file) {
        return file.path.endsWith('.mp4') || file.path.endsWith('.m4a') || file.path.endsWith('.mp3');
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
                const Text('تم التنزيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                const Icon(Icons.delete_outline, color: Colors.white, size: 24),
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
                final sizeMb = (File(file.path).lengthSync() / (1024 * 1024)).toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                        child: Icon(isAudio ? Icons.music_note : Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 5),
                            Text('MB $sizeMb', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        color: const Color(0xFF1E1E1E),
                        onSelected: (val) {
                          if (val == 'share') Share.shareXFiles([XFile(file.path)]);
                          if (val == 'delete') {
                            File(file.path).deleteSync();
                            _loadFiles();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'share', child: Text('مشاركة', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ],
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
// التبويبة 4: الإعدادات (نفس الكود السابق)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text('الإعدادات قريباً...', style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
    );
  }
}
