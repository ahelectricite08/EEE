import 'package:dvcr/models/benevole_posts.dart';
import 'package:dvcr/models/sedan_squad.dart';
import 'package:dvcr/screens/matches/matches_helpers.dart';
import 'package:dvcr/screens/profile/match_story_visual.dart';
import 'package:dvcr/services/match_sheet_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 29, 20, 0);

  final squad = SedanSquad(
    players: [
      const SedanSquadPlayer(
        id: 'p1',
        name: 'Dupont',
        number: 9,
        position: 'ATT',
        photoUrl: 'https://example.com/dupont.jpg',
      ),
      const SedanSquadPlayer(
        id: 'p2',
        name: 'Durand',
        number: 10,
        position: 'MIL',
        photoUrl: 'https://example.com/durand.jpg',
      ),
      const SedanSquadPlayer(
        id: 'p3',
        name: 'Lopez',
        number: 4,
        position: 'DEF',
        photoUrl: 'https://example.com/lopez-cssa.jpg',
      ),
    ],
  );

  test('kickoff logos follow the match, footer is DVCR', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.kickoff,
      matchId: 'm1',
      data: {
        'team1': 'VITRY FC',
        'team2': 'SEDAN ARDENNES CS',
        'date': now,
        'competition': 'Coupe de France',
        'logo1': 'https://cdn.example/vitry.png',
        'logo2': 'https://cdn.example/sedan.png',
      },
      squad: squad,
    );
    expect(payload.storyFooter, 'DVCR  ·  DRAPEAU VERT CARTON ROUGE');
    expect(payload.logo1, 'https://cdn.example/vitry.png');
    expect(payload.logo2, 'https://cdn.example/sedan.png');
    expect(
      payload.shareCaption,
      contains('VITRY FC — SEDAN ARDENNES CS'),
    );
  });

  test('pickStoryCrest retrouve l’écusson FFF même si le libellé bouge', () {
    final index = {
      'STADE DE REIMS': 'https://x/reims.png',
      normalizeTeamLabel('STADE DE REIMS'): 'https://x/reims.png',
    };
    expect(pickStoryCrest(index, 'Stade de Reims'), 'https://x/reims.png');
    expect(pickStoryCrest(index, 'VITRY FC'), isNull);
    expect(storyTeamInitials('VITRY FC'), 'VF');
    expect(storyTeamInitials('CSSA'), 'CSSA');
  });

  test('kickoff caption sends people to YouTube', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.kickoff,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'competition': 'N3',
      },
      squad: squad,
    );
    expect(payload.storyHeadline, 'COUP D’ENVOI');
    expect(
      payload.shareCaption,
      'Coup d’envoi CSSA — Pau — rendez-vous sur YouTube dès maintenant !',
    );
  });

  test('full-time caption invites people to stay for the after-match', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.fullTime,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'score1': 2,
        'score2': 1,
      },
      squad: squad,
    );
    expect(payload.storyHeadline, 'FIN DE MATCH');
    expect(
      payload.shareCaption,
      'Fin de match CSSA — Pau 2 – 1 — restez avec nous pour l’après-match !',
    );
  });

  test('composition prend l’écusson CSSA, pas l’adversaire', () {
    final home = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.lineup,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'competition': 'Régional 1',
        'logo1': 'https://cdn.example/cssa.png',
        'logo2': 'https://cdn.example/pau.png',
      },
      squad: squad,
    );
    expect(home.storyHeadline, 'COMPOSITION');
    expect(home.cssaLogoUrl, 'https://cdn.example/cssa.png');

    final away = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.lineup,
      matchId: 'm2',
      data: {
        'team1': 'Pau',
        'team2': 'SEDAN ARDENNES CS',
        'date': now,
        'logo1': 'https://cdn.example/pau.png',
        'logo2': 'https://cdn.example/cssa.png',
      },
      squad: squad,
    );
    expect(away.cssaLogoUrl, 'https://cdn.example/cssa.png');
  });

  test('lineup payload uses squad photoUrl when names match', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.lineup,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'competition': 'N3',
        'benevoleType': BenevolePosts.typeR1,
        'lineupHome': {
          'starters': ['9 Dupont', '10 Durand'],
        },
      },
      squad: squad,
    );
    expect(payload.xiPlayers.length, 2);
    expect(
      payload.xiPlayers.firstWhere((p) => p.name == 'Dupont').photoUrl,
      'https://example.com/dupont.jpg',
    );
    expect(
      payload.xiPlayers.firstWhere((p) => p.name == 'Durand').photoUrl,
      'https://example.com/durand.jpg',
    );
  });

  test('composition opponent XI stays generic even if the name exists at CSSA', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.lineup,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'lineupHome': {
          'starters': ['9 Dupont'],
        },
        'lineupAway': {
          'starters': ['4 Lopez'],
        },
      },
      squad: squad,
    );
    expect(
      payload.xiPlayers.firstWhere((p) => p.name == 'Dupont').photoUrl,
      'https://example.com/dupont.jpg',
    );
    expect(payload.opponentXiPlayers, hasLength(1));
    expect(payload.opponentXiPlayers.single.name, 'Lopez');
    expect(payload.opponentXiPlayers.single.photoUrl, isNull);
  });

  test('goal payload attaches CSSA photo, never invents the score', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.goal,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'score1': 1,
        'score2': 0,
        'competition': 'N3',
        'logo1': 'https://cdn.example/cssa.png',
        'logo2': 'https://cdn.example/pau.png',
      },
      squad: squad,
      goal: const MatchSheetScorer(player: 'Dupont', minute: 12),
    );
    expect(payload.goal?.player, 'Dupont');
    expect(payload.goal?.minute, 12);
    expect(payload.goal?.photoUrl, 'https://example.com/dupont.jpg');
    expect(payload.scoreLabel, '1 – 0');
    expect(payload.scoringTeamLogoUrl, 'https://cdn.example/cssa.png');
    expect(payload.opponentLogoUrl, 'https://cdn.example/pau.png');
    expect(payload.logo1, 'https://cdn.example/cssa.png');
    expect(payload.logo2, 'https://cdn.example/pau.png');
    expect(payload.scoringTeamName, 'CSSA');
    expect(payload.chromeHeadline, 'BUT !!!');
    expect(payload.storyHeadline, 'BUT !!!');
  });

  test('own-goal recap does not steal a CSSA portrait', () {
    final face = storyFaceForScorer(
      squad,
      const MatchSheetScorer(player: 'Lopez', minute: 9, ownGoal: true),
    );
    expect(face.photoUrl, isNull);
    expect(face.name, 'Lopez');
  });

  test('recap opponent never receives a CSSA portrait', () {
    final face = storyFaceForScorer(
      squad,
      const MatchSheetScorer(player: 'Lopez', minute: 20),
      cssa: false,
    );
    expect(face.photoUrl, isNull);
    expect(face.name, 'Lopez');
  });

  test('half-time recap lists both sides and scales a lone scorer', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.halfTime,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'score1': 1,
        'score2': 1,
        'logo1': 'https://cdn.example/cssa.png',
        'logo2': 'https://cdn.example/pau.png',
        'events': [
          {
            'type': 'goal',
            'team': 'CSSA',
            'player': 'Dupont',
            'minute': 12,
          },
          {
            'type': 'goal',
            'team': 'Pau',
            'player': 'Martin',
            'minute': 40,
          },
        ],
      },
      squad: squad,
    );
    expect(payload.sedanScorers.map((s) => s.player).toList(), ['Dupont']);
    expect(payload.opponentScorers.map((s) => s.player).toList(), ['Martin']);
    expect(payload.opponentLogoUrl, 'https://cdn.example/pau.png');
    final rows = storyRecapGoalRows(payload);
    expect(rows.map((r) => r.scorer.player).toList(), ['Dupont', 'Martin']);
    expect(rows.first.cssa, isTrue);
    expect(rows.last.cssa, isFalse);
    expect(
      storyRecapFaceSize(count: 1, maxHeight: 900),
      greaterThan(storyRecapFaceSize(count: 5, maxHeight: 900)),
    );
  });

  test('mi-temps / fin de match tally yellow and red per side', () {
    final payload = MatchStoryPayload.fromMerged(
      kind: MatchStoryKind.halfTime,
      matchId: 'm1',
      data: {
        'team1': 'CSSA',
        'team2': 'Pau',
        'date': now,
        'events': [
          {'type': 'yellow', 'team': 'CSSA', 'player': 'Dupont', 'minute': 18},
          {'type': 'yellow', 'team': 'CSSA', 'player': 'Durand', 'minute': 33},
          {'type': 'red', 'team': 'Pau', 'player': 'Martin', 'minute': 41},
        ],
      },
      squad: squad,
    );
    expect(payload.yellow1, 2);
    expect(payload.red1, 0);
    expect(payload.yellow2, 0);
    expect(payload.red2, 1);

    final stored = storyCardTally({
      'team1': 'CSSA',
      'team2': 'Pau',
      'yellowHome': 1,
      'redAway': 1,
    });
    expect(stored.yellow1, 1);
    expect(stored.red2, 1);
  });

  test('cssa goal stories skip own goals', () {
    final goals = cssaGoalStoryScorers({
      'team1': 'CSSA',
      'team2': 'Pau',
      'events': [
        {
          'type': 'goal',
          'team': 'CSSA',
          'player': 'Dupont',
          'minute': 12,
        },
        {
          'type': 'own_goal',
          'team': 'Pau',
          'player': 'Lopez',
          'minute': 40,
        },
      ],
    });
    expect(goals.map((g) => g.player).toList(), ['Dupont']);
    expect(
      cssaGoalStoryScorers({
        'team1': 'CSSA',
        'team2': 'Pau',
        'events': [
          {
            'type': 'goal',
            'team': 'Pau',
            'player': 'Martin',
            'minute': 22,
          },
        ],
      }),
      isEmpty,
    );
  });

  test('pickMatchStorySource prefers the live Sedan premiere', () {
    final picked = pickMatchStorySource(
      now: now,
      live: {
        'matchId': 'live-m',
        'team1': 'CSSA',
        'team2': 'Pau',
        'benevoleType': BenevolePosts.typeR1,
        'date': now,
      },
      matches: [
        (
          id: 'upcoming',
          data: {
            'team1': 'CSSA',
            'team2': 'Épinal',
            'benevoleType': BenevolePosts.typeR1,
            'date': now.add(const Duration(days: 2)),
          },
        ),
        (
          id: 'live-m',
          data: {
            'team1': 'CSSA',
            'team2': 'Pau',
            'benevoleType': BenevolePosts.typeR1,
            'date': now,
            'logo1': 'https://example.com/cssa.png',
          },
        ),
      ],
    );
    expect(picked?.id, 'live-m');
    expect(picked?.data['logo1'], 'https://example.com/cssa.png');
  });

  test('pickMatchStorySource takes next Sedan premiere, else most recent', () {
    final upcoming = pickMatchStorySource(
      now: now,
      matches: [
        (
          id: 'old',
          data: {
            'team1': 'CSSA',
            'team2': 'Pau',
            'benevoleType': BenevolePosts.typeR1,
            'date': now.subtract(const Duration(days: 10)),
          },
        ),
        (
          id: 'next',
          data: {
            'team1': 'CSSA',
            'team2': 'Épinal',
            'benevoleType': BenevolePosts.typeR1,
            'date': now.add(const Duration(hours: 3)),
          },
        ),
      ],
    );
    expect(upcoming?.id, 'next');

    final recent = pickMatchStorySource(
      now: now,
      matches: [
        (
          id: 'older',
          data: {
            'team1': 'CSSA',
            'team2': 'Pau',
            'benevoleType': BenevolePosts.typeR1,
            'date': now.subtract(const Duration(days: 20)),
          },
        ),
        (
          id: 'newer',
          data: {
            'team1': 'CSSA',
            'team2': 'Épinal',
            'benevoleType': BenevolePosts.typeR1,
            'date': now.subtract(const Duration(days: 2)),
          },
        ),
        (
          id: 'r2',
          data: {
            'team1': 'CSSA',
            'team2': 'Réserve',
            'benevoleType': BenevolePosts.typeReserve,
            'date': now.subtract(const Duration(hours: 1)),
          },
        ),
      ],
    );
    expect(recent?.id, 'newer');
  });

  test('kit title is CSSA — adversaire even when Sedan is away', () {
    expect(
      kitMatchTitle({
        'team1': 'Pau',
        'team2': 'CSSA',
      }),
      'CSSA — Pau',
    );
  });
}
