import 'package:dvcr/services/fff_device_score_sync.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(int journee, String team, {int rank = 1}) {
  return {
    'cj_no': journee,
    'rank': rank,
    'equipe': {'short_name': team},
  };
}

void main() {
  test('URLs FFF R1 / R2 = calendrier + classement + matchs poule A', () {
    expect(
      FffDeviceScoreSync.pouleCalendrierUrl(449966, 1, 1),
      'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/calendrier?itemsPerPage=50',
    );
    expect(
      FffDeviceScoreSync.pouleClassementUrl(449966, 1, 1),
      'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/classement_journees?itemsPerPage=200',
    );
    expect(
      FffDeviceScoreSync.pouleMatchsUrl(449972, 1, 1),
      'https://api-dofa.fff.fr/api/compets/449972/phases/1/poules/1/matchs?itemsPerPage=30',
    );
    expect(
      FffDeviceScoreSync.clubMatchsUrl(380),
      'https://api-dofa.fff.fr/api/clubs/380/matchs?itemsPerPage=100',
    );
  });

  test('affiliation 500266 → cl_no DOFA 380', () {
    expect(resolveCssaDofaClubNo(500266), 380);
    expect(resolveCssaDofaClubNo(380), 380);
  });

  test('libellés coupe / amical FFF', () {
    expect(
      fffCompetitionLabel('COUPE DE FRANCE CRÉDIT AGRICOLE', 'CP'),
      'Coupe de France',
    );
    expect(fffCompetitionLabel('MATCHS AMICAUX', 'AC'), 'Match Amical');
  });

  test('1ère séniors CSSA, pas Torcy ni R2', () {
    expect(
      isSeniorFirstTeamClubMatch({
        'away': {
          'category_code': 'SEM',
          'number': 1,
          'club': {'cl_no': 380},
          'short_name': 'SEDAN ARDENNES CS',
        },
        'competition': {'type': 'CP'},
      }, 380),
      isTrue,
    );
    expect(
      isSeniorFirstTeamClubMatch({
        'home': {
          'category_code': 'SEM',
          'number': 1,
          'club': {'cl_no': 21999},
          'short_name': 'TORCY SEDAN OLYMP.',
        },
        'competition': {'type': 'CP'},
      }, 380),
      isFalse,
    );
    expect(
      isSeniorFirstTeamClubMatch({
        'home': {
          'category_code': 'SEM',
          'number': 3,
          'club': {'cl_no': 380},
        },
        'competition': {'type': 'CH'},
      }, 380),
      isFalse,
    );
    expect(isFffCupOrFriendly({'competition': {'type': 'AC'}}), isTrue);
    expect(isFffCupOrFriendly({'competition': {'type': 'CH'}}), isFalse);
  });

  group('pickLatestCompleteFffRankingJournee', () {
    test('prend la dernière journée complète, pas la J incomplète', () {
      final mixed = [
        for (var i = 0; i < 14; i++) _row(1, 'T$i', rank: i + 1),
        _row(2, 'SEDAN ARDENNES CS'),
      ];
      final picked = pickLatestCompleteFffRankingJournee(mixed);
      expect(picked.complete, isTrue);
      expect(picked.journee, 1);
      expect(picked.rows.length, 14);
    });

    test('préfère J2 quand les deux journées sont complètes', () {
      final all = [
        for (var i = 0; i < 14; i++) _row(1, 'A$i', rank: i + 1),
        for (var i = 0; i < 14; i++) _row(2, 'B$i', rank: i + 1),
      ];
      final picked = pickLatestCompleteFffRankingJournee(all);
      expect(picked.complete, isTrue);
      expect(picked.journee, 2);
      expect(picked.rows.length, 14);
    });

    test('ne mélange pas deux journées incomplètes', () {
      final split = [
        for (var i = 0; i < 7; i++) _row(6, 'A$i', rank: i + 1),
        for (var i = 0; i < 7; i++) _row(7, 'B$i', rank: i + 1),
      ];
      final picked = pickLatestCompleteFffRankingJournee(split);
      expect(picked.complete, isFalse);
      expect(picked.journee, 7);
    });

    test('dump sans cj_no = poule entière', () {
      final dump = [
        for (var i = 0; i < 14; i++)
          {'rank': i + 1, 'equipe': {'short_name': 'T$i'}},
      ];
      final picked = pickLatestCompleteFffRankingJournee(dump);
      expect(picked.complete, isTrue);
      expect(picked.rows.length, 14);
    });

    test('liste vide', () {
      final picked = pickLatestCompleteFffRankingJournee(const []);
      expect(picked.complete, isFalse);
      expect(picked.rows, isEmpty);
    });
  });

  test('matchs FFF : scores d’abord, date récente ensuite', () {
    final j1 = {
      'date': '2026-08-23T00:00:00+00:00',
      'home_score': 1,
      'away_score': 2,
    };
    final j9 = {
      'date': '2026-11-01T00:00:00+00:00',
      'home_score': 3,
      'away_score': 0,
    };
    final next = {
      'date': '2026-11-08T00:00:00+00:00',
    };
    final ordered = [j1, next, j9]..sort(compareFffMatchesForSync);
    expect(ordered[0], j9);
    expect(ordered[1], j1);
    expect(ordered[2], next);
  });

  test('hydra last page + next', () {
    expect(
      fffHydraLastPage({
        'hydra:view': {
          'hydra:last':
              '/api/compets/449966/phases/1/poules/1/matchs?itemsPerPage=30&page=7',
        },
      }),
      7,
    );
    expect(
      fffUrlWithPage(
        'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/matchs?itemsPerPage=30',
        3,
      ),
      'https://api-dofa.fff.fr/api/compets/449966/phases/1/poules/1/matchs?itemsPerPage=30&page=3',
    );
    expect(
      fffHydraNextUrl({
        'hydra:view': {
          'hydra:next': '/api/compets/1/matchs?page=2',
        },
      }),
      'https://api-dofa.fff.fr/api/compets/1/matchs?page=2',
    );
  });

  group('rankingMembersForIngest', () {
    test('ne garde que rank / stats / nom, pas le dump Hydra', () {
      final rows = rankingMembersForIngest([
        {
          'rank': 1,
          'cj_no': 4,
          'point_count': 12,
          'hydra:id': '/secret',
          'equipe': {
            'short_name': 'CSSA',
            'club': {'logo': 'https://x/logo.png', 'cl_no': 500266},
          },
        },
        {'equipe': {'short_name': 'sans rang'}},
      ]);
      expect(rows, hasLength(1));
      expect(rows.single['rank'], 1);
      expect(rows.single['point_count'], 12);
      expect(rows.single.containsKey('hydra:id'), isFalse);
      expect(
        (rows.single['equipe'] as Map)['short_name'],
        'CSSA',
      );
    });
  });
}
