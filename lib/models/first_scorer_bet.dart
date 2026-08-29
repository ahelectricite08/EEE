import '../features/prono/domain/prono_lock.dart';
import '../utils/player_name_normalize.dart';

/// Config admin — `app_config/first_scorer_bet`.
///
/// Switch OFF : rien dans l’app (pas d’encart vide). Comme ticketing / VOD.
class FirstScorerBetConfig {
  static const String firestoreDocId = 'first_scorer_bet';

  /// Classement + XP : bon buteur CSSA = +3 pts et +10 XP.
  static const int sedanHitPoints = 3;
  static const int sedanHitXp = 10;
  static const String sedanHitXpEvent = 'first_scorer_cssa';
  static const int opponentHitPoints = 1;

  final bool enabled;

  const FirstScorerBetConfig({this.enabled = false});

  static const FirstScorerBetConfig defaults = FirstScorerBetConfig();

  bool get showInApp => enabled;

  factory FirstScorerBetConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return FirstScorerBetConfig(enabled: data['enabled'] == true);
  }

  Map<String, dynamic> toMap() => {'enabled': enabled};
}

/// Pari fan — `first_scorer_bets/{matchId}_{uid}`.
class FirstScorerBetPick {
  static const String kindSedan = 'sedan';
  static const String kindOpponent = 'opponent';

  final String uid;
  final String matchId;
  final String kind;
  final String playerId;
  final String playerName;
  final bool awarded;
  final int? points;
  final int? xp;

  const FirstScorerBetPick({
    required this.uid,
    required this.matchId,
    required this.kind,
    this.playerId = '',
    this.playerName = '',
    this.awarded = false,
    this.points,
    this.xp,
  });

  bool get isOpponent => kind == kindOpponent;

  bool get isSedanPlayer =>
      kind == kindSedan && playerName.trim().isNotEmpty;

  String get lockedLabel {
    if (isOpponent) return 'Adversaire';
    final n = playerName.trim();
    return n.isEmpty ? '—' : n;
  }

  factory FirstScorerBetPick.fromMap(
    Map<String, dynamic>? d, {
    String? uid,
    String? matchId,
  }) {
    final m = d ?? const <String, dynamic>{};
    final pts = m['points'];
    final xp = m['xp'];
    return FirstScorerBetPick(
      uid: (uid ?? m['uid'] ?? '').toString(),
      matchId: (matchId ?? m['matchId'] ?? '').toString(),
      kind: (m['kind'] ?? '').toString().trim(),
      playerId: (m['playerId'] ?? '').toString().trim(),
      playerName: (m['playerName'] ?? '').toString().trim(),
      awarded: m['awarded'] == true,
      points: pts is num ? pts.toInt() : null,
      xp: xp is num ? xp.toInt() : null,
    );
  }

  static String docId(String matchId, String uid) => '${matchId}_$uid';
}

/// 1er but connu (faits de jeu ou override admin).
class FirstScorerResolution {
  final String kind;
  final String playerId;
  final String playerName;

  const FirstScorerResolution({
    required this.kind,
    this.playerId = '',
    this.playerName = '',
  });

  bool get isOpponent => kind == FirstScorerBetPick.kindOpponent;

  bool get isSedan => kind == FirstScorerBetPick.kindSedan;

  factory FirstScorerResolution.fromOverride(Map<String, dynamic>? raw) {
    final m = raw ?? const <String, dynamic>{};
    final kind = (m['kind'] ?? '').toString().trim();
    return FirstScorerResolution(
      kind: kind,
      playerId: (m['playerId'] ?? '').toString().trim(),
      playerName: (m['playerName'] ?? '').toString().trim(),
    );
  }

  bool get isValidOverride =>
      kind == FirstScorerBetPick.kindOpponent ||
      (kind == FirstScorerBetPick.kindSedan && playerName.isNotEmpty);
}

/// Même horloge que le prono 1N2 : [isMatchPronoLocked] (`matches.date`).
bool firstScorerBetIsLocked({
  required DateTime kickoff,
  DateTime? now,
}) =>
    isMatchPronoLocked(kickoff, now: now);

