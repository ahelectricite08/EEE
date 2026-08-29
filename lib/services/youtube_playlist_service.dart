import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_model.dart';
import '../utils/youtube_parser.dart';
import '../utils/youtube_thumbnail.dart';
import 'app_cache_service.dart';

// ── Durées ─────────────────────────────────────────────────────────────────────
/// Cache local (mémoire / disque) : 12h comme avant.
const _kLocalMaxAge = Duration(hours: 12);

/// Cooldown du déclenchement Cloud Function :
/// le premier visiteur après ce délai déclenche la sync YouTube → Firestore.
const _kSyncCooldown = Duration(hours: 1);

/// Doc Firestore qui sert de verrou distribué.
const _kSyncLockDoc = 'config/video_feed_sync';

class YoutubePlaylistService {
  static const _allCategory = 'all';
  static const _shortsCategory = 'shorts';
  static const _catalogCacheKey = 'youtube.feed.all';
  static const _shortsCacheKey = 'youtube.feed.shorts';
  static const _catalogSyncMsKey = 'youtube.catalog.syncMs';

  /// @drapeauvertcartonrouge — playlist Shorts YouTube (UUSH + id sans UC).
  static const channelId = 'UCt5uHMCEz9w1BhE0D-ZerKg';
  static const shortsPlaylistId = 'UUSHt5uHMCEz9w1BhE0D-ZerKg';

  // ── Cache mémoire / in-flight ─────────────────────────────────────────────
  static List<VideoModel>? _catalogCache;
  static Future<List<VideoModel>>? _catalogInFlight;

  // ── Stream Firestore en direct (partagé entre tous les listeners) ─────────
  static Stream<List<VideoModel>>? _liveStream;

  // ── API publique ──────────────────────────────────────────────────────────

  static Future<List<VideoModel>> getEmissions() => forCategory('podcast');
  static Future<List<VideoModel>> getMatchday() => forCategory('matchday');
  static Future<List<VideoModel>> getResumes() => forCategory('resume');
  static Future<List<VideoModel>> getLatest() => forCategory(_allCategory);
  static Future<List<VideoModel>> getAll() async {
    final catalog = await _ensureCatalog();
    return catalog.where((v) => !v.hidden).toList();
  }
  static Future<List<VideoModel>> getShorts({bool preferComplete = false}) =>
      _ensureShorts(preferComplete: preferComplete);

  static final Map<String, List<VideoModel>> _publicPlaylistCache = {};
  static final Map<String, Future<List<VideoModel>>> _publicPlaylistInFlight =
      {};

