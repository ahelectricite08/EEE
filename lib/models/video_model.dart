import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String title;
  final String youtubeId;
  final String? thumbnailUrl;
  final String duration; // ex: "12:34"
  final DateTime date;
  final String category;
  final int views;

  VideoModel({
    required this.id,
    required this.title,
    required this.youtubeId,
    this.thumbnailUrl,
    required this.duration,
    required this.date,
    required this.category,
    this.views = 0,
  });

  String get cleanId {
    final uri = Uri.tryParse(youtubeId);
    if (uri != null && uri.hasScheme) {
      // https://youtu.be/ID
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      // https://youtube.com/watch?v=ID
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      // https://youtube.com/live/ID ou https://youtube.com/shorts/ID
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments[0] == 'live' || uri.pathSegments[0] == 'shorts')) {
        return uri.pathSegments[1];
      }
    }
    return youtubeId;
  }

  String get youtubeThumbnail =>
      thumbnailUrl ?? 'https://img.youtube.com/vi/$cleanId/mqdefault.jpg';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'youtubeId': youtubeId,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'date': date.toIso8601String(),
    'category': category,
    'views': views,
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
  );

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      title: d['title'] ?? '',
      youtubeId: d['youtubeId'] ?? '',
      thumbnailUrl: d['thumbnailUrl'],
      duration: d['duration'] ?? '0:00',
      date: (d['created_at'] as Timestamp).toDate(),
      category: d['category'] ?? 'DVCR TV',
      views: d['views'] ?? 0,
    );
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
