import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fff_season_config.dart';
import '../models/season_palmares.dart';
import 'match_service.dart';

/// Palmarès HDM / notes : lecture publique `matches/{id}`, saison calendrier FR.
class SeasonPalmaresService {
  SeasonPalmaresService._();

  static final _col = FirebaseFirestore.instance.collection('matches');

  static String currentSeasonLabel([DateTime? at]) =>
      FffSeasonConfig.frenchFootballSeasonLabel(at);

  static Stream<SeasonPalmares> watchCurrentSeason({DateTime? at}) {
    final season = currentSeasonLabel(at);
    final years = FffSeasonConfig.parseSeasonYears(season);
    if (years == null) {
      return Stream.value(
        SeasonPalmares(
          seasonLabel: season,
          averageNote: null,
          ratedMatchCount: 0,
          hdm: const [],
          noteHistory: const [],
        ),
      );
    }

    final start = DateTime(years.$1, 7, 1);
    final end = DateTime(years.$2, 7, 1);

    return _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
          final docs = MatchService.dedupeMatchDocuments(
            snap.docs,
            preferManualInDuplicates: true,
            dateDescending: true,
          );
          return SeasonPalmares.fromMatchDocs(
            seasonLabel: season,
            docs: docs.map(
              (d) => SeasonPalmaresMatchDoc(id: d.id, data: d.data()),
            ),
          );
        });
  }
}
