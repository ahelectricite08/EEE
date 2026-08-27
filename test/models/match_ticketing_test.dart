import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/match_ticketing.dart';
import 'package:dvcr/screens/matches/matches_helpers.dart';

void main() {
  test('MatchTicketing doc id is stable and hidden by default', () {
    expect(MatchTicketing.firestoreDocId, 'match_ticketing');
    expect(MatchTicketing.defaults.enabled, isFalse);
    expect(MatchTicketing.defaults.showOnHome, isFalse);
  });

  test('showOnHome requires switch ON and http(s) URL', () {
    expect(
      MatchTicketing.fromMap({
        'enabled': true,
        'url': ' https://billets.example/match ',
      }).showOnHome,
      isTrue,
    );
    expect(
      MatchTicketing.fromMap({
        'enabled': false,
        'url': 'https://billets.example/match',
      }).showOnHome,
      isFalse,
    );
    expect(
      MatchTicketing.fromMap({
        'enabled': true,
        'url': '',
      }).showOnHome,
      isFalse,
    );
    expect(
      MatchTicketing.fromMap({
        'enabled': true,
        'url': 'billets.example',
      }).showOnHome,
      isFalse,
    );
  });

  test('visibleOnHome also requires Sedan domicile', () {
    final on = MatchTicketing.fromMap({
      'enabled': true,
      'url': 'https://billets.example/match',
    });
    expect(on.visibleOnHome(sedanIsHome: true), isTrue);
    expect(on.visibleOnHome(sedanIsHome: false), isFalse);

    final off = MatchTicketing.fromMap({
      'enabled': false,
      'url': 'https://billets.example/match',
    });
    expect(off.visibleOnHome(sedanIsHome: true), isFalse);

    final noUrl = MatchTicketing.fromMap({
      'enabled': true,
      'url': '',
    });
    expect(noUrl.visibleOnHome(sedanIsHome: true), isFalse);
  });

  test('Accueil domicile = isSedanTeam(team1) like calendar / next match card', () {
    final on = MatchTicketing.fromMap({
      'enabled': true,
      'url': 'https://billets.example/match',
    });
    expect(
      on.visibleOnHome(sedanIsHome: isSedanTeam('CS Sedan Ardennes')),
      isTrue,
    );
    expect(
      on.visibleOnHome(sedanIsHome: isSedanTeam('CSSA')),
      isTrue,
    );
    expect(
      on.visibleOnHome(sedanIsHome: isSedanTeam('FC Rouen')),
      isFalse,
    );
  });
}
