import 'package:dvcr/features/home/data/datasources/home_banner_datasource.dart';
import 'package:dvcr/features/home/data/datasources/home_sections_datasource.dart';
import 'package:dvcr/features/home/data/repositories/home_repository_impl.dart';
import 'package:dvcr/features/home/domain/entities/home_layout_hints.dart';
import 'package:dvcr/features/home/domain/repositories/home_repository.dart';

export 'package:dvcr/features/home/domain/entities/home_layout_hints.dart'
    show HomeLayoutHints;

/// Legacy static façade over [HomeRepositoryImpl] (sections only).
///
/// **Dette acceptée (Home 2026-07-26):** new code should use
/// `package:dvcr/features/home/home.dart` providers. This façade keeps
/// call sites compiling until consumers migrate.
class HomeSectionsService {
  static final HomeSectionsDatasource _sections = HomeSectionsDatasource();
  static final HomeRepository _repository = HomeRepositoryImpl(
    sectionsDatasource: _sections,
    bannerDatasource: HomeBannerDatasource(),
  );

  static Stream<Map<String, dynamic>> stream() => _sections.watchRaw();

  static Stream<HomeLayoutHints> layoutHintsStream() {
    return _repository.watchLayoutHints();
  }

  static Future<void> setPodcastNextEvent(DateTime dateTime) async {
    final result = await _repository.setPodcastNextEvent(dateTime);
    result.when(
      success: (_) {},
      failure: (e) => throw e,
    );
  }

  static Future<void> clearPodcastNextEvent() async {
    final result = await _repository.clearPodcastNextEvent();
    result.when(
      success: (_) {},
      failure: (e) => throw e,
    );
  }
}
