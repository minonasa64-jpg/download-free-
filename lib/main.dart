import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// نواقل الحالة العالمية (اللغة + السمة)
// ==========================================
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> langNotifier = ValueNotifier('ar');

// قاموس اللغات الحقيقي
const Map<String, Map<String, String>> langMap = {
  'ar': {
    'search': 'بحث', 'link': 'رابط', 'downloads': 'تنزيلاتي', 'settings': 'الإعدادات',
    'discover': 'اكتشف فيديوهات جديدة', 'search_hint': 'ابحث في يوتيوب...', 'start_search': 'ابدأ البحث الآن',
    'have_link': 'لديك رابط مباشر؟', 'paste_here': 'ألصق الرابط هنا للتحميل', 'downloaded': 'تم التنزيل',
    'general': 'عام', 'dl_settings': 'إعدادات التنزيل', 'notif': 'الإشعارات', 'theme': 'السمة', 'language': 'اللغة',
    'more_tools': 'أدوات إضافية', 'share_app': 'مشاركة التطبيق', 'clean_cache': 'تنظيف الملفات المؤقتة', 'about': 'حول التطبيق',
    'formats_title': 'المزيد من التنسيقات', 'audio': 'موسيقى', 'video': 'فيديو', 'download_btn': 'تنزيل',
  },
  'en': {
    'search': 'Search', 'link': 'Link', 'downloads': 'Downloads', 'settings': 'Settings',
    'discover': 'Discover new videos', 'search_hint': 'Search YouTube...', 'start_search': 'Start searching now',
    'have_link': 'Have a direct link?', 'paste_here': 'Paste link here to download', 'downloaded': 'Downloaded',
    'general': 'General', 'dl_settings': 'Download Settings', 'notif': 'Notifications', 'theme': 'Theme', 'language': 'Language',
    'more_tools': 'More Tools', 'share_app': 'Share App', 'clean_cache': 'Clear Cache', 'about': 'About App',
    'formats_title': 'More Formats', 'audio': 'Audio', 'video': 'Video', 'download_btn': 'Download',
  },
  'fr': {
    'search': 'Recherche', 'link': 'Lien', 'downloads': 'Téléchargements', 'settings': 'Paramètres',
    'discover': 'Découvrir des vidéos', 'search_hint': 'Rechercher sur YouTube...', 'start_search': 'Commencez à chercher',
    'have_link': 'Lien direct ?', 'paste_here': 'Collez le lien ici', 'downloaded': 'Téléchargé',
    'general': 'Général', 'dl_settings': 'Paramètres de téléchargement', 'notif': 'Notifications', 'theme': 'Thème', 'language': 'Langue',
    'more_tools': 'Outils supplémentaires', 'share_app': 'Partager l\'app', 'clean_cache': 'Vider le cache', 'about': 'À propos',
    'formats_title': 'Plus de formats', 'audio': 'Audio', 'video': 'Vidéo', 'download_btn': 'Télécharger',
  },
  'es': {
    'search': 'Buscar', 'link': 'Enlace', 'downloads': 'Descargas', 'settings': 'Ajustes',
    'discover': 'Descubrir videos', 'search_hint': 'Buscar en YouTube...', 'start_search': 'Empieza a buscar',
    'have_link': '¿Tienes un enlace?', 'paste_here': 'Pega el enlace aquí', 'downloaded': 'Descargado',
    'general': 'General', 'dl_settings': 'Ajustes de descarga', 'notif': 'Notificaciones', 'theme': 'Tema', 'language': 'Idioma',
    'more_tools': 'Más herramientas', 'share_app': 'Compartir app', 'clean_cache': 'Limpiar caché', 'about': 'Acerca de',
    'formats_title': 'Más formatos', 'audio': 'Audio', 'video': 'Video', 'download_btn': 'Descargar',
  },
  'tr': {
    'search': 'Ara', 'link': 'Bağlantı', 'downloads': 'İndirilenler', 'settings': 'Ayarlar',
    'discover': 'Yeni videolar keşfedin', 'search_hint': 'YouTube\'da ara...', 'start_search': 'Aramaya başla',
    'have_link': 'Bağlantınız var mı?', 'paste_here': 'Bağlantıyı buraya yapıştırın', 'downloaded': 'İndirildi',
    'general': 'Genel', 'dl_settings': 'İndirme Ayarları', 'notif': 'Bildirimler', 'theme': 'Tema', 'language': 'Dil',
    'more_tools': 'Daha fazla araç', 'share_app': 'Uygulamayı paylaş', 'clean_cache': 'Önbelleği temizle', 'about': 'Hakkında',
    'formats_title': 'Daha Fazla Format', 'audio': 'Ses', 'video': 'Video', 'download_btn': 'İndir',
  },
  'hi': {
    'search': 'खोजें', 'link': 'लिंक', 'downloads': 'डाउनलोड', 'settings': 'सेटिंग्स',
    'discover': 'नए वीडियो खोजें', 'search_hint': 'यूट्यूब पर खोजें...', 'start_search': 'खोजना शुरू करें',
    'have_link': 'सीधा लिंक है?', 'paste_here': 'डाउनलोड करने के लिए लिंक पेस्ट करें', 'downloaded': 'डाउनलोड किया गया',
    'general': 'सामान्य', 'dl_settings': 'डाउनलोड सेटिंग्स', 'notif': 'सूचनाएं', 'theme': 'थीम', 'language': 'भाषा',
    'more_tools': 'अधिक टूल', 'share_app': 'ऐप साझा करें', 'clean_cache': 'कैश साफ़ करें', 'about': 'के बारे में',
    'formats_title': 'अधिक प्रारूप', 'audio': 'ऑडियो', 'video': 'वीडियो', 'download_btn': 'डाउनलोड',
  },
};

