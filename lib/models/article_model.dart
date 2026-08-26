import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleModel {
  /// Catégorie Firestore réservée : article uniquement dans le filtre « TOUT » (pas de catégorie Wix reconnue).
  static const String kUncategorizedToutOnly = 'UNCATEGORIZED_TOUT';

  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime date;
  final String? imageUrl;
  final String? authorName;
  final bool featured;
  final String status; // 'published' | 'draft'
  final List<String> images; // photos dans l'article (URLs Wix)
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy;
  final String? wixUrl;

  /// HTML du corps (sync serveur depuis la page Wix) — affichage in-app sans WebView.
  final String? contentHtml;

  /// Chapô Wix (`excerpt` / `description`) — distinct du corps.
  final String? excerpt;

  /// Tags / labels Wix (hors catégorie mappée).
  final List<String> tags;

  /// Première vidéo Wix (YouTube / Vimeo / URL) si le payload ou la page en a une.
  final String? videoUrl;

  bool get isDraft => status == 'draft';
  bool get isWixArticle => wixUrl != null && wixUrl!.isNotEmpty;

  /// Lien « ouvrir sur le site » : uniquement un billet `/post/…`, jamais la home.
  bool get hasOpenableWixArticleUrl => isWixArticlePageUrl(wixUrl);

  static bool isWixArticlePageUrl(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return false;
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final path = uri.path;
    if (RegExp(r'/post/[^/]+', caseSensitive: false).hasMatch(path)) {
      return true;
    }
    return RegExp(r'/blog/[^/]+', caseSensitive: false).hasMatch(path) &&
        !RegExp(r'/blog/?$', caseSensitive: false).hasMatch(path);
  }

  static bool htmlLooksLikeSiteHome(String? html) {
    final h = html ?? '';
    if (h.isEmpty) return false;
    return RegExp(
          r'''href\s*=\s*['"][^'"]*/post/''',
          caseSensitive: false,
        ).allMatches(h).length >=
        4;
  }

  bool get isUncategorizedToutOnly => category == kUncategorizedToutOnly;

  /// Libellé vide si l’article n’est dans aucun onglet de catégorie (affiche seulement sous « TOUT »).
  String get displayCategoryLabel =>
      isUncategorizedToutOnly ? '' : category;

  /// Libellé lisible pour partage / sous-titres (remplace le sentinelle par « Actus »).
  String get categoryForShare =>
      isUncategorizedToutOnly ? 'Actus' : category;

  /// Assez de texte extrait du HTML pour afficher l’article en natif (évite WebView).
  bool get hasDisplayableContentHtml {
    final h = contentHtml?.trim();
    if (h == null || h.isEmpty) return false;
    if (htmlLooksLikeSiteHome(h)) return false;
    final textLen = h.replaceAll(RegExp('<[^>]*>'), '').length;
    return textLen >= 180;
  }

  /// Texte / photos du payload — à afficher plutôt qu’une WebView dvcr.fr.
  bool get hasDisplayablePlainContent {
    final raw = content
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.length >= 80 && raw != title.trim()) return true;
    if (images.isNotEmpty && raw.isNotEmpty && raw != title.trim()) return true;
    return false;
  }

  ArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    this.imageUrl,
    this.authorName,
    this.featured = false,
    this.status = 'published',
    this.images = const [],
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
    this.wixUrl,
    this.contentHtml,
    this.excerpt,
    this.tags = const [],
    this.videoUrl,
  });

  /// Texte d’accroche : chapô Wix, sinon début du corps (sans HTML).
  String get teaser {
    final e = (excerpt ?? '').trim();
    if (e.length >= 24) return e;
    final raw = content.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.length <= 180) return raw;
    return '${raw.substring(0, 180).trimRight()}…';
  }

  bool get hasTeaser => teaser.trim().isNotEmpty && teaser.trim() != title.trim();

  List<String> get galleryImages {
    final cover = (imageUrl ?? '').trim();
    final seen = <String>{};
    final out = <String>[];
    for (final raw in images) {
      final u = raw.trim();
      if (u.isEmpty || u == cover || seen.contains(u)) continue;
      seen.add(u);
      out.add(u);
    }
    return out;
  }

  /// ~200 mots / min, depuis le HTML Wix si assez riche, sinon le texte stocké.
  int get estimatedReadingMinutes {
    final html = (contentHtml ?? '').trim();
    String text;
    if (html.isNotEmpty) {
      text = html
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ');
    } else {
      text = content;
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words == 0) return 1;
    return ((words / 200).ceil()).clamp(1, 99);
  }

  factory ArticleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime parseDate() {
      final c = d['created_at'];
      if (c is Timestamp) return c.toDate();
      final u = d['updated_at'];
      if (u is Timestamp) return u.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ArticleModel(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      category: d['category'] ?? 'ACTUS',
      date: parseDate(),
      imageUrl: d['imageUrl'],
      authorName: d['authorName'],
      featured: d['featured'] ?? false,
      status: d['status'] ?? 'published',
      images: List<String>.from(d['images'] ?? []),
      viewsCount: (d['viewsCount'] as num?)?.toInt() ?? 0,
      likesCount: (d['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (d['commentsCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(d['likedBy'] ?? const []),
      wixUrl: d['wixUrl'] as String?,
      contentHtml: d['contentHtml'] as String?,
      excerpt: (d['excerpt'] as String?)?.trim().isNotEmpty == true
          ? (d['excerpt'] as String).trim()
          : null,
      tags: _stringList(d['tags']),
      videoUrl: (d['videoUrl'] as String?)?.trim().isNotEmpty == true
          ? (d['videoUrl'] as String).trim()
          : null,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      final s = item is String
          ? item.trim()
          : (item is Map
              ? '${item['name'] ?? item['label'] ?? item['title'] ?? ''}'.trim()
              : '');
      if (s.isEmpty || out.contains(s)) continue;
      out.add(s);
    }
    return out;
  }

  static List<ArticleModel> mock = [
    ArticleModel(
      id: 'a1',
      title: 'Victoire 3-1 face à Romans SC : retour sur le match',
      content:
          'Une belle victoire ce weekend pour la CSSA qui s\'impose 3 buts à 1 face à Romans SC. Un match maîtrisé de bout en bout avec un premier but de Dupont à la 12e minute...',
      category: 'RÉSULTATS',
      date: DateTime.now().subtract(const Duration(days: 1)),
      authorName: 'Rédaction DVCR',
      featured: true,
    ),
    ArticleModel(
      id: 'a2',
      title: 'Prochaine sortie : déplacement à Valence FC jeudi soir',
      content:
          'La CSSA se déplace à Valence jeudi prochain pour un match décisif dans la course au titre. Coup d\'envoi à 20h30...',
      category: 'FOOTBALL',
      date: DateTime.now().subtract(const Duration(days: 2)),
      authorName: 'Rédaction DVCR',
    ),
    ArticleModel(
      id: 'a3',
      title: 'Interview : Martin, capitaine depuis 5 ans',
      content:
          'On a rencontré Martin, capitaine de la CSSA depuis 5 saisons. Il nous parle de ses ambitions pour la fin de saison et du projet du club...',
      category: 'INTERVIEW',
      date: DateTime.now().subtract(const Duration(days: 4)),
      authorName: 'Rédaction DVCR',
    ),
    ArticleModel(
      id: 'a4',
      title: 'Analyse : les clés tactiques du coach pour les playoffs',
      content:
          'Après plusieurs semaines d\'observation, notre analyste décortique la tactique mise en place par le coach pour aborder les phases finales...',
      category: 'ANALYSE',
      date: DateTime.now().subtract(const Duration(days: 6)),
      authorName: 'Rédaction DVCR',
    ),
    ArticleModel(
      id: 'a5',
      title: 'Coulisses de l\'entraînement : la semaine en images',
      content:
          'Plongez dans les coulisses de la semaine d\'entraînement de la CSSA. Photos, vidéos, et anecdotes de nos journalistes présents...',
      category: 'COULISSES',
      date: DateTime.now().subtract(const Duration(days: 8)),
      authorName: 'Rédaction DVCR',
    ),
  ];
}
