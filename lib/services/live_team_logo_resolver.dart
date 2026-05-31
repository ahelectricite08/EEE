import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../screens/matches/matches_helpers.dart';

/// Résout les logos d’équipes pour la Live Activity quand `live/current` est incomplet.
class LiveTeamLogoResolver {
  LiveTeamLogoResolver._();

  static final Map<String, String> _cacheByTeam = {};
  static Map<String, String> _byExact = {};
  static Map<String, String> _byNorm = {};
  static DateTime? _indexBuiltAt;
  static const _indexTtl = Duration(minutes: 20);

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

    if (l1.isNotEmpty && l2.isNotEmpty) {
      return (logo1: l1, logo2: l2);
    }

    await _ensureMatchIndex();
    if (l1.isEmpty && team1.trim().isNotEmpty) {
      l1 = _pickLogo(team1) ?? '';
    }
    if (l2.isEmpty && team2.trim().isNotEmpty) {
      l2 = _pickLogo(team2) ?? '';
    }

    return (logo1: l1, logo2: l2);
  }

  static bool _isSyntheticLiveId(String id) =>
      id.startsWith('live_') && RegExp(r'^live_\d+$').hasMatch(id);

  static Future<void> _ensureMatchIndex() async {
    final built = _indexBuiltAt;
    if (built != null && DateTime.now().difference(built) < _indexTtl) {
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .orderBy('date', descending: true)
          .limit(160)
          .get();

      final exact = <String, String>{};
      final norm = <String, String>{};

      void put(String team, String? logo) {
        final t = team.trim();
        final u = logo?.trim();
        if (t.isEmpty || u == null || u.isEmpty) return;
        exact.putIfAbsent(t, () => u);
        norm.putIfAbsent(normalizeTeamLabel(t), () => u);
        _cacheByTeam.putIfAbsent(t, () => u);
      }

      for (final doc in snap.docs) {
        final d = doc.data();
        put((d['team1'] as String?) ?? '', d['logo1'] as String?);
        put((d['team2'] as String?) ?? '', d['logo2'] as String?);
      }

      _byExact = exact;
      _byNorm = norm;
      _indexBuiltAt = DateTime.now();
    } catch (e) {
      debugPrint('LiveTeamLogoResolver index: $e');
    }
  }

  static String? _pickLogo(String team) {
    final cached = _cacheByTeam[team.trim()];
    if (cached != null && cached.isNotEmpty) return cached;

    final t = team.trim();
    if (t.isEmpty) return null;
    final direct = _byExact[t] ?? _byNorm[normalizeTeamLabel(t)];
    if (direct != null) {
      _cacheByTeam[t] = direct;
      return direct;
    }
    for (final e in _byExact.entries) {
      if (teamMatchesPreference(t, e.key) ||
          teamMatchesPreference(e.key, t)) {
        _cacheByTeam[t] = e.value;
        return e.value;
      }
    }
    return null;
  }
}
