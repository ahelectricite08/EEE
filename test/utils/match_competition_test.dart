import 'package:dvcr/utils/match_competition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pronos ouverts R1 et coupes, fermés R2 / réserve', () {
    expect(MatchCompetition.isPronoEligible('Régional 1'), isTrue);
    expect(MatchCompetition.isPronoEligible('Coupe de France'), isTrue);
    expect(MatchCompetition.isPronoEligible('Coupe Grand Est'), isTrue);
    expect(MatchCompetition.isPronoEligible('Championnat'), isTrue);
    expect(MatchCompetition.isPronoEligible('Régional 2'), isFalse);
    expect(MatchCompetition.isPronoEligible('Équipe réserve'), isFalse);
    expect(
      MatchCompetition.isPronoEligible('Régional 1', matchId: 'fff_r2_123'),
      isFalse,
    );
  });
}
