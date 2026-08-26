import 'package:flutter_test/flutter_test.dart';
import 'package:dvcr/models/article_model.dart';

void main() {
  test('refuse la home DVCR comme URL d’article', () {
    expect(ArticleModel.isWixArticlePageUrl('https://www.dvcr.fr'), isFalse);
    expect(ArticleModel.isWixArticlePageUrl('https://www.dvcr.fr/'), isFalse);
    expect(
      ArticleModel.isWixArticlePageUrl('https://www.dvcr.fr/post/victoire-3-1'),
      isTrue,
    );
  });

  test('HTML de home (plusieurs /post/) n’est pas affichable', () {
    const home = '''
      <a href="/post/a">a</a>
      <a href="/post/b">b</a>
      <a href="https://www.dvcr.fr/post/c">c</a>
      <a href="/post/d">d</a>
      <p>Accueil DVCR</p>
    ''';
    expect(ArticleModel.htmlLooksLikeSiteHome(home), isTrue);
    final article = ArticleModel(
      id: 'wix_x',
      title: 'Test',
      content:
          'Le vrai chapô envoyé par Wix, avec assez de texte et le contexte du match pour le rendu natif dans l’app.',
      category: 'CLUB',
      date: DateTime(2026, 1, 1),
      wixUrl: 'https://www.dvcr.fr',
      contentHtml: home,
    );
    expect(article.hasDisplayableContentHtml, isFalse);
    expect(article.hasOpenableWixArticleUrl, isFalse);
    expect(article.hasDisplayablePlainContent, isTrue);
  });
}
