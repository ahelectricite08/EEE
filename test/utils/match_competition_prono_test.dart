import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/utils/match_competition.dart';

void main() {
  test('pronos R1 et coupes, jamais R2 / réserve', () {
    expect(MatchCompetition.isPronoEligible('Régional 1'), isTrue);
    expect(MatchCompetition.isPronoEligible('Coupe de France'), isTrue);
    expect(MatchCompetition.isPronoEligible('Coupe Grand Est'), isTrue);
    expect(MatchCompetition.isPronoEligible('Championnat'), isTrue);
    expect(MatchCompetition.isPronoEligible('Régional 2'), isFalse);
    expect(MatchCompetition.isPronoEligible('Équipe réserve'), isFalse);
    expect(
      MatchCompetition.isPronoEligible('Régional 1', matchId: 'fff_r2_12'),
      isFalse,
    );
  });
}
