import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class YoutubePlaylistService {
  static const _channelId     = 'UCt5uHMCEz9w1BhE0D-ZerKg';
  static const _emissionsId   = 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22';
  static const _matchdayId    = 'PLHZuIRHxEd8w_J7I_aEhtGc2MpLfINJVB';
  static const _resumesId     = 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD';
  static const _partenairesId = 'PLHZuIRHxEd8zKv-Z_Y-kg1_1S7u07Nw90';

  // Cache in-memory
  static final Map<String, List<VideoModel>> _cache = {};

  static Future<List<VideoModel>> getEmissions()   => _fromPlaylist(_emissionsId,   'podcast');
  static Future<List<VideoModel>> getMatchday()    => _fromPlaylist(_matchdayId,    'matchday');
  static Future<List<VideoModel>> getResumes()     => _fromPlaylist(_resumesId,     'resume');
  static Future<List<VideoModel>> getPartenaires() => _fromPlaylist(_partenairesId, 'partenaire');
  static Future<List<VideoModel>> getLatest()      => _fromChannel(_channelId);

  static Future<List<VideoModel>> getAll() async {
    final results = await Future.wait([
      getLatest(),
    ]);
    final all = results.expand((e) => e).toList();
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  static Future<List<VideoModel>> forCategory(String category) {
    switch (category) {
      case 'resume':     return getResumes();
      case 'podcast':    return getEmissions();
      case 'matchday':   return getMatchday();
      case 'partenaire': return getPartenaires();
      default:           return getAll();
    }
  }

  static Future<List<VideoModel>> _fromPlaylist(String playlistId, String category) async {
    // Supprimons le cache pour forcer le refresh pendant le debug
    // if (_cache.containsKey(playlistId)) return _cache[playlistId]!;

    // Charge depuis le disque si dispo (instantané)
    final disk = await _loadFromDisk(playlistId, category);
    if (disk.isNotEmpty) {
      _cache[playlistId] = disk;
      // Rafraîchit en arrière-plan
      _fetchAndCache(playlistId, category, 'https://www.youtube.com/feeds/videos.xml?playlist_id=$playlistId');
      return disk;
    }

    // Sinon fetch réseau
    return _fetchAndCache(playlistId, category, 'https://www.youtube.com/feeds/videos.xml?playlist_id=$playlistId');
  }

  static Future<List<VideoModel>> _fromChannel(String channelId) async {
    // Supprimons le cache pour forcer le refresh pendant le debug
    // if (_cache.containsKey(channelId)) return _cache[channelId]!;
    final disk = await _loadFromDisk(channelId, 'all');
    if (disk.isNotEmpty) {
      _cache[channelId] = disk;
      _fetchAndCache(channelId, 'all', 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
      return disk;
    }
    return _fetchAndCache(channelId, 'all', 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
  }

  static Future<List<VideoModel>> _fetchAndCache(String key, String category, String url) async {
    try {
      print('DEBUG: Fetching YouTube RSS from: $url');
      final res = await http.get(Uri.parse(url));
      print('DEBUG: Status Code: ${res.statusCode}');
      if (res.statusCode != 200) {
        print('DEBUG: Error response body: ${res.body}');
        return _cache[key] ?? [];
      }
      print('DEBUG: Raw XML response for $category: ${res.body}');
      final videos = _parseXml(res.body, category);
      print('DEBUG: Parsed ${videos.length} videos for $category');
      _cache[key] = videos;
      _saveToDisk(key, videos);
      return videos;
    } catch (e) {
      print('DEBUG: Exception during fetch: $e');
      return _cache[key] ?? [];
    }
  }

  // ── Persistance disque ────────────────────────────────────────────────────────
  static Future<List<VideoModel>> _loadFromDisk(String key, String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('yt_$key');
      if (json == null) return [];
      final list = jsonDecode(json) as List;
      return list.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveToDisk(String key, List<VideoModel> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yt_$key', jsonEncode(videos.map((v) => v.toJson()).toList()));
    } catch (_) {}
  }

  static List<VideoModel> _parseXml(String xml, String category) {
    final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xml);
    final videos = <VideoModel>[];
    for (final m in entries) {
      final entry = m.group(1)!;
      final videoId = _tag(entry, 'yt:videoId');
      final title   = _tag(entry, 'title');
      final pub     = _tag(entry, 'published');
      final thumb   = RegExp(r'<media:thumbnail[^>]+url="([^"]+)"').firstMatch(entry)?.group(1) ?? '';
      if (videoId.isEmpty || title.isEmpty) continue;
      DateTime date;
      try { date = DateTime.parse(pub); } catch (_) { date = DateTime.now(); }
      videos.add(VideoModel(
        id: videoId,
        title: title,
        youtubeId: videoId,
        thumbnailUrl: thumb.isNotEmpty ? thumb : null,
        duration: '',
        date: date,
        category: category,
        views: 0,
      ));
    }
    return videos;
  }

  static String _tag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>([^<]*)</$tag>').firstMatch(xml);
    return (m?.group(1) ?? '').trim();
  }

  static void clearCache() {
    _cache.clear();
  }
}
