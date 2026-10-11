import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_resume.dart';
import '../models/video_model.dart';

class MediaResumeStore extends ChangeNotifier {
  MediaResumeStore._();
  static final MediaResumeStore instance = MediaResumeStore._();

  static const _prefsKey = 'media.resume.v1';

  List<MediaResumeItem> _items = const [];
  bool _loaded = false;
  Future<void>? _loadFuture;

  List<MediaResumeItem> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items = decoded
              .whereType<Map>()
              .map((e) => MediaResumeItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .where((e) => e.id.isNotEmpty && e.title.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      _items = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  MediaResumeItem? itemFor(MediaResumeKind kind, String id) {
    final key = '${kind.name}:$id';
    for (final item in _items) {
      if (item.key == key) return item;
    }
    return null;
  }

  Duration positionForVideo(String youtubeId) {
    return itemFor(MediaResumeKind.video, youtubeId)?.position ?? Duration.zero;
  }

  Duration positionForPodcast(String mp3Url) {
    return itemFor(MediaResumeKind.podcast, mp3Url)?.position ?? Duration.zero;
  }

  Future<void> upsertVideo({
    required String youtubeId,
    required String title,
    required Duration position,
    required Duration duration,
    VideoModel? video,
    bool isShort = false,
  }) {
    return upsert(
      MediaResumeItem.video(
        youtubeId: youtubeId,
        title: title,
        position: position,
        duration: duration,
        video: video,
      ),
      isShort: isShort || (video?.isShort ?? false),
    );
  }

  Future<void> upsertPodcast({
    required String mp3Url,
    required String title,
    required Duration position,
    required Duration duration,
    String? durationLabel,
  }) {
    return upsert(
      MediaResumeItem.podcast(
        mp3Url: mp3Url,
        title: title,
        position: position,
        duration: duration,
        durationLabel: durationLabel,
      ),
    );
  }

  Future<void> upsert(MediaResumeItem item, {bool isShort = false}) async {
    await ensureLoaded();
    final next = MediaResumeRules.upsert(_items, item, isShort: isShort);
    await _setItems(next);
  }

  Future<void> remove({
    required MediaResumeKind kind,
    required String id,
  }) async {
    await ensureLoaded();
    await _setItems(MediaResumeRules.remove(_items, kind: kind, id: id));
  }

  Future<void> removeVideo(String youtubeId) {
    return remove(kind: MediaResumeKind.video, id: youtubeId);
  }

  Future<void> removePodcast(String mp3Url) {
    return remove(kind: MediaResumeKind.podcast, id: mp3Url);
  }

  Future<void> _setItems(List<MediaResumeItem> next) async {
    if (_same(next, _items)) return;
    _items = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(next.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static bool _same(List<MediaResumeItem> a, List<MediaResumeItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key ||
          a[i].positionMs != b[i].positionMs ||
          a[i].durationMs != b[i].durationMs) {
        return false;
      }
    }
    return true;
  }
}
