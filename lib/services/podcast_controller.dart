import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PodcastEpisode {
  final String title;
  final String duration;
  final DateTime pubDate;
  final String mp3Url;
  PodcastEpisode({required this.title, required this.duration, required this.pubDate, required this.mp3Url});
}

// ── AudioHandler pour les notifications système ────────────────────────────────
class _DVCRAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  _DVCRAudioHandler() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.ready,
        playing: playing,
      ));
    });
    _player.onPlayerComplete.listen((_) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
      ));
    });
  }

  Future<void> playUrl(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.play(UrlSource(url));
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  bool get isPlaying => _player.state == PlayerState.playing;
}

// ── Controller singleton ───────────────────────────────────────────────────────
class PodcastController extends ChangeNotifier {
  static final PodcastController instance = PodcastController._internal();
  PodcastController._internal();

  _DVCRAudioHandler? _handler;
  List<PodcastEpisode> episodes = [];
  int? currentIndex;
  bool isPlaying = false;
  bool isLoading = true;

  static const _rss = 'https://feeds.soundcloud.com/users/soundcloud:users:1150891726/sounds.rss';

  Future<void> init() async {
    _handler = await AudioService.init(
      builder: () => _DVCRAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.dvcr.podcast',
        androidNotificationChannelName: 'DVCR Podcast',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    _handler!.playbackState.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });
    fetchRss();
  }

  Future<void> fetchRss() async {
    try {
      final res = await http.get(Uri.parse(_rss));
      if (res.statusCode != 200) { isLoading = false; notifyListeners(); return; }
      final body = res.body;
      final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(body);
      final list = <PodcastEpisode>[];
      for (final m in items.take(8)) {
        final item = m.group(1)!;
        final title = _tag(item, 'title');
        final dur   = _tag(item, 'itunes:duration');
        final pub   = _tag(item, 'pubDate');
        final mp3   = RegExp(r'<enclosure[^>]+url="([^"]+)"').firstMatch(item)?.group(1) ?? '';
        if (title.isEmpty || mp3.isEmpty) continue;
        DateTime date;
        try { date = _parseRssDate(pub); } catch (_) { date = DateTime.now(); }
        list.add(PodcastEpisode(title: title, duration: dur, pubDate: date, mp3Url: mp3));
      }
      episodes = list;
    } catch (_) {}
    isLoading = false;
    notifyListeners();
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
    } else {
      currentIndex = index;
      notifyListeners();
      await _handler!.playUrl(
        ep.mp3Url,
        MediaItem(
          id: ep.mp3Url,
          title: ep.title,
          artist: 'DVCR Podcast',
          duration: _parseDuration(ep.duration),
          artUri: Uri.parse('https://i1.sndcdn.com/avatars-000000000000-000000-t500x500.jpg'),
        ),
      );
    }
  }

  Future<void> pause() => _handler?.pause() ?? Future.value();
  Future<void> resume() => _handler?.play() ?? Future.value();

  Future<void> dismiss() async {
    await _handler?.stop();
    currentIndex = null;
    notifyListeners();
  }

  PodcastEpisode? get currentEpisode =>
      currentIndex != null && currentIndex! < episodes.length ? episodes[currentIndex!] : null;

  String _tag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></$tag>|<$tag[^>]*>([^<]*)</$tag>').firstMatch(xml);
    return (m?.group(1) ?? m?.group(2) ?? '').trim();
  }

  DateTime _parseRssDate(String s) {
    const months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
    final parts = s.trim().split(' ');
    return DateTime(int.parse(parts[3]), months[parts[2]] ?? 1, int.parse(parts[1]));
  }

  Duration? _parseDuration(String s) {
    try {
      final parts = s.split(':').map(int.parse).toList();
      if (parts.length == 3) return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
    } catch (_) {}
    return null;
  }
}
