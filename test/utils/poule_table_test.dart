import 'package:dvcr/utils/poule_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sedan gagne, Reims perd → Sedan passe devant', () {
    final table = pouleTableFromMatches([
      {
        'team1': 'SEDAN ARDENNES CS',
        'team2': 'REIMS STE ANNE',
        'score1': 2,
        'score2': 0,
        'journee': 8,
        'fffSeason': '2026-2027',
      },
      {
        'team1': 'REIMS STE ANNE',
        'team2': 'AUTRE',
        'score1': 0,
        'score2': 1,
        'journee': 8,
        'fffSeason': '2026-2027',
      },
      {
        'team1': 'SEDAN ARDENNES CS',
        'team2': 'AUTRE',
        'score1': 2,
        'score2': 2,
        'journee': 7,
        'fffSeason': '2026-2027',
      },
    ], seasonLabel: '2026-2027');

    expect(table.rows.first.team, 'SEDAN ARDENNES CS');
    expect(table.rows.first.pts, 4);
    expect(table.rows.first.diff, 2);
    expect(table.rows[1].team, 'AUTRE');
    expect(table.gamesPlayed, 3);
    expect(table.maxJournee, 8);

    final staleFff = [
      PouleTableRow(team: 'REIMS STE ANNE', mj: 2, pts: 3, bf: 2, bc: 2),
      PouleTableRow(team: 'SEDAN ARDENNES CS', mj: 2, pts: 4, bf: 4, bc: 2),
      PouleTableRow(team: 'AUTRE', mj: 2, pts: 4, bf: 3, bc: 2),
    ];
    expect(
      pouleTableShouldReplaceRanking(table, staleFff, minTeams: 3),
      isTrue,
    );
  });

  test('ne remplace pas une poule complète par 3 fiches Sedan', () {
    final sedanOnly = pouleTableFromMatches([
      {
        'team1': 'SEDAN ARDENNES CS',
        'team2': 'REIMS STE ANNE',
        'score1': 2,
        'score2': 0,
      },
    ]);
    final fullTable = [
      for (var i = 0; i < 8; i++)
        PouleTableRow(team: 'T$i', mj: 7, pts: 21 - i),
    ];
    expect(
      pouleTableShouldReplaceRanking(sedanOnly, fullTable, minTeams: 8),
      isFalse,
    );
  });

  test('même MJ, même ordre → on ne réécrit pas', () {
    final table = pouleTableFromMatches([
      {
        'team1': 'A',
        'team2': 'B',
        'score1': 1,
        'score2': 0,
      },
      {
        'team1': 'C',
        'team2': 'D',
        'score1': 0,
        'score2': 0,
      },
      {
        'team1': 'A',
        'team2': 'C',
        'score1': 2,
        'score2': 1,
      },
      {
        'team1': 'B',
        'team2': 'D',
        'score1': 3,
        'score2': 0,
      },
    ]);
    expect(
      pouleTableShouldReplaceRanking(table, table.rows, minTeams: 4),
      isFalse,
    );
  });

  test('refuse un tableau gonflé (plusieurs saisons → 53 pts)', () {
    final inflated = [
      for (var i = 0; i < 8; i++)
        PouleTableRow(team: 'T$i', mj: 19, pts: 53 - i),
    ];
    final fff = [
      for (var i = 0; i < 8; i++)
        PouleTableRow(team: 'T$i', mj: 7, pts: 15 - i),
    ];
    expect(
      pouleTableShouldReplaceRanking(PouleTable(rows: inflated), fff),
      isFalse,
    );
  });

  test('ignore une autre saison et les matchs sans score', () {
    final table = pouleTableFromMatches([
      {
        'team1': 'A',
        'team2': 'B',
        'score1': 1,
        'score2': 0,
        'fffSeason': '2025-2026',
      },
      {
        'team1': 'A',
        'team2': 'B',
        'fffSeason': '2026-2027',
      },
    ], seasonLabel: '2026-2027');
    expect(table.rows, isEmpty);
  });
}
