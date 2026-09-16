import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
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
  
  VideoPlayerController? _videoPlayerController;
  VideoPlayerController? _audioPlayerController;
  ChewieController? _chewieController;
  
  final ScrollController _relatedScrollController = ScrollController();
  
  bool _isLoadingExtraction = false;
  bool _isLoadingVideo = true;
  bool _hasPlayerError = false;
  bool _isMutedPreview = false;
  
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
      if (_relatedScrollController.position.pixels >= _relatedScrollController.position.maxScrollExtent - 200) {
        _loadMoreRelatedVideos();
      }
    });
  }

  Future<void> _initializeDirectPlayer() async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(widget.video.id);
      var muxedStreams = manifest.muxed.toList();
      
      String? videoUrl;
      String? audioUrl;
      
      if (muxedStreams.isNotEmpty) {
        muxedStreams.sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
        videoUrl = muxedStreams.last.url.toString();
        _isMutedPreview = false;
      } else {
        var videoOnlyStreams = manifest.videoOnly.toList();
        var audioOnlyStreams = manifest.audioOnly;
        
        if (videoOnlyStreams.isNotEmpty && audioOnlyStreams.isNotEmpty) {
          videoOnlyStreams.sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
          videoUrl = videoOnlyStreams.last.url.toString();
          audioUrl = audioOnlyStreams.withHighestBitrate().url.toString();
          _isMutedPreview = false;
        } else if (videoOnlyStreams.isNotEmpty) {
          videoOnlyStreams.sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
          videoUrl = videoOnlyStreams.last.url.toString();
          _isMutedPreview = true;
        }
      }

      // إضافة هوية المتصفح (User-Agent) لتخطي حظر يوتيوب للمشغلات الخارجية
      const headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };

      if (videoUrl != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl), httpHeaders: headers);
        
        if (audioUrl != null) {
          _audioPlayerController = VideoPlayerController.networkUrl(Uri.parse(audioUrl), httpHeaders: headers);
          
          await Future.wait([
            _videoPlayerController!.initialize(),
            _audioPlayerController!.initialize(),
          ]);
          
          await _videoPlayerController!.setVolume(0.0);
          
          _videoPlayerController!.addListener(() {
            if (_audioPlayerController == null) return;
            final vidVal = _videoPlayerController!.value;
            final audVal = _audioPlayerController!.value;
            
            if (vidVal.volume != audVal.volume) {
               _audioPlayerController!.setVolume(vidVal.volume);
            }
            if (vidVal.isBuffering) {
              if (audVal.isPlaying) _audioPlayerController!.pause();
            } else {
              if (vidVal.isPlaying && !audVal.isPlaying) {
                _audioPlayerController!.play();
              } else if (!vidVal.isPlaying && audVal.isPlaying) {
                _audioPlayerController!.pause();
              }
            }
            final diff = (vidVal.position - audVal.position).inMilliseconds.abs();
            if (diff > 500) _audioPlayerController!.seekTo(vidVal.position);
          });
        } else {
          await _videoPlayerController!.initialize();
        }

        if (mounted) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoPlayerController!,
              autoPlay: true,
              looping: false,
              allowFullScreen: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: AppColors.cyan,
                handleColor: AppColors.magenta,
                backgroundColor: Colors.white24,
                bufferedColor: Colors.white54,
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
      // 1. البحث أولاً باسم القناة لضمان الحصول على نتائج
      var results = await _yt.search.search(widget.video.author);
      var filteredList = results.whereType<yt.Video>().where((v) => v.id.value != widget.video.id.value).toList();
      
      // 2. إذا فشل، نبحث بأول 3 كلمات من العنوان فقط
      if (filteredList.isEmpty) {
        String shortTitle = widget.video.title.split(' ').take(3).join(' ');
        results = await _yt.search.search(shortTitle);
        filteredList = results.whereType<yt.Video>().where((v) => v.id.value != widget.video.id.value).toList();
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
    try {
      final result = await _backend.extractMediaLinks(widget.video.url);
      
      final String videoTitle = result['title'] as String;
      final String highestAudioUrl = result['highestAudioUrl'] as String;
      
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
    _videoPlayerController?.dispose();
    _audioPlayerController?.dispose();
    _chewieController?.dispose();
    _relatedScrollController.dispose();
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 230,
            width: double.infinity,
            color: Colors.black,
            child: _isLoadingVideo 
              ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
              : _hasPlayerError || _chewieController == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'العرض المباشر غير متاح.\nاستخدم زر التنزيل بالأسفل ⬇️',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Chewie(controller: _chewieController!),
                      if (_isMutedPreview)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_off, color: Colors.white, size: 14),
                                SizedBox(width: 5),
                                Text('معاينة بدون صوت', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
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
                            widget.video.title, 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)
                          ), 
                          const SizedBox(height: 10), 
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 5),
                              Text(widget.video.author, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, 
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                              ), 
                              onPressed: _isLoadingExtraction ? null : _handleExtraction, 
                              icon: _isLoadingExtraction 
                                  ? const SizedBox.shrink() 
                                  : const Icon(Icons.download_rounded, color: Colors.white, size: 24), 
                              label: _isLoadingExtraction 
                                  ? const SizedBox(
                                      height: 20, 
                                      width: 20, 
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    ) 
                                  : const Text('تحميل الجودات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          const Divider(color: AppColors.surfaceLight),
                          const SizedBox(height: 15),
                          const Text('فيديوهات ذات صلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cyan)),
                          const SizedBox(height: 15),
                          
                          if (_isLoadingRelated)
                            const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                          else if (_relatedVideos.isEmpty)
                            const Center(child: Text('لا توجد فيديوهات ذات صلة.', style: TextStyle(color: AppColors.textMuted)))
                        ]
                      )
                    );
                  }
                  
                  if (index == _relatedVideos.length + 1) {
                    return _isLoadingMoreRelated 
                        ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: AppColors.cyan))) 
                        : const SizedBox.shrink();
                  }
                  
                  final v = _relatedVideos[index - 1];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8), 
                        child: Image.network(v.thumbnails.lowResUrl, width: 100, height: 60, fit: BoxFit.cover)
                      ),
                      title: Text(
                        v.title, 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5), 
                        child: Text(v.author, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ),
                      onTap: () {
                        _chewieController?.pause();
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => WatchVideoScreen(video: v)));
                      },
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

class FormatSelectionSheet extends StatefulWidget {
  final String title;
  final String highestAudioUrl;
  final List<Map<String, dynamic>> videoFormats;
  final List<Map<String, dynamic>> audioFormats;

  const FormatSelectionSheet({
    super.key,
    required this.title,
    required this.highestAudioUrl,
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
            color: AppColors.surface.withOpacity(0.8),
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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
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
                            ),
                          );
                        },
                        child: const Text(
                          'بدء التنزيل', 
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
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
                        fontWeight: FontWeight.bold
                      )
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MB ${format['size']}', 
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)
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
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)
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
