import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import 'match_stats_service.dart';

class MatchService {
  static final _col = FirebaseFirestore.instance.collection('matches');

  /// Matchs à venir (bruts) - filtrés pour SEDAN uniquement + dédupliqué
  static Stream<List<MatchModel>> upcoming() => _col
      .where('date', isGreaterThan: Timestamp.now())
      .orderBy('date')
      .snapshots()
      .map((s) {
        final seen = <String>{};
        return s.docs
            .map(MatchModel.fromFirestore)
            .where((m) {
              final key = '${m.team1}|${m.team2}|${m.date}';
              if (seen.contains(key)) return false;
              seen.add(key);
              return m.team1.toUpperCase().contains('SEDAN') || m.team2.toUpperCase().contains('SEDAN');
            })
            .toList();
      });

  /// Tous les matchs à venir (toutes équipes, sans filtre SEDAN)
  static Stream<List<MatchModel>> allUpcoming() => _col
      .where('date', isGreaterThan: Timestamp.now())
      .orderBy('date')
      .snapshots()
      .map((s) {
        final seen = <String>{};
        return s.docs
            .map(MatchModel.fromFirestore)
            .where((m) {
              final key = '${m.team1}|${m.team2}|${m.date}';
              if (seen.contains(key)) return false;
              seen.add(key);
              return true;
            })
            .toList();
      });

  /// Matchs à venir enrichis avec forme + rang calculés automatiquement
  static Stream<List<MatchModel>> upcomingEnriched() =>
      upcoming().asyncMap(MatchStatsService.enrichAll);

  /// Matchs passés (bruts) - filtrés pour SEDAN uniquement + dédupliqué
  static Stream<List<MatchModel>> results() => _col
      .where('status', isEqualTo: 'finished')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) {
        final seen = <String>{};
        return s.docs
            .map(MatchModel.fromFirestore)
            .where((m) {
              final key = '${m.team1}|${m.team2}|${m.date}';
              if (seen.contains(key)) return false;
              seen.add(key);
              return m.team1.toUpperCase().contains('SEDAN') || m.team2.toUpperCase().contains('SEDAN');
            })
            .toList();
      });

  /// Tous les résultats (toutes équipes, sans filtre SEDAN)
  static Stream<List<MatchModel>> allResults() => _col
      .where('status', isEqualTo: 'finished')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) {
        final seen = <String>{};
        return s.docs
            .map(MatchModel.fromFirestore)
            .where((m) {
              final key = '${m.team1}|${m.team2}|${m.date}';
              if (seen.contains(key)) return false;
              seen.add(key);
              return true;
            })
            .toList();
      });

  /// Matchs passés enrichis avec forme + rang calculés automatiquement
  static Stream<List<MatchModel>> resultsEnriched() =>
      results().asyncMap(MatchStatsService.enrichAll);

  /// Classement
  static Stream<QuerySnapshot> ranking() => FirebaseFirestore.instance
      .collection('ranking')
      .orderBy('position')
      .snapshots();

  /// Match en direct (s'il existe)
  static Stream<DocumentSnapshot> liveMatch() => FirebaseFirestore.instance
      .collection('live')
      .doc('current')
      .snapshots();

  /// Tous les matchs d'un mois donné (pour le calendrier)
  static Stream<List<MatchModel>> forMonth(int year, int month) {
    final start = Timestamp.fromDate(DateTime(year, month, 1));
    final end = Timestamp.fromDate(DateTime(year, month + 1, 0, 23, 59));
    return _col
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .snapshots()
        .map((s) => s.docs.map(MatchModel.fromFirestore).toList());
  }
}
