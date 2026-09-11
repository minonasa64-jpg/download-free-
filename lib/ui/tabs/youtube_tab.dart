import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../core/app_colors.dart';
import '../watch_video_screen.dart';

class YoutubeTab extends StatefulWidget {
  const YoutubeTab({super.key});

  @override
  State<YoutubeTab> createState() => _YoutubeTabState();
}

class _YoutubeTabState extends State<YoutubeTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  
  List<yt.Video> _searchResults = [];
  yt.VideoSearchList? _currentSearchPage;
  
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasSearchedOnce = false; 

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus(); 
    
    setState(() {
      _isSearching = true;
      _hasSearchedOnce = true;
      _searchResults.clear();
      _currentSearchPage = null;
    });

    try {
      final results = await _yt.search.search(query);
      if (mounted) {
        setState(() {
          _currentSearchPage = results;
          _searchResults = results.whereType<yt.Video>().toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('حدث خطأ أثناء البحث. تحقق من الاتصال.'),
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return; 
    if (_currentSearchPage?.nextPage != null) {
      setState(() => _isLoadingMore = true);
      try {
        final next = await _currentSearchPage!.nextPage();
        if (next != null) {
          setState(() {
            _currentSearchPage = next;
            _searchResults.addAll(next.whereType<yt.Video>());
          });
        }
      } catch (e) {
        debugPrint('Error loading more: $e');
      } finally {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _performSearch(),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في يوتيوب...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isSearching ? null : _performSearch,
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
    if (_isSearching) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, top: 10), 
        itemCount: 4,
        itemBuilder: (context, index) => _buildSkeletonCard(),
      );
    }
    
    if (!_hasSearchedOnce && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_outline, size: 80, color: AppColors.cyan),
            ),
            const SizedBox(height: 20),
            const Text('اكتشف وحمّل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            const Text('ابحث عن أي فيديو أو مقطع صوتي\nبجودة عالية وبكل سهولة', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      );
    }

    if (_hasSearchedOnce && _searchResults.isEmpty) {
      return const Center(
        child: Text('لم نتمكن من العثور على أي نتائج 😔', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100, top: 10), 
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
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
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black.withOpacity(0.6),
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
