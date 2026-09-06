import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';

import 'services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendService().initBackend();

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
    final backend = BackendService();

    return ValueListenableBuilder<String>(
      valueListenable: backend.langNotifier,
      builder: (context, currentLang, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: backend.themeNotifier,
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

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final BackendService _backend = BackendService();
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
            _buildNavItem(Icons.search, _backend.t('search'), 0, isDark),
            _buildNavItem(Icons.link, _backend.t('link'), 1, isDark),
            _buildNavItem(Icons.play_circle_outline, _backend.t('downloads'), 2, isDark),
            _buildNavItem(Icons.settings_outlined, _backend.t('settings'), 3, isDark),
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

Future<void> handleExtraction(BuildContext context, String url, Function(bool) setLoading) async {
  setLoading(true);
  try {
    final backend = BackendService();
    final result = await backend.extractMediaLinks(url);
    
    final String videoTitle = result['title'] as String;
    final List<Map<String, dynamic>> videoList = List<Map<String, dynamic>>.from(result['video']);

    if (context.mounted && videoList.isNotEmpty) {
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

class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> videoFormats;

  const FormatSelectionSheet({
    super.key,
    required this.title,
    required this.videoFormats,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  Map<String, dynamic>? _selectedFormat;
  final BackendService _backend = BackendService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_forward, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                _backend.t('formats_title'),
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
              children: widget.videoFormats.map((fmt) {
                return _buildFormatRow(fmt, textColor);
              }).toList(),
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
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => DownloadProgressDialog(
                      downloadUrl: _selectedFormat!['url'],
                      audioUrl: _selectedFormat!['audio_url'], // تمرير مسار الصوت إن وُجد
                      title: widget.title,
                      extension: _selectedFormat!['ext'],
                    )
                  );
                },
                child: Text(
                  _backend.t('download_btn'),
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

  Widget _buildFormatRow(Map<String, dynamic> format, Color textColor) {
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
            Icon(format['audio_url'] != null ? Icons.auto_awesome : Icons.play_arrow, color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}

class DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String? audioUrl;
  final String title;
  final String extension;

  const DownloadProgressDialog({
    super.key,
    required this.downloadUrl,
    this.audioUrl,
    required this.title,
    required this.extension,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  final BackendService _backend = BackendService();
  double _progress = 0.0;
  String _downloadedSize = "0.0";
  String _totalSize = "0.0";
  bool _isFinished = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initiateDownload();
  }

  Future<void> _initiateDownload() async {
    await _backend.startDownloadProcess(
      downloadUrl: widget.downloadUrl,
      audioUrl: widget.audioUrl,
      title: widget.title,
      extension: widget.extension,
      onProgress: (progress, downloaded, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _downloadedSize = downloaded;
            _totalSize = total;
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isFinished = true;
          });
        }
      },
      onError: () {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasError) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 15),
            const Text('فشل التنزيل. يرجى التحقق من مساحة التخزين أو الأذونات.', textAlign: TextAlign.center),
            const SizedBox(height: 15),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))
          ] else if (_isFinished) ...[
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
            const SizedBox(height: 15),
            Text(_backend.t('completed'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context), 
              child: const Text('حسناً', style: TextStyle(color: Colors.white))
            )
          ] else ...[
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(_backend.t('downloading'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[300],
              color: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            Text('$_downloadedSize MB / $_totalSize', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]
        ],
      ),
    );
  }
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final BackendService _backend = BackendService();
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
      // صمت
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
        // صمت
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
              _backend.t('discover'),
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
                        hintText: _backend.t('search_hint'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
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
                      children: [
                        const Icon(Icons.search, size: 80, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          _backend.t('start_search'),
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

class WatchVideoScreen extends StatefulWidget { 
  final yt.Video video; 
  const WatchVideoScreen({super.key, required this.video}); 
  @override
  State<WatchVideoScreen> createState() => _WatchVideoScreenState(); 
}

class _WatchVideoScreenState extends State<WatchVideoScreen> {
  final BackendService _backend = BackendService();
  
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  final ScrollController _relatedScrollController = ScrollController();
  
  bool _isLoadingExtraction = false;
  bool _isLoadingVideo = true;
  bool _hasPlayerError = false;
  
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  List<yt.Video> _relatedVideos = [];
  yt.VideoSearchList? _relatedSearchPage;
  bool _isLoadingRelated = true;
  bool _isLoadingMoreRelated = false;
  
  @override
  void initState() { 
    super.initState(); 
    _initializeDirectPlayer();
    _fetchRelatedVideos();

    _relatedScrollController.addListener(() {
      if (_relatedScrollController.position.pixels >= _relatedScrollController.position.maxScrollExtent - 200 && !_isLoadingMoreRelated) {
        _loadMoreRelatedVideos();
      }
    });
  }

  Future<void> _initializeDirectPlayer() async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(widget.video.id);
      var muxedStreams = manifest.muxed.toList();
      
      if (muxedStreams.isNotEmpty) {
        muxedStreams.sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
        var streamUrl = muxedStreams.last.url.toString();

        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
        await _videoPlayerController!.initialize();

        if (mounted) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoPlayerController!,
              autoPlay: true,
              looping: false,
              allowFullScreen: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: Colors.redAccent,
                handleColor: Colors.red,
                backgroundColor: Colors.grey,
                bufferedColor: Colors.white,
              ),
            );
            _isLoadingVideo = false;
          });
        }
      } else {
        if (mounted) setState(() { _hasPlayerError = true; _isLoadingVideo = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _hasPlayerError = true; _isLoadingVideo = false; });
    }
  }

  Future<void> _fetchRelatedVideos() async {
    try {
      var results = await _yt.search.search(widget.video.title);
      var filteredList = results.whereType<yt.Video>().where((v) => v.id.value != widget.video.id.value).toList();
      
      if (filteredList.isEmpty) {
        results = await _yt.search.search(widget.video.author);
        filteredList = results.whereType<yt.Video>().where((v) => v.id.value != widget.video.id.value).toList();
      }

      if (filteredList.isEmpty) {
        results = await _yt.search.search("أحدث الفيديوهات المنوعة");
        filteredList = results.whereType<yt.Video>().toList();
      }

      if (mounted) {
        setState(() {
          _relatedSearchPage = results;
          _relatedVideos = filteredList;
          _isLoadingRelated = false;
        });
      }
    } catch(e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _loadMoreRelatedVideos() async {
    if (_relatedSearchPage?.nextPage != null) {
      setState(() => _isLoadingMoreRelated = true);
      try {
        final next = await _relatedSearchPage!.nextPage();
        if (next != null) {
          setState(() {
            _relatedSearchPage = next;
            _relatedVideos.addAll(next.whereType<yt.Video>());
          });
        }
      } catch (e) {}
      setState(() => _isLoadingMoreRelated = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _relatedScrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            color: Colors.black,
            child: _isLoadingVideo 
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : _hasPlayerError || _chewieController == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'تعذر تشغيل الفيديو مباشرة.\nلكن يمكنك تنزيله من الزر بالأسفل!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                      ),
                    ),
                  )
                : Chewie(controller: _chewieController!),
          ),
              
          Expanded(
            child: ListView.builder(
              controller: _relatedScrollController,
              itemCount: _relatedVideos.length + 2, 
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(widget.video.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), 
                        const SizedBox(height: 10), 
                        Text(widget.video.author, style: const TextStyle(color: Colors.grey, fontSize: 14)), 
                        const SizedBox(height: 25), 
                        SizedBox(
                          width: double.infinity,
                          height: 55, 
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
                            onPressed: _isLoadingExtraction ? null : () => handleExtraction(context, widget.video.url, (val) => setState(() => _isLoadingExtraction = val)), 
                            icon: _isLoadingExtraction ? const SizedBox.shrink() : const Icon(Icons.download, color: Colors.black), 
                            label: _isLoadingExtraction ? const CircularProgressIndicator(color: Colors.black) : Text(_backend.t('download_btn'), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 15),
                        Text(_backend.t('related'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 15),
                        if (_isLoadingRelated)
                          const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                        else if (_relatedVideos.isEmpty)
                          const Text('لا توجد فيديوهات ذات صلة.', style: TextStyle(color: Colors.grey))
                      ]
                    )
                  );
                }
                
                if (index == _relatedVideos.length + 1) {
                  return _isLoadingMoreRelated ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.redAccent))) : const SizedBox.shrink();
                }
                
                final v = _relatedVideos[index - 1];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(v.thumbnails.lowResUrl, width: 80, height: 50, fit: BoxFit.cover)),
                  title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(v.author, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: const Icon(Icons.play_circle_outline, color: Colors.redAccent),
                  onTap: () {
                    _chewieController?.pause();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: v)));
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class LinkTab extends StatefulWidget {
  const LinkTab({super.key});
  @override
  State<LinkTab> createState() => _LinkTabState();
}