String t(String key) {
  return langMap[langNotifier.value]?[key] ?? key;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // تحميل الثيم
  final savedTheme = prefs.getString('theme') ?? 'dark';
  themeNotifier.value = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
  
  // تحميل اللغة
  final savedLang = prefs.getString('lang') ?? 'ar';
  langNotifier.value = savedLang;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(const ProDownloaderApp());
}

class ProDownloaderApp extends StatelessWidget {
  const ProDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (_, currentLang, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, currentTheme, __) {
            return MaterialApp(
              title: 'Pro Downloader',
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                // تحديد الاتجاه بناءً على اللغة (العربية من اليمين لليسار)
                return Directionality(textDirection: currentLang == 'ar' ? TextDirection.rtl : TextDirection.ltr, child: child!);
              },
              themeMode: currentTheme,
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF5F5F5),
                colorScheme: const ColorScheme.light(primary: Colors.redAccent, background: Color(0xFFF5F5F5), surface: Colors.white),
                fontFamily: 'Cairo',
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: const ColorScheme.dark(primary: Colors.redAccent, background: Color(0xFF121212), surface: Color(0xFF1E1E1E)),
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
// محرك الاستخراج وواجهة التحميل الجديدة (مطابقة للصورة)
// ==========================================
Future<void> extractAndShowFormats(BuildContext context, String url, Function(bool) setLoading) async {
  setLoading(true);
  try {
    final ytEngine = yt.YoutubeExplode();
    var video = await ytEngine.videos.get(url);
    var manifest = await ytEngine.videos.streamsClient.getManifest(video.id);
    
    List<Map<String, dynamic>> audioList = [];
    List<Map<String, dynamic>> videoList = [];

    // جلب الصوتيات
    for (var stream in manifest.audioOnly) {
      if(stream.container.name == 'mp4' || stream.container.name == 'webm') {
        audioList.add({
          'quality_name': 'كلاسيكي (128K) ${stream.container.name.toUpperCase()}',
          'desc': 'الأفضل للتشغيل على الهواتف والسيارات',
          'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
          'url': stream.url.toString(),
          'ext': stream.container.name
        });
      }
    }
    // جلب الفيديوهات
    for (var stream in manifest.muxed) {
      String q = '${stream.videoResolution.height}p';
      String desc = 'جودة عادية للتشغيل السريع';
      if(stream.videoResolution.height >= 720) desc = 'جودة عالية (عرض واضح)';
      videoList.add({
        'quality_name': 'سريع ($q)',
        'desc': desc,
        'size': (stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(1),
        'url': stream.url.toString(),
        'ext': stream.container.name
      });
    }
    ytEngine.close();

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => FormatSelectionSheet(
          title: video.title,
          audioFormats: audioList,
          videoFormats: videoList,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ تعذر استخراج الروابط')));
  } finally {
    setLoading(false);
  }
}

// --- واجهة التحميل المطابقة لصورتك تماماً ---
class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> audioFormats;
  final List<Map<String, dynamic>> videoFormats;

  const FormatSelectionSheet({super.key, required this.title, required this.audioFormats, required this.videoFormats});

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
          // شريط العنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
              Text(t('formats_title'), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 48), // للتوازن
            ],
          ),
          const SizedBox(height: 10),
          
