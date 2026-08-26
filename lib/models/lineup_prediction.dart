import 'package:cloud_firestore/cloud_firestore.dart';

/// Prono XI Sedan — `lineup_predictions/{matchId_uid}`.
///
/// Verrouillage (défaut documenté) :
/// - ouvert tant que le match est `upcoming` ET qu’aucune compo Sedan
///   officielle (≥11 titulaires) n’est publiée ;
/// - fermé **2 j 12 h (60 h) avant le coup d’envoi**, ou dès publication
///   de la compo (les compos sont souvent dites la veille) ;
/// - scoring Cloud Function idempotent (`awarded`) à la publication de la compo.
class LineupPrediction {
  static const int requiredPlayers = 11;

  /// Anti-triche : plus de saisie à partir de J-2 12 h (compos souvent la veille).
  static const Duration lockBeforeKickoff = Duration(days: 2, hours: 12);

  /// Copy FR unique — client, « Comment ça marche », admin.
  static const String lockWindowLabel = '2 j 12 h avant le match';
  static const String lockReasonLabel =
      'Les compos sont souvent dites la veille.';

  static DateTime lockAt(DateTime kickoff) =>
      kickoff.subtract(lockBeforeKickoff);

  /// 9/11 → +1, 10/11 → +2, 11/11 → +3
  static int pointsForMatches(int matched) {
    if (matched >= 11) return 3;
    if (matched >= 10) return 2;
    if (matched >= 9) return 1;
    return 0;
  }

  // L’XP du XI vient en plus de ces points, mais elle est administrable :
  // voir `PronoXpScale`, qui lit `app_settings/xp_config`.

  final String id;
  final String matchId;
  final String uid;
  final String displayName;
  final List<String> playerNames;
  final List<String> playerIds;
  final bool awarded;
  final int? points;
  final int? matchedCount;
  final DateTime? updatedAt;
  final DateTime? awardedAt;

  const LineupPrediction({
    required this.id,
    required this.matchId,
    required this.uid,
    required this.displayName,
    required this.playerNames,
    this.playerIds = const [],
    this.awarded = false,
    this.points,
    this.matchedCount,
    this.updatedAt,
    this.awardedAt,
  });

  static String docId(String matchId, String uid) => '${matchId}_$uid';

  bool get isComplete =>
      playerNames.where((e) => e.trim().isNotEmpty).length >= requiredPlayers;

  factory LineupPrediction.fromMap(
    Map<String, dynamic>? d, {
    String? id,
  }) {
    final m = d ?? const <String, dynamic>{};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    final names = <String>[];
    final rawNames = m['playerNames'];
    if (rawNames is List) {
      for (final e in rawNames) {
        final n = e.toString().trim();
        if (n.isNotEmpty) names.add(n);
      }
    }
    final ids = <String>[];
    final rawIds = m['playerIds'];
    if (rawIds is List) {
      for (final e in rawIds) {
        final n = e.toString().trim();
        if (n.isNotEmpty) ids.add(n);
      }
    }
    final pts = m['points'];
    final matched = m['matchedCount'];
    return LineupPrediction(
      id: id ?? (m['id'] ?? '').toString(),
      matchId: (m['matchId'] ?? '').toString(),
      uid: (m['uid'] ?? '').toString(),
      displayName: (m['displayName'] ?? '').toString(),
      playerNames: names,
      playerIds: ids,
      awarded: m['awarded'] == true,
      points: pts is num ? pts.toInt() : null,
      matchedCount: matched is num ? matched.toInt() : null,
      updatedAt: ts(m['updatedAt']),
      awardedAt: ts(m['awardedAt']),
    );
  }

  Map<String, dynamic> toUserWriteMap() => {
        'matchId': matchId,
        'uid': uid,
        'displayName': displayName.trim().isEmpty ? 'Membre' : displayName.trim(),
        'playerNames': playerNames
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .take(requiredPlayers)
            .toList(),
        'playerIds': playerIds.take(requiredPlayers).toList(),
        'awarded': false,
        // Client never owns scoring fields — omit/delete so rules see points == null.
        'points': FieldValue.delete(),
        'matchedCount': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
