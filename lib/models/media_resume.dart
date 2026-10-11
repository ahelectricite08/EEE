import 'video_model.dart';

enum MediaResumeKind { video, podcast }

/// Progression locale VOD / podcast — un média se reprend, il ne repart pas à 0:00.
class MediaResumeItem {
  final MediaResumeKind kind;
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int positionMs;
  final int durationMs;
  final int updatedAtMs;
  final String? videoDocId;
  final String? category;
  final String? durationLabel;
  final String? dateIso;

  const MediaResumeItem({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAtMs,
    this.videoDocId,
    this.category,
    this.durationLabel,
    this.dateIso,
  });

  String get key => '${kind.name}:$id';

  double get fraction {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);

  bool get isVideo => kind == MediaResumeKind.video;
  bool get isPodcast => kind == MediaResumeKind.podcast;

  factory MediaResumeItem.video({
    required String youtubeId,
    required String title,
    required Duration position,
    required Duration duration,
    VideoModel? video,
    int? updatedAtMs,
  }) {
    return MediaResumeItem(
      kind: MediaResumeKind.video,
      id: youtubeId.trim(),
      title: title.trim(),
      subtitle: video?.category,
      imageUrl: video?.youtubeThumbnail,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      videoDocId: video?.id,
      category: video?.category,
      durationLabel: video?.duration,
      dateIso: video?.date.toIso8601String(),
    );
  }

  factory MediaResumeItem.podcast({
    required String mp3Url,
    required String title,
    required Duration position,
    required Duration duration,
    String? durationLabel,
    int? updatedAtMs,
  }) {
    return MediaResumeItem(
      kind: MediaResumeKind.podcast,
      id: mp3Url.trim(),
      title: title.trim(),
      subtitle: 'Podcast',
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      durationLabel: durationLabel,
    );
  }

  VideoModel? get asVideo {
    if (!isVideo || id.isEmpty) return null;
    DateTime date = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    final parsed = DateTime.tryParse(dateIso ?? '');
    if (parsed != null) date = parsed;
    return VideoModel(
      id: (videoDocId ?? id).trim().isEmpty ? id : (videoDocId ?? id),
      title: title,
      youtubeId: id,
      thumbnailUrl: imageUrl,
      duration: durationLabel ?? MediaResumeLabels.clock(duration),
      date: date,
      category: category ?? '',
      durationSeconds: durationMs > 0 ? (durationMs / 1000).round() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAtMs': updatedAtMs,
        'videoDocId': videoDocId,
        'category': category,
        'durationLabel': durationLabel,
        'dateIso': dateIso,
      };

  factory MediaResumeItem.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] ?? '').toString();
    final kind = kindRaw == MediaResumeKind.podcast.name
        ? MediaResumeKind.podcast
        : MediaResumeKind.video;
    return MediaResumeItem(
      kind: kind,
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      videoDocId: json['videoDocId']?.toString(),
      category: json['category']?.toString(),
      durationLabel: json['durationLabel']?.toString(),
      dateIso: json['dateIso']?.toString(),
    );
  }
}

abstract final class MediaResumeRules {
  static const int minWatchMs = 15000;
  static const int nearEndMs = 12000;
  static const double nearEndFraction = 0.95;
  static const int maxItems = 20;
  static const int minDurationMs = 90 * 1000;

  static bool eligibleDuration({
    required int durationMs,
    bool isShort = false,
  }) {
    if (isShort) return false;
    if (durationMs > 0 && durationMs < minDurationMs) return false;
    return true;
  }

  static bool shouldKeep(MediaResumeItem item, {bool isShort = false}) {
    if (item.id.isEmpty || item.title.isEmpty) return false;
    if (!eligibleDuration(durationMs: item.durationMs, isShort: isShort)) {
      return false;
    }
    if (item.positionMs < minWatchMs) return false;
    if (item.durationMs >= minWatchMs) {
      final remaining = item.durationMs - item.positionMs;
      if (remaining <= nearEndMs) return false;
      if (item.positionMs / item.durationMs >= nearEndFraction) return false;
    }
    return true;
  }

  static List<MediaResumeItem> upsert(
    List<MediaResumeItem> current,
    MediaResumeItem next, {
    bool isShort = false,
  }) {
    final without = current.where((e) => e.key != next.key).toList();
    if (!shouldKeep(next, isShort: isShort)) return without;
    return [next, ...without].take(maxItems).toList();
  }

  static List<MediaResumeItem> remove(
    List<MediaResumeItem> current, {
    required MediaResumeKind kind,
    required String id,
  }) {
    final key = '${kind.name}:$id';
    return current.where((e) => e.key != key).toList();
  }
}

abstract final class MediaResumeLabels {
  static String clock(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 99 * 3600);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String remaining(int positionMs, int durationMs) {
    if (durationMs <= 0) return 'Reprendre';
    final leftMs = durationMs - positionMs;
    if (leftMs <= 0) return 'Reprendre';
    final left = Duration(milliseconds: leftMs);
    if (left.inHours >= 1) {
      final min = left.inMinutes.remainder(60);
      if (min == 0) return 'Plus que ${left.inHours} h';
      return 'Plus que ${left.inHours} h $min min';
    }
    if (left.inMinutes >= 1) return 'Plus que ${left.inMinutes} min';
    return 'Plus que ${left.inSeconds} s';
  }

  static String resumeAt(int positionMs) {
    if (positionMs <= 0) return 'Reprendre';
    return 'Reprendre à ${clock(Duration(milliseconds: positionMs))}';
  }
}
