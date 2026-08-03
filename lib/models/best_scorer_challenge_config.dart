import 'package:cloud_firestore/cloud_firestore.dart';

/// Joueur proposé au défi « meilleur buteur » (liste admin).
class BestScorerPlayer {
  final String id;
  final String name;

  const BestScorerPlayer({required this.id, required this.name});

  factory BestScorerPlayer.fromMap(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    return BestScorerPlayer(
      id: (m['id'] ?? '').toString().trim(),
      name: (m['name'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  bool get isValid => id.isNotEmpty && name.isNotEmpty;
}

/// Config défi meilleur buteur — `app_config/best_scorer_challenge`.
class BestScorerChallengeConfig {
  static const String firestoreDocId = 'best_scorer_challenge';
  static const int bonusPoints = 10;

  final bool enabled;
  final String seasonId;
  final List<BestScorerPlayer> players;
  final String? resolvedPlayerId;
  final String? resolvedPlayerName;
  final DateTime? resolvedAt;
  final bool awardsApplied;
  final DateTime? awardsAppliedAt;

  const BestScorerChallengeConfig({
    required this.enabled,
    required this.seasonId,
    required this.players,
    this.resolvedPlayerId,
    this.resolvedPlayerName,
    this.resolvedAt,
    this.awardsApplied = false,
    this.awardsAppliedAt,
  });

  static String defaultSeasonId() {
    final now = DateTime.now();
    if (now.month >= 7) return '${now.year}-${now.year + 1}';
    return '${now.year - 1}-${now.year}';
  }

  static BestScorerChallengeConfig defaults = BestScorerChallengeConfig(
    enabled: false,
    seasonId: defaultSeasonId(),
    players: const [],
  );

  bool get isResolved =>
      resolvedPlayerId != null && resolvedPlayerId!.trim().isNotEmpty;

  /// Défi ouvert : les fans sans réponse sont bloqués à l’entrée Prono.
  bool get isGateActive => enabled && !isResolved && players.isNotEmpty;

  BestScorerPlayer? playerById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory BestScorerChallengeConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null || d.isEmpty) return defaults;
    final rawPlayers = d['players'];
    final players = <BestScorerPlayer>[];
    if (rawPlayers is List) {
      for (final item in rawPlayers) {
        if (item is Map) {
          final p = BestScorerPlayer.fromMap(Map<String, dynamic>.from(item));
          if (p.isValid) players.add(p);
        }
      }
    }
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final resolvedId = (d['resolvedPlayerId'] ?? '').toString().trim();
    return BestScorerChallengeConfig(
      enabled: d['enabled'] == true,
      seasonId: ((d['seasonId'] ?? '').toString().trim().isEmpty)
          ? defaultSeasonId()
          : (d['seasonId'] as Object).toString().trim(),
      players: players,
      resolvedPlayerId: resolvedId.isEmpty ? null : resolvedId,
      resolvedPlayerName: ((d['resolvedPlayerName'] ?? '').toString().trim().isEmpty)
          ? null
          : (d['resolvedPlayerName'] as Object).toString().trim(),
      resolvedAt: ts(d['resolvedAt']),
      awardsApplied: d['awardsApplied'] == true,
      awardsAppliedAt: ts(d['awardsAppliedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'enabled': enabled,
      'seasonId': seasonId.trim(),
      'players': players.map((p) => p.toMap()).toList(),
      'resolvedPlayerId': resolvedPlayerId,
      'resolvedPlayerName': resolvedPlayerName,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'awardsApplied': awardsApplied,
      'awardsAppliedAt':
          awardsAppliedAt != null ? Timestamp.fromDate(awardsAppliedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Payload admin save — ne touche pas aux champs de résolution (CF).
  Map<String, dynamic> toAdminSaveMap() {
    return {
      'enabled': enabled,
      'seasonId': seasonId.trim(),
      'players': players.map((p) => p.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  BestScorerChallengeConfig copyWith({
    bool? enabled,
    String? seasonId,
    List<BestScorerPlayer>? players,
    String? resolvedPlayerId,
    String? resolvedPlayerName,
    DateTime? resolvedAt,
    bool? awardsApplied,
    DateTime? awardsAppliedAt,
  }) {
    return BestScorerChallengeConfig(
      enabled: enabled ?? this.enabled,
      seasonId: seasonId ?? this.seasonId,
      players: players ?? this.players,
      resolvedPlayerId: resolvedPlayerId ?? this.resolvedPlayerId,
      resolvedPlayerName: resolvedPlayerName ?? this.resolvedPlayerName,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      awardsApplied: awardsApplied ?? this.awardsApplied,
      awardsAppliedAt: awardsAppliedAt ?? this.awardsAppliedAt,
    );
  }
}

/// Pari / ignore utilisateur — `prono_best_scorer_picks/{uid}`.
class BestScorerPick {
  static const String statusPicked = 'picked';
  static const String statusIgnored = 'ignored';

  final String uid;
  final String seasonId;
  final String status;
  final String playerId;
  final String playerName;
  final DateTime? pickedAt;
  final DateTime? ignoredAt;
  final bool awarded;

  const BestScorerPick({
    required this.uid,
    required this.seasonId,
    required this.status,
    required this.playerId,
    required this.playerName,
    this.pickedAt,
    this.ignoredAt,
    this.awarded = false,
  });

  bool get isPicked => status == statusPicked && playerId.trim().isNotEmpty;

  bool get isIgnored => status == statusIgnored;

  /// A levé le portail d’entrée Prono (pari ou ignore).
  bool get hasClearedGate => isPicked || isIgnored;

  factory BestScorerPick.fromMap(Map<String, dynamic>? d, {String? uid}) {
    final m = d ?? const <String, dynamic>{};
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final playerId = (m['playerId'] ?? '').toString().trim();
    final rawStatus = (m['status'] ?? '').toString().trim();
    // Rétrocompat : ancien doc sans status mais avec playerId = picked.
    final status = rawStatus.isNotEmpty
        ? rawStatus
        : (playerId.isNotEmpty ? statusPicked : '');

    return BestScorerPick(
      uid: (uid ?? m['uid'] ?? '').toString(),
      seasonId: (m['seasonId'] ?? '').toString(),
      status: status,
      playerId: playerId,
      playerName: (m['playerName'] ?? '').toString(),
      pickedAt: ts(m['pickedAt']),
      ignoredAt: ts(m['ignoredAt']),
      awarded: m['awarded'] == true,
    );
  }
}
