import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/features/prono/domain/prono_lock.dart';
import 'package:dvcr/models/first_scorer_bet.dart';

void main() {
  test('config hidden by default', () {
    expect(FirstScorerBetConfig.firestoreDocId, 'first_scorer_bet');
    expect(FirstScorerBetConfig.defaults.enabled, isFalse);
    expect(FirstScorerBetConfig.defaults.showInApp, isFalse);
    expect(FirstScorerBetConfig.fromMap({'enabled': true}).showInApp, isTrue);
  });

  test('locks at kickoff like 1N2, not when live starts early', () {
    final ko = DateTime(2026, 8, 28, 20);
    expect(
      firstScorerBetIsLocked(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 19, 59),
      ),
      isFalse,
    );
    expect(
      firstScorerBetIsLocked(
        kickoff: ko,
        now: DateTime(2026, 8, 28, 20),
      ),
      isTrue,
    );
    // Direct lancé avant l’heure du match : encore ouvert (comme le prono).
    expect(
      isMatchPronoLocked(
        DateTime(2026, 8, 28, 21),
        now: DateTime(2026, 8, 28, 19),
      ),
      isFalse,
    );
  });

  test('first goal CSSA awards +3 pts and +10 XP on name match', () {
    final resolved = resolveFirstScorerFromEvents(
      events: [
        {'type': 'yellow', 'minute': 1, 'player': 'X', 'team': 'SEDAN ARDENNES CS'},
        {'type': 'goal', 'minute': 12, 'player': '9 Dupont', 'team': 'SEDAN ARDENNES CS'},
        {'type': 'goal', 'minute': 40, 'player': 'Adverse', 'team': 'Bourg'},
      ],
      team1: 'SEDAN ARDENNES CS',
      team2: 'Bourg-en-Bresse',
    );
    expect(resolved?.kind, FirstScorerBetPick.kindSedan);
    const cssaPick = FirstScorerBetPick(
      uid: 'u',
      matchId: 'm',
      kind: FirstScorerBetPick.kindSedan,
      playerName: 'Dupont',
    );
    expect(pointsForFirstScorerPick(pick: cssaPick, resolved: resolved), 3);
    expect(xpForFirstScorerPick(pick: cssaPick, resolved: resolved), 10);
    expect(
      pointsForFirstScorerPick(
        pick: const FirstScorerBetPick(
          uid: 'u',
          matchId: 'm',
          kind: FirstScorerBetPick.kindOpponent,
        ),
        resolved: resolved,
      ),
      0,
    );
  });

  test('encart only on Sedan / CSSA matches', () {
    expect(
      firstScorerBetMatchInvolvesCssa('SEDAN ARDENNES CS', 'Bourg'),
      isTrue,
    );
    expect(
      firstScorerBetMatchInvolvesCssa('Rouen', 'CSSA'),
      isTrue,
    );
    expect(
      firstScorerBetMatchInvolvesCssa('Rouen', 'Bourg-en-Bresse'),
      isFalse,
    );
  });

  test('first goal opponent awards +1', () {
    final resolved = resolveFirstScorerFromEvents(
      events: [
        {'type': 'goal', 'minute': 8, 'player': 'Martin', 'team': 'Rouen'},
      ],
      team1: 'SEDAN ARDENNES CS',
      team2: 'Rouen',
    );
    expect(resolved?.kind, FirstScorerBetPick.kindOpponent);
    const opp = FirstScorerBetPick(
      uid: 'u',
      matchId: 'm',
      kind: FirstScorerBetPick.kindOpponent,
    );
    expect(pointsForFirstScorerPick(pick: opp, resolved: resolved), 1);
    expect(xpForFirstScorerPick(pick: opp, resolved: resolved), 0);
    expect(
      pointsForFirstScorerPick(
        pick: const FirstScorerBetPick(
          uid: 'u',
          matchId: 'm',
          kind: FirstScorerBetPick.kindSedan,
          playerName: 'Dupont',
        ),
        resolved: resolved,
      ),
      0,
    );
  });

  test('admin override beats events', () {
    final resolved = resolveFirstScorerFromEvents(
      events: [
        {'type': 'goal', 'minute': 1, 'player': 'Dupont', 'team': 'SEDAN ARDENNES CS'},
      ],
      team1: 'SEDAN ARDENNES CS',
      team2: 'Rouen',
      override: {'kind': 'opponent'},
    );
    expect(resolved?.kind, FirstScorerBetPick.kindOpponent);
  });

  test('sedan own goal counts as opponent opener', () {
    final resolved = resolveFirstScorerFromEvents(
      events: [
        {'type': 'own_goal', 'minute': 3, 'player': 'Dupont', 'team': 'SEDAN ARDENNES CS'},
      ],
      team1: 'SEDAN ARDENNES CS',
      team2: 'Rouen',
    );
    expect(resolved?.kind, FirstScorerBetPick.kindOpponent);
  });
}
