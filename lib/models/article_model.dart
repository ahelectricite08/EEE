import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleModel {
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

  bool get isDraft => status == 'draft';

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
  });

  factory ArticleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ArticleModel(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      category: d['category'] ?? 'ACTUS',
      date: (d['created_at'] as Timestamp).toDate(),
      imageUrl: d['imageUrl'],
      authorName: d['authorName'],
      featured: d['featured'] ?? false,
      status: d['status'] ?? 'published',
      images: List<String>.from(d['images'] ?? []),
    );
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