  static const _ytBrowseHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 DVCR-App',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
  };

  /// Playlist YouTube (page watch + RSS + explode). Pas de clé API client.
  ///
  /// Le RSS n’expose que les vidéos **publiques**. Une playlist adhérents
  /// « Non répertoriée » est donc vide en RSS. youtube_explode 3.x ne lit plus
  /// les playlists YouTube (lockupViewModel). On parse la page `/playlist`.
  static Future<List<VideoModel>> forPublicPlaylist(String rawId) async {
    final id = YoutubeParser.extractPlaylistId(rawId) ?? rawId.trim();
    if (id.isEmpty) return const [];
    final cached = _publicPlaylistCache[id];
    if (cached != null && cached.isNotEmpty) return cached;
    final pending = _publicPlaylistInFlight[id];
    if (pending != null) return pending;
    final request = _loadPublicPlaylist(id);
    _publicPlaylistInFlight[id] = request;
    try {
      final videos = await request;
      if (videos.isNotEmpty) _publicPlaylistCache[id] = videos;
      return videos;
    } finally {
      _publicPlaylistInFlight.remove(id);
    }
  }

  static Future<List<VideoModel>> _loadPublicPlaylist(String id) async {
    const category = 'adherent_vod';
    final html = await _fetchPlaylistHtml(id, category: category);
    if (html.isNotEmpty) return html;
    final rss = await _fetchPlaylistRss(id, category: category);
    if (rss.isNotEmpty) return rss;
    return _fetchPlaylistExplode(id, category: category);
  }

  static void clearPublicPlaylistCache() {
    _publicPlaylistCache.clear();
    _publicPlaylistInFlight.clear();
  }

  static Future<List<VideoModel>> forCategory(String category) async {
    final catalog = await _ensureCatalog();
    return _filterCategory(catalog, category);
  }

  static Future<List<VideoModel>> refreshIncremental() async {
    return _ensureCatalog(forceIncremental: true);
  }

  static Future<List<VideoModel>> refreshCategory(String category) async {
    await refreshIncremental();
    return forCategory(category);
  }

  static Future<List<VideoModel>> refreshAllFeeds() => refreshIncremental();

  // ── Stream en direct ──────────────────────────────────────────────────────
  /// Écoute la collection Firestore en temps réel.
  /// Dès qu'une nouvelle vidéo est ajoutée (par la Cloud Function),
  /// tous les widgets abonnés se reconstruisent automatiquement.
  static Stream<List<VideoModel>> liveStream({String category = _allCategory}) {
    _liveStream ??= FirebaseFirestore.instance
        .collection('videos')
        .orderBy('created_at', descending: true)
        .limit(150)
        .snapshots()
        .map((snap) {
          final seen = <String>{};
          return snap.docs
              .map(VideoModel.fromFirestore)
              .where((v) => v.youtubeId.isNotEmpty && seen.add(v.youtubeId))
              .toList();
        })
        .asBroadcastStream(); // partagé : un seul socket Firestore pour tous

    return _liveStream!.map((all) => _filterCategory(all, category));
  }

  // ── Déclenchement intelligent de la sync ─────────────────────────────────
  /// À appeler quand l'utilisateur ouvre la page vidéo.
  ///
  /// - Lit le verrou Firestore `config/video_feed_sync.lastTriggeredAt`.
  /// - Si > [_kSyncCooldown] (ou absent) : tente de mettre à jour le verrou
  ///   atomiquement via transaction → appel unique à `syncYoutubeVideosManual`.
  /// - Si le verrou est récent : ne fait rien (quelqu'un d'autre a déjà déclenché).
  ///
  /// Garanti : 1 appel Cloud Function max par [_kSyncCooldown], même si
  /// 1 000 utilisateurs ouvrent la page en même temps.
  static Future<void> maybeRequestSync() async {
    try {
      final db  = FirebaseFirestore.instance;
      final ref = db.doc(_kSyncLockDoc);

      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final now  = DateTime.now();

        if (snap.exists) {
          final ts = (snap.data()!['lastTriggeredAt'] as Timestamp?)?.toDate();
          if (ts != null && now.difference(ts) < _kSyncCooldown) {
            // Trop récent → on ne fait rien (on lève pour sortir de la transaction)
            throw _SkipException();
          }
        }

        // On gagne la course → on met à jour le verrou
        tx.set(ref, {'lastTriggeredAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      });

      // Transaction réussie = on est le premier, on déclenche la Cloud Function
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('syncYoutubeVideosManual')
          .call();
    } on _SkipException {
      // Normal : quelqu'un d'autre a déjà déclenché dans le cooldown
    } catch (_) {
      // Erreur réseau / Cloud Function indisponible → silencieux
    }
  }

  // ── Implémentation interne (inchangée) ───────────────────────────────────

  static Future<List<VideoModel>> _ensureCatalog({
    bool forceIncremental = false,
  }) async {
    if (!forceIncremental &&
        _catalogCache != null &&
        await AppCacheService.isFresh(_catalogCacheKey, _kLocalMaxAge)) {
      return _catalogCache!;
    }

    final pending = _catalogInFlight;
    if (pending != null) return pending;

    final request = _loadCatalog(forceIncremental: forceIncremental);
    _catalogInFlight = request;
    return request.whenComplete(() => _catalogInFlight = null);
  }

  static Future<List<VideoModel>> _loadCatalog({
    required bool forceIncremental,
  }) async {
    if (!forceIncremental) {
      final memory = _catalogCache;
      if (memory != null &&
          await AppCacheService.isFresh(_catalogCacheKey, _kLocalMaxAge)) {
        return memory;
      }
    }

    final disk = await _loadFromDisk(_catalogCacheKey);
    if (!forceIncremental &&
        disk != null &&
        await AppCacheService.isFresh(_catalogCacheKey, _kLocalMaxAge)) {
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
              jsonEncode(disk.map((v) => v.toJson()).toList()),
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
      if (memory != null && memory.isNotEmpty) return memory;
      rethrow;
    }
  }

  static Future<List<VideoModel>> _fetchVideos() async {
    final snap = await FirebaseFirestore.instance
        .collection('videos')
        .orderBy('created_at', descending: true)
        .limit(150)
        .get();
    return _mapDocs(snap.docs);
  }

  static Future<List<VideoModel>> _fetchVideosSince(int sinceMs) async {
    final snap = await FirebaseFirestore.instance
        .collection('videos')
        .where('created_at',
            isGreaterThan:
                Timestamp.fromMillisecondsSinceEpoch(sinceMs))
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();
    return _mapDocs(snap.docs);
  }

  static List<VideoModel> _mapDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final seen = <String>{};
    return docs
        .map(VideoModel.fromFirestore)
        .where((v) => v.youtubeId.isNotEmpty && seen.add(v.youtubeId))
        .toList();
  }

  static List<VideoModel> _mergeVideos(
      List<VideoModel> existing, List<VideoModel> incoming) {
    final byId = <String, VideoModel>{
      for (final v in existing) v.id: v,
    };
    for (final v in incoming) {
      byId[v.id] = v;
    }
    return byId.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<VideoModel> _filterCategory(
      List<VideoModel> catalog, String category) {
    final n = _normalizeCategory(category);
    if (n == _shortsCategory) {
      return _sortShorts(catalog.where((v) => v.isVisibleShort).toList());
    }
    final longForm = catalog.where((v) => !v.hidden && !v.isVisibleShort);
    if (n == _allCategory) return longForm.toList();
    return longForm.where((v) => v.category == n).toList();
  }

  static List<VideoModel> _sortShorts(List<VideoModel> videos) {
    videos.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return videos;
  }

  static Future<List<VideoModel>> _ensureShorts({
    bool preferComplete = false,
  }) async {
    final fromStore = await _fetchShortsFromFirestore();
    if (fromStore.isNotEmpty) return fromStore;

    if (!preferComplete) {
      final cached = await _loadFromDisk(_shortsCacheKey);
      if (cached != null &&
          cached.isNotEmpty &&
          await AppCacheService.isFresh(_shortsCacheKey, _kLocalMaxAge)) {
        return _sortShorts(cached);
      }
      final rss = await _fetchShortsRss();
      if (rss.isNotEmpty) {
        await _persistShorts(rss);
        unawaited(_fetchShortsExplodeAndCache());
        return rss;
      }
    }

    final exploded = await _fetchShortsExplodeAndCache();
    if (exploded.isNotEmpty) return exploded;
    return _fetchShortsRss();
  }

  static Future<List<VideoModel>> _fetchShortsFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('videos')
          .where('category', isEqualTo: _shortsCategory)
          .orderBy('created_at', descending: true)
          .limit(80)
          .get();
      final dedicated = _mapDocs(snap.docs)
          .where((v) => v.isVisibleShort)
          .toList();
      if (dedicated.isNotEmpty) {
        await _persistShorts(dedicated);
        return _sortShorts(dedicated);
      }

      final catalog = await _ensureCatalog();
      final fromCatalog =
          catalog.where((v) => v.isVisibleShort).toList();
      if (fromCatalog.isNotEmpty) return _sortShorts(fromCatalog);
    } catch (_) {
      try {
        final catalog = await _ensureCatalog();
        final fromCatalog =
            catalog.where((v) => v.isVisibleShort).toList();
        if (fromCatalog.isNotEmpty) return _sortShorts(fromCatalog);
      } catch (_) {}
    }
    return const [];
  }

  static Future<void> _persistShorts(List<VideoModel> videos) async {
    final sorted = _sortShorts(List<VideoModel>.from(videos));
    await AppCacheService.upsertBody(
      _shortsCacheKey,
      jsonEncode(sorted.map((v) => v.toJson()).toList()),
    );
  }

  static Future<List<VideoModel>> _fetchShortsRss() async {
    return _fetchPlaylistRss(shortsPlaylistId, category: _shortsCategory);
  }

  static Future<List<VideoModel>> _fetchPlaylistHtml(
    String playlistId, {
    required String category,
  }) async {
    try {
      final uri = Uri.https('www.youtube.com', '/playlist', {
        'list': playlistId,
        'hl': 'fr',
      });
      final res = await http.get(
        uri,
        headers: {
          ..._ytBrowseHeaders,
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || res.body.isEmpty) return const [];
      return parsePlaylistWatchPageHtml(res.body, category: category);
    } catch (_) {
      return const [];
    }
  }

  /// Page `/playlist?list=` — YouTube sert `lockupViewModel` (plus `playlistVideoRenderer`).
  @visibleForTesting
  static List<VideoModel> parsePlaylistWatchPageHtml(
    String html, {
    required String category,
  }) {
    final ids = <String>[];
    final seen = <String>{};
    for (final match in RegExp(
      r'"lockupViewModel":\{"contentImage":\{"thumbnailViewModel":\{"image":\{"sources":\[\{"url":"https://i\.ytimg\.com/vi/([^/"\\]+)/',
    ).allMatches(html)) {
      final id = match.group(1)?.trim() ?? '';
      if (id.length == 11 && seen.add(id)) ids.add(id);
    }
    if (ids.isEmpty) {
      for (final match in RegExp(
        r'"watchEndpoint":\{"videoId":"([A-Za-z0-9_-]{11})"',
      ).allMatches(html)) {
        final id = match.group(1)!;
        if (seen.add(id)) ids.add(id);
      }
    }
    if (ids.isEmpty) return const [];

    final titles = <String>[];
    for (final match in RegExp(
      r'"lockupMetadataViewModel":\{"title":\{"content":"((?:\\.|[^"\\])*)"',
    ).allMatches(html)) {
      titles.add(_unescapeYoutubeJsonString(match.group(1)!));
    }

    final out = <VideoModel>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final title = i < titles.length && titles[i].trim().isNotEmpty
          ? titles[i]
          : (category == _shortsCategory ? 'Short DVCR' : 'Vidéo DVCR');
      out.add(
        VideoModel(
          id: 'ytpl_$id',
          title: title,
          youtubeId: id,
          thumbnailUrl: bestYoutubeThumbnailUrl(id),
          duration: '',
          date: DateTime.now().subtract(Duration(seconds: i)),
          category: category,
          isShort: category == _shortsCategory,
        ),
      );
    }
    if (category == _shortsCategory) return _sortShorts(out);
    return out;
  }

  static String _unescapeYoutubeJsonString(String raw) {
    try {
      final decoded = jsonDecode('"$raw"');
      if (decoded is String) return decoded;
    } catch (_) {}
    return raw
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', '\n');
  }

  static Future<List<VideoModel>> _fetchPlaylistRss(
    String playlistId, {
    required String category,
  }) async {
    try {
      final uri = Uri.https('www.youtube.com', '/feeds/videos.xml', {
        'playlist_id': playlistId,
      });
      final res = await http.get(
        uri,
        headers: {
          ..._ytBrowseHeaders,
          'Accept': 'application/atom+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200 || res.body.isEmpty) return const [];
      return parsePlaylistRssXml(res.body, category: category);
    } catch (_) {
      return const [];
    }
  }

  @visibleForTesting
  static List<VideoModel> parsePlaylistRssXml(
    String xml, {
    required String category,
  }) {
    final out = <VideoModel>[];
    final seen = <String>{};
    for (final match in RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xml)) {
      final block = match.group(1)!;
      final videoId = RegExp(r'<yt:videoId>([^<]+)</yt:videoId>')
              .firstMatch(block)
              ?.group(1)
              ?.trim() ??
          RegExp(r'<id>yt:video:([^<]+)</id>')
              .firstMatch(block)
              ?.group(1)
              ?.trim();
      if (videoId == null || videoId.isEmpty || !seen.add(videoId)) continue;
      final title = _decodeXml(
        RegExp(r'<media:title>([^<]+)</media:title>')
                .firstMatch(block)
                ?.group(1) ??
            (RegExp(r'<title>([^<]+)</title>').firstMatch(block)?.group(1) ??
                (category == _shortsCategory ? 'Short DVCR' : 'Vidéo DVCR')),
      );
      final published = DateTime.tryParse(
            RegExp(r'<published>([^<]+)</published>')
                    .firstMatch(block)
                    ?.group(1) ??
                '',
          ) ??
          DateTime.now();
      final thumb = RegExp(r'<media:thumbnail[^>]+url="([^"]+)"')
          .firstMatch(block)
          ?.group(1);
      out.add(
        VideoModel(
          id: 'rss_$videoId',
          title: title,
          youtubeId: videoId,
          thumbnailUrl: bestYoutubeThumbnailUrl(videoId, stored: thumb),
          duration: '',
          date: published,
          category: category,
          isShort: category == _shortsCategory,
        ),
      );
    }
    if (category == _shortsCategory) return _sortShorts(out);
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static Future<List<VideoModel>> _fetchPlaylistExplode(
    String playlistId, {
    required String category,
  }) async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final videos = <VideoModel>[];
      final seen = <String>{};
      await for (final v in yt.playlists.getVideos(playlistId)) {
        final id = v.id.value;
        if (id.isEmpty || !seen.add(id)) continue;
        final seconds = v.duration?.inSeconds ?? 0;
        videos.add(
          VideoModel(
            id: 'yt_$id',
            title: v.title,
            youtubeId: id,
            thumbnailUrl: bestYoutubeThumbnailUrl(id),
            duration: _formatClock(seconds),
            date: v.uploadDate ?? DateTime.now(),
            category: category,
            isShort: category == _shortsCategory,
            durationSeconds: seconds,
          ),
        );
      }
      if (category == _shortsCategory) return _sortShorts(videos);
      videos.sort((a, b) => b.date.compareTo(a.date));
      return videos;
    } catch (_) {
      return const [];
    } finally {
      yt?.close();
    }
  }

  static String _decodeXml(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  static Future<List<VideoModel>> _fetchShortsExplodeAndCache() async {
    YoutubeExplode? yt;
    try {
      yt = YoutubeExplode();
      final videos = <VideoModel>[];
      final seen = <String>{};
      await for (final v in yt.playlists.getVideos(shortsPlaylistId)) {
        final id = v.id.value;
        if (id.isEmpty || !seen.add(id)) continue;
        final seconds = v.duration?.inSeconds ?? 0;
        videos.add(
          VideoModel(
            id: 'yt_$id',
            title: v.title,
            youtubeId: id,
            thumbnailUrl: bestYoutubeThumbnailUrl(id),
            duration: _formatClock(seconds),
            date: v.uploadDate ?? DateTime.now(),
            category: _shortsCategory,
            isShort: true,
            durationSeconds: seconds,
          ),
        );
      }
      if (videos.isNotEmpty) await _persistShorts(videos);
      return _sortShorts(videos);
    } catch (_) {
      return const [];
    } finally {
      yt?.close();
    }
  }

  static String _formatClock(int seconds) {
    if (seconds <= 0) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static Future<void> _persistCatalog(List<VideoModel> videos) async {
    _catalogCache = videos;
    await AppCacheService.upsertBody(
      _catalogCacheKey,
      jsonEncode(videos.map((v) => v.toJson()).toList()),
    );
    final maxMs = videos
        .map((v) => v.date.millisecondsSinceEpoch)
        .fold<int>(0, (max, val) => val > max ? val : max);
    if (maxMs > 0) await _writeSyncMs(maxMs);
  }

  static Future<List<VideoModel>?> _loadFromDisk(String cacheKey) async {
    final rawBody = await AppCacheService.readBody(cacheKey);
    if (rawBody == null || rawBody.isEmpty) return null;
    try {
      final list = jsonDecode(rawBody) as List;
      return list
          .map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
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
      case 'shorts':
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
    _liveStream = null;
    _publicPlaylistCache.clear();
    _publicPlaylistInFlight.clear();
  }

  static Future<void> clearAllCache() async {
    clearCache();
    await AppCacheService.clear(_catalogCacheKey);
    await AppCacheService.clear(_shortsCacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_catalogSyncMsKey);
    for (final key
        in prefs.getKeys().where((k) => k.startsWith('yt_'))) {
      await prefs.remove(key);
    }
  }
}

// Sentinel interne pour court-circuiter la transaction sans erreur
class _SkipException implements Exception {}
