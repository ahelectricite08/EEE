import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/dugauguez_place.dart';

/// Votes `dugauguez_places/{matchId}` + switch TEST `app_config/dugauguez_place_test`.
class DugauguezPlaceService {
  DugauguezPlaceService._();
  static final instance = DugauguezPlaceService._();

  static const collection = 'dugauguez_places';
  static const testDocId = 'dugauguez_place_test';
  static const testMatchId = 'dugauguez_test';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get testRef =>
      _db.collection('app_config').doc(testDocId);

  DocumentReference<Map<String, dynamic>> summaryRef(String matchId) =>
      _db.collection(collection).doc(matchId);

  CollectionReference<Map<String, dynamic>> votesCol(String matchId) =>
      summaryRef(matchId).collection('votes');

  static DateTime? parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  /// Switch admin : [force] reste ON jusqu’à ce qu’Axel l’éteigne.
  static bool isForceTest(Map<String, dynamic>? data) {
    return data?['force'] == true;
  }

  Future<void> setForceTest(bool on) async {
    await testRef.set({
      'force': on,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentSummaries({
    int limit = 8,
  }) {
    return _db.collection(collection).limit(limit).snapshots();
  }

  Future<void> castVote({
    required String matchId,
    required DugauguezPlaceChoice choice,
    String team1 = '',
    String team2 = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Connecte-toi pour dire où tu regardes.');
    }
    final id = matchId.trim();
    if (id.isEmpty) {
      throw StateError('Aucun match pour ce sondage.');
    }

    final sumRef = summaryRef(id);
    final voteRef = votesCol(id).doc(user.uid);

    await _db.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final previous = DugauguezPlaceChoiceCodec.fromId(
        voteSnap.data()?['choice'] as String?,
      );
      if (previous == choice) return;

      tx.set(sumRef, {
        'matchId': id,
        'updatedAt': FieldValue.serverTimestamp(),
        'counts.${choice.id}': FieldValue.increment(1),
        if (previous == null) 'total': FieldValue.increment(1),
        if (previous != null) 'counts.${previous.id}': FieldValue.increment(-1),
        if (team1.trim().isNotEmpty) 'team1': team1.trim(),
        if (team2.trim().isNotEmpty) 'team2': team2.trim(),
      }, SetOptions(merge: true));
      tx.set(voteRef, {
        'uid': user.uid,
        'choice': choice.id,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!voteSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