class _LinkTabState extends State<LinkTab> {
  final BackendService _backend = BackendService();
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
          Text(_backend.t('have_link'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 10),
          Text(_backend.t('paste_here'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 55,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[300]!)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: const InputDecoration(hintText: 'http://...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20)),
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        if (_urlController.text.isNotEmpty) handleExtraction(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val));
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(5),
                    width: 45, height: 45,
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: _isLoadingExtraction
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : IconButton(icon: const Icon(Icons.download, color: Colors.white, size: 22), onPressed: () {
                            FocusScope.of(context).unfocus();
                            if (_urlController.text.isNotEmpty) handleExtraction(context, _urlController.text, (val) => setState(() => _isLoadingExtraction = val));
                          }),
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

class LocalVideoPlayerScreen extends StatefulWidget {
  final FileSystemEntity file;
  const LocalVideoPlayerScreen({super.key, required this.file});

  @override
  State<LocalVideoPlayerScreen> createState() => _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<LocalVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(File(widget.file.path));
    _videoPlayerController.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.redAccent,
            handleColor: Colors.red,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.file.path.split('/').last, style: const TextStyle(fontSize: 14)),
      ),
      body: Center(
        child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(color: Colors.redAccent),
      ),
    );
  }
}

class DownloadsTab extends StatefulWidget {
  const DownloadsTab({super.key});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
  final BackendService _backend = BackendService();
  List<FileSystemEntity> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await _backend.getDownloadedFiles();
    setState(() {
      _downloadedFiles = files;
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
                Text(_backend.t('downloaded'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: _downloadedFiles.isEmpty 
            ? const Center(child: Text('لا توجد تنزيلات بعد', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
              itemCount: _downloadedFiles.length,
              itemBuilder: (context, index) {
                final file = _downloadedFiles[index];
                final fileName = file.path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                  title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(file: file)));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      await _backend.deleteFile(file.path);
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

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Widget _buildNavSetting(BuildContext context, String title, IconData icon, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 22),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = BackendService();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(backend.t('settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20, left: 20, bottom: 5),
                  child: Text(backend.t('general'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                _buildNavSetting(context, backend.t('dl_settings'), Icons.download_outlined, const DownloadSettingsScreen()),
                _buildNavSetting(context, backend.t('notif'), Icons.notifications_none, const NotificationSettingsScreen()),
                _buildNavSetting(context, backend.t('theme'), Icons.dark_mode_outlined, const ThemeSettingsScreen()),
                _buildNavSetting(context, backend.t('language'), Icons.language, const LanguageSettingsScreen()),
                
                Padding(
                  padding: const EdgeInsets.only(right: 20, left: 20, top: 20, bottom: 5),
                  child: Text(backend.t('more_tools'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                _buildActionSetting(context, backend.t('share_app'), Icons.share_outlined, () {
                  Share.share('قم بتجربة Pro Downloader الأفضل لتحميل المقاطع');
                }),
                _buildActionSetting(context, backend.t('clean_cache'), Icons.cleaning_services_outlined, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنظيف الملفات المؤقتة بنجاح'), backgroundColor: Colors.green));
                }),
                _buildActionSetting(context, backend.t('about'), Icons.info_outline, () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Pro Downloader',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.download, color: Colors.redAccent, size: 40),
                    children: [const Text('تطبيق احترافي لتحميل الفيديوهات.')]
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

class DownloadSettingsScreen extends StatefulWidget {
  const DownloadSettingsScreen({super.key});

  @override
  State<DownloadSettingsScreen> createState() => _DownloadSettingsScreenState();
}

class _DownloadSettingsScreenState extends State<DownloadSettingsScreen> {
  final BackendService _backend = BackendService();
  bool _downloadViaMobile = true;
  String _downloadPath = '/storage/emulated/0/Download';
  int _maxTasks = 4;
  String _speedLimit = 'غير محدود';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _backend.getDownloadSettings();
    setState(() {
      _downloadViaMobile = settings['downloadMobile'];
      _downloadPath = settings['download_path'];
      _maxTasks = settings['max_tasks'];
      _speedLimit = settings['speed_limit'];
    });
  }

  Future<void> _saveMobile(bool val) async {
    await _backend.updateDownloadSetting('downloadMobile', val);
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
          content: TextField(controller: pathController),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                await _backend.updateDownloadSetting('download_path', pathController.text);
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
                  await _backend.updateDownloadSetting('max_tasks', taskNum);
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
                  await _backend.updateDownloadSetting('speed_limit', speed);
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
        title: Text(_backend.t('dl_settings'), style: const TextStyle(fontSize: 16)),
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

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final BackendService _backend = BackendService();
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
    final settings = await _backend.getNotificationSettings();
    setState(() {
      _progressNotif = settings['n_prog']!;
      _completeNotif = settings['n_comp']!;
      _recommendNotif = settings['n_recom']!;
      _toolNotif = settings['n_tool']!;
      _toolbarNotif = settings['n_toolbar']!;
    });
  }

  Future<void> _saveBool(String key, bool val, Function(bool) updateState) async {
    await _backend.updateNotificationSetting(key, val);
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
        title: Text(_backend.t('notif'), style: const TextStyle(fontSize: 16)),
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
            onChanged: (val) => _saveBool('n_prog', val, (v) => _progressNotif = v),
          ),
          SwitchListTile(
            title: const Text('اكتمل التنزيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: const Text('أعلمني عند اكتمال التنزيل', style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: _completeNotif,
            activeColor: Colors.redAccent,
            onChanged: (val) => _saveBool('n_comp', val, (v) => _completeNotif = v),
          ),
        ],
      ),
    );
  }
}

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final BackendService _backend = BackendService();
  String _selectedTheme = 'dark'; 

  @override
  void initState() {
    super.initState();
    _selectedTheme = _backend.themeNotifier.value == ThemeMode.light ? 'light' : 'dark';
  }

  Future<void> _saveTheme(String value) async {
    await _backend.changeTheme(value);
    setState(() {
      _selectedTheme = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(_backend.t('theme'), style: const TextStyle(fontSize: 16)),
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
            onTap: () => _saveTheme('light'),
          ),
          ListTile(
            title: const Text('داكن', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            trailing: _selectedTheme == 'dark' ? const Icon(Icons.check, color: Colors.redAccent) : null,
            onTap: () => _saveTheme('dark'),
          )
        ],
      ),
    );
  }
}

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final BackendService _backend = BackendService();
  String _selectedLang = 'ar';

  @override
  void initState() {
    super.initState();
    _selectedLang = _backend.langNotifier.value;
  }

  Future<void> _saveLang(String val) async {
    await _backend.changeLanguage(val);
    setState(() {
      _selectedLang = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(_backend.t('language'), style: const TextStyle(fontSize: 16)),
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
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: _selectedLang == value ? const Icon(Icons.check, color: Colors.redAccent) : null,
      onTap: () => _saveLang(value),
    );
  }
}
