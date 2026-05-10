import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_cache_service.dart';

class PodcastEpisode {
  final String title;
  final String duration;
  final DateTime pubDate;
  final String mp3Url;

  PodcastEpisode({
    required this.title,
    required this.duration,
    required this.pubDate,
    required this.mp3Url,
  });
}

class _DVCRAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  Duration currentPositionValue = Duration.zero;
  Duration currentDurationValue = Duration.zero;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Future<Duration> getCurrentPosition() async =>
      await _player.getCurrentPosition() ?? Duration.zero;
  Future<Duration> getCurrentDuration() async =>
      await _player.getDuration() ?? Duration.zero;

  _DVCRAudioHandler() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0],
          processingState: AudioProcessingState.ready,
          playing: playing,
          updatePosition: currentPositionValue,
        ),
      );
    });
    _player.onPositionChanged.listen((position) {
      currentPositionValue = position;
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: position,
          playing: _player.state == PlayerState.playing,
        ),
      );
    });
    _player.onDurationChanged.listen((duration) {
      currentDurationValue = duration;
    });
    _player.onPlayerComplete.listen((_) {
      currentPositionValue = Duration.zero;
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
          updatePosition: Duration.zero,
        ),
      );
    });
  }

  Future<void> playUrl(String url, MediaItem item) async {
    currentPositionValue = Duration.zero;
    mediaItem.add(item);
    await _player.play(UrlSource(url));
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    currentPositionValue = Duration.zero;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
      ),
    );
  }
}

class PodcastController extends ChangeNotifier {
  static final PodcastController instance = PodcastController._internal();
  PodcastController._internal();

  static const _rss =
      'https://feeds.soundcloud.com/users/soundcloud:users:1150891726/sounds.rss';
  static const _cacheKey = 'podcast.rss';
  static const _maxAge = Duration(minutes: 20);
  static const _resumePrefix = 'podcast.resume.';

  _DVCRAudioHandler? _handler;
  List<PodcastEpisode> episodes = [];
  int? currentIndex;
  bool isPlaying = false;
  bool isLoading = true;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Timer? _progressTimer;
  int _lastSavedSecond = -1;
  Future<void>? _initFuture;

