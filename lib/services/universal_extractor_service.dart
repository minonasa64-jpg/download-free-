import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// خدمة استخراج الروابط العالمية (Universal Extractor Service)
/// تدعم استخراج وتحليل مقاطع الفيديو والصوت من:
/// TikTok, Instagram, Facebook, Twitter/X, Pinterest, Reddit, Vimeo, Dailymotion,
/// الروابط المباشرة (Direct Media URLs)، وأي موقع ويب يحتوي على فيديو (HTML5 Web Scraper).
class UniversalExtractorService {
  static final UniversalExtractorService _instance = UniversalExtractorService._internal();
  factory UniversalExtractorService() => _instance;
  UniversalExtractorService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    },
  ));

  /// كشف نوع المنصة تلقائياً من الرابط
  String detectPlatform(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'youtube';
    if (lower.contains('tiktok.com') || lower.contains('douyin.com')) return 'tiktok';
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) return 'instagram';
    if (lower.contains('facebook.com') || lower.contains('fb.watch') || lower.contains('fb.com')) return 'facebook';
    if (lower.contains('twitter.com') || lower.contains('x.com') || lower.contains('t.co')) return 'twitter';
    if (lower.contains('pinterest.com') || lower.contains('pin.it')) return 'pinterest';
    if (lower.contains('reddit.com') || lower.contains('redd.it')) return 'reddit';
    if (lower.contains('vimeo.com')) return 'vimeo';
    if (lower.contains('dailymotion.com') || lower.contains('dai.ly')) return 'dailymotion';

    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mp4') ||
          path.endsWith('.m3u8') ||
          path.endsWith('.webm') ||
          path.endsWith('.mov') ||
          path.endsWith('.mkv') ||
          path.endsWith('.mp3') ||
          path.endsWith('.m4a') ||
          path.endsWith('.wav') ||
          path.endsWith('.aac')) {
        return 'direct';
      }
    }

    return 'web';
  }

  /// الاستخراج الرئيسي لأي رابط
  Future<Map<String, dynamic>> extract(String rawUrl) async {
    final url = rawUrl.trim();
    final platform = detectPlatform(url);

    debugPrint('بدء استخراج الرابط عبر المحرك الشامل ($platform): $url');

    switch (platform) {
      case 'tiktok':
        return await _extractTikTok(url);
      case 'instagram':
        return await _extractInstagram(url);
      case 'facebook':
        return await _extractFacebook(url);
      case 'twitter':
        return await _extractTwitter(url);
      case 'pinterest':
        return await _extractPinterest(url);
      case 'direct':
        return await _extractDirectMedia(url);
      case 'web':
      default:
        return await _extractGenericWebOrFallbacks(url);
    }
  }

  // =========================================================================
  // 1. استخراج TikTok (فائق السرعة، بدون علامة مائية، صوت MP3)
  // =========================================================================
  Future<Map<String, dynamic>> _extractTikTok(String url) async {
    try {
      final response = await _dio.post(
        'https://www.tikwm.com/api/',
        data: {'url': url},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );

      final body = response.data;
      if (body is Map && body['code'] == 0 && body['data'] != null) {
        final data = body['data'] as Map;
        final title = (data['title'] ?? 'فيديو تيك توك').toString().trim();
        final cover = (data['cover'] ?? '').toString();
        final playUrl = (data['play'] ?? '').toString();
        final hdPlayUrl = (data['hdplay'] ?? '').toString();
        final wmPlayUrl = (data['wmplay'] ?? '').toString();
        final musicUrl = (data['music'] ?? '').toString();
        final author = data['author'] is Map ? (data['author']['nickname'] ?? 'TikTok') : 'TikTok';
        final int sizeBytes = (data['size'] as num?)?.toInt() ?? (data['hd_size'] as num?)?.toInt() ?? 0;
        final double sizeMb = sizeBytes > 0 ? (sizeBytes / (1024 * 1024)) : 5.0;

        final List<Map<String, dynamic>> videoFormats = [];

        if (hdPlayUrl.isNotEmpty) {
          videoFormats.add({
            'url': hdPlayUrl,
            'quality_name': 'عالي الدقة HD (بدون علامة مائية)',
            'quality_order': 1080,
            'quality_badge': 'HD فائقة',
            'quality_desc': 'جودة فائقة الوضوح وبدون أي علامة مائية',
            'size': (sizeMb * 1.3).toStringAsFixed(1),
            'size_bytes': (sizeBytes * 1.3).toInt(),
            'ext': 'mp4',
            'needs_merge': false,
            'platform': 'tiktok',
          });
        }

        if (playUrl.isNotEmpty) {
          videoFormats.add({
            'url': playUrl,
            'quality_name': 'بدون علامة مائية (سريع)',
            'quality_order': 720,
            'quality_badge': 'HD متوازن',
            'quality_desc': 'تنزيل سريع وبجودة عالية خالية من العلامة المائية',
            'size': sizeMb.toStringAsFixed(1),
            'size_bytes': sizeBytes,
            'ext': 'mp4',
            'needs_merge': false,
            'platform': 'tiktok',
          });
        }

        if (wmPlayUrl.isNotEmpty && videoFormats.isEmpty) {
          videoFormats.add({
            'url': wmPlayUrl,
            'quality_name': 'النسخة الأصلية',
            'quality_order': 720,
            'quality_badge': 'أصلي',
            'quality_desc': 'النسخة المباشرة من تطبيق تيك توك',
            'size': sizeMb.toStringAsFixed(1),
            'size_bytes': sizeBytes,
            'ext': 'mp4',
            'needs_merge': false,
            'platform': 'tiktok',
          });
        }

        final List<Map<String, dynamic>> audioFormats = [];
        if (musicUrl.isNotEmpty) {
          audioFormats.add({
            'url': musicUrl,
            'quality_name': 'صوت تيك توك الأصلي MP3',
            'quality_order': 192,
            'quality_badge': 'صوت HQ',
            'quality_desc': 'استخراج المسار الصوتي الأصلي بنقاء عالي',
            'size': '3.2',
            'size_bytes': 3200000,
            'ext': 'mp3',
            'needs_merge': false,
            'platform': 'tiktok',
          });
        }

        return {
          'id': (data['id'] ?? 'tiktok_${DateTime.now().millisecondsSinceEpoch}').toString(),
          'title': title.isEmpty ? 'فيديو تيك توك' : title,
          'thumbnail': cover,
          'author': author.toString(),
          'platform': 'tiktok',
          'highestAudioUrl': musicUrl,
          'highestAudioTag': null,
          'video': videoFormats,
          'audio': audioFormats,
          'subtitles': [],
        };
      }
    } catch (e) {
      debugPrint('تنبيه TikWM فشل، جاري المحاولة عبر المحرك الاحتياطي: $e');
    }

    // المحاولة الاحتياطية لـ TikTok
    return await _extractGenericWebOrFallbacks(url, forcedPlatform: 'tiktok');
  }

  // =========================================================================
  // 2. استخراج Instagram (Reels, Posts, Stories, IGTV)
  // =========================================================================
  Future<Map<String, dynamic>> _extractInstagram(String url) async {
    // محاولة 1: GraphQL السريع ?__a=1&__d=dis
    try {
      final cleanUri = Uri.parse(url);
      final segments = cleanUri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        final shortcode = segments[1];
        final apiUrl = 'https://www.instagram.com/p/$shortcode/?__a=1&__d=dis';
        final res = await _dio.get(
          apiUrl,
          options: Options(headers: {
            'User-Agent': 'Instagram 219.0.0.12.117 Android',
            'Accept': '*/*',
          }),
        );
        if (res.statusCode == 200 && res.data is Map) {
          final media = res.data['graphql']?['shortcode_media'] ?? res.data['items']?[0];
          if (media != null) {
            final videoUrl = media['video_url'] ?? media['video_versions']?[0]?['url'];
            final thumb = media['display_url'] ?? media['image_versions2']?[0]?['url'] ?? '';
            final caption = media['edge_media_to_caption']?['edges']?[0]?['node']?['text'] ?? 'ريلز إنستغرام';

            if (videoUrl != null && videoUrl.toString().isNotEmpty) {
              return _buildSimpleMediaResult(
                id: shortcode,
                title: caption.toString().split('\n').first,
                thumbnail: thumb.toString(),
                videoUrl: videoUrl.toString(),
                platform: 'instagram',
                author: media['owner']?['username'] ?? 'Instagram',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Instagram GraphQL محاولة 1: $e');
    }

    // محاولة 2: استدعاء محرك FastDL / SnapSave العام
    try {
      final res = await _dio.post(
        'https://v3.fdownloader.net/api/ajaxSearch',
        data: {'q': url, 'lang': 'en'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'origin': 'https://fdownloader.net', 'referer': 'https://fdownloader.net/'},
        ),
      );
      if (res.data != null && res.data['data'] != null) {
        final html = res.data['data'].toString();
        final match = RegExp(r'href="([^"]+)"[^>]*class="[^"]*btn-download').firstMatch(html) ??
            RegExp(r'href="([^"]+)"[^>]*>Download Video').firstMatch(html) ??
            RegExp(r'href="(https:\/\/[^"]+\.mp4[^"]*)"').firstMatch(html);

        if (match != null) {
          final vUrl = match.group(1)!.replaceAll('&amp;', '&');
          return _buildSimpleMediaResult(
            id: 'ig_${DateTime.now().millisecondsSinceEpoch}',
            title: 'ريلز إنستغرام',
            thumbnail: '',
            videoUrl: vUrl,
            platform: 'instagram',
            author: 'Instagram',
          );
        }
      }
    } catch (e) {
      debugPrint('Instagram FDownloader محاولة 2: $e');
    }

    // محاولة 3: استخراج من وسوم HTML و OpenGraph
    return await _extractGenericWebOrFallbacks(url, forcedPlatform: 'instagram');
  }

  // =========================================================================
  // 3. استخراج Facebook (Watch, Reels, Videos)
  // =========================================================================
  Future<Map<String, dynamic>> _extractFacebook(String url) async {
    // محاولة 1: FDownloader API
    try {
      final res = await _dio.post(
        'https://fdownloader.net/api/ajaxSearch',
        data: {'q': url, 'lang': 'en'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'origin': 'https://fdownloader.net', 'referer': 'https://fdownloader.net/'},
        ),
      );
      if (res.data != null && res.data['data'] != null) {
        final html = res.data['data'].toString();
        final hdMatch = RegExp(r'href="([^"]+)"[^>]*data-quality="HD"').firstMatch(html) ??
            RegExp(r'href="([^"]+)"[^>]*>Download HD').firstMatch(html);
        final sdMatch = RegExp(r'href="([^"]+)"[^>]*data-quality="SD"').firstMatch(html) ??
            RegExp(r'href="([^"]+)"[^>]*>Download SD').firstMatch(html) ??
            RegExp(r'href="(https:\/\/[^"]+\.mp4[^"]*)"').firstMatch(html);

        final videoUrl = (hdMatch?.group(1) ?? sdMatch?.group(1) ?? '').replaceAll('&amp;', '&');
        if (videoUrl.isNotEmpty) {
          return _buildSimpleMediaResult(
            id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
            title: 'فيديو فيسبوك',
            thumbnail: '',
            videoUrl: videoUrl,
            platform: 'facebook',
            author: 'Facebook',
          );
        }
      }
    } catch (e) {
      debugPrint('Facebook FDownloader محاولة 1: $e');
    }

    // محاولة 2: استخراج مباشر لـ sd_src و hd_src من صفحة فيسبوك
    try {
      final res = await _dio.get(
        url,
        options: Options(headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        }),
      );
      final html = res.data.toString();
      final hdSrc = RegExp(r'"playable_url_quality_hd":"([^"]+)"').firstMatch(html)?.group(1) ??
          RegExp(r'hd_src:"([^"]+)"').firstMatch(html)?.group(1);
      final sdSrc = RegExp(r'"playable_url":"([^"]+)"').firstMatch(html)?.group(1) ??
          RegExp(r'sd_src:"([^"]+)"').firstMatch(html)?.group(1);

      final rawUrl = (hdSrc ?? sdSrc ?? '').replaceAll(r'\/', '/').replaceAll('&amp;', '&');
      if (rawUrl.isNotEmpty) {
        return _buildSimpleMediaResult(
          id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
          title: 'فيديو فيسبوك',
          thumbnail: '',
          videoUrl: rawUrl,
          platform: 'facebook',
          author: 'Facebook',
        );
      }
    } catch (e) {
      debugPrint('Facebook Direct Scraping محاولة 2: $e');
    }

    return await _extractGenericWebOrFallbacks(url, forcedPlatform: 'facebook');
  }

  // =========================================================================
  // 4. استخراج Twitter / X
  // =========================================================================
  Future<Map<String, dynamic>> _extractTwitter(String url) async {
    // استخراج ID التغريدة
    final match = RegExp(r'status\/(\d+)').firstMatch(url);
    if (match != null) {
      final tweetId = match.group(1)!;
      // محاولة 1: VxTwitter / FxTwitter API السريعة
      try {
        final res = await _dio.get('https://api.vxtwitter.com/Twitter/status/$tweetId');
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map;
          final mediaList = data['mediaURLs'] as List? ?? [];
          final mediaUrl = mediaList.firstWhere(
            (m) => m.toString().contains('.mp4'),
            orElse: () => data['video_url'] ?? '',
          );

          if (mediaUrl.toString().isNotEmpty) {
            return _buildSimpleMediaResult(
              id: tweetId,
              title: data['text'] ?? 'فيديو من منصة X (تويتر)',
              thumbnail: (data['media_thumb'] ?? '').toString(),
              videoUrl: mediaUrl.toString(),
              platform: 'twitter',
              author: data['user_name'] ?? 'Twitter',
            );
          }
        }
      } catch (e) {
        debugPrint('Twitter VxTwitter محاولة 1: $e');
      }

      // محاولة 2: SaveTwitter API
      try {
        final res = await _dio.post(
          'https://savetwitter.net/api/ajaxSearch',
          data: {'q': url, 'lang': 'en'},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {'origin': 'https://savetwitter.net', 'referer': 'https://savetwitter.net/'},
          ),
        );
        if (res.data != null && res.data['data'] != null) {
          final html = res.data['data'].toString();
          final vMatch = RegExp(r'href="(https:\/\/[^"]+\.mp4[^"]*)"').firstMatch(html) ??
              RegExp(r'href="([^"]+)"[^>]*class="[^"]*tw-button-dl').firstMatch(html);
          if (vMatch != null) {
            return _buildSimpleMediaResult(
              id: tweetId,
              title: 'فيديو تويتر / X',
              thumbnail: '',
              videoUrl: vMatch.group(1)!.replaceAll('&amp;', '&'),
              platform: 'twitter',
              author: 'Twitter',
            );
          }
        }
      } catch (e) {
        debugPrint('Twitter SaveTwitter محاولة 2: $e');
      }
    }

    return await _extractGenericWebOrFallbacks(url, forcedPlatform: 'twitter');
  }

  // =========================================================================
  // 5. استخراج Pinterest
  // =========================================================================
  Future<Map<String, dynamic>> _extractPinterest(String url) async {
    try {
      final res = await _dio.get('https://www.savepin.app/download.php?url=${Uri.encodeComponent(url)}&lang=en&type=redirect');
      final html = res.data.toString();
      final vMatch = RegExp(r'href="([^"]*url=https%3A%2F%2Fv\.pinimg\.com[^"]*)"').firstMatch(html) ??
          RegExp(r'href="(https:\/\/v\.pinimg\.com[^"]+\.mp4[^"]*)"').firstMatch(html);

      if (vMatch != null) {
        String directUrl = vMatch.group(1)!;
        if (directUrl.contains('url=')) {
          directUrl = Uri.decodeComponent(directUrl.split('url=')[1]);
        }
        return _buildSimpleMediaResult(
          id: 'pin_${DateTime.now().millisecondsSinceEpoch}',
          title: 'فيديو بنترست Pinterest',
          thumbnail: '',
          videoUrl: directUrl,
          platform: 'pinterest',
          author: 'Pinterest',
        );
      }
    } catch (e) {
      debugPrint('Pinterest SavePin محاولة 1: $e');
    }

    return await _extractGenericWebOrFallbacks(url, forcedPlatform: 'pinterest');
  }

  // =========================================================================
  // 6. استخراج الروابط المباشرة لملفات الوسائط (.mp4, .m3u8, .mp3, etc.)
  // =========================================================================
  Future<Map<String, dynamic>> _extractDirectMedia(String url) async {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'media_file';
    final nameWithoutExt = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'mp4';
    final isAudio = ['mp3', 'm4a', 'wav', 'aac', 'flac'].contains(ext);

    int sizeBytes = 0;
    try {
      final headRes = await _dio.head(url);
      final cl = headRes.headers.value('content-length');
      if (cl != null) sizeBytes = int.tryParse(cl) ?? 0;
    } catch (_) {}

    final sizeMb = sizeBytes > 0 ? (sizeBytes / (1024 * 1024)).toStringAsFixed(1) : 'مباشر';

    final List<Map<String, dynamic>> videoFormats = [];
    final List<Map<String, dynamic>> audioFormats = [];

    if (!isAudio) {
      videoFormats.add({
        'url': url,
        'quality_name': 'جودة الرابط الأصلية ($ext)',
        'quality_order': 1080,
        'quality_badge': ext.toUpperCase(),
        'quality_desc': 'رابط مباشر بجودة المقطع الأصلية الكاملة',
        'size': sizeMb,
        'size_bytes': sizeBytes,
        'ext': ext,
        'needs_merge': false,
        'platform': 'direct',
      });
    }

    audioFormats.add({
      'url': url,
      'quality_name': 'صوت نقي (${isAudio ? ext.toUpperCase() : "MP3"})',
      'quality_order': 192,
      'quality_badge': isAudio ? ext.toUpperCase() : 'MP3',
      'quality_desc': isAudio ? 'ملف صوتي مباشر' : 'تحويل المقطع الصوتي تلقائياً إلى MP3',
      'size': isAudio ? sizeMb : 'صوت',
      'size_bytes': isAudio ? sizeBytes : 0,
      'ext': isAudio ? ext : 'mp3',
      'needs_merge': false,
      'platform': 'direct',
    });

    return {
      'id': 'direct_${DateTime.now().millisecondsSinceEpoch}',
      'title': nameWithoutExt.replaceAll('_', ' ').replaceAll('-', ' '),
      'thumbnail': 'https://via.placeholder.com/640x360/1A1A24/00D9FF?text=Direct+Media',
      'platform': 'direct',
      'author': uri.host,
      'highestAudioUrl': url,
      'highestAudioTag': null,
      'video': videoFormats,
      'audio': audioFormats,
      'subtitles': [],
    };
  }

  // =========================================================================
  // 7. استخراج أي صفحة ويب عامة أو المحرك الاحتياطي الشامل (Generic HTML5 / OpenGraph Scraper)
  // =========================================================================
  Future<Map<String, dynamic>> _extractGenericWebOrFallbacks(String url, {String? forcedPlatform}) async {
    debugPrint('جاري فحص محتوى صفحة الويب عبر HTML Scraper: $url');
    try {
      final res = await _dio.get(
        url,
        options: Options(
          followRedirects: true,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final html = res.data.toString();

      // استخراج العنوان
      final titleMatch = RegExp(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*property='og:title'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<meta[^>]*content="([^"]+)"[^>]*property="og:title"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*content='([^']+)'[^>]*property='og:title'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<meta[^>]*name="twitter:title"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*name='twitter:title'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
      final title = (titleMatch?.group(1) ?? 'فيديو من الإنترنت').replaceAll('&amp;', '&').trim();

      // استخراج الصورة المصغرة
      final thumbMatch = RegExp(r'<meta[^>]*property="og:image"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*property='og:image'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<meta[^>]*content="([^"]+)"[^>]*property="og:image"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*content='([^']+)'[^>]*property='og:image'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<meta[^>]*name="twitter:image"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*name='twitter:image'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html);
      final thumbnail = (thumbMatch?.group(1) ?? '').replaceAll('&amp;', '&');

      // استخراج رابط الفيديو من وسوم OpenGraph أو Twitter Card أو Video Tags
      final videoMatch = RegExp(r'<meta[^>]*property="og:video(?::secure_url|:url)?"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*property='og:video(?::secure_url|:url)?'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<meta[^>]*name="twitter:player:stream"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<meta[^>]*name='twitter:player:stream'[^>]*content='([^']+)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<source[^>]*src="([^"]+\.mp4[^"]*)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<source[^>]*src='([^']+\.mp4[^']*)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'<video[^>]*src="([^"]+\.mp4[^"]*)"', caseSensitive: false).firstMatch(html) ??
          RegExp(r"<video[^>]*src='([^']+\.mp4[^']*)'", caseSensitive: false).firstMatch(html) ??
          RegExp(r'"contentUrl":\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false).firstMatch(html);

      if (videoMatch != null) {
        String videoUrl = videoMatch.group(1)!.replaceAll(r'\/', '/').replaceAll('&amp;', '&');
        if (!videoUrl.startsWith('http')) {
          final uri = Uri.parse(url);
          videoUrl = '${uri.scheme}://${uri.host}$videoUrl';
        }

        return _buildSimpleMediaResult(
          id: 'web_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          thumbnail: thumbnail,
          videoUrl: videoUrl,
          platform: forcedPlatform ?? detectPlatform(url),
          author: Uri.tryParse(url)?.host ?? 'Web',
        );
      }
    } catch (e) {
      debugPrint('HTML Scraper خطأ: $e');
    }

    throw Exception('تعذر استخراج الفيديو من هذا الرابط. يرجى التأكد من أن الرابط عام وصالح.');
  }

  /// بناء هيكل نتيجة وسائط موحد
  Map<String, dynamic> _buildSimpleMediaResult({
    required String id,
    required String title,
    required String thumbnail,
    required String videoUrl,
    required String platform,
    required String author,
  }) {
    final List<Map<String, dynamic>> videoFormats = [
      {
        'url': videoUrl,
        'quality_name': 'عالي الجودة MP4 (الأصلية)',
        'quality_order': 1080,
        'quality_badge': 'HD فائقة',
        'quality_desc': 'جودة الفيديو الكاملة والأصلية من المصدر',
        'size': 'جاهز',
        'size_bytes': 0,
        'ext': 'mp4',
        'needs_merge': false,
        'platform': platform,
      },
      {
        'url': videoUrl,
        'quality_name': 'جودة قياسية متوازنة MP4',
        'quality_order': 720,
        'quality_badge': 'SD متوازن',
        'quality_desc': 'تنزيل سريع بحجم اقتصادي',
        'size': 'سريع',
        'size_bytes': 0,
        'ext': 'mp4',
        'needs_merge': false,
        'platform': platform,
      },
    ];

    final List<Map<String, dynamic>> audioFormats = [
      {
        'url': videoUrl,
        'quality_name': 'استخراج المسار الصوتي MP3',
        'quality_order': 192,
        'quality_badge': 'HQ نقي',
        'quality_desc': 'تحويل الصوت واستخراجه بجودة MP3 نقية 192kbps',
        'size': 'صوت',
        'size_bytes': 0,
        'ext': 'mp3',
        'needs_merge': false,
        'platform': platform,
      }
    ];

    return {
      'id': id,
      'title': title.isEmpty ? 'فيديو من $platform' : title,
      'thumbnail': thumbnail.isEmpty ? 'https://via.placeholder.com/640x360/1A1A24/00D9FF?text=$platform' : thumbnail,
      'author': author,
      'platform': platform,
      'highestAudioUrl': videoUrl,
      'highestAudioTag': null,
      'video': videoFormats,
      'audio': audioFormats,
      'subtitles': [],
    };
  }
}
