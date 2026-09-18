import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  late YoutubePlayerController _youtubeController;
  final ScrollController _relatedScrollController = ScrollController();
  
  // مشغل البث المباشر (Direct Stream Player via ExoPlayer)
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoadingDirectPlayer = true;
  String? _directPlayerError;
  bool _useDirectPlayer = true; // الافتراضي هو المشغل المباشر لضمان العمل 100%

  bool _isLoadingExtraction = false;
  List<yt.Video> _relatedVideos = [];
  yt.VideoSearchList? _relatedSearchPage;
  bool _isLoadingRelated = true;
  bool _isLoadingMoreRelated = false;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    
    // 1. تهيئة مشغل البث المباشر فائق السرعة
    _initDirectPlayer();

    // 2. تهيئة مشغل يوتيوب الرسمي كخيار بديل مع إعدادات مستقرة تمنع التجميد
    _youtubeController = YoutubePlayerController(
      initialVideoId: widget.video.id.value,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: false,
        showLiveFullscreenButton: true,
      ),
    )..addListener(_onPlayerStateChange);

    _fetchRelatedVideos();

    _relatedScrollController.addListener(() {
      if (_relatedScrollController.position.pixels >= _relatedScrollController.position.maxScrollExtent - 200) {
        _loadMoreRelatedVideos();
      }
    });
  }

  Future<void> _initDirectPlayer() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDirectPlayer = true;
      _directPlayerError = null;
    });

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(_currentVideo.id.value);
      
      // اختيار أفضل دفق مدمج فيديو وصوت (Muxed)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      yt.MuxedStreamInfo? bestStream;
      if (muxedStreams.isNotEmpty) {
        bestStream = muxedStreams.last;
      }
      bestStream ??= manifest.muxed.withHighestVideoQuality();

      final streamUri = bestStream.url;

      _videoPlayerController?.dispose();
      _chewieController?.dispose();

      final controller = VideoPlayerController.networkUrl(streamUri);
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.cyan,
          handleColor: AppColors.magenta,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
      );

      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _chewieController = chewie;
          _isLoadingDirectPlayer = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading direct player stream: $e');
      if (mounted) {
        setState(() {
          _isLoadingDirectPlayer = false;
          _directPlayerError = 'تعذر تشغيل البث المباشر. اضغط للتبديل لمشغل يوتيوب الرسمي.';
        });
      }
    }
  }

  void _onPlayerStateChange() {
    if (_isPlayerReady && mounted && !_youtubeController.value.isFullScreen) {
      // مزامنة حالة المشغل إذا لزم
    }
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
    
    _youtubeController.load(newVideo.id.value);
    setState(() {
      _currentVideo = newVideo;
      _isLoadingRelated = true;
      _relatedVideos.clear();
    });
    _initDirectPlayer();
    _fetchRelatedVideos();
  }

  List<Map<String, dynamic>> _processFormats(List<Map<String, dynamic>> formats) {
    if (formats.isEmpty) return [];
    var uniqueFormats = <String, Map<String, dynamic>>{};
    for (var f in formats) {
      uniqueFormats[f['quality_name']] = f; 
    }
    var sortedList = uniqueFormats.values.toList();
    
    sortedList.sort((a, b) {
      double sizeA = double.tryParse(a['size'].toString()) ?? 0.0;
      double sizeB = double.tryParse(b['size'].toString()) ?? 0.0;
      return sizeB.compareTo(sizeA);
    });
    return sortedList;
  }

  Future<void> _handleExtraction() async {
    setState(() => _isLoadingExtraction = true);
    
    if (_youtubeController.value.isPlaying) {
      _youtubeController.pause();
    }
    _videoPlayerController?.pause();

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
    _youtubeController.removeListener(_onPlayerStateChange);
    _youtubeController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _relatedScrollController.dispose();
    _yt.close();
    super.dispose();
  }

  Widget _buildDirectPlayerWidget() {
    if (_isLoadingDirectPlayer) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: NetworkImage(_currentVideo.thumbnails.highResUrl),
            fit: BoxFit.cover,
            opacity: 0.35,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 3),
              SizedBox(height: 12),
              Text(
                'جاري تجهيز المشغل المباشر السريع...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (_directPlayerError != null || _chewieController == null) {
      return Container(
        height: 220,
        width: double.infinity,
        color: Colors.black,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.orange, size: 40),
            const SizedBox(height: 10),
            Text(
              _directPlayerError ?? 'تعذر تحميل المشغل المباشر',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() => _useDirectPlayer = false);
              },
              icon: const Icon(Icons.ondemand_video, color: AppColors.cyan, size: 18),
              label: const Text('التبديل إلى مشغل يوتيوب الرسمي', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      height: 220,
      width: double.infinity,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildPlayerSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (!_useDirectPlayer) {
                  _youtubeController.pause();
                  setState(() => _useDirectPlayer = true);
                  if (_videoPlayerController == null) {
                    _initDirectPlayer();
                  }
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _useDirectPlayer ? AppColors.cyan.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _useDirectPlayer ? Border.all(color: AppColors.cyan, width: 1.2) : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: _useDirectPlayer ? AppColors.cyan : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'المشغل المباشر السريع ⚡',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _useDirectPlayer ? AppColors.cyan : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () {
                if (_useDirectPlayer) {
                  _videoPlayerController?.pause();
                  setState(() => _useDirectPlayer = false);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_useDirectPlayer ? AppColors.magenta.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: !_useDirectPlayer ? Border.all(color: AppColors.magenta, width: 1.2) : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 18, color: !_useDirectPlayer ? AppColors.magenta : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'مشغل يوتيوب الرسمي 🎬',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_useDirectPlayer ? AppColors.magenta : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.cyan,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.cyan,
          handleColor: AppColors.magenta,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.black26,
        ),
        topActions: <Widget>[
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _currentVideo.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
        onReady: () {
          if (mounted) {
            setState(() {
              _isPlayerReady = true;
            });
          }
        },
      ),
      builder: (context, youtubePlayerWidget) {
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
              // منطقة المشغل: مشغل البث المباشر أو مشغل يوتيوب
              _useDirectPlayer ? _buildDirectPlayerWidget() : youtubePlayerWidget,
              
              // شريط التبديل بين المشغلين
              _buildPlayerSwitcher(),
              
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
      },
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
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
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
                        child: const Text(
                          'بدء التنزيل',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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

        return InkWell(
          onTap: () => setState(() => _selectedFormat = format),
          child: Container(
            color: isSelected ? AppColors.cyan.withOpacity(0.1) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.cyan : AppColors.textMuted,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format['quality_name'],
                      style: TextStyle(
                        color: isSelected ? AppColors.cyan : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MB ${format['size']}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (format['needs_merge'] == true)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('عالية الجودة', style: TextStyle(color: AppColors.orange, fontSize: 9)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    format['ext'].toString().toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
