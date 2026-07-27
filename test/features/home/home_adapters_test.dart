import 'package:dvcr/features/home/data/adapters/home_articles_feed_adapter.dart';
import 'package:dvcr/features/home/data/adapters/home_live_hub_adapter.dart';
import 'package:dvcr/features/home/data/adapters/home_match_catalog_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home hub adapters construct without throwing', () {
    expect(const HomeLiveHubAdapter(), isA<HomeLiveHubAdapter>());
    expect(const HomeMatchCatalogAdapter(), isA<HomeMatchCatalogAdapter>());
    expect(const HomeArticlesFeedAdapter(), isA<HomeArticlesFeedAdapter>());
  });
}
