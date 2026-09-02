import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; 
import 'package:permission_handler/permission_handler.dart'; // مكتبة الصلاحيات

// ==========================================
// 1. نقطة الانطلاق (MAIN & APP)
// ==========================================
void main() {
  runApp(const ProDownloaderApp());
}

class ProDownloaderApp extends StatefulWidget {
  const ProDownloaderApp({super.key});

  @override
  State<ProDownloaderApp> createState() => _ProDownloaderAppState();
}

class _ProDownloaderAppState extends State<ProDownloaderApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Downloader',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent, brightness: Brightness.dark),
      ),
      home: SplashScreen(onThemeChanged: toggleTheme),
    );
  }
}

// ==========================================
// 2. شاشة البداية المتحركة (SPLASH SCREEN)
// ==========================================
class SplashScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const SplashScreen({super.key, required this.onThemeChanged});

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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(onThemeChanged: widget.onThemeChanged)),
      );
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
      backgroundColor: Theme.of(context).colorScheme.background,
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.download_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pro Downloader',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  'حمل أي فيديو بسهولة',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. شريط التنقل السفلي (MAIN NAVIGATION)
// ==========================================
class MainNavigation extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const MainNavigation({super.key, required this.onThemeChanged});

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
      const HomeTab(),
      const DownloadsTab(),
      SettingsTab(onThemeChanged: widget.onThemeChanged),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'تنزيلاتي'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ==========================================
// 4. الشاشة الرئيسية (HOME TAB - مع الحفظ في المعرض)
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoadingExtraction = false;
  bool _isDownloadingFile = false;
  double _downloadProgress = 0.0;

  Future<void> _extractVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط أولاً!')));
      return;
    }

    setState(() => _isLoadingExtraction = true);

    try {
      final dio = Dio();
      final response = await dio.post(
        'https://web-production-69773.up.railway.app/api/extract',
        data: {'url': url},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final formats = response.data['formats'] as List;
        final title = response.data['title'] ?? 'فيديو بدون عنوان';
        
        if (mounted) _showQualityBottomSheet(context, title, formats);
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
    // 1. طلب صلاحية الوصول لذاكرة الهاتف
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب الموافقة على صلاحية التخزين لحفظ الفيديو!')));
      return;
    }

    setState(() {
      _isDownloadingFile = true;
      _downloadProgress = 0.0;
    });

    try {
      // 2. تحديد مجلد التنزيلات العام (Public Downloads)
      Directory dir = Directory('/storage/emulated/0/Download/ProDownloader');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = '${dir.path}/$safeTitle.$extension';

      final dio = Dio();
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم الحفظ في التنزيلات:\n$savePath'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل التحميل: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDownloadingFile = false);
    }
  }

  void _showQualityBottomSheet(BuildContext context, String title, List formats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: formats.length,
                      itemBuilder: (context, index) {
                        final format = formats[index];
                        final quality = format['quality'];
                        final ext = format['ext'].toString().toLowerCase();
                        final sizeMb = format['filesize'] != null && format['filesize'] > 0 
                            ? '${(format['filesize'] / (1024 * 1024)).toStringAsFixed(1)} MB' 
                            : 'غير معروف';
                        final icon = ext == 'm4a' || ext == 'mp3' ? Icons.music_note : Icons.video_file;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                            title: Text('$quality - ${ext.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الحجم: $sizeMb'),
                            trailing: const Icon(Icons.download_rounded),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مرحباً بك 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('من أين تريد التحميل اليوم؟', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 30),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'ألصق رابط الفيديو هنا...',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => _urlController.clear()),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: _isLoadingExtraction 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton.icon(
                    onPressed: _isDownloadingFile ? null : _extractVideo,
                    icon: const Icon(Icons.search),
                    label: const Text('استخراج الروابط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                    ),
                  ),
            ),
            if (_isDownloadingFile) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('جاري تحميل الملف...', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${(_downloadProgress * 100).toStringAsFixed(0)}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(value: _downloadProgress, minHeight: 8, borderRadius: BorderRadius.circular(10)),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. قسم التنزيلات (DOWNLOADS TAB - يعرض الملفات المحملة)
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
    _loadFiles(); // تحميل الملفات عند فتح الشاشة
  }

  // دالة لجلب الملفات من مجلد التطبيق
  Future<void> _loadFiles() async {
    try {
      final dir = Directory('/storage/emulated/0/Download/ProDownloader');
      if (await dir.exists()) {
        setState(() {
          _downloadedFiles = dir.listSync().where((file) {
            return file.path.endsWith('.mp4') || file.path.endsWith('.m4a') || file.path.endsWith('.mp3');
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب الملفات: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('تنزيلاتي المكتملة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles), // زر تحديث القائمة
              ],
            ),
          ),
          Expanded(
            child: _downloadedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.video_library, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('لم تقم بتحميل أي فيديو بعد', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _downloadedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _downloadedFiles[index];
                      final fileName = file.path.split('/').last;
                      final isAudio = fileName.endsWith('.m4a') || fileName.endsWith('.mp3');
                      
                      // حساب حجم الملف
                      final fileSize = File(file.path).lengthSync();
                      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(2);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(isAudio ? Icons.music_note : Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('الحجم: $sizeMb MB'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              // حذف الملف
                              File(file.path).deleteSync();
                              _loadFiles(); // تحديث القائمة
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
                            },
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
// 6. شاشة الإعدادات (SETTINGS TAB)
// ==========================================
class SettingsTab extends StatelessWidget {
  final Function(bool) onThemeChanged;
  const SettingsTab({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الوضع الليلي'),
                  secondary: const Icon(Icons.dark_mode),
                  value: isDark,
                  onChanged: (value) => onThemeChanged(value),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('مسار الحفظ'),
                  subtitle: const Text('الذاكرة الداخلية / Download / ProDownloader'),
                  trailing: const Icon(Icons.check, color: Colors.green),
                  onTap: () {},
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('حول التطبيق'),
                  subtitle: const Text('الإصدار 1.0.0'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
