import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:pod_player/pod_player.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import '../services/ad_service.dart';
import 'widgets/download_dialogs.dart';

class WatchVideoScreen extends StatefulWidget {
  final yt.Video video;
  
  const WatchVideoScreen({super.key, required this.video});

  @override
  State<WatchVideoScreen> createState() => _WatchVideoScreenState();
}

class _WatchVideoScreenState extends State<WatchVideoScreen> {
  final BackendService _backend = BackendService();
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  
  late yt.Video _currentVideo;
  late final PodPlayerController _podController;
  final ScrollController _relatedScrollController = ScrollController();

  bool _isLoadingExtraction = false;
  List<yt.Video> _relatedVideos = [];
  yt.VideoSearchList? _relatedSearchPage;
  bool _isLoadingRelated = true;
  bool _isLoadingMoreRelated = false;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    
    // تهيئة مشغل الفيديوهات المتقدم pod_player لدعم يوتيوب فائق السرعة
    _podController = PodPlayerController(
      playVideoFrom: PlayVideoFrom.youtube('https://youtu.be/${widget.video.id.value}'),
      podPlayerConfig: const PodPlayerConfig(
        autoPlay: true,
        isLooping: false,
        videoQualityPriority: [720, 1080, 480, 360],
      ),
    )..initialise();

    _fetchRelatedVideos();

