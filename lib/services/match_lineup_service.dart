import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_lineup.dart';
import 'match_stats_sheet_service.dart';

/// Sauvegarde compositions : live → match → fiche stats (`match_stats`) pour résumés.
class MatchLineupService {
  MatchLineupService._();
  static final instance = MatchLineupService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _liveRef =>
      _db.collection('live').doc('current');

  Future<String?> _linkedMatchId() async {
    final snap = await _liveRef.get();
    if (!snap.exists) return null;
    final id = (snap.data()?['matchId'] as String? ?? '').trim();
    if (id.isEmpty || id.startsWith('live_')) return null;
    return id;
  }

  Future<void> saveLineups({
    required MatchLineupSide home,
    required MatchLineupSide away,
    bool? showOnCard,
  }) async {
    final patch = <String, dynamic>{
      'lineupHome': home.toMap(),
      'lineupAway': away.toMap(),
      'lineupsUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (showOnCard != null) {
      patch['showLineupOnCard'] = showOnCard;
    }

    await _liveRef.set(patch, SetOptions(merge: true));

    final matchId = await _linkedMatchId();
    if (matchId == null) return;

    await _db.collection('matches').doc(matchId).set(
          patch,
          SetOptions(merge: true),
        );

    if (home.hasContent || away.hasContent) {
      await MatchStatsSheetService.instance.syncLineups(
        matchId: matchId,
        home: home,
        away: away,
      );
    }
  }

  Future<void> setShowOnCard(bool enabled) async {
    await _liveRef.set({
      'showLineupOnCard': enabled,
      'lineupsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final matchId = await _linkedMatchId();
    if (matchId == null) return;
    await _db.collection('matches').doc(matchId).set({
      'showLineupOnCard': enabled,
      'lineupsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