  Future<void> init() {
    final pending = _initFuture;
    if (pending != null) {
      return pending;
    }
    final future = _initInternal();
    _initFuture = future.catchError((Object error) {
      _initFuture = null;
      throw error;
    });
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    if (_handler != null) {
      return;
    }
    _handler = await AudioService.init(
      builder: () => _DVCRAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.dvcr.podcast',
        androidNotificationChannelName: 'DVCR Podcast',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    _playbackSub?.cancel();
    _playbackSub = _handler!.playbackState.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == AudioProcessingState.completed) {
        unawaited(_clearSavedPositionForCurrent());
      }
      _syncProgressTimer();
      notifyListeners();
    });
    _positionSub?.cancel();
    _positionSub = _handler!.positionStream.listen((position) {
      currentPosition = position;
      _persistProgressIfNeeded();
      notifyListeners();
    });
    _durationSub?.cancel();
    _durationSub = _handler!.durationStream.listen((duration) {
      totalDuration = duration;
      notifyListeners();
    });
    _syncProgressTimer();
    unawaited(fetchRss());
  }

  Future<void> fetchRss() async {
    final cachedBody = await AppCacheService.readBody(_cacheKey);
    if (cachedBody != null && cachedBody.isNotEmpty) {
      episodes = _parseEpisodes(cachedBody);
      isLoading = false;
      notifyListeners();
      if (await AppCacheService.isFresh(_cacheKey, _maxAge)) {
        return;
      }
    }

    try {
      final res = await http.get(Uri.parse(_rss));
      if (res.statusCode != 200) {
        isLoading = false;
        notifyListeners();
        return;
      }

      final changed = await AppCacheService.upsertBody(_cacheKey, res.body);
      if (changed || episodes.isEmpty) {
        episodes = _parseEpisodes(res.body);
      }
    } catch (_) {}

    isLoading = false;
    notifyListeners();
  }

  List<PodcastEpisode> _parseEpisodes(String body) {
    final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(body);
    final list = <PodcastEpisode>[];
    for (final m in items.take(8)) {
      final item = m.group(1)!;
      final title = _tag(item, 'title');
      final dur = _tag(item, 'itunes:duration');
      final pub = _tag(item, 'pubDate');
      final mp3 =
          RegExp(r'<enclosure[^>]+url="([^"]+)"').firstMatch(item)?.group(1) ??
          '';
      if (title.isEmpty || mp3.isEmpty) continue;
      DateTime date;
      try {
        date = _parseRssDate(pub);
      } catch (_) {
        date = DateTime.now();
      }
      list.add(
        PodcastEpisode(title: title, duration: dur, pubDate: date, mp3Url: mp3),
      );
    }
    return list;
  }

  Future<void> togglePlay(int index) async {
    if (_handler == null) return;
    final ep = episodes[index];
    if (currentIndex == index) {
      if (isPlaying) {
        await _handler!.pause();
      } else {
        await _handler!.play();
      }
      _syncProgressTimer();
    } else {
      currentIndex = index;
      currentPosition = Duration.zero;
      totalDuration = _parseDuration(ep.duration) ?? Duration.zero;
      _lastSavedSecond = -1;
      notifyListeners();
      await _handler!.playUrl(
        ep.mp3Url,
        MediaItem(
          id: ep.mp3Url,
          title: ep.title,
          artist: 'DVCR Podcast',
          duration: _parseDuration(ep.duration),
          artUri: Uri.parse(
            'https://i1.sndcdn.com/avatars-000000000000-000000-t500x500.jpg',
          ),
        ),
      );
      final resumeAt = await _loadSavedPosition(ep.mp3Url);
      if (resumeAt > Duration.zero) {
        await _handler!.seek(resumeAt);
        currentPosition = resumeAt;
      }
      _syncProgressTimer();
      notifyListeners();
    }
  }

  Future<void> pause() => _handler?.pause() ?? Future.value();
  Future<void> resume() => _handler?.play() ?? Future.value();

  Future<void> seek(Duration position) async {
    if (_handler == null) return;
    final capped = _capPosition(position);
    await _handler!.seek(capped);
    currentPosition = capped;
    await _persistProgress(force: true);
    _syncProgressTimer();
    notifyListeners();
  }

  Future<void> seekToFraction(double fraction) async {
    final duration = effectiveDuration;
    if (duration <= Duration.zero) return;
    final target = Duration(
      milliseconds: (duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    await seek(target);
  }

  Future<void> skipBy(Duration delta) async {
    await seek(currentPosition + delta);
  }

  Future<void> dismiss() async {
    await _persistProgress(force: true);
    await _handler?.stop();
    currentIndex = null;
    currentPosition = Duration.zero;
    totalDuration = Duration.zero;
    _syncProgressTimer();
    notifyListeners();
  }

  PodcastEpisode? get currentEpisode {
    return currentIndex != null && currentIndex! < episodes.length
        ? episodes[currentIndex!]
        : null;
  }

  Duration get effectiveDuration {
    if (totalDuration > Duration.zero) return totalDuration;
    final episode = currentEpisode;
    if (episode == null) return Duration.zero;
    return _parseDuration(episode.duration) ?? Duration.zero;
  }

  double get progress {
    final duration = effectiveDuration;
    if (duration <= Duration.zero) return 0;
    final ratio = currentPosition.inMilliseconds / duration.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  String get positionLabel => formatDuration(currentPosition);

  String get durationLabel {
    final duration = effectiveDuration;
    if (duration > Duration.zero) return formatDuration(duration);
    return currentEpisode?.duration ?? '--:--';
  }

  bool get hasProgress => currentPosition > Duration.zero;

  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _tag(String xml, String tag) {
    final m = RegExp(
      '<$tag[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></$tag>|<$tag[^>]*>([^<]*)</$tag>',
    ).firstMatch(xml);
    return (m?.group(1) ?? m?.group(2) ?? '').trim();
  }

  DateTime _parseRssDate(String s) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final parts = s.trim().split(' ');
    return DateTime(
      int.parse(parts[3]),
      months[parts[2]] ?? 1,
      int.parse(parts[1]),
    );
  }

  Duration? _parseDuration(String s) {
    try {
      final parts = s.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
      if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    } catch (_) {}
    return null;
  }

  Duration _capPosition(Duration position) {
    final duration = effectiveDuration;
    if (position.isNegative) return Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }

  String _resumeKey(String url) => '$_resumePrefix${Uri.encodeComponent(url)}';

  Future<Duration> _loadSavedPosition(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_resumeKey(url)) ?? 0;
    if (millis <= 0) return Duration.zero;
    final saved = Duration(milliseconds: millis);
    final duration = effectiveDuration;
    if (duration > Duration.zero &&
        saved >= duration - const Duration(seconds: 3)) {
      return Duration.zero;
    }
    return saved;
  }

  Future<void> _persistProgressIfNeeded() async {
    final sec = currentPosition.inSeconds;
    if (sec <= 0) return;
    if ((sec - _lastSavedSecond).abs() < 5) return;
    _lastSavedSecond = sec;
    await _persistProgress();
  }

  Future<void> _persistProgress({bool force = false}) async {
    final episode = currentEpisode;
    if (episode == null) return;
    final prefs = await SharedPreferences.getInstance();
    final duration = effectiveDuration;
    final nearEnd = duration > Duration.zero &&
        currentPosition >= duration - const Duration(seconds: 3);
    if (!force && currentPosition <= Duration.zero) return;
    if (nearEnd) {
      await prefs.remove(_resumeKey(episode.mp3Url));
      return;
    }
    await prefs.setInt(
      _resumeKey(episode.mp3Url),
      currentPosition.inMilliseconds,
    );
  }

  Future<void> _clearSavedPositionForCurrent() async {
    final episode = currentEpisode;
    if (episode == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeKey(episode.mp3Url));
  }

  void _syncProgressTimer() {
    if (currentEpisode == null) {
      _progressTimer?.cancel();
      _progressTimer = null;
      return;
    }
    if (!isPlaying) return;
    _progressTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_pollProgress()),
    );
  }

  Future<void> _pollProgress() async {
    final handler = _handler;
    if (handler == null || currentEpisode == null) return;
    var position = handler.currentPositionValue;
    var duration = handler.currentDurationValue;
    if (position <= Duration.zero) {
      position = await handler.getCurrentPosition();
    }
    if (duration <= Duration.zero) {
      duration = await handler.getCurrentDuration();
    }
    var changed = false;
    if (position != currentPosition) {
      currentPosition = position;
      changed = true;
    }
    if (duration > Duration.zero && duration != totalDuration) {
      totalDuration = duration;
      changed = true;
    }
    if (changed) {
      await _persistProgressIfNeeded();
      notifyListeners();
    }
    if (!isPlaying) {
      _progressTimer?.cancel();
      _progressTimer = null;
    }
  }
}
