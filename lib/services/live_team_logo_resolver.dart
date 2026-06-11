import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../screens/matches/matches_helpers.dart';

/// Résout les logos d’équipes pour la Live Activity quand `live/current` est incomplet.
class LiveTeamLogoResolver {
  LiveTeamLogoResolver._();

  static Future<({String logo1, String logo2})> resolve({
    required String team1,
    required String team2,
    required String logo1,
    required String logo2,
    required String matchId,
  }) async {
    var l1 = logo1.trim();
    var l2 = logo2.trim();
    if (l1.isNotEmpty && l2.isNotEmpty) {
      return (logo1: l1, logo2: l2);
    }

    final mid = matchId.trim();
    if (mid.isNotEmpty && !_isSyntheticLiveId(mid)) {
      try {
        final snap =
            await FirebaseFirestore.instance.collection('matches').doc(mid).get();
        if (snap.exists) {
          final d = snap.data() ?? {};
          if (l1.isEmpty) {
            l1 = (d['logo1'] as String? ?? '').trim();
          }
          if (l2.isEmpty) {
            l2 = (d['logo2'] as String? ?? '').trim();
          }
          if (l1.isEmpty && team1.trim().isNotEmpty) {
            final docTeam1 = (d['team1'] as String? ?? '').trim();
            if (teamMatchesPreference(team1, docTeam1)) {
              l1 = (d['logo1'] as String? ?? '').trim();
            }
          }
          if (l2.isEmpty && team2.trim().isNotEmpty) {
            final docTeam2 = (d['team2'] as String? ?? '').trim();
            if (teamMatchesPreference(team2, docTeam2)) {
              l2 = (d['logo2'] as String? ?? '').trim();
            }
          }
        }
      } catch (e) {
        debugPrint('LiveTeamLogoResolver match doc: $e');
      }
    }

    return (logo1: l1, logo2: l2);
  }

  static bool _isSyntheticLiveId(String id) =>
      id.startsWith('live_') && RegExp(r'^live_\d+$').hasMatch(id);
}
