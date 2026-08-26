import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/youtube_thumbnail.dart';

class VideoModel {
  final String id;
  final String title;
  final String youtubeId;
  final String? thumbnailUrl;
  final String duration; // ex: "12:34"
  final DateTime date;
  final String category;
  final int views;
  final bool isShort;
  final bool hidden;
  final bool pinned;
  final int durationSeconds;

  VideoModel({
    required this.id,
    required this.title,
    required this.youtubeId,
    this.thumbnailUrl,
    required this.duration,
    required this.date,
    required this.category,
    this.views = 0,
    this.isShort = false,
    this.hidden = false,
    this.pinned = false,
    this.durationSeconds = 0,
  });

  String get cleanId {
    final uri = Uri.tryParse(youtubeId);
    if (uri != null && uri.hasScheme) {
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      if (uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v']!;
      }
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments[0] == 'live' || uri.pathSegments[0] == 'shorts')) {
        return uri.pathSegments[1];
      }
    }
    return youtubeId;
  }

  String get youtubeThumbnail =>
      bestYoutubeThumbnailUrl(cleanId, stored: thumbnailUrl);

  int get resolvedDurationSeconds {
    if (durationSeconds > 0) return durationSeconds;
    return parseDurationSeconds(duration);
  }

  /// Short YouTube (playlist Shorts / ≤ 60 s) et non masqué.
  bool get isVisibleShort {
    if (hidden) return false;
    if (isShort || category == 'shorts') return true;
    final sec = resolvedDurationSeconds;
    return sec > 0 && sec <= 60;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'youtubeId': youtubeId,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'date': date.toIso8601String(),
        'category': category,
        'views': views,
        'isShort': isShort,
        'hidden': hidden,
        'pinned': pinned,
        'durationSeconds': durationSeconds,
      };

  factory VideoModel.fromJson(Map<String, dynamic> d) => VideoModel(
        id: d['id'] ?? '',
        title: d['title'] ?? '',
        youtubeId: d['youtubeId'] ?? '',
        thumbnailUrl: d['thumbnailUrl'],
        duration: d['duration'] ?? '',
        date: DateTime.parse(d['date']),
        category: d['category'] ?? '',
        views: d['views'] ?? 0,
        isShort: d['isShort'] == true,
        hidden: d['hidden'] == true,
        pinned: d['pinned'] == true,
        durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 0,
      );

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawDate = d['created_at'] ?? d['date'];
    final parsedDate = switch (rawDate) {
      Timestamp timestamp => timestamp.toDate(),
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };

    return VideoModel(
      id: doc.id,
      title: d['title'] ?? '',
      youtubeId: d['youtubeId'] ?? '',
      thumbnailUrl: d['thumbnailUrl'],
      duration: d['duration'] ?? '0:00',
      date: parsedDate,
      category: d['category'] ?? 'DVCR TV',
      views: (d['views'] as num?)?.toInt() ?? 0,
      isShort: d['isShort'] == true || d['category'] == 'shorts',
      hidden: d['hidden'] == true,
      pinned: d['pinned'] == true,
      durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  static int parseDurationSeconds(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final parts = t.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return 0;
  }

  static List<VideoModel> mock = [
    VideoModel(
      id: 'v1',
      title: 'Dans les coulisses de nos DERNIÈRES ANNONCES',
      youtubeId: 'dQw4w9WgXcQ',
      duration: '08:32',
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'COULISSES',
      views: 1240,
    ),
    VideoModel(
      id: 'v2',
      title: 'Résumé CSSA 3-1 Romans SC — Le match en vidéo',
      youtubeId: 'dQw4w9WgXcQ',
      duration: '05:14',
      date: DateTime.now().subtract(const Duration(days: 4)),
      category: 'RÉSULTATS',
      views: 3560,
    ),
    VideoModel(
      id: 'v3',
      title: 'Interview du capitaine avant le match de Valence',
      youtubeId: 'dQw4w9WgXcQ',
      duration: '03:47',
      date: DateTime.now().subtract(const Duration(days: 5)),
      category: 'INTERVIEW',
      views: 890,
    ),
    VideoModel(
      id: 'v4',
      title: 'Entraînement ouvert — Les images exclusives',
      youtubeId: 'dQw4w9WgXcQ',
      duration: '07:21',
      date: DateTime.now().subtract(const Duration(days: 7)),
      category: 'COULISSES',
      views: 2100,
    ),
  ];
}