bool firstScorerCssaPickHits({
  required FirstScorerBetPick pick,
  required FirstScorerResolution? resolved,
}) {
  if (resolved == null || !pick.isSedanPlayer || !resolved.isSedan) {
    return false;
  }
  if (pick.playerId.isNotEmpty &&
      resolved.playerId.isNotEmpty &&
      pick.playerId == resolved.playerId) {
    return true;
  }
  final a = normalizePlayerName(pick.playerName);
  final b = normalizePlayerName(resolved.playerName);
  return a.isNotEmpty && a == b;
}

int pointsForFirstScorerPick({
  required FirstScorerBetPick pick,
  required FirstScorerResolution? resolved,
}) {
  if (resolved == null) return 0;
  if (pick.isOpponent) {
    return resolved.isOpponent ? FirstScorerBetConfig.opponentHitPoints : 0;
  }
  return firstScorerCssaPickHits(pick: pick, resolved: resolved)
      ? FirstScorerBetConfig.sedanHitPoints
      : 0;
}

int xpForFirstScorerPick({
  required FirstScorerBetPick pick,
  required FirstScorerResolution? resolved,
}) {
  return firstScorerCssaPickHits(pick: pick, resolved: resolved)
      ? FirstScorerBetConfig.sedanHitXp
      : 0;
}

/// Domicile ou extérieur : l’encart ne vit que sur un match Sedan / CSSA.
bool firstScorerBetMatchInvolvesCssa(String team1, String team2) {
  return _isCssaTeamLabel(team1) || _isCssaTeamLabel(team2);
}

bool firstScorerBetMatchInvolvesCssaFromMap(Map<String, dynamic> match) {
  return firstScorerBetMatchInvolvesCssa(
    (match['team1'] ?? '').toString(),
    (match['team2'] ?? '').toString(),
  );
}

bool _isCssaTeamLabel(String name) {
  final u = name.toUpperCase();
  return u.contains('SEDAN') || u.contains('CSSA');
}

int _eventMinute(Map<String, dynamic> e) {
  final v = e['minute'];
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

bool _eventIsSedanSide(
  Map<String, dynamic> event,
  String team1,
  String team2,
) {
  final teamRaw =
      (event['team'] ?? event['teamName'] ?? '').toString().trim();
  if (teamRaw.isNotEmpty) {
    if (_isCssaTeamLabel(teamRaw)) return true;
    final u = teamRaw.toUpperCase();
    if (_isCssaTeamLabel(team1) && u == team1.trim().toUpperCase()) {
      return true;
    }
    if (_isCssaTeamLabel(team2) && u == team2.trim().toUpperCase()) {
      return true;
    }
  }
  final side = (event['side'] ?? event['teamSide'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final home = side == 'home' ||
      side == 'team1' ||
      event['isHome'] == true ||
      (event['teamIndex'] is num && (event['teamIndex'] as num).toInt() == 0);
  if (_isCssaTeamLabel(team1) && home) return true;
  if (_isCssaTeamLabel(team2) && !home && side.isNotEmpty) return true;
  if (_isCssaTeamLabel(team2) && event['isHome'] == false) return true;
  return false;
}

/// Premier but valable : `goal` (le live retire les buts annulés).
/// `own_goal` : ouvre le score pour l’équipe adverse du buteur.
FirstScorerResolution? resolveFirstScorerFromEvents({
  required List<Map<String, dynamic>> events,
  required String team1,
  required String team2,
  Map<String, dynamic>? override,
}) {
  final ov = FirstScorerResolution.fromOverride(override);
  if (ov.isValidOverride) return ov;

  final scored = <Map<String, dynamic>>[];
  for (final e in events) {
    final type = (e['type'] ?? '').toString().trim().toLowerCase();
    if (type == 'goal' || type == 'own_goal') scored.add(e);
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) => _eventMinute(a).compareTo(_eventMinute(b)));
  final first = scored.first;
  final type = (first['type'] ?? '').toString().trim().toLowerCase();
  final sedanSide = _eventIsSedanSide(first, team1, team2);
  final player = (first['player'] ?? '').toString().trim();

  if (type == 'own_goal') {
    if (sedanSide) {
      return const FirstScorerResolution(kind: FirstScorerBetPick.kindOpponent);
    }
    return FirstScorerResolution(
      kind: FirstScorerBetPick.kindSedan,
      playerName: player,
    );
  }

  if (sedanSide) {
    return FirstScorerResolution(
      kind: FirstScorerBetPick.kindSedan,
      playerName: player,
    );
  }
  return const FirstScorerResolution(kind: FirstScorerBetPick.kindOpponent);
}
