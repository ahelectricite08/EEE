/// Home hub adapter → legacy [ArticleService] (Articles hors périmètre Home).
library;

import 'package:dvcr/models/article_model.dart';
import 'package:dvcr/services/article_service.dart';

class HomeArticlesFeedAdapter {
  const HomeArticlesFeedAdapter();
  Stream<List<ArticleModel>> watchPublished({String? category, int limit = 20}) {
    return ArticleService.all(category: category, limit: limit);
  }
}
