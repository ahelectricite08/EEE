import 'package:freezed_annotation/freezed_annotation.dart';

import 'home_layout_hints.dart';

part 'home_sections_config.freezed.dart';

/// `config/home_sections` domain snapshot (podcast rendez-vous + layout hints).
@freezed
class HomeSectionsConfig with _$HomeSectionsConfig {
  const factory HomeSectionsConfig({
    DateTime? podcastNextEventAt,
    @Default(HomeLayoutHints()) HomeLayoutHints layoutHints,
  }) = _HomeSectionsConfig;

  static const HomeSectionsConfig defaults = HomeSectionsConfig();
}
