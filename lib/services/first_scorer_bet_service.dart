import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/first_scorer_bet.dart';
import '../models/sedan_squad.dart';

/// Pari 1er buteur du match — `app_config/first_scorer_bet` + `first_scorer_bets`.
class FirstScorerBetService {
  FirstScorerBetService._();
  static final instance = FirstScorerBetService._();

  final _db = FirebaseFirestore.instance;

  FirstScorerBetConfig _last = FirstScorerBetConfig.defaults;

  FirstScorerBetConfig get lastKnown => _last;

  DocumentReference<Map<String, dynamic>> get configRef =>
      _db.collection('app_config').doc(FirstScorerBetConfig.firestoreDocId);

  CollectionReference<Map<String, dynamic>> get picksCol =>
      _db.collection('first_scorer_bets');

  DocumentReference<Map<String, dynamic>> pickRef(String matchId, String uid) =>
      picksCol.doc(FirstScorerBetPick.docId(matchId, uid));

  Stream<FirstScorerBetConfig> watchConfig() {
    return configRef.snapshots().map((snap) {
      _last = FirstScorerBetConfig.fromMap(snap.data());
      return _last;
    });
  }

  Future<void> setEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await configRef.set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Stream<FirstScorerBetPick?> watchPick(String matchId, String uid) {
    return pickRef(matchId, uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return FirstScorerBetPick.fromMap(
        snap.data(),
        uid: uid,
        matchId: matchId,
      );
    });
  }

  static String userFacingWriteError(Object error) {
    if (error is StateError) return error.message;
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'unauthenticated') {
        return 'Connecte-toi pour parier.';
      }
      if (code == 'permission-denied') {
        return 'Pari verrouillé — coup d’envoi.';
      }
    }
    return 'Impossible d’enregistrer. Réessaie dans un instant.';
  }

  String _clip(String value, int max) {
    final t = value.trim();
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  Future<void> saveSedanPick({
    required String matchId,
    required String uid,
    required String displayName,
    required SedanSquadPlayer player,
  }) async {
    final id = _clip(player.id, 120);
    final name = _clip(player.name, 80);
    if (id.isEmpty || name.isEmpty) {
      throw StateError('Choisis un joueur de l’effectif.');
    }
    await _writePick({
      'uid': uid,
      'matchId': _clip(matchId, 80),
      'displayName': _clip(displayName, 80),
      'kind': FirstScorerBetPick.kindSedan,
      'playerId': id,
      'playerName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, matchId: matchId, uid: uid);
  }

  Future<void> saveOpponentPick({
    required String matchId,
    required String uid,
    required String displayName,
  }) async {
    await _writePick({
      'uid': uid,
      'matchId': _clip(matchId, 80),
      'displayName': _clip(displayName, 80),
      'kind': FirstScorerBetPick.kindOpponent,
      'playerId': '',
      'playerName': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, matchId: matchId, uid: uid);
  }

  Future<void> _writePick(
    Map<String, dynamic> payload, {
    required String matchId,
    required String uid,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('Connecte-toi pour parier.');
    }
    final ref = pickRef(matchId, uid);
    final snap = await ref.get();
    if (!snap.exists) {
      payload['awarded'] = false;
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }
}
