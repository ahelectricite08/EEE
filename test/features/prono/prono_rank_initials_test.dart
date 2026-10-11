import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/features/prono/presentation/widgets/prono_ui.dart';

void main() {
  test('pronoRankInitials : un mot → 1 lettre', () {
    expect(pronoRankInitials('Dupont'), 'D');
    expect(pronoRankInitials('  alex  '), 'A');
  });

  test('pronoRankInitials : prénom + nom → 2 lettres', () {
    expect(pronoRankInitials('Alex Martin'), 'AM');
    expect(pronoRankInitials('jean luc pérez'), 'JL');
  });

  test('pronoRankInitials : vide → ?', () {
    expect(pronoRankInitials(''), '?');
    expect(pronoRankInitials('   '), '?');
  });

  test('pronoLeagueAvgPtsLabel : entier si moyenne ronde', () {
    expect(
      pronoLeagueAvgPtsLabel({
        'rankingStats': {'memberPointsAvg': 12},
      }),
      '12',
    );
    expect(
      pronoLeagueAvgPtsLabel({
        'rankingStats': {'memberPointsAvg': 12.0},
      }),
      '12',
    );
  });

  test('pronoLeagueAvgPtsLabel : une décimale sinon', () {
    expect(
      pronoLeagueAvgPtsLabel({
        'rankingStats': {'memberPointsAvg': 12.4},
      }),
      '12.4',
    );
  });

  test('pronoLeagueAvgPtsLabel : absent → null', () {
    expect(pronoLeagueAvgPtsLabel(null), isNull);
    expect(pronoLeagueAvgPtsLabel(const {}), isNull);
    expect(
      pronoLeagueAvgPtsLabel({'rankingStats': 'nope'}),
      isNull,
    );
  });
}