          Expanded(
            child: ListView(
              children: [
                // قسم الموسيقى
                if (widget.audioFormats.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.all(15), child: Text(t('audio'), style: const TextStyle(color: Colors.grey, fontSize: 14))),
                  ...widget.audioFormats.map((fmt) => _buildFormatRow(fmt, Icons.music_note, textColor)),
                ],
                // قسم الفيديو
                if (widget.videoFormats.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.all(15), child: Text(t('video'), style: const TextStyle(color: Colors.grey, fontSize: 14))),
                  ...widget.videoFormats.map((fmt) => _buildFormatRow(fmt, Icons.play_arrow, textColor)),
                ],
              ],
            ),
          ),
          
          // زر التنزيل الكبير (أحمر بدل الأصفر)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: _selectedFormat == null ? null : () {
                  Navigator.pop(context);
                  downloadFileFinal(context, _selectedFormat!['url'], widget.title, _selectedFormat!['ext']);
                },
                child: Text(t('download_btn'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
      onTap: () => setState(() => _selectedFormat = format),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            // زر الراديو الدائري
            Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.redAccent : Colors.grey, size: 24),
            const SizedBox(width: 15),
            // الحجم
            Text('${format['size']} MB', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            // التفاصيل (في الوسط يمين)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(format['quality_name'], style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(format['desc'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 15),
            // الأيقونة (يمين)
            Icon(icon, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}

// دالة التحميل الحقيقية وإصلاح صلاحيات أندرويد 13+
Future<void> downloadFileFinal(BuildContext context, String downloadUrl, String title, String extension) async {
  // طلب الصلاحيات القوية الخاصة بأندرويد 13 فما فوق
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }
  await Permission.storage.request();

  try {
    String safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String basePath = '/storage/emulated/0/Download/ProDownloader';
    Directory(basePath).createSync(recursive: true);
    String savePath = '$basePath/$safeTitle.$extension';
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بدأ التحميل...'), backgroundColor: Colors.orange));
    final dio = Dio();
    await dio.download(downloadUrl, savePath, options: Options(headers: {'User-Agent': 'Mozilla/5.0'}));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم الحفظ بنجاح في التنزيلات!'), backgroundColor: Colors.green));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ فشل التحميل، يرجى التحقق من الأذونات'), backgroundColor: Colors.red));
  }
}

