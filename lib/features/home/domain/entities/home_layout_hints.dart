import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_layout_hints.freezed.dart';

/// Display preferences for home blocks while any live is on.
@freezed
class HomeLayoutHints with _$HomeLayoutHints {
  const factory HomeLayoutHints({
    @Default(false) bool hideDonationBannerWhenAnyLive,
    @Default(false) bool hidePodcastBlockWhenAnyLive,
    @Default(false) bool hideDvcrTvBlockWhenAnyLive,
  }) = _HomeLayoutHints;

  /// Same defaults as legacy `HomeLayoutHints.defaults`.
  static const HomeLayoutHints defaults = HomeLayoutHints();
}
