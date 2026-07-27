import 'dart:typed_data';

import 'package:dvcr/core/core.dart';

import '../../domain/entities/home_layout_hints.dart';
import '../../domain/entities/home_sections_config.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_banner_datasource.dart';
import '../datasources/home_sections_datasource.dart';
import '../mappers/home_sections_mapper.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({
    required HomeSectionsDatasource sectionsDatasource,
    required HomeBannerDatasource bannerDatasource,
  })  : _sections = sectionsDatasource,
        _banner = bannerDatasource;

  final HomeSectionsDatasource _sections;
  final HomeBannerDatasource _banner;

  @override
  Stream<HomeLayoutHints> watchLayoutHints() {
    return _sections.watchRaw().map(homeLayoutHintsFromMap);
  }

  @override
  Stream<HomeSectionsConfig> watchSectionsConfig() {
    return _sections.watchRaw().map(homeSectionsConfigFromMap);
  }

  @override
  Stream<String?> watchBannerPhotoUrl() => _banner.watchPhotoUrl();

  @override
  Future<Result<void>> setPodcastNextEvent(DateTime dateTime) async {
    try {
      await _sections.setPodcastNextEvent(dateTime);
      return const Success(null);
    } catch (e) {
      return Failure(UnexpectedFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> clearPodcastNextEvent() async {
    try {
      await _sections.clearPodcastNextEvent();
      return const Success(null);
    } catch (e) {
      return Failure(UnexpectedFailure(cause: e));
    }
  }

  @override
  Future<Result<String>> uploadBannerPhoto({
    required Uint8List bytes,
    required String extension,
  }) async {
    try {
      final url = await _banner.uploadPhoto(
        bytes: bytes,
        extension: extension,
      );
      return Success(url);
    } catch (e) {
      return Failure(UnexpectedFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> clearBannerPhoto() async {
    try {
      await _banner.clearPhoto();
      return const Success(null);
    } catch (e) {
      return Failure(UnexpectedFailure(cause: e));
    }
  }
}
