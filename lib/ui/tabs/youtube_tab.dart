import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../core/app_colors.dart';
import '../watch_video_screen.dart';
import '../../services/backend_service.dart';

enum SearchSortFilter { relevance, uploadDate, viewCount, rating }

class YoutubeTab extends StatefulWidget {
  const YoutubeTab({super.key});

  @override
  State<YoutubeTab> createState() => _YoutubeTabState();
}

class _YoutubeTabState extends State<YoutubeTab> {
  final BackendService _backend = BackendService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  Timer? _debounceTimer;

  static List<yt.Video> _feedMemoryCache = [];
  
  List<yt.Video> _searchResults = [];
  List<String> _searchSuggestions = [];
  List<String> _recentSearches = [];
  yt.VideoSearchList? _currentSearchPage;
  
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasSearchedOnce = false; 
  bool _showSuggestions = false;
  SearchSortFilter _currentFilter = SearchSortFilter.relevance;

  static const String _prefRecentSearchesKey = 'yt_recent_searches_list';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        if (_searchController.text.trim().isEmpty && _recentSearches.isNotEmpty) {
          setState(() => _showSuggestions = true);
        }
      }
    });

    _loadInitialFeed();
  }

  bool _isSafeVideo(yt.Video video) {
    final t = video.title.toLowerCase();
    final d = video.description.toLowerCase();
    final banned = [
      '18+', 'sex', 'sexy', 'hot girl', 'bikini', 'adult', 'nsfw', 'prank',
      'إباحي', 'فضيحة', 'رقص ساخن', 'مثير', 'عري', 'سكس', 'بنات ليل', 'عارية',
      'xxx', 'porn', 'erotic', 'nude', 'strip'
    ];
    for (final word in banned) {
      if (t.contains(word) || d.contains(word)) return false;
    }
    return true;
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefRecentSearchesKey) ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.remove(clean);
      _recentSearches.insert(0, clean);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
      await prefs.setStringList(_prefRecentSearchesKey, _recentSearches);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.remove(query);
      await prefs.setStringList(_prefRecentSearchesKey, _recentSearches);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefRecentSearchesKey);
      if (mounted) {
        setState(() {
          _recentSearches.clear();
          _showSuggestions = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialFeed({String? customQuery}) async {
    final query = customQuery ?? 'relaxing 4k nature landscape science documentary';
    
    // If we have cached items and it is default feed, show them immediately
    if (customQuery == null && _feedMemoryCache.isNotEmpty) {
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
      final list = results.whereType<yt.Video>().where(_isSafeVideo).toList();
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = _applyFilterToList(list);
          _hasSearchedOnce = true;
          _isSearching = false;
          if (customQuery == null) {
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
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
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
            _showSuggestions = _recentSearches.isNotEmpty;
          });
        }
      }
    });
  }

  List<yt.Video> _applyFilterToList(List<yt.Video> list) {
    final copy = List<yt.Video>.from(list);
    switch (_currentFilter) {
      case SearchSortFilter.viewCount:
        copy.sort((a, b) => (b.engagement.viewCount).compareTo(a.engagement.viewCount));
        break;
      case SearchSortFilter.uploadDate:
        copy.sort((a, b) {
          final dateA = a.uploadDate ?? DateTime(2000);
          final dateB = b.uploadDate ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
      case SearchSortFilter.rating:
      case SearchSortFilter.relevance:
      default:
        break;
    }
    return copy;
  }

  Future<void> _performSearch([String? suggestionQuery]) async {
    final query = suggestionQuery ?? _searchController.text.trim();
    if (query.isEmpty) return;

    if (suggestionQuery != null) {
      _searchController.text = suggestionQuery;
    }

    _searchFocusNode.unfocus();
    _saveRecentSearch(query);
    
    setState(() {
      _isSearching = true;
      _hasSearchedOnce = true;
      _showSuggestions = false;
      _searchResults.clear();
      _currentSearchPage = null;
    });

    try {
      final results = await _yt.search.search(query).timeout(const Duration(seconds: 12));
      final list = results.whereType<yt.Video>().where(_isSafeVideo).toList();
      
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = _applyFilterToList(list);
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
        final newVideos = nextPage.whereType<yt.Video>().where(_isSafeVideo).toList();
        if (mounted) {
          setState(() {
            _currentSearchPage = nextPage;
            _searchResults.addAll(_applyFilterToList(newVideos));
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
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GestureDetector(
        onTap: () {
          if (_showSuggestions) {
            _searchFocusNode.unfocus();
            setState(() => _showSuggestions = false);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildQuickControls(),
                Expanded(
                  child: _buildBodyContent(),
                ),
              ],
            ),
            
            // قائمة اقتراحات وسجل البحث المتطورة
            if (_showSuggestions && (_searchSuggestions.isNotEmpty || _recentSearches.isNotEmpty))
              Positioned(
                top: 75,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: _buildSuggestionsOrHistoryList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsOrHistoryList() {
    final isQueryEmpty = _searchController.text.trim().isEmpty;

    if (isQueryEmpty && _recentSearches.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.cyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'سجل عمليات البحث الأخيرة',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _clearAllRecentSearches,
                  child: const Text(
                    'مسح الكل',
                    style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) {
                final item = _recentSearches[index];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.history, color: AppColors.textMuted, size: 18),
                  title: Text(item, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: AppColors.textMuted, size: 16),
                    onPressed: () => _removeRecentSearch(item),
                  ),
                  onTap: () => _performSearch(item),
                );
              },
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _searchSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _searchSuggestions[index];
        return ListTile(
          dense: true,
          leading: Icon(Icons.search_rounded, color: AppColors.cyan, size: 18),
          title: Text(suggestion, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          trailing: Icon(Icons.north_west_rounded, color: AppColors.textMuted, size: 14),
          onTap: () => _performSearch(suggestion),
        );
      },
    );
  }

  Widget _buildQuickControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          // شارة تصفية النتائج
          PopupMenuButton<SearchSortFilter>(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.cyan.withOpacity(0.3))),
            initialValue: _currentFilter,
            onSelected: (filter) {
              setState(() {
                _currentFilter = filter;
                _searchResults = _applyFilterToList(_searchResults);
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SearchSortFilter.relevance,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.cyan, size: 18),
                    SizedBox(width: 8),
                    Text('الأكثر صلة (افتراضي)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SearchSortFilter.uploadDate,
                child: Row(
                  children: [
                    Icon(Icons.new_releases_outlined, color: AppColors.cyan, size: 18),
                    SizedBox(width: 8),
                    Text('الأحدث تاريخاً (Newest)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SearchSortFilter.viewCount,
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: AppColors.cyan, size: 18),
                    SizedBox(width: 8),
                    Text('الأعلى مشاهدة (Most Viewed)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, color: AppColors.cyan, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    _getFilterLabel(),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_drop_down, color: AppColors.textMuted, size: 16),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_searchResults.isNotEmpty)
            Text(
              '${_searchResults.length} فيديو متوفر',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }

  String _getFilterLabel() {
    switch (_currentFilter) {
      case SearchSortFilter.viewCount:
        return 'الأعلى مشاهدة';
      case SearchSortFilter.uploadDate:
        return 'الأحدث رفعاً';
      case SearchSortFilter.rating:
      case SearchSortFilter.relevance:
      default:
        return 'الأكثر صلة';
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search, color: AppColors.cyan, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: _backend.t('search_hint'),
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppColors.textMuted, size: 18),
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
                    margin: const EdgeInsets.all(6),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: _isSearching
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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
            Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 60),
            const SizedBox(height: 15),
            Text(_backend.t('no_results'), style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        await _loadInitialFeed();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 155, top: 10),
        itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            return Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
            );
          }
          final video = _searchResults[index];
          return _buildVideoCard(video);
        },
      ),
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
                        child: Icon(Icons.broken_image, color: AppColors.textMuted),
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
                    if (video.engagement.viewCount > 0)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.black.withOpacity(0.65),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_outlined, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatViewCount(video.engagement.viewCount),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
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
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            video.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('تحميل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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
