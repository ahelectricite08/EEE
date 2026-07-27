import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/adapters/home_articles_feed_adapter.dart';
import '../data/adapters/home_live_hub_adapter.dart';
import '../data/adapters/home_match_catalog_adapter.dart';
import '../data/datasources/home_banner_datasource.dart';
import '../data/datasources/home_match_lookup_datasource.dart';
import '../data/datasources/home_prediction_datasource.dart';
import '../data/datasources/home_prono_leaderboard_datasource.dart';
import '../data/datasources/home_sections_datasource.dart';
import '../data/datasources/home_stadium_datasource.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/entities/home_layout_hints.dart';
import '../domain/entities/home_sections_config.dart';
import '../domain/repositories/home_repository.dart';
import '../domain/usecases/clear_podcast_next_event.dart';
import '../domain/usecases/set_podcast_next_event.dart';

final homeSectionsDatasourceProvider = Provider<HomeSectionsDatasource>((ref) {
  return HomeSectionsDatasource();
});

final homeBannerDatasourceProvider = Provider<HomeBannerDatasource>((ref) {
  return HomeBannerDatasource();
});

final homeStadiumDatasourceProvider = Provider<HomeStadiumDatasource>((ref) {
  return HomeStadiumDatasource();
});

final homeMatchLookupDatasourceProvider =
    Provider<HomeMatchLookupDatasource>((ref) {
  return HomeMatchLookupDatasource();
});

final homePredictionDatasourceProvider = Provider<HomePredictionDatasource>((ref) {
  return HomePredictionDatasource();
});

final homePronoLeaderboardDatasourceProvider =
    Provider<HomePronoLeaderboardDatasource>((ref) {
  return HomePronoLeaderboardDatasource();
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(
    sectionsDatasource: ref.watch(homeSectionsDatasourceProvider),
    bannerDatasource: ref.watch(homeBannerDatasourceProvider),
  );
});

final setPodcastNextEventProvider = Provider<SetPodcastNextEvent>((ref) {
  return SetPodcastNextEvent(ref.watch(homeRepositoryProvider));
});

final clearPodcastNextEventProvider = Provider<ClearPodcastNextEvent>((ref) {
  return ClearPodcastNextEvent(ref.watch(homeRepositoryProvider));
});

final homeLayoutHintsProvider = StreamProvider<HomeLayoutHints>((ref) {
  return ref.watch(homeRepositoryProvider).watchLayoutHints();
});

final homeSectionsConfigProvider = StreamProvider<HomeSectionsConfig>((ref) {
  return ref.watch(homeRepositoryProvider).watchSectionsConfig();
});

final homeBannerPhotoUrlProvider = StreamProvider<String?>((ref) {
  return ref.watch(homeRepositoryProvider).watchBannerPhotoUrl();
});

final homeLiveHubAdapterProvider = Provider<HomeLiveHubAdapter>((ref) {
  return const HomeLiveHubAdapter();
});

final homeMatchCatalogAdapterProvider = Provider<HomeMatchCatalogAdapter>((ref) {
  return const HomeMatchCatalogAdapter();
});

final homeArticlesFeedAdapterProvider = Provider<HomeArticlesFeedAdapter>((ref) {
  return const HomeArticlesFeedAdapter();
});
