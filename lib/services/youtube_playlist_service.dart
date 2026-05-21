import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_model.dart';
import 'app_cache_service.dart';

class YoutubePlaylistService {
  static const _allCategory = 'all';
  static const _catalogCacheKey = 'youtube.feed.all';
  static const _catalogSyncMsKey = 'youtube.catalog.syncMs';
  static const _maxAge = Duration(hours: 12);

  static List<VideoModel>? _catalogCache;
  static Future<List<VideoModel>>? _catalogInFlight;

  static Future<List<VideoModel>> getEmissions() => forCategory('podcast');

  static Future<List<VideoModel>> getMatchday() => forCategory('matchday');

  static Future<List<VideoModel>> getResumes() => forCategory('resume');

  static Future<List<VideoModel>> getLatest() => forCategory(_allCategory);

  static Future<List<VideoModel>> getAll() => forCategory(_allCategory);

  static Future<List<VideoModel>> forCategory(String category) async {
    final catalog = await _ensureCatalog();
    return _filterCategory(catalog, category);
  }

  /// Pull-to-refresh : uniquement les vidéos ajoutées depuis la dernière synchro.
  static Future<List<VideoModel>> refreshIncremental() async {
    return _ensureCatalog(forceIncremental: true);
  }

  static Future<List<VideoModel>> refreshCategory(String category) async {
    await refreshIncremental();
    return forCategory(category);
  }

  static Future<List<VideoModel>> refreshAllFeeds() => refreshIncremental();

  static Future<List<VideoModel>> _ensureCatalog({
    bool forceIncremental = false,
  }) async {
    if (!forceIncremental &&
        _catalogCache != null &&
        await AppCacheService.isFresh(_catalogCacheKey, _maxAge)) {
      return _catalogCache!;
    }

    final pending = _catalogInFlight;
    if (pending != null) {
      return pending;
    }

    final request = _loadCatalog(forceIncremental: forceIncremental);
    _catalogInFlight = request;
    return request.whenComplete(() {
      _catalogInFlight = null;
    });
  }

  static Future<List<VideoModel>> _loadCatalog({
    required bool forceIncremental,
  }) async {
    if (!forceIncremental) {
      final memory = _catalogCache;
      if (memory != null && await AppCacheService.isFresh(_catalogCacheKey, _maxAge)) {
        return memory;
      }
    }

    final disk = await _loadFromDisk(_catalogCacheKey);
    if (!forceIncremental &&
        disk != null &&
        await AppCacheService.isFresh(_catalogCacheKey, _maxAge)) {
      _catalogCache = disk;
      return disk;
    }

    try {
      if (disk != null && disk.isNotEmpty) {
        final syncMs = await _readSyncMs();
        if (syncMs > 0) {
          final delta = await _fetchVideosSince(syncMs);
          if (delta.isEmpty) {
            await AppCacheService.upsertBody(
              _catalogCacheKey,
              jsonEncode(disk.map((video) => video.toJson()).toList()),
            );
            _catalogCache = disk;
            return disk;
          }
          final merged = _mergeVideos(disk, delta);
          await _persistCatalog(merged);
          return merged;
        }
      }

      final full = await _fetchVideos();
      await _persistCatalog(full);
      return full;
    } catch (_) {
      if (disk != null && disk.isNotEmpty) {
        _catalogCache = disk;
        return disk;
      }
      final memory = _catalogCache;
      if (memory != null && memory.isNotEmpty) {
        return memory;
      }
      rethrow;
    }
  }

  static Future<List<VideoModel>> _fetchVideos() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('videos')
        .orderBy('created_at', descending: true)
        .limit(150)
        .get();
    return _mapDocs(snapshot.docs);
  }

  static Future<List<VideoModel>> _fetchVideosSince(int sinceMs) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('videos')
        .where('created_at', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs))
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();
    return _mapDocs(snapshot.docs);
  }

  static List<VideoModel> _mapDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final seen = <String>{};
    return docs
        .map(VideoModel.fromFirestore)
        .where(
          (video) => video.youtubeId.isNotEmpty && seen.add(video.youtubeId),
        )
        .toList();
  }

  static List<VideoModel> _mergeVideos(
    List<VideoModel> existing,
    List<VideoModel> incoming,
  ) {
    final byId = <String, VideoModel>{
      for (final video in existing) video.id: video,
    };
    for (final video in incoming) {
      byId[video.id] = video;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  static List<VideoModel> _filterCategory(
    List<VideoModel> catalog,
    String category,
  ) {
    final normalized = _normalizeCategory(category);
    if (normalized == _allCategory) {
      return catalog;
    }
    return catalog.where((video) => video.category == normalized).toList();
  }

  static Future<void> _persistCatalog(List<VideoModel> videos) async {
    _catalogCache = videos;
    await AppCacheService.upsertBody(
      _catalogCacheKey,
      jsonEncode(videos.map((video) => video.toJson()).toList()),
    );
    final maxMs = videos
        .map((video) => video.date.millisecondsSinceEpoch)
        .fold<int>(0, (max, value) => value > max ? value : max);
    if (maxMs > 0) {
      await _writeSyncMs(maxMs);
    }
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

  static Future<int> _readSyncMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_catalogSyncMsKey) ?? 0;
  }

  static Future<void> _writeSyncMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_catalogSyncMsKey, value);
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

  static void clearCache() {
    _catalogCache = null;
    _catalogInFlight = null;
  }

  static Future<void> clearAllCache() async {
    clearCache();
    await AppCacheService.clear(_catalogCacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_catalogSyncMsKey);
    for (final key in prefs.getKeys().where((key) => key.startsWith('yt_'))) {
      await prefs.remove(key);
    }
  }
}
