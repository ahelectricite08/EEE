import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Note du match (1–10) sur l’accueil après la fin de match.
class MatchRatingService {
  MatchRatingService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DocumentReference<Map<String, dynamic>> _liveRef = _db
      .collection('live')
      .doc('current');

  static const String defaultTitle = 'Note du match';

  /// Fin de match déclarée (90′ ou fin prolongation).
  static bool isFulltimeDeclared(Map<String, dynamic> liveData) {
    final event = (liveData['lastEvent'] as String? ?? '').trim();
    return event == 'fulltime' || event == 'extra_fulltime';
  }

  /// La note du match prend la priorité sur l’encart homme du match (accueil).
  static bool takesPriorityOverMotm(Map<String, dynamic> liveData) {
    return isRatingActive(liveData) ||
        isFulltimeDeclared(liveData) ||
        liveData['matchRatingPending'] == true;
  }

  /// Appelé après [SeedService.notifyFulltime] / [notifyExtraFulltime].
  /// N’arrête pas le vote MOTM : l’accueil bascule sur la note, l’admin peut
  /// encore piloter / clôturer le trophée manuellement.
  static Future<void> onMatchFulltime() async {
    final snap = await _liveRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? <String, dynamic>{};

    if (isRatingActive(data)) return;
    await _openRatingSession(data);
  }

  /// Après clôture du vote homme du match (timer ou manuel).
  static Future<void> tryOpenPendingAfterMotmClosed() async {
    final snap = await _liveRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? <String, dynamic>{};
    if (data['matchRatingPending'] != true) return;
    if (isRatingActive(data)) return;
    await _openRatingSession(data);
  }

  static Future<void> _openRatingSession(Map<String, dynamic> data) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final counts = <String, int>{};
    for (var n = 1; n <= 10; n++) {
      counts['$n'] = 0;
    }

    final bg = (data['motmVoteBackgroundImage'] as String? ?? '').trim();
    final team1 = (data['team1'] as String? ?? '').trim();
    final team2 = (data['team2'] as String? ?? '').trim();
    final title = team1.isNotEmpty && team2.isNotEmpty
        ? '$team1 — $team2'
        : defaultTitle;

    await _liveRef.set({
      'matchRatingPending': false,
      'matchRatingStatus': 'active',
      'matchRatingSessionId': sessionId,
      'matchRatingTitle': title,
      'matchRatingBackgroundImage': bg,
      'matchRatingCounts': counts,
      'matchRatingTotal': 0,
      'matchRatingSum': 0,
      'matchRatingAverage': 0.0,
      'matchRatingStartedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> castRating(int rating) async {
    if (rating < 1 || rating > 10) {
      throw StateError('Choisis une note entre 1 et 10.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté pour noter le match.');
    }

    final voteRef = _liveRef.collection('matchRatings').doc(user.uid);

    Map<String, dynamic>? liveForMirror;
    double mirrorAverage = 0;
    int mirrorTotal = 0;
    int mirrorSum = 0;

    await _db.runTransaction((tx) async {
      final liveSnap = await tx.get(_liveRef);
      if (!liveSnap.exists) {
        throw StateError('Aucune note de match disponible.');
      }
      final liveData = liveSnap.data() ?? <String, dynamic>{};
      if (!isRatingActive(liveData)) {
        throw StateError('La fenêtre de notation est fermée.');
      }

      final sessionId =
          (liveData['matchRatingSessionId'] as String? ?? '').trim();
      final counts = _countsMap(liveData);
      var total = _totalVotes(liveData);
      var sum = _ratingSum(liveData);

      final voteSnap = await tx.get(voteRef);
      final previous = voteSnap.data() ?? <String, dynamic>{};
      final prevSession = (previous['sessionId'] as String? ?? '').trim();
      final prevRating = previous['rating'] is num
          ? (previous['rating'] as num).toInt()
          : int.tryParse('${previous['rating']}') ?? 0;

      if (prevSession == sessionId && prevRating == rating) return;

      if (prevSession == sessionId && prevRating >= 1 && prevRating <= 10) {
        final key = '$prevRating';
        counts[key] = ((counts[key] ?? 0) - 1).clamp(0, 999999);
        sum -= prevRating;
      } else {
        total += 1;
      }

      final key = '$rating';
      counts[key] = (counts[key] ?? 0) + 1;
      sum += rating;

      final average = total > 0 ? sum / total : 0.0;

      tx.update(_liveRef, {
        'matchRatingCounts': counts,
        'matchRatingTotal': total,
        'matchRatingSum': sum,
        'matchRatingAverage': double.parse(average.toStringAsFixed(2)),
        'matchRatingUpdatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(voteRef, {
        'uid': user.uid,
        'sessionId': sessionId,
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!voteSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      liveForMirror = liveData;
      mirrorAverage = average;
      mirrorTotal = total;
      mirrorSum = sum;
    });

    if (liveForMirror != null && mirrorTotal > 0) {
      await _mirrorRatingToMatch(
        liveForMirror!,
        average: mirrorAverage,
        total: mirrorTotal,
        sum: mirrorSum,
      );
    }
  }

  static Future<void> _mirrorRatingToMatch(
    Map<String, dynamic> liveData, {
    required double average,
    required int total,
    required int sum,
  }) async {
    if (total <= 0) return;
    final matchId = (liveData['matchId'] as String? ?? '').trim();
    if (matchId.isEmpty || matchId.startsWith('live_')) return;
    try {
      await _db.collection('matches').doc(matchId).set({
        'matchRatingAverage': double.parse(average.toStringAsFixed(2)),
        'matchRatingTotal': total,
        'matchRatingSum': sum,
        'matchRatingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static bool isRatingActive(Map<String, dynamic> liveData) {
    return (liveData['matchRatingStatus'] as String? ?? '').trim() == 'active';
  }

  static bool hasVisibleRating(Map<String, dynamic> liveData) {
    return isRatingActive(liveData);
  }

  static int totalVotes(Map<String, dynamic> liveData) => _totalVotes(liveData);

  static double averageRating(Map<String, dynamic> liveData) {
    final avg = liveData['matchRatingAverage'];
    if (avg is num) return avg.toDouble();
    final total = _totalVotes(liveData);
    if (total <= 0) return 0;
    return _ratingSum(liveData) / total;
  }

  static Map<String, int> countsMap(Map<String, dynamic> liveData) =>
      _countsMap(liveData);

  static Map<String, int> _countsMap(Map<String, dynamic> liveData) {
    final raw = liveData['matchRatingCounts'];
    final out = <String, int>{};
    for (var n = 1; n <= 10; n++) {
      out['$n'] = 0;
    }
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key.toString();
        if (int.tryParse(k) != null && e.value is num) {
          out[k] = (e.value as num).toInt();
        }
      }
    }
    return out;
  }

  static int _totalVotes(Map<String, dynamic> liveData) {
    final total = liveData['matchRatingTotal'];
    return total is num ? total.toInt() : 0;
  }

  static int _ratingSum(Map<String, dynamic> liveData) {
    final sum = liveData['matchRatingSum'];
    return sum is num ? sum.toInt() : 0;
  }
}
