import 'package:dvcr/models/fff_season_config.dart';
import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/models/season_palmares.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonPalmaresMatchDoc _doc({
  required String id,
  required DateTime date,
  String team1 = 'CSSA',
  String team2 = 'AS Test',
  String competition = 'Régional 1',
  String status = 'finished',
  String? fffSeason,
  String? hdm,
  bool showMotm = true,
  double? note,
  int votes = 0,
}) {
  return SeasonPalmaresMatchDoc(
    id: id,
    data: {
      'date': date,
      'team1': team1,
      'team2': team2,
      'competition': competition,
      'status': status,
      if (fffSeason != null) 'fffSeason': fffSeason,
      if (hdm != null) 'manOfTheMatchName': hdm,
      'showMotm': showMotm,
      if (note != null) 'matchRatingAverage': note,
      if (votes > 0) 'matchRatingTotal': votes,
    },
  );
}

void main() {
  final season = FffSeasonConfig.frenchFootballSeasonLabel(
    DateTime(2026, 8, 28),
  );

  test('saison calendaire août 2026 = 2026-2027', () {
    expect(season, '2026-2027');
  });

  test('moyenne = moyenne des notes de match, pas un histogramme', () {
    final palmares = SeasonPalmares.fromMatchDocs(
      seasonLabel: season,
      docs: [
        _doc(
          id: 'a',
          date: DateTime(2026, 8, 15, 18),
          team2: 'Épinal',
          note: 7.0,
          votes: 40,
          hdm: 'Koffi',
        ),
        _doc(
          id: 'b',
          date: DateTime(2026, 8, 22, 18),
          team2: 'Biesheim',
          note: 5.8,
          votes: 10,
          hdm: 'Koffi',
        ),
      ],
    );

    expect(palmares.ratedMatchCount, 2);
    expect(palmares.averageNote, closeTo(6.4, 0.001));
    expect(palmares.averageNoteLabel, '6,4');
    expect(palmares.hdm, hasLength(1));
    expect(palmares.hdm.first.name, 'Koffi');
    expect(palmares.hdm.first.count, 2);
    expect(palmares.noteHistory.first.fixtureLabel, 'Biesheim');
  });

  test('ignore un match hors saison et un HDM masqué', () {
    final palmares = SeasonPalmares.fromMatchDocs(
      seasonLabel: season,
      docs: [
        _doc(
          id: 'old',
          date: DateTime(2026, 3, 10, 18),
          fffSeason: '2025-2026',
          note: 9,
          votes: 99,
          hdm: 'Ancien',
        ),
        _doc(
          id: 'hidden',
          date: DateTime(2026, 8, 16, 18),
          hdm: 'Secret',
          showMotm: false,
          note: 6,
          votes: 12,
        ),
      ],
    );

    expect(palmares.hdm, isEmpty);
    expect(palmares.ratedMatchCount, 1);
    expect(palmares.noteHistory.single.matchId, 'hidden');
  });

  test('Récap ignore amicaux et coupes, garde le R1', () {
    final palmares = SeasonPalmares.fromMatchDocs(
      seasonLabel: season,
      docs: [
        _doc(
          id: 'r1',
          date: DateTime(2026, 8, 22, 18),
          competition: 'Régional 1',
          note: 7,
          votes: 20,
          hdm: 'Koffi',
        ),
        _doc(
          id: 'amical',
          date: DateTime(2026, 8, 8, 18),
          competition: 'Match Amical',
          note: 9,
          votes: 50,
          hdm: 'AmicalStar',
        ),
        _doc(
          id: 'cdf',
          date: DateTime(2026, 8, 29, 18),
          competition: 'Coupe de France',
          note: 8,
          votes: 30,
          hdm: 'CoupeStar',
        ),
      ],
    );

    expect(palmares.ratedMatchCount, 1);
    expect(palmares.noteHistory.single.matchId, 'r1');
    expect(palmares.hdm.single.name, 'Koffi');
  });

  test('empty si rien à afficher', () {
    final palmares = SeasonPalmares.fromMatchDocs(
      seasonLabel: season,
      docs: [
        _doc(id: 'bare', date: DateTime(2026, 8, 8, 18)),
      ],
    );
    expect(palmares.isEmpty, isTrue);
  });

  test('HDM classés par nombre de titres puis match le plus récent', () {
    final palmares = SeasonPalmares.fromMatchDocs(
      seasonLabel: season,
      docs: [
        _doc(
          id: '1',
          date: DateTime(2026, 8, 8, 18),
          team2: 'A',
          hdm: 'Alpha',
        ),
        _doc(
          id: '2',
          date: DateTime(2026, 8, 15, 18),
          team2: 'B',
          hdm: 'Bravo',
        ),
        _doc(
          id: '3',
          date: DateTime(2026, 8, 22, 18),
          team2: 'C',
          hdm: 'Alpha',
        ),
      ],
    );
    expect(palmares.hdm.map((e) => e.name).toList(), ['Alpha', 'Bravo']);
    expect(palmares.hdm.first.matches.first.fixtureLabel, 'C');
  });

  test('MatchModel helper still builds from DateTime maps', () {
    final match = _doc(
      id: 'x',
      date: DateTime(2026, 8, 29, 18),
    ).toMatchModel();
    expect(match, isNotNull);
    expect(match!.status, MatchStatus.finished);
  });
}
