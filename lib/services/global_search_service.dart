import '../models/article_model.dart';
import '../models/match_model.dart';
import '../models/video_model.dart';
import 'article_service.dart';
import 'match_service.dart';
import 'youtube_playlist_service.dart';

enum SearchResultType { article, match, video }

class SearchResultItem {
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final DateTime? date;
  final String? imageUrl;
  final ArticleModel? article;
  final MatchModel? match;
  final VideoModel? video;

  const SearchResultItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.date,
    this.imageUrl,
    this.article,
    this.match,
    this.video,
  });
}

class GlobalSearchPayload {
  final List<ArticleModel> articles;
  final List<MatchModel> matches;
  final List<VideoModel> videos;

  const GlobalSearchPayload({
    required this.articles,
    required this.matches,
    required this.videos,
  });
}

class GlobalSearchService {
  static Future<GlobalSearchPayload> load() async {
    final results = await Future.wait([
      ArticleService.fetchAllPublished(limit: 60),
      MatchService.fetchSearchableMatches(limit: 60),
      YoutubePlaylistService.getAll(),
    ]);
    return GlobalSearchPayload(
      articles: results[0] as List<ArticleModel>,
      matches: results[1] as List<MatchModel>,
      videos: results[2] as List<VideoModel>,
    );
  }

  static List<SearchResultItem> search(
    GlobalSearchPayload payload,
    String query,
  ) {
    final cleaned = _normalize(query);
    if (cleaned.isEmpty) return const [];

    final items = <SearchResultItem>[
      ...payload.articles
          .where((article) => _articleHaystack(article).contains(cleaned))
          .map(
            (article) => SearchResultItem(
              type: SearchResultType.article,
              id: article.id,
              title: article.title,
              subtitle: article.categoryForShare,
              meta: article.authorName ?? 'Redaction DVCR',
              date: article.date,
              imageUrl: article.imageUrl,
              article: article,
            ),
          ),
      ...payload.matches
          .where((match) => _matchHaystack(match).contains(cleaned))
          .map(
            (match) => SearchResultItem(
              type: SearchResultType.match,
              id: match.id,
              title: '${match.team1} vs ${match.team2}',
              subtitle: match.competition,
              meta: match.status.name,
              date: match.date,
              match: match,
            ),
          ),
      ...payload.videos
          .where((video) => _videoHaystack(video).contains(cleaned))
          .map(
            (video) => SearchResultItem(
              type: SearchResultType.video,
              id: video.id,
              title: video.title,
              subtitle: video.category,
              meta: video.duration.isEmpty ? 'DVCR TV' : video.duration,
              date: video.date,
              imageUrl: video.youtubeThumbnail,
              video: video,
            ),
          ),
    ];

    items.sort((a, b) {
      final scoreB = _scoreFor(cleaned, b);
      final scoreA = _scoreFor(cleaned, a);
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      final dateA = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return items.take(30).toList();
  }

  static int _scoreFor(String query, SearchResultItem item) {
    final title = _normalize(item.title);
    final subtitle = _normalize(item.subtitle);
    if (title.startsWith(query)) return 300;
    if (title.contains(query)) return 200;
    if (subtitle.contains(query)) return 120;
    return 60;
  }

  static String _articleHaystack(ArticleModel article) {
    final body = (article.contentHtml != null &&
            article.contentHtml!.length > 80)
        ? article.contentHtml!.replaceAll(RegExp(r'<[^>]+>'), ' ')
        : article.content;
    return _normalize(
      '${article.title} $body ${article.category} ${article.authorName ?? ''}',
    );
  }

  static String _matchHaystack(MatchModel match) {
    return _normalize(
      '${match.team1} ${match.team2} ${match.competition} ${match.status.name}',
    );
  }

  static String _videoHaystack(VideoModel video) {
    return _normalize('${video.title} ${video.category}');
  }

  static String _normalize(String input) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
      'ç': 'c',
    };
    var result = input.toLowerCase();
    accents.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }
}
