import 'package:dvcr/screens/matches/match_tv_broadcast.dart';
import 'package:dvcr/screens/social/social_links_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV row always shows YouTube, Facebook and Twitch logos', () {
    final tv = MatchTvBroadcast.row(SocialLinksOverlay.empty.resolveAll());
    expect(tv.map((s) => s.id), ['youtube', 'facebook', 'twitch']);
  });

  test('TV openable links use club social URLs, not per-match links', () {
    final visible = SocialLinksOverlay.empty.resolve();
    final tv = MatchTvBroadcast.platforms(visible);
    expect(tv.map((s) => s.id), ['youtube', 'facebook']);
    expect(tv.every((s) => s.url.startsWith('http')), isTrue);
  });

  test('empty twitch still keeps the logo on the match sheet', () {
    final overlay = SocialLinksOverlay.fromMaps([
      {
        'twitch': {'url': '', 'enabled': true},
      },
    ]);
    expect(MatchTvBroadcast.row(overlay.resolveAll()).map((s) => s.id),
        ['youtube', 'facebook', 'twitch']);
    expect(MatchTvBroadcast.platforms(overlay.resolve()).map((s) => s.id),
        ['youtube', 'facebook']);
  });

  test('twitch from NOS RÉSEAUX overlay is openable', () {
    final overlay = SocialLinksOverlay.fromMaps([
      {
        'twitch': {
          'url': 'https://www.twitch.tv/drapeauvertcartonrouge',
          'enabled': true,
        },
      },
    ]);
    expect(
      MatchTvBroadcast.platforms(overlay.resolve()).map((s) => s.id),
      ['youtube', 'facebook', 'twitch'],
    );
  });
}