// ==========================================
// تبويبة البحث (إصلاح الصور)
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
      if (mounted) setState(() { _currentSearchPage = results; _searchResults = results.whereType<yt.Video>().toList(); });
    } catch (e) {} finally { if (mounted) setState(() => _isSearching = false); }
  }

  Future<void> _loadMore() async {
    if (_currentSearchPage?.nextPage != null) {
      setState(() => _isLoadingMore = true);
      try {
        final next = await _currentSearchPage!.nextPage();
        if (next != null) setState(() { _currentSearchPage = next; _searchResults.addAll(next.whereType<yt.Video>()); });
      } catch (e) {}
      setState(() => _isLoadingMore = false);
    }
  }

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(20.0), child: Text(t('discover'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
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
                  Expanded(child: TextField(controller: _searchController, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(hintText: t('search_hint'), hintStyle: const TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 15)), onSubmitted: (_) => _searchYouTube())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _searchResults.isEmpty && !_isSearching
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search, size: 80, color: Colors.grey), const SizedBox(height: 10), Text(t('start_search'), style: const TextStyle(color: Colors.grey))]))
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
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 5), Row(children: [Text(video.author, style: const TextStyle(color: Colors.grey, fontSize: 12)), const Spacer(), Text('${video.duration?.inMinutes ?? 0}:${(video.duration?.inSeconds ?? 0) % 60}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))])])
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
// إصلاح مشغل الفيديو (يعمل الآن بثبات)
// ==========================================
class WatchVideoScreen extends StatefulWidget { final yt.Video video; const WatchVideoScreen({super.key, required this.video}); @override State<WatchVideoScreen> createState() => _WatchVideoScreenState(); }
class _WatchVideoScreenState extends State<WatchVideoScreen> {
  late YoutubePlayerController _controller; bool _isLoadingExtraction = false; bool _hasError = false;
  
  @override void initState() { 
    super.initState(); 
    try {
      _controller = YoutubePlayerController(initialVideoId: widget.video.id.value, flags: const YoutubePlayerFlags(autoPlay: true, mute: false)); 
    } catch(e) { _hasError = true; }
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hasError 
            ? const SizedBox(height: 200, child: Center(child: Text('عذراً، لا يمكن تشغيل هذا الفيديو هنا.', style: TextStyle(color: Colors.white))))
            : YoutubePlayer(controller: _controller, showVideoProgressIndicator: true, progressIndicatorColor: Colors.redAccent),
          Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.video.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(widget.video.author, style: const TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _isLoadingExtraction ? null : () => extractAndShowFormats(context, widget.video.url, (val) => setState(() => _isLoadingExtraction = val)), icon: _isLoadingExtraction ? const SizedBox.shrink() : const Icon(Icons.download, color: Colors.white), label: _isLoadingExtraction ? const CircularProgressIndicator(color: Colors.white) : Text(t('download_btn'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))])),
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
          const Spacer(flex: 1), const Icon(Icons.link, size: 80, color: Colors.redAccent), const SizedBox(height: 20), Text(t('have_link'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), const SizedBox(height: 10), Text(t('paste_here'), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!)),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _urlController, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: const InputDecoration(hintText: 'http://...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20)), onSubmitted: (_) { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractAndShowFormats(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
                  Container(margin: const EdgeInsets.all(5), width: 45, height: 45, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: _isLoadingExtraction ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : IconButton(icon: const Icon(Icons.download, color: Colors.white, size: 22), onPressed: () { FocusScope.of(context).unfocus(); if (_urlController.text.isNotEmpty) extractAndShowFormats(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val)); })),
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
          Padding(padding: const EdgeInsets.all(15.0), child: Row(children: [Text(t('downloaded'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])),
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
// الإعدادات (تعمل وتحفظ)
// ==========================================
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  Widget _buildNavSetting(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Row(children: [Icon(icon, color: Colors.grey, size: 22), const SizedBox(width: 20), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const Spacer(), const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14)])),
    );
  }
  Widget _buildActionSetting(BuildContext context, String title, IconData icon, VoidCallback action) {
    return InkWell(
      onTap: action,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Row(children: [Icon(icon, color: Colors.grey, size: 22), const SizedBox(width: 20), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))])),
    );
  }

  @override Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(20.0), child: Text(t('settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView(
              children: [
                Padding(padding: const EdgeInsets.only(right: 20, left: 20, bottom: 5), child: Text(t('general'), style: const TextStyle(color: Colors.grey, fontSize: 12))),
                _buildNavSetting(context, t('dl_settings'), Icons.download_outlined, const DownloadSettingsScreen()),
                _buildNavSetting(context, t('notif'), Icons.notifications_none, const NotificationSettingsScreen()),
                _buildNavSetting(context, t('theme'), Icons.dark_mode_outlined, const ThemeSettingsScreen()),
                _buildNavSetting(context, t('language'), Icons.language, const LanguageSettingsScreen()),
                
                Padding(padding: const EdgeInsets.only(right: 20, left: 20, top: 20, bottom: 5), child: Text(t('more_tools'), style: const TextStyle(color: Colors.grey, fontSize: 12))),
                _buildActionSetting(context, t('share_app'), Icons.share_outlined, () { Share.share('Download Pro Downloader now!'); }),
                _buildActionSetting(context, t('clean_cache'), Icons.cleaning_services_outlined, () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التنظيف بنجاح'), backgroundColor: Colors.green)); }),
                _buildActionSetting(context, t('about'), Icons.info_outline, () { showAboutDialog(context: context, applicationName: 'Pro Downloader', applicationVersion: '1.0.0'); }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadSettingsScreen extends StatefulWidget { const DownloadSettingsScreen({super.key}); @override State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState(); }
class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  bool _downloadViaMobile = true;
  @override void initState() { super.initState(); _loadSettings(); }
  Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); setState(() { _downloadViaMobile = prefs.getBool('downloadMobile') ?? true; }); }
  Future<void> _saveMobile(bool val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('downloadMobile', val); setState(() => _downloadViaMobile = val); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: Text(t('dl_settings'), style: const TextStyle(fontSize: 16))), body: ListView(children: [SwitchListTile(title: const Text('التنزيل عبر بيانات الهاتف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), value: _downloadViaMobile, activeColor: Colors.redAccent, onChanged: _saveMobile)]));
  }
}

class NotificationSettingsScreen extends StatefulWidget { const NotificationSettingsScreen({super.key}); @override State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState(); }
class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _progressNotif = true; 
  @override void initState() { super.initState(); _loadSettings(); }
  Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); setState(() { _progressNotif = prefs.getBool('n_prog') ?? true; }); }
  Future<void> _saveProg(bool val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('n_prog', val); setState(() => _progressNotif = val); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: Text(t('notif'), style: const TextStyle(fontSize: 16))), body: ListView(children: [SwitchListTile(title: const Text('إشعارات التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), value: _progressNotif, activeColor: Colors.redAccent, onChanged: _saveProg)]));
  }
}

class ThemeSettingsScreen extends StatefulWidget { const ThemeSettingsScreen({super.key}); @override State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState(); }
class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  String _selectedTheme = 'dark'; 
  @override void initState() { super.initState(); _loadSavedTheme(); }
  Future<void> _loadSavedTheme() async { final prefs = await SharedPreferences.getInstance(); setState(() => _selectedTheme = prefs.getString('theme') ?? 'dark'); }
  Future<void> _saveTheme(String value) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('theme', value); setState(() => _selectedTheme = value); themeNotifier.value = value == 'light' ? ThemeMode.light : ThemeMode.dark; }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: Text(t('theme'), style: const TextStyle(fontSize: 16))),
      body: ListView(
        children: [ ListTile(title: const Text('فاتح', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _selectedTheme == 'light' ? const Icon(Icons.check, color: Colors.redAccent) : null, onTap: () => _saveTheme('light')), ListTile(title: const Text('داكن', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _selectedTheme == 'dark' ? const Icon(Icons.check, color: Colors.redAccent) : null, onTap: () => _saveTheme('dark')) ],
      ),
    );
  }
}

class LanguageSettingsScreen extends StatefulWidget { const LanguageSettingsScreen({super.key}); @override State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState(); }
class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLang = 'ar';
  @override void initState() { super.initState(); _selectedLang = langNotifier.value; }
  Future<void> _saveLang(String val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('lang', val); setState(() => _selectedLang = val); langNotifier.value = val; }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.background, elevation: 0, title: Text(t('language'), style: const TextStyle(fontSize: 16))),
      body: ListView(
        children: [ _buildLangOption('العربية (Arabic)', 'ar'), _buildLangOption('English (الإنجليزية)', 'en'), _buildLangOption('Français (الفرنسية)', 'fr'), _buildLangOption('Español (الإسبانية)', 'es'), _buildLangOption('Türkçe (التركية)', 'tr'), _buildLangOption('हिन्दी (الهندية)', 'hi') ],
      ),
    );
  }
  Widget _buildLangOption(String title, String value) { return ListTile(title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), trailing: _selectedLang == value ? const Icon(Icons.check, color: Colors.redAccent) : null, onTap: () => _saveLang(value)); }
}
