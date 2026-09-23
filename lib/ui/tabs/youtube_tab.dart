import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../core/app_colors.dart';
import '../watch_video_screen.dart';
import '../../services/backend_service.dart';

class YoutubeTab extends StatefulWidget {
  const YoutubeTab({super.key});

  @override
  State<YoutubeTab> createState() => _YoutubeTabState();
}

class _YoutubeTabState extends State<YoutubeTab> {
  final BackendService _backend = BackendService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  Timer? _debounceTimer;

  static List<yt.Video> _feedMemoryCache = [];
  
  List<yt.Video> _searchResults = [];
  List<String> _searchSuggestions = [];
  yt.VideoSearchList? _currentSearchPage;
  
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasSearchedOnce = false; 
  bool _showSuggestions = false;
  String _selectedCategory = 'الكل';

  final List<Map<String, String>> _categories = [
    {'name': 'الكل', 'query': 'trending 2025'},
    {'name': 'موسيقى', 'query': 'top music hits'},
    {'name': 'ألعاب', 'query': 'trending gaming'},
    {'name': 'تقنية', 'query': 'technology news reviews'},
    {'name': 'بودكاست', 'query': 'best podcast episodes'},
    {'name': 'كوميديا', 'query': 'comedy skits funny'},
    {'name': 'أخبار', 'query': 'world news live'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });

    _searchController.addListener(_onSearchChanged);
    _loadInitialFeed();
  }

  Future<void> _loadInitialFeed({String? customQuery}) async {
    final query = customQuery ?? (_selectedCategory == 'الكل' ? 'trending' : _categories.firstWhere((c) => c['name'] == _selectedCategory, orElse: () => {'query': 'trending'})['query']!);
    
    // If we have cached items and it's default feed, show them immediately
    if (customQuery == null && _selectedCategory == 'الكل' && _feedMemoryCache.isNotEmpty) {
      setState(() {
        _searchResults = List.from(_feedMemoryCache);
        _hasSearchedOnce = true;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });
    try {
      final results = await _yt.search.search(query).timeout(const Duration(seconds: 12));
      final list = results.whereType<yt.Video>().toList();
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = list;
          _hasSearchedOnce = true;
          _isSearching = false;
          if (customQuery == null && _selectedCategory == 'الكل') {
            _feedMemoryCache = list;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        try {
          final suggestions = await _yt.search.getQuerySuggestions(query);
          if (mounted) {
            setState(() {
              _searchSuggestions = suggestions;
              _showSuggestions = true;
            });
          }
        } catch (_) {}
      } else {
        if (mounted) {
          setState(() {
            _searchSuggestions.clear();
            _showSuggestions = false;
          });
        }
      }
    });
  }

  Future<void> _performSearch([String? suggestionQuery]) async {
    final query = suggestionQuery ?? _searchController.text.trim();
    if (query.isEmpty) return;

    if (suggestionQuery != null) {
      _searchController.text = suggestionQuery;
    }

    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSearching = true;
      _hasSearchedOnce = true;
      _showSuggestions = false;
      _searchResults.clear();
      _currentSearchPage = null;
    });

    try {
      final results = await _yt.search.search(query).timeout(const Duration(seconds: 12));
      final list = results.whereType<yt.Video>().toList();
      
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = list;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_backend.t('search_error')),
            backgroundColor: AppColors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isSearching || _currentSearchPage == null) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final nextPage = await _currentSearchPage!.nextPage().timeout(const Duration(seconds: 10));
      if (nextPage != null) {
        final newVideos = nextPage.whereType<yt.Video>().toList();
        if (mounted) {
          setState(() {
            _currentSearchPage = nextPage;
            _searchResults.addAll(newVideos);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              _buildCategoryBar(),
              Expanded(
                child: _buildBodyContent(),
              ),
            ],
          ),
          
          if (_showSuggestions && _searchSuggestions.isNotEmpty)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.history, color: AppColors.textMuted, size: 20),
                          title: Text(suggestion, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          onTap: () => _performSearch(suggestion),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat['name'] == _selectedCategory;
          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                _selectedCategory = cat['name']!;
                _searchController.clear();
              });
              _loadInitialFeed(customQuery: cat['query']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.cyan : AppColors.surfaceLight.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.cyan : Colors.white.withOpacity(0.08),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat['name']!,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: _backend.t('search_hint'),
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSuggestions = false;
                                  _searchSuggestions.clear();
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isSearching ? null : () => _performSearch(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isSearching && _searchResults.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 155, top: 10),
        itemCount: 4,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      );
    }
    
    if (_hasSearchedOnce && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 60),
            const SizedBox(height: 15),
            Text(_backend.t('no_results'), style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 155, top: 10),
      itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
          );
        }
        final video = _searchResults[index];
        return _buildVideoCard(video);
      },
    );
  }

  Widget _buildVideoCard(yt.Video video) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.cyan.withOpacity(0.2),
          highlightColor: AppColors.cyan.withOpacity(0.1),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: video)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      video.thumbnails.highResUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black.withOpacity(0.7),
                            child: Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            video.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, color: AppColors.cyan, size: 14),
                              SizedBox(width: 4),
                              Text('تحميل', style: TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
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
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: const BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 15, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(5))),
                const SizedBox(height: 10),
                Container(width: 150, height: 15, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
