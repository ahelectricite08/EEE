import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import 'match_stats_service.dart';

class MatchService {
  static final _col = FirebaseFirestore.instance.collection('matches');

  static String _dedupeKeyForDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final rawDate = d['date'];
    if (rawDate is! Timestamp) return doc.id;
    final date = rawDate.toDate();
    final day = DateTime(date.year, date.month, date.day);
    final t1 = (d['team1'] ?? '').toString().trim().toLowerCase();
    final t2 = (d['team2'] ?? '').toString().trim().toLowerCase();
    final pair = t1.compareTo(t2) <= 0 ? '$t1|$t2' : '$t2|$t1';
    final comp = (d['competition'] ?? '').toString().trim().toLowerCase();
    return '$pair|$comp|${day.year}|${day.month}|${day.day}';
  }

  static int _scoreCompleteness(Map<String, dynamic> d) {
    final s1 = MatchModel.parseScoreField(d['score1'] ?? d['homeScore']);
    final s2 = MatchModel.parseScoreField(d['score2'] ?? d['awayScore']);
    if (s1 != null && s2 != null) return 2;
    if (s1 != null || s2 != null) return 1;
    return 0;
  }

  static bool _shouldReplaceDuplicateDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> current,
    QueryDocumentSnapshot<Map<String, dynamic>> candidate,
  ) {
    final c0 = _scoreCompleteness(current.data());
    final c1 = _scoreCompleteness(candidate.data());
    if (c1 > c0) return true;
    if (c1 < c0) return false;
    final t0 = current.data()['updatedAt'];
    final t1 = candidate.data()['updatedAt'];
    if (t0 is Timestamp && t1 is Timestamp) {
      return t1.compareTo(t0) > 0;
    }
    if (t1 is Timestamp && t0 is! Timestamp) return true;
    return candidate.id.compareTo(current.id) > 0;
  }

  /// Fusionne les doublons (même paire + même jour + même compétition), garde le doc le plus fiable.
  static List<MatchModel> _materializeDeduped(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool dateDescending,
  }) {
    final winners = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final key = _dedupeKeyForDoc(doc);
      final existing = winners[key];
      if (existing == null) {
        winners[key] = doc;
      } else if (_shouldReplaceDuplicateDoc(existing, doc)) {
        winners[key] = doc;
      }
    }
    final list = winners.values.map(MatchModel.fromFirestore).toList();
    list.sort(
      (a, b) =>
          dateDescending ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );
    return list;
  }

  /// Matchs à venir (bruts) - tous les matchs, pas de filtre
  static Stream<List<MatchModel>> upcoming() => _col
      .where('date', isGreaterThan: Timestamp.now())
      .orderBy('date')
      .snapshots()
      .map((s) => _materializeDeduped(s.docs, dateDescending: false));

  /// Tous les matchs à venir (toutes équipes, sans filtre SEDAN)
  static Stream<List<MatchModel>> allUpcoming() => _col
      .where('date', isGreaterThan: Timestamp.now())
      .orderBy('date')
      .snapshots()
      .map((s) => _materializeDeduped(s.docs, dateDescending: false));

  /// Matchs à venir enrichis avec forme + rang calculés automatiquement
  static Stream<List<MatchModel>> upcomingEnriched() =>
      upcoming().asyncMap(MatchStatsService.enrichAll);

  /// Matchs passés (bruts) - tous les matchs, pas de filtre
  static Stream<List<MatchModel>> results() => _col
      .where('status', isEqualTo: 'finished')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) {
        final now = DateTime.now();
        final deduped = _materializeDeduped(s.docs, dateDescending: true);
        return deduped.where((m) => !m.date.isAfter(now)).toList();
      });

  /// Tous les résultats (toutes équipes, sans filtre SEDAN)
  static Stream<List<MatchModel>> allResults() => _col
      .where('status', isEqualTo: 'finished')
      .orderBy('date', descending: true)
      .limit(100)
      .snapshots()
      .map((s) {
        final now = DateTime.now();
        final deduped = _materializeDeduped(s.docs, dateDescending: true);
        return deduped.where((m) => !m.date.isAfter(now)).toList();
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
  static Stream<DocumentSnapshot> liveMatch() =>
      FirebaseFirestore.instance.collection('live').doc('current').snapshots();

  /// Tous les matchs d'un mois donné (pour le calendrier)
  static Stream<List<MatchModel>> forMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final exclusiveEnd = DateTime(year, month + 1, 1);
    return _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(exclusiveEnd))
        .orderBy('date')
        .snapshots()
        .map((s) => _materializeDeduped(s.docs, dateDescending: false));
  }

  /// Une fiche match par id document Firestore (notifs, deep links).
  static Future<MatchModel?> byId(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return MatchModel.fromFirestore(doc);
  }

  static Future<List<MatchModel>> fetchSearchableMatches({
    int limit = 60,
  }) async {
    final snap = await _col
        .orderBy('date', descending: false)
        .limit(limit)
        .get();
    return _materializeDeduped(snap.docs, dateDescending: false);
  }
}
