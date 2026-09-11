import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
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
  ChewieController? _chewieController;
  
  final ScrollController _relatedScrollController = ScrollController();
  
  bool _isLoadingExtraction = false;
  bool _isLoadingVideo = true;
  bool _hasPlayerError = false;
  
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
      var results = await _yt.search.search(widget.video.title);
      var filteredList = results.whereType<yt.Video>().where((v) => v.id.value != widget.video.id.value).toList();
      
      if (filteredList.isEmpty) {
        results = await _yt.search.search(widget.video.author);
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

  Future<void> _handleExtraction() async {
    setState(() => _isLoadingExtraction = true);
    try {
      final result = await _backend.extractMediaLinks(widget.video.url);
      
      final String videoTitle = result['title'] as String;
      final List<Map<String, dynamic>> videoList = List<Map<String, dynamic>>.from(result['video'] ?? []);
      final List<Map<String, dynamic>> audioList = List<Map<String, dynamic>>.from(result['audio'] ?? []);

      if (mounted && (videoList.isNotEmpty || audioList.isNotEmpty)) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return FormatSelectionSheet(
              title: videoTitle,
              videoFormats: videoList,
              audioFormats: audioList,
            );
          },
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر استخراج الجودات، الرابط قد يكون محمياً'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الاستخراج. تأكد من اتصالك بالإنترنت.'))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingExtraction = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
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
                : Chewie(controller: _chewieController!),
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
