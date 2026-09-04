import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:dio/dio.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; 

// ==========================================
// 1. نقطة الانطلاق
// ==========================================
void main() {
  // تلوين شريط حالة الهاتف العلوي ليتناسب مع التصميم الأسود
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProDownloaderApp());
}

class ProDownloaderApp extends StatefulWidget {
  const ProDownloaderApp({super.key});

  @override
  State<ProDownloaderApp> createState() => _ProDownloaderAppState();
}

class _ProDownloaderAppState extends State<ProDownloaderApp> {
  // التصميم أصبح أسود وأحمر بشكل افتراضي (Dark Mode)
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Downloader',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // إجبار التطبيق على الوضع الداكن لتطابق الصور
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // أسود داكن جداً
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent, // اللون الأحمر المخصص
          background: Color(0xFF0F0F0F),
          surface: Color(0xFF1E1E1E), // لون البطاقات
        ),
        useMaterial3: true,
        fontFamily: 'Cairo', // يفضل إضافة خط عربي لاحقاً
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 2. شاشة البداية المتحركة
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E), 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(Icons.download_rounded, size: 80, color: Colors.redAccent),
                ),
                const SizedBox(height: 20),
                const Text('Pro Downloader', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. شريط التنقل السفلي (مستوحى من الصور)
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
    _pages = [const HomeTab(), const DownloadsTab(), const SettingsTab()];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF0F0F0F),
          indicatorColor: Colors.transparent, // إخفاء دائرة التحديد لتبدو مثل الصورة
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: _currentIndex == 0 ? Colors.redAccent : Colors.grey), 
              label: 'الرئيسية'
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline, color: _currentIndex == 1 ? Colors.redAccent : Colors.grey), 
              label: 'تنزيلاتي'
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: _currentIndex == 2 ? Colors.redAccent : Colors.grey), 
              label: 'الإعدادات'
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. الشاشة الرئيسية (تطابق تصميم الصور تماماً)
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoadingExtraction = false;
  bool _isDownloadingFile = false;
  double _downloadProgress = 0.0;
  String _lastCheckedLink = ""; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboardForLinks(); 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForLinks();
    }
  }

  Future<void> _checkClipboardForLinks() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      String copiedText = data.text!.trim();
      if (copiedText.startsWith('http') && copiedText != _lastCheckedLink) {
        _lastCheckedLink = copiedText;
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('تم اكتشاف رابط 🔍', style: TextStyle(color: Colors.white)),
              content: Text('هل تريد استخراج الفيديو من الرابط المنسوخ؟\n\n$copiedText', style: const TextStyle(color: Colors.grey), maxLines: 3, overflow: TextOverflow.ellipsis),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _urlController.text = copiedText;
                    _extractVideo();
                  },
                  child: const Text('استخراج'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _extractVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط أولاً!')));
      return;
    }
    setState(() => _isLoadingExtraction = true);
    try {
      final dio = Dio();
      final response = await dio.post('https://web-production-69773.up.railway.app/api/extract', data: {'url': url});

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final formats = response.data['formats'] as List;
        final title = response.data['title'] ?? 'فيديو بدون عنوان';
        final thumbnail = response.data['thumbnail']; 
        if (mounted) _showQualityBottomSheet(context, title, formats, thumbnail);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رد غير متوقع من الخادم.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الاستخراج: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingExtraction = false);
    }
  }

  Future<void> _downloadFile(String downloadUrl, String title, String extension) async {
    await Permission.storage.request();
    await Permission.videos.request();

    setState(() {
      _isDownloadingFile = true;
      _downloadProgress = 0.0;
    });

    try {
      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = '';
      try {
        Directory customDir = Directory('/storage/emulated/0/Download/ProDownloader');
        if (!await customDir.exists()) await customDir.create(recursive: true);
        savePath = '${customDir.path}/$safeTitle.$extension';
      } catch (e) {
        savePath = '/storage/emulated/0/Download/$safeTitle.$extension';
      }

      final dio = Dio();
      await dio.download(
        downloadUrl,
        savePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) setState(() => _downloadProgress = received / total);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ بنجاح!\nالمسار: $savePath'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل التحميل: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDownloadingFile = false);
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
                  if (thumbnail != null && thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(thumbnail, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 15),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: formats.length,
                      itemBuilder: (context, index) {
                        final format = formats[index];
                        final quality = format['quality'];
                        final ext = format['ext'].toString().toLowerCase();
                        final sizeMb = format['filesize'] != null && format['filesize'] > 0 ? '${(format['filesize'] / (1024 * 1024)).toStringAsFixed(1)} MB' : 'غير معروف';
                        final icon = ext == 'm4a' || ext == 'mp3' ? Icons.music_note : Icons.play_circle_fill;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(icon, color: Colors.redAccent),
                            title: Text('$quality - ${ext.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Text('الحجم: $sizeMb', style: const TextStyle(color: Colors.grey)),
                            trailing: const Icon(Icons.download, color: Colors.white70),
                            onTap: () {
                              Navigator.pop(context);
                              _downloadFile(format['url'], title, ext);
                            },
                          ),
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

  // واجهة اختصارات المواقع (التي تظهر في الجزء العلوي)
  Widget _buildSocialIcon(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // الخلفية الداكنة
          Container(color: const Color(0xFF0F0F0F)),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // 1. اختصارات المواقع العلوية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSocialIcon(Icons.play_arrow, Colors.red, 'YouTube'),
                    _buildSocialIcon(Icons.facebook, Colors.blue, 'Facebook'),
                    _buildSocialIcon(Icons.camera_alt, Colors.purpleAccent, 'Instagram'),
                    _buildSocialIcon(Icons.music_note, Colors.white, 'TikTok'),
                  ],
                ),
                
                const SizedBox(height: 70),
                
                // 2. الشعار في المنتصف (أحمر)
                const Text('Pro Downloader', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: -0.5)),
                const SizedBox(height: 30),
                
                // 3. شريط البحث المنحني (Pill shape)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF333333), width: 1),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ابحث للتنزيل أو أدخل الرابط...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _isLoadingExtraction 
                        ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward, color: Colors.redAccent),
                            onPressed: _isDownloadingFile ? null : _extractVideo,
                          ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _extractVideo(),
                  ),
                ),
                
                // 4. شريط تقدم التحميل (يظهر فقط أثناء التحميل)
                if (_isDownloadingFile) ...[
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جاري التنزيل...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('${(_downloadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        LinearProgressIndicator(value: _downloadProgress, minHeight: 6, backgroundColor: Colors.grey[800], color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. قسم التنزيلات (تصميم القائمة الداكنة)
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
      final dir = Directory('/storage/emulated/0/Download/ProDownloader');
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الشريط العلوي للتنزيلات (يحتوي على أيقونات כמו الصورة)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تم التنزيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: () {}),
                  ],
                )
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          
          Expanded(
            child: _downloadedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('لا توجد ملفات حالياً', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _downloadedFiles.length,
                    separatorBuilder: (context, index) => const Divider(color: Color(0xFF2A2A2A), indent: 80),
                    itemBuilder: (context, index) {
                      final file = _downloadedFiles[index];
                      final fileName = file.path.split('/').last;
                      final isAudio = fileName.endsWith('.m4a') || fileName.endsWith('.mp3');
                      final fileSize = File(file.path).lengthSync();
                      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(2);

                      return ListTile(
                        leading: Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF333333)),
                          ),
                          child: Icon(isAudio ? Icons.music_note : Icons.play_arrow, color: Colors.redAccent, size: 30),
                        ),
                        title: Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text('الحجم: $sizeMb MB', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          color: const Color(0xFF1E1E1E),
                          onSelected: (value) {
                            if (value == 'share') {
                              Share.shareXFiles([XFile(file.path)], text: 'شاهد هذا الملف!');
                            } else if (value == 'delete') {
                              File(file.path).deleteSync();
                              _loadFiles(); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, color: Colors.white, size: 20), SizedBox(width: 10), Text('مشاركة', style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('حذف', style: TextStyle(color: Colors.redAccent))])),
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
// 6. شاشة الإعدادات (قائمة داكنة احترافية)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _buildSettingsItem(IconData icon, String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
      onTap: () {},
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
            child: Text('الإعدادات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSettingsItem(Icons.download_rounded, 'إعدادات التنزيل'),
                _buildSettingsItem(Icons.notifications_none, 'إعدادات الإشعارات'),
                _buildSettingsItem(Icons.folder_outlined, 'مسار الحفظ (التنزيلات)'),
                const Divider(color: Color(0xFF2A2A2A), height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text('أدوات إضافية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                _buildSettingsItem(Icons.cleaning_services_outlined, 'تنظيف الملفات المؤقتة'),
                _buildSettingsItem(Icons.share_outlined, 'مشاركة Pro Downloader'),
                _buildSettingsItem(Icons.info_outline, 'حول التطبيق (v1.0.0)'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
