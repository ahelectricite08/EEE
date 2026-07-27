import 'dart:typed_data';

import 'package:dvcr/core/core.dart';

import '../entities/home_layout_hints.dart';
import '../entities/home_sections_config.dart';

/// Home-owned config port (sections + hero banner).
///
/// Live / matches / articles stay outside this module (composition debt).
abstract class HomeRepository {
  Stream<HomeLayoutHints> watchLayoutHints();

  Stream<HomeSectionsConfig> watchSectionsConfig();

  Stream<String?> watchBannerPhotoUrl();

  Future<Result<void>> setPodcastNextEvent(DateTime dateTime);

  Future<Result<void>> clearPodcastNextEvent();

  Future<Result<String>> uploadBannerPhoto({
    required Uint8List bytes,
    required String extension,
  });

  Future<Result<void>> clearBannerPhoto();
}