    _relatedScrollController.addListener(() {
      if (_relatedScrollController.position.pixels >= _relatedScrollController.position.maxScrollExtent - 200) {
        _loadMoreRelatedVideos();
      }
    });
  }

  Future<void> _fetchRelatedVideos() async {
    try {
      var results = await _yt.search.search(_currentVideo.author);
      var filteredList = results.whereType<yt.Video>().where((v) => v.id.value != _currentVideo.id.value).toList();
      
      if (filteredList.isEmpty) {
        String shortTitle = _currentVideo.title.split(' ').take(3).join(' ');
        results = await _yt.search.search(shortTitle);
        filteredList = results.whereType<yt.Video>().where((v) => v.id.value != _currentVideo.id.value).toList();
      }

      if (mounted) {
        setState(() {
          _relatedSearchPage = results;
          _relatedVideos = filteredList;
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _loadMoreRelatedVideos() async {
    if (_isLoadingMoreRelated) return;
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
      } catch (e) {
        debugPrint('Error loading more related: $e');
      } finally {
        if (mounted) setState(() => _isLoadingMoreRelated = false);
      }
    }
  }

  void _changeVideo(yt.Video newVideo) {
    if (_currentVideo.id.value == newVideo.id.value) return;
    
    _podController.changeVideo(
      playVideoFrom: PlayVideoFrom.youtube('https://youtu.be/${newVideo.id.value}'),
    );
    setState(() {
      _currentVideo = newVideo;
      _isLoadingRelated = true;
      _relatedVideos.clear();
    });
    _fetchRelatedVideos();
  }

  List<Map<String, dynamic>> _processFormats(List<Map<String, dynamic>> formats) {
    if (formats.isEmpty) return [];
    var uniqueFormats = <String, Map<String, dynamic>>{};
    for (var f in formats) {
      uniqueFormats[f['quality_name']] = f; 
    }
    var sortedList = uniqueFormats.values.toList();
    
    // ترتيب القائمة تصاعدياً من أدنى جودة إلى أعلى جودة بدقة
    sortedList.sort((a, b) {
      int orderA = a['quality_order'] is int 
          ? a['quality_order'] 
          : (int.tryParse(a['quality_order']?.toString() ?? '') ?? 0);
      int orderB = b['quality_order'] is int 
          ? b['quality_order'] 
          : (int.tryParse(b['quality_order']?.toString() ?? '') ?? 0);
      
      if (orderA != 0 && orderB != 0 && orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      double sizeA = double.tryParse(a['size'].toString()) ?? 0.0;
      double sizeB = double.tryParse(b['size'].toString()) ?? 0.0;
      return sizeA.compareTo(sizeB);
    });
    return sortedList;
  }

  Future<void> _handleExtraction() async {
    setState(() => _isLoadingExtraction = true);
    _podController.pause();

    try {
      final result = await _backend.extractMediaLinks(_currentVideo.url);
      
      final String videoTitle = result['title'] as String;
      final String highestAudioUrl = result['highestAudioUrl'] as String;
      final int? highestAudioTag = result['highestAudioTag'] as int?;
      
      final List<Map<String, dynamic>> videoList = _processFormats(List<Map<String, dynamic>>.from(result['video'] ?? []));
      final List<Map<String, dynamic>> audioList = _processFormats(List<Map<String, dynamic>>.from(result['audio'] ?? []));

      if (mounted && (videoList.isNotEmpty || audioList.isNotEmpty)) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return FormatSelectionSheet(
              title: videoTitle,
              highestAudioUrl: highestAudioUrl,
              highestAudioTag: highestAudioTag,
              videoId: _currentVideo.id.value,
              videoFormats: videoList,
              audioFormats: audioList,
            );
          },
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرابط محمي أو لا توجد جودات متاحة.'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الخطأ: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.orange,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingExtraction = false);
    }
  }

  @override
  void dispose() {
    _podController.dispose();
    _relatedScrollController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentVideo.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مشغل الفيديوهات المتقدم pod_player
          PodVideoPlayer(
            controller: _podController,
            videoThumbnail: DecorationImage(
              image: NetworkImage(_currentVideo.thumbnails.highResUrl),
              fit: BoxFit.cover,
            ),
          ),
          
          Expanded(
            child: Container(
              color: AppColors.background,
              child: ListView.builder(
                    controller: _relatedScrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _relatedVideos.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentVideo.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                                  const SizedBox(width: 5),
                                  Text(_currentVideo.author, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 25),
                              
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    )
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  onPressed: _isLoadingExtraction ? null : _handleExtraction,
                                  icon: _isLoadingExtraction
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.download_rounded, color: Colors.white, size: 26),
                                  label: Text(
                                    _isLoadingExtraction ? 'جاري الفحص...' : _backend.t('download_btn'),
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (index == 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.cyan, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _backend.t('related'),
                                style: const TextStyle(color: AppColors.cyan, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }

                      final v = _relatedVideos[index - 2];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              v.thumbnails.lowResUrl,
                              width: 90,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 90, height: 60, color: AppColors.surfaceLight),
                            ),
                          ),
                          title: Text(
                            v.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(v.author, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ),
                          onTap: () => _changeVideo(v),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final String highestAudioUrl;
  final int? highestAudioTag;
  final String? videoId;
  final List<Map<String, dynamic>> videoFormats;
  final List<Map<String, dynamic>> audioFormats;

  const FormatSelectionSheet({
    super.key,
    required this.title,
    required this.highestAudioUrl,
    this.highestAudioTag,
    this.videoId,
    required this.videoFormats,
    required this.audioFormats,
  });

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  Map<String, dynamic>? _selectedFormat;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.9),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 15, bottom: 5),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(
                    'اختر الجودة المطلوبة',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const TabBar(
                  indicatorColor: AppColors.cyan,
                  labelColor: AppColors.cyan,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    Tab(icon: Icon(Icons.video_library), text: 'فيديو'),
                    Tab(icon: Icon(Icons.library_music), text: 'صوت'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(widget.videoFormats),
                      _buildList(widget.audioFormats),
                    ],
                  ),
                ),
                if (_selectedFormat != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                
                                try {
                                  AdService().showInterstitialAd();
                                } catch (_) {}
                                
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => DownloadProgressDialog(
                                    selectedUrl: _selectedFormat!['url'],
                                    title: widget.title,
                                    ext: _selectedFormat!['ext'],
                                    needsMerge: _selectedFormat!['needs_merge'],
                                    highestAudioUrl: widget.highestAudioUrl,
                                    videoId: _selectedFormat!['video_id'] ?? widget.videoId,
                                    videoTag: _selectedFormat!['tag'],
                                    highestAudioTag: widget.highestAudioTag,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'تنزيل فوري',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.cyan,
                              side: const BorderSide(color: AppColors.cyan, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              
                              try {
                                AdService().showInterstitialAd();
                              } catch (_) {}

                              BackendService().startDownloadInBackground(
                                selectedUrl: _selectedFormat!['url'],
                                title: widget.title,
                                ext: _selectedFormat!['ext'],
                                needsMerge: _selectedFormat!['needs_merge'],
                                highestAudioUrl: widget.highestAudioUrl,
                                videoId: _selectedFormat!['video_id'] ?? widget.videoId,
                                videoTag: _selectedFormat!['tag'],
                                highestAudioTag: widget.highestAudioTag,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.downloading_rounded, color: AppColors.cyan),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text('بدأ التنزيل في الخلفية بنجاح 📥! يمكنك متابعة التقدم من الإشعارات أو تبويب التنزيلات.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.surface,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            label: const Text(
                              'في الخلفية 📥',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> formats) {
    if (formats.isEmpty) return const Center(child: Text('غير متوفر', style: TextStyle(color: AppColors.textMuted)));
    
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: formats.length,
      itemBuilder: (context, index) {
        final format = formats[index];
        final isSelected = _selectedFormat == format;
        final String? badge = format['quality_badge'];
        final String? desc = format['quality_desc'];

        return InkWell(
          onTap: () => setState(() => _selectedFormat = format),
          child: Container(
            color: isSelected ? AppColors.cyan.withOpacity(0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.cyan : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            format['quality_name'],
                            style: TextStyle(
                              color: isSelected ? AppColors.cyan : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppColors.cyan.withOpacity(0.2) 
                                    : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppColors.cyan.withOpacity(0.4) 
                                      : Colors.white10,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (desc != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          desc,
                          style: TextStyle(
                            color: isSelected ? AppColors.cyan.withOpacity(0.85) : AppColors.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'الحجم: ${format['size']} MB',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        format['ext'].toString().toUpperCase(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (format['needs_merge'] == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('دقة أصلية', style: TextStyle(color: AppColors.orange, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
