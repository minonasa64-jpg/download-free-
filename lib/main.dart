import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // مكتبة الاتصال بالإنترنت والمحرك

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
// 4. الشاشة الرئيسية (HOME TAB - مع كشف الأخطاء)
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  // دالة الاتصال بالمحرك (API) بعد التعديل لكشف الأخطاء الحقيقية
  Future<void> _extractVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط أولاً!')));
      return;
    }

    setState(() => _isLoading = true);

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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رد غير متوقع من الخادم: ${response.data}')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ الشبكة: ${e.message ?? e.response?.statusCode}'),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ تقني: $e'),
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showQualityBottomSheet(BuildContext context, String title, List formats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
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
                        final ext = format['ext'].toString().toUpperCase();
                        final sizeMb = format['filesize'] != null && format['filesize'] > 0 
                            ? '${(format['filesize'] / (1024 * 1024)).toStringAsFixed(1)} MB' 
                            : 'غير معروف';
                        
                        final icon = ext == 'M4A' || ext == 'MP3' ? Icons.music_note : Icons.video_file;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                            title: Text('$quality - $ext', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الحجم: $sizeMb'),
                            trailing: const Icon(Icons.download_rounded),
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اختيار الجودة: $quality')));
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _urlController.clear(),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton.icon(
                    onPressed: _extractVideo,
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. قسم التنزيلات (DOWNLOADS TAB)
// ==========================================
class DownloadsTab extends StatelessWidget {
  const DownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('إدارة التنزيلات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            const TabBar(
              tabs: [Tab(text: 'جاري التحميل (0)'), Tab(text: 'مكتملة (0)')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.downloading, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('لا توجد تحميلات حالياً', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.video_library, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('لم تقم بتحميل أي فيديو بعد', style: TextStyle(color: Colors.grey)),
                      ],
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
                  subtitle: const Text('الذاكرة الداخلية / التنزيلات'),
                  trailing: const Icon(Icons.edit, size: 20),
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
