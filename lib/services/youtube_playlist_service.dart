import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_model.dart';
import 'app_cache_service.dart';

class YoutubePlaylistService {
  static const _channelId = 'UCt5uHMCEz9w1BhE0D-ZerKg';
  static const _emissionsId = 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22';
  static const _matchdayId = 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB';
  static const _resumesId = 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD';
  static const _allCategory = 'all';
  static const _maxAge = Duration(hours: 2);

  static final Map<String, List<VideoModel>> _cache = {};
  static final Map<String, Future<List<VideoModel>>> _inFlight = {};

  static Future<List<VideoModel>> getEmissions() => _fromCategory('podcast');

  static Future<List<VideoModel>> getMatchday() => _fromCategory('matchday');

  static Future<List<VideoModel>> getResumes() => _fromCategory('resume');

  static Future<List<VideoModel>> getLatest() => _fromAllVideos();

  static Future<List<VideoModel>> getAll() => _fromAllVideos();

  static Future<List<VideoModel>> forCategory(String category) {
    final normalized = _normalizeCategory(category);
    if (normalized == _allCategory) {
      return _fromAllVideos();
    }
    return _fromCategory(normalized);
  }

  static Future<List<VideoModel>> refreshCategory(String category) async {
    final normalized = _normalizeCategory(category);
    final keysToClear = <String>{
      _cacheKeyFor(normalized),
      _cacheKeyFor(_allCategory),
    };
    await _clearCacheKeys(keysToClear);
    return forCategory(normalized);
  }

  static Future<List<VideoModel>> refreshAllFeeds() async {
    await _clearCacheKeys({
      _cacheKeyFor('resume'),
      _cacheKeyFor('podcast'),
      _cacheKeyFor('matchday'),
      _cacheKeyFor(_allCategory),
    });
    return getAll();
  }

  static Future<List<VideoModel>> _fromCategory(String category) {
    final normalized = _normalizeCategory(category);
    final cacheKey = _cacheKeyFor(normalized);
    return _loadOrRefresh(
      memoryKey: cacheKey,
      cacheKey: cacheKey,
      fetcher: () => _fetchVideos(category: normalized),
    );
  }

  static Future<List<VideoModel>> _fromAllVideos() {
    const cacheKey = 'youtube.feed.all';
    return _loadOrRefresh(
      memoryKey: cacheKey,
      cacheKey: cacheKey,
      fetcher: _fetchVideos,
    );
  }

  static Future<List<VideoModel>> _loadOrRefresh({
    required String memoryKey,
    required String cacheKey,
    required Future<List<VideoModel>> Function() fetcher,
  }) async {
    final memory = _cache[memoryKey];
    if (memory != null && await AppCacheService.isFresh(cacheKey, _maxAge)) {
      return memory;
    }

    final disk = await _loadFromDisk(cacheKey);
    if (disk != null && await AppCacheService.isFresh(cacheKey, _maxAge)) {
      _cache[memoryKey] = disk;
      return disk;
    }

    final pending = _inFlight[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _fetchAndCache(
      memoryKey: memoryKey,
      cacheKey: cacheKey,
      fetcher: fetcher,
      staleFallback: disk,
    );
    _inFlight[cacheKey] = request;
    return request.whenComplete(() {
      _inFlight.remove(cacheKey);
    });
  }

  static Future<List<VideoModel>> _fetchAndCache({
    required String memoryKey,
    required String cacheKey,
    required Future<List<VideoModel>> Function() fetcher,
    List<VideoModel>? staleFallback,
  }) async {
    try {
      final videos = await fetcher();
      _cache[memoryKey] = videos;
      await AppCacheService.upsertBody(
        cacheKey,
        jsonEncode(videos.map((video) => video.toJson()).toList()),
      );
      return videos;
    } catch (_) {
      final memory = _cache[memoryKey];
      if (staleFallback != null) {
        return staleFallback;
      }
      if (memory != null && memory.isNotEmpty) {
        return memory;
      }
      rethrow;
    }
  }

  static Future<List<VideoModel>> _fetchVideos({String? category}) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'videos',
    );
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.orderBy('created_at', descending: true).get();
    final seen = <String>{};
    return snapshot.docs
        .map(VideoModel.fromFirestore)
        .where(
          (video) => video.youtubeId.isNotEmpty && seen.add(video.youtubeId),
        )
        .toList();
  }

  static Future<List<VideoModel>?> _loadFromDisk(String cacheKey) async {
    final rawBody = await AppCacheService.readBody(cacheKey);
    if (rawBody == null || rawBody.isEmpty) {
      return null;
    }

    try {
      final list = jsonDecode(rawBody) as List;
      return list
          .map((entry) => VideoModel.fromJson(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static String _normalizeCategory(String category) {
    switch (category) {
      case 'resume':
      case 'podcast':
      case 'matchday':
        return category;
      case 'mission':
        return 'podcast';
      case '':
      case 'all':
      default:
        return _allCategory;
    }
  }

  static String _cacheKeyFor(String category) => 'youtube.feed.$category';

  static Future<void> _clearCacheKeys(Set<String> keys) async {
    for (final key in keys) {
      _cache.remove(key);
      _inFlight.remove(key);
      await AppCacheService.clear(key);
    }
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static Future<void> clearAllCache() async {
    clearCache();

    for (final key in const [
      'youtube.feed.resume',
      'youtube.feed.podcast',
      'youtube.feed.matchday',
      'youtube.feed.all',
      'youtube.playlist.$_emissionsId',
      'youtube.playlist.$_matchdayId',
      'youtube.playlist.$_resumesId',
      'youtube.channel.$_channelId',
    ]) {
      await AppCacheService.clear(key);
    }

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith('yt_'))) {
      await prefs.remove(key);
    }
  }
}
