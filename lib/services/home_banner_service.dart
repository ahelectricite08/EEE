import 'dart:typed_data';

import 'package:dvcr/features/home/data/datasources/home_banner_datasource.dart';
import 'package:dvcr/features/home/data/datasources/home_sections_datasource.dart';
import 'package:dvcr/features/home/data/repositories/home_repository_impl.dart';
import 'package:dvcr/features/home/domain/repositories/home_repository.dart';

/// Legacy static façade over [HomeRepositoryImpl] (banner only).
///
/// **Dette acceptée (Home 2026-07-26):** admin settings still call this;
/// Accueil uses `homeBannerPhotoUrlProvider`.
class HomeBannerService {
  HomeBannerService._();

  static final HomeRepository _repository = HomeRepositoryImpl(
    sectionsDatasource: HomeSectionsDatasource(),
    bannerDatasource: HomeBannerDatasource(),
  );

  /// Stream de l'URL courante (null = utiliser l'asset par défaut).
  static Stream<String?> photoUrlStream() =>
      _repository.watchBannerPhotoUrl();

  /// Télécharge une image et enregistre son URL dans Firestore.
  static Future<String> uploadPhoto(
    Uint8List bytes,
    String extension,
  ) async {
    final result = await _repository.uploadBannerPhoto(
      bytes: bytes,
      extension: extension,
    );
    return result.when(
      success: (url) => url,
      failure: (e) => throw e,
    );
  }

  /// Remet la photo par défaut (asset local).
  static Future<void> clearPhoto() async {
    final result = await _repository.clearBannerPhoto();
    result.when(
      success: (_) {},
      failure: (e) => throw e,
    );
  }
}
