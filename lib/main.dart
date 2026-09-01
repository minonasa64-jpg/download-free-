import 'package:flutter/material.dart';

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
  // متغير للتحكم في الوضع الليلي/النهاري
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
      // الثيم النهاري
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      ),
      // الثيم الليلي (الافتراضي)
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
    // إعداد حركة الظهور والتكبير (Fade & Scale)
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack);
    _controller.forward();

    // الانتقال للشاشة الرئيسية بعد 3 ثواني
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
// 4. الشاشة الرئيسية (HOME TAB)
// ==========================================
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  // دالة لإظهار نافذة اختيار الجودة من الأسفل
  void _showQualityBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text('اختر جودة التحميل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildQualityTile(context, 'فيديو عالي الدقة (1080p)', '45.2 MB', Icons.hd),
              _buildQualityTile(context, 'فيديو متوسط الدقة (720p)', '20.1 MB', Icons.sd),
              _buildQualityTile(context, 'صوت فقط (MP3)', '4.5 MB', Icons.music_note),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQualityTile(BuildContext context, String title, String size, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(size),
        trailing: const Icon(Icons.download_rounded),
        onTap: () {
          Navigator.pop(context); // إغلاق النافذة
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدأ التحميل...')));
        },
      ),
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
            
            // شريط المنصات المدعومة
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPlatformIcon(context, 'يوتيوب', Icons.ondemand_video, Colors.red),
                  _buildPlatformIcon(context, 'فيسبوك', Icons.facebook, Colors.blue),
                  _buildPlatformIcon(context, 'إنستغرام', Icons.camera_alt, Colors.purple),
                  _buildPlatformIcon(context, 'تويتر', Icons.alternate_email, Colors.lightBlue),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // حقل إدخال الرابط
            TextField(
              decoration: InputDecoration(
                hintText: 'ألصق رابط الفيديو هنا...',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(icon: const Icon(Icons.content_paste), onPressed: () {}),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
            const SizedBox(height: 25),

            // زر الاستخراج
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => _showQualityBottomSheet(context),
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

  Widget _buildPlatformIcon(BuildContext context, String name, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Column(
        children: [
          CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 30)),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
    // استخدام DefaultTabController لتقسيم الشاشة لتبويبتين
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
              tabs: [Tab(text: 'جاري التحميل (1)'), Tab(text: 'مكتملة (3)')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // تبويبة: جاري التحميل
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مقطع فيديو مضحك.mp4', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(value: 0.65),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [Text('65%'), Text('1.2 MB/s')],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // تبويبة: مكتملة
                  ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: Container(
                            width: 80,
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
                          ),
                          title: Text('فيديو محمل ${index + 1}'),
                          subtitle: const Text('15 MB • MP4'),
                          trailing: IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                        ),
                      );
                    },
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
                  subtitle: const Text('/storage/emulated/0/ProDownloader'),
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
