import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_router.dart';
import '../../models/match_lineup.dart';
import '../../models/match_model.dart';
import '../../models/match_stats_schema.dart';
import '../../models/sedan_squad.dart';
import '../../services/dvcr_share_service.dart';
import '../../services/lineup_prediction_service.dart';
import '../../services/match_rating_service.dart';
import '../../services/match_sheet_share_service.dart';
import '../matches/matches_helpers.dart';
import '../../services/sedan_squad_service.dart';
import '../../utils/remote_image_url.dart';
import '../../utils/save_image_to_gallery.dart';
import '../../widgets/dvcr_network_image.dart';
import '../../widgets/xi_mini_pitch.dart';
import '../../widgets/xi_player_verdict_list.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';
import 'profile_type.dart';

const double kMatchStoryW = 1080;
const double kMatchStoryH = 1920;

const Color _storyWhite = Color(0xFFFFFFFF);
const Color _storyInk = Color(0xFF0A1C18);
const Color _storyGreen = Color(0xFF0B3D2E);

enum MatchStoryKind { kickoff, lineup, goal, halfTime, fullTime }

class MatchStoryGoal {
  final String player;
  final int minute;
  final String? photoUrl;
  final bool ownGoal;

  const MatchStoryGoal({
    required this.player,
    required this.minute,
    this.photoUrl,
    this.ownGoal = false,
  });
}

class MatchStoryPayload {
  final MatchStoryKind kind;
  final String matchId;
  final String team1;
  final String team2;
  final String? logo1;
  final String? logo2;
  final int? score1;
  final int? score2;
  final DateTime date;
  final String competition;
  final List<MatchSheetScorer> sedanScorers;
  final List<MatchSheetScorer> opponentScorers;
  final MatchStoryGoal? goal;
  final List<SedanSquadPlayer> xiPlayers;
  final List<SedanSquadPlayer> opponentXiPlayers;
  final SedanSquad squad;
  final int yellow1;
  final int yellow2;
  final int red1;
  final int red2;

  const MatchStoryPayload({
    required this.kind,
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.date,
    required this.sedanScorers,
    this.opponentScorers = const [],
    this.xiPlayers = const [],
    this.opponentXiPlayers = const [],
    this.logo1,
    this.logo2,
    this.score1,
    this.score2,
    this.competition = '',
    this.goal,
    this.squad = SedanSquad.empty,
    this.yellow1 = 0,
    this.yellow2 = 0,
    this.red1 = 0,
    this.red2 = 0,
  });

  String get scoreLabel {
    if (score1 == null || score2 == null) return '—';
    return '$score1 – $score2';
  }

  String get opponentName {
    if (MatchSheetShareService.isCssaTeamLabel(team1)) return team2;
    if (MatchSheetShareService.isCssaTeamLabel(team2)) return team1;
    return team2;
  }

  String get appBarTitle => switch (kind) {
        MatchStoryKind.kickoff => 'Coup d’envoi',
        MatchStoryKind.lineup => 'Composition',
        MatchStoryKind.goal => 'But',
        MatchStoryKind.halfTime => 'Mi-temps',
        MatchStoryKind.fullTime => 'Fin de match',
      };

  String get storyHeadline => switch (kind) {
        MatchStoryKind.kickoff => 'COUP D’ENVOI',
        MatchStoryKind.lineup => 'COMPOSITION',
        MatchStoryKind.goal => 'BUT !!!',
        MatchStoryKind.halfTime => 'MI-TEMPS',
        MatchStoryKind.fullTime => 'FIN DE MATCH',
      };

  /// Pied média DVCR — pas CSSA / Sedan.
  String get storyFooter => 'DVCR  ·  DRAPEAU VERT CARTON ROUGE';

  /// Écusson CSSA du match (domicile ou extérieur).
  String? get cssaLogoUrl {
    if (MatchSheetShareService.isCssaTeamLabel(team1)) {
      final u = (logo1 ?? '').trim();
      return u.isEmpty ? null : u;
    }
    if (MatchSheetShareService.isCssaTeamLabel(team2)) {
      final u = (logo2 ?? '').trim();
      return u.isEmpty ? null : u;
    }
    return null;
  }

  /// Écusson de l’adversaire (domicile ou extérieur).
  String? get opponentLogoUrl {
    if (MatchSheetShareService.isCssaTeamLabel(team1)) {
      final u = (logo2 ?? '').trim();
      return u.isEmpty ? null : u;
    }
    if (MatchSheetShareService.isCssaTeamLabel(team2)) {
      final u = (logo1 ?? '').trim();
      return u.isEmpty ? null : u;
    }
    final u = (logo2 ?? '').trim();
    return u.isEmpty ? null : u;
  }

  /// Écusson de l’équipe qui a marqué (kit actuel = CSSA, hors c.s.c.).
  String? get scoringTeamLogoUrl => cssaLogoUrl;

  String get scoringTeamName {
    if (MatchSheetShareService.isCssaTeamLabel(team1)) return team1;
    if (MatchSheetShareService.isCssaTeamLabel(team2)) return team2;
    return 'CSSA';
  }

  String get chromeHeadline => storyHeadline;

  String get shareCaption {
    final vs = '$team1 — $team2';
    switch (kind) {
      case MatchStoryKind.kickoff:
        return 'Coup d’envoi $vs — rendez-vous sur YouTube dès maintenant !';
      case MatchStoryKind.lineup:
        return 'Composition du jour $vs';
      case MatchStoryKind.goal:
        final g = goal;
        if (g == null) return 'But $vs';
        final min = g.minute > 0 ? "${g.minute}'" : '';
        return 'But ${g.player} $min $vs'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      case MatchStoryKind.halfTime:
        return 'Mi-temps $vs $scoreLabel';
      case MatchStoryKind.fullTime:
        return 'Fin de match $vs $scoreLabel — restez avec nous pour l’après-match !';
    }
  }

  factory MatchStoryPayload.fromMerged({
    required MatchStoryKind kind,
    required String matchId,
    required Map<String, dynamic> data,
    required SedanSquad squad,
    MatchSheetScorer? goal,
  }) {
    final match = storyMatchFrom(matchId, data);
    final sedanScorers =
        MatchSheetShareService.scorersFromDoc(data, cssa: true);
    final opponentScorers =
        MatchSheetShareService.scorersFromDoc(data, cssa: false);
    var xiPlayers = const <SedanSquadPlayer>[];
    var opponentXiPlayers = const <SedanSquadPlayer>[];
    if (kind == MatchStoryKind.lineup) {
      final lineups = MatchLineups.mergeForMotm(data);
      final side = cssaLineupSide(lineups, match);
      final starters =
          side?.starters.where((e) => e.trim().isNotEmpty) ?? const <String>[];
      xiPlayers = XiComparePitches.playersFromLabels(squad, starters);
      final oppSide = opponentLineupSide(lineups, match);
      opponentXiPlayers = [
        for (final raw in oppSide?.starters ?? const <String>[])
          if (raw.trim().isNotEmpty) SedanSquad.placeholderFromLabel(raw),
      ];
    }
    final cards = storyCardTally(data);
    MatchStoryGoal? storyGoal;
    if (kind == MatchStoryKind.goal &&
        goal != null &&
        goal.player.trim().isNotEmpty) {
      final face = squad.matchVoteLabel(goal.player, sedanSide: true) ??
          squad.matchLineupLabel(goal.player);
      storyGoal = MatchStoryGoal(
        player: goal.player.trim(),
        minute: goal.minute,
        photoUrl: face?.photoUrl,
        ownGoal: goal.ownGoal,
      );
    }
    return MatchStoryPayload(
      kind: kind,
      matchId: matchId,
      team1: match.team1,
      team2: match.team2,
      logo1: match.logo1,
      logo2: match.logo2,
      score1: MatchModel.parseScoreField(
        data['score1'] ?? data['scoreHome'] ?? data['homeScore'],
      ),
      score2: MatchModel.parseScoreField(
        data['score2'] ?? data['scoreAway'] ?? data['awayScore'],
      ),
      date: match.date,
      competition: match.competition,
      sedanScorers: sedanScorers,
      opponentScorers: opponentScorers,
      goal: storyGoal,
      xiPlayers: xiPlayers,
      opponentXiPlayers: opponentXiPlayers,
      squad: squad,
      yellow1: cards.yellow1,
      yellow2: cards.yellow2,
      red1: cards.red1,
      red2: cards.red2,
    );
  }
}

MatchModel storyMatchFrom(String id, Map<String, dynamic> data) {
  final date = MatchRatingService.parseDateTime(data['date']) ?? DateTime.now();
  final team1 = (data['team1'] as String? ?? 'Équipe 1').trim();
  final team2 = (data['team2'] as String? ?? 'Équipe 2').trim();
  final competition = (data['competition'] as String? ?? '').trim();
  final score1 = MatchModel.parseScoreField(
    data['score1'] ?? data['scoreHome'] ?? data['homeScore'],
  );
  final score2 = MatchModel.parseScoreField(
    data['score2'] ?? data['scoreAway'] ?? data['awayScore'],
  );
  return MatchModel(
    id: id,
    team1: team1.isEmpty ? 'Équipe 1' : team1,
    team2: team2.isEmpty ? 'Équipe 2' : team2,
    logo1: (data['logo1'] as String?)?.trim(),
    logo2: (data['logo2'] as String?)?.trim(),
    score1: score1,
    score2: score2,
    date: date,
    competition: competition,
    status: MatchModel.resolveDisplayStatus(
      rawStatus: data['status']?.toString(),
      date: date,
      score1: score1,
      score2: score2,
    ),
  );
}

MatchLineupSide? cssaLineupSide(MatchLineups lineups, MatchModel match) {
  if (MatchSheetShareService.isCssaTeamLabel(match.team1)) return lineups.home;
  if (MatchSheetShareService.isCssaTeamLabel(match.team2)) return lineups.away;
  return LineupPredictionService.sedanSide(lineups, match);
}

MatchLineupSide? opponentLineupSide(MatchLineups lineups, MatchModel match) {
  if (MatchSheetShareService.isCssaTeamLabel(match.team1)) return lineups.away;
  if (MatchSheetShareService.isCssaTeamLabel(match.team2)) return lineups.home;
  return null;
}

String matchStoryLastName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final withoutNum =
      trimmed.replaceFirst(RegExp(r'^\d+\s*[-.]?\s*'), '').trim();
  final parts =
      withoutNum.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return trimmed.toUpperCase();
  return parts.last.toUpperCase();
}

@visibleForTesting
String? pickStoryCrest(Map<String, String> index, String team) {
  final t = team.trim();
  if (t.isEmpty) return null;
  final direct = index[t] ?? index[normalizeTeamLabel(t)];
  if (direct != null && direct.trim().isNotEmpty) return direct.trim();
  for (final e in index.entries) {
    if (teamMatchesPreference(t, e.key) || teamMatchesPreference(e.key, t)) {
      final u = e.value.trim();
      if (u.isNotEmpty) return u;
    }
  }
  return null;
}

Future<Map<String, String>> _storyCrestIndex() async {
  final byExact = <String, String>{};
  final byNorm = <String, String>{};
  void put(String team, String? logo) {
    final t = team.trim();
    final u = (logo ?? '').trim();
    if (t.isEmpty || u.isEmpty) return;
    byExact.putIfAbsent(t, () => u);
    byNorm.putIfAbsent(normalizeTeamLabel(t), () => u);
  }

  final db = FirebaseFirestore.instance;
  Future<void> fromCol(
    String col, {
    String? teamKey,
    String? logoKey,
    bool matchSides = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> q = db.collection(col);
      if (limit != null) {
        q = q.orderBy('date', descending: true).limit(limit);
      }
      final snap = await q.get();
      for (final doc in snap.docs) {
        final d = doc.data();
        if (matchSides) {
          put((d['team1'] as String?) ?? '', d['logo1'] as String?);
          put((d['team2'] as String?) ?? '', d['logo2'] as String?);
        } else {
          put(
            (d[teamKey ?? 'team'] as String?) ??
                (d['shortName'] as String?) ??
                '',
            d[logoKey ?? 'logo'] as String?,
          );
        }
      }
    } catch (_) {}
  }

  await fromCol('ranking');
  await fromCol('ranking_r2');
  await fromCol('fff_club_logos', teamKey: 'shortName');
  await fromCol('matches', matchSides: true, limit: 160);
  await fromCol('matches_r2', matchSides: true, limit: 80);
  return {
    ...byNorm,
    ...byExact,
  };
}

/// Complète logo1 / logo2 depuis le classement FFF si la fiche est vide.
Future<Map<String, dynamic>> fillStoryTeamLogos(
  Map<String, dynamic> data,
) async {
  final team1 = (data['team1'] as String? ?? '').trim();
  final team2 = (data['team2'] as String? ?? '').trim();
  var logo1 = (data['logo1'] as String? ?? '').trim();
  var logo2 = (data['logo2'] as String? ?? '').trim();
  if (logo1.isNotEmpty && logo2.isNotEmpty) return data;
  try {
    final index = await _storyCrestIndex();
    if (logo1.isEmpty) logo1 = pickStoryCrest(index, team1) ?? '';
    if (logo2.isEmpty) logo2 = pickStoryCrest(index, team2) ?? '';
  } catch (_) {}
  if (logo1.isEmpty && logo2.isEmpty) return data;
  final out = Map<String, dynamic>.from(data);
  if (logo1.isNotEmpty) out['logo1'] = logo1;
  if (logo2.isNotEmpty) out['logo2'] = logo2;
  return out;
}

@visibleForTesting
String storyTeamInitials(String name) {
  final parts = name
      .trim()
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.length <= 4 ? w : w.substring(0, 3);
  }
  return parts.take(3).map((e) => e[0]).join();
}

String kitMatchTitle(Map<String, dynamic> data) {
  final t1 = (data['team1'] as String? ?? '').trim();
  final t2 = (data['team2'] as String? ?? '').trim();
  if (t1.isEmpty && t2.isEmpty) return '';
  if (MatchSheetShareService.isCssaTeamLabel(t1)) {
    return t2.isEmpty ? t1 : '$t1 — $t2';
  }
  if (MatchSheetShareService.isCssaTeamLabel(t2)) {
    return t1.isEmpty ? t2 : '$t2 — $t1';
  }
  if (t1.isEmpty) return t2;
  if (t2.isEmpty) return t1;
  return '$t1 — $t2';
}

List<MatchSheetScorer> cssaGoalStoryScorers(Map<String, dynamic> data) {
  return MatchSheetShareService.scorersFromDoc(data, cssa: true)
      .where((s) => !s.ownGoal)
      .toList();
}

bool hasSedanStoryStarters(Map<String, dynamic> data) {
  final id = MatchSheetShareService.storyMatchIdOf(data);
  final match = storyMatchFrom(id.isEmpty ? 'match' : id, data);
  final lineups = MatchLineups.mergeForMotm(data);
  final side = cssaLineupSide(lineups, match);
  if (side == null) return false;
  return side.starters.any((e) => e.trim().isNotEmpty);
}

({String id, Map<String, dynamic> data})? pickMatchStorySource({
  Map<String, dynamic>? live,
  required List<({String id, Map<String, dynamic> data})> matches,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final byId = <String, Map<String, dynamic>>{
    for (final m in matches) m.id: m.data,
  };

  final liveId = (live?['matchId'] as String? ?? '').trim();
  if (liveId.isNotEmpty && live != null) {
    final merged = MatchSheetShareService.composeStoryDoc(
      live: live,
      match: byId[liveId],
    );
    merged['matchId'] = liveId;
    if (MatchSheetShareService.isSedanPremiereMatch(merged)) {
      return (id: liveId, data: merged);
    }
  }

  final premiere = <({String id, Map<String, dynamic> data})>[];
  for (final m in matches) {
    final data = Map<String, dynamic>.from(m.data)..['matchId'] = m.id;
    if (MatchSheetShareService.isSedanPremiereMatch(data)) {
      premiere.add((id: m.id, data: data));
    }
  }
  if (premiere.isEmpty) return null;

  final cutoff = t.subtract(const Duration(hours: 6));
  final upcoming = premiere.where((m) {
    final d = MatchRatingService.parseDateTime(m.data['date']);
    return d != null && !d.isBefore(cutoff);
  }).toList()
    ..sort((a, b) {
      final da = MatchRatingService.parseDateTime(a.data['date'])!;
      final db = MatchRatingService.parseDateTime(b.data['date'])!;
      return da.compareTo(db);
    });
  if (upcoming.isNotEmpty) return upcoming.first;

  premiere.sort((a, b) {
    final da = MatchRatingService.parseDateTime(a.data['date']);
    final db = MatchRatingService.parseDateTime(b.data['date']);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return premiere.first;
}

SedanSquadPlayer storyFaceForScorer(
  SedanSquad squad,
  MatchSheetScorer scorer, {
  bool cssa = true,
}) {
  if (!cssa || scorer.ownGoal) {
    return SedanSquad.placeholderFromLabel(scorer.player);
  }
  return squad.matchVoteLabel(scorer.player, sedanSide: true) ??
      squad.matchLineupLabel(scorer.player) ??
      SedanSquad.placeholderFromLabel(scorer.player);
}

@visibleForTesting
List<({MatchSheetScorer scorer, bool cssa})> storyRecapGoalRows(
  MatchStoryPayload payload,
) {
  final rows = <({MatchSheetScorer scorer, bool cssa})>[
    for (final s in payload.sedanScorers) (scorer: s, cssa: true),
    for (final s in payload.opponentScorers) (scorer: s, cssa: false),
  ];
  rows.sort((a, b) => a.scorer.minute.compareTo(b.scorer.minute));
  return rows.take(10).toList();
}

@visibleForTesting
double storyRecapFaceSize({
  required int count,
  required double maxHeight,
}) {
  if (count <= 0) return 72;
  final slot = maxHeight / count;
  final cap = switch (count) {
    1 => 300.0,
    2 => 220.0,
    3 => 176.0,
    4 => 140.0,
    _ => 100.0,
  };
  final floor = count <= 2 ? 128.0 : 64.0;
  return (slot * (count == 1 ? 0.42 : 0.62)).clamp(floor, cap);
}

class StoryCardTally {
  final int yellow1;
  final int yellow2;
  final int red1;
  final int red2;

  const StoryCardTally({
    this.yellow1 = 0,
    this.yellow2 = 0,
    this.red1 = 0,
    this.red2 = 0,
  });
}

int _storyIntField(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse('$raw'.trim()) ?? 0;
}

@visibleForTesting
StoryCardTally storyCardTally(Map<String, dynamic> data) {
  final t1 = (data['team1'] as String? ?? '').trim();
  final t2 = (data['team2'] as String? ?? '').trim();
  final events = [
    for (final e in MatchStatsSchema.eventsFromMatchDoc(data))
      {
        ...e,
        'type': MatchStatsSchema.normalizeGameEventType(e['type']),
      },
  ];
  final counted = MatchStatsSchema.countFromEvents(events, t1, t2);
  var yellow1 = counted.yellowHome;
  var yellow2 = counted.yellowAway;
  var red1 = counted.redHome;
  var red2 = counted.redAway;
  if (yellow1 + yellow2 + red1 + red2 == 0) {
    yellow1 = _storyIntField(data['yellowHome']);
    yellow2 = _storyIntField(data['yellowAway']);
    red1 = _storyIntField(data['redHome']);
    red2 = _storyIntField(data['redAway']);
  }
  return StoryCardTally(
    yellow1: yellow1,
    yellow2: yellow2,
    red1: red1,
    red2: red2,
  );
}

Future<void> openMatchStory(
  BuildContext context, {
  required MatchStoryKind kind,
  required Map<String, dynamic> data,
  MatchSheetScorer? goal,
}) async {
  void snack(String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  try {
    final merged = await fillStoryTeamLogos(
      await MatchSheetShareService.instance.mergeStorySource(data),
    );
    if (!context.mounted) return;
    final matchId = MatchSheetShareService.storyMatchIdOf(merged);
    final squad = await SedanSquadService.get();
    if (!context.mounted) return;

    if (kind == MatchStoryKind.lineup) {
      final match = storyMatchFrom(matchId.isEmpty ? 'match' : matchId, merged);
      final lineups = MatchLineups.mergeForMotm(merged);
      final side = cssaLineupSide(lineups, match);
      final starters =
          side?.starters.where((e) => e.trim().isNotEmpty).toList() ??
              const <String>[];
      if (starters.isEmpty) {
        snack('XI Sedan pas encore publié');
        return;
      }
    }

    if (kind == MatchStoryKind.goal) {
      if (goal == null || goal.player.trim().isEmpty || goal.ownGoal) {
        snack('Buteur CSSA manquant');
        return;
      }
    }

    final payload = MatchStoryPayload.fromMerged(
      kind: kind,
      matchId: matchId.isEmpty ? 'match' : matchId,
      data: merged,
      squad: squad,
      goal: goal,
    );

    NavigatorState? nav;
    if (context.mounted) {
      nav = Navigator.of(context, rootNavigator: true);
    }
    nav ??= dvcrNavigatorKey.currentState;
    if (nav == null || !nav.mounted) return;
    await nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MatchStoryVisualScreen(payload: payload),
      ),
    );
  } catch (_) {
    snack('Impossible d’ouvrir le visuel.');
  }
}

class MatchStoryVisualScreen extends StatefulWidget {
  final MatchStoryPayload payload;

  const MatchStoryVisualScreen({super.key, required this.payload});

  @override
  State<MatchStoryVisualScreen> createState() => _MatchStoryVisualScreenState();
}

class _MatchStoryVisualScreenState extends State<MatchStoryVisualScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _fileBase {
    String slug(String s) {
      final t = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return t.length <= 12 ? t : t.substring(0, 12);
    }

    final kind = switch (widget.payload.kind) {
      MatchStoryKind.kickoff => 'kickoff',
      MatchStoryKind.lineup => 'lineup',
      MatchStoryKind.goal => 'goal',
      MatchStoryKind.halfTime => 'halftime',
      MatchStoryKind.fullTime => 'fulltime',
    };
    return 'dvcr_story_${kind}_${slug(widget.payload.team1)}_${slug(widget.payload.team2)}';
  }

  Future<Uint8List?> _capturePng() async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null || bytes.isEmpty) throw StateError('capture');
      final name = '$_fileBase.png';
      final caption = widget.payload.shareCaption;
      if (!mounted) return;
      if (kIsWeb) {
        await DvcrShare.shareLocalFiles(
          [
            XFile.fromData(bytes, mimeType: 'image/png', name: name),
          ],
          text: caption,
          subject: 'Story DVCR',
          context: context,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/dvcr_story_${DateTime.now().millisecondsSinceEpoch}.png';
        final tmp = File(path);
        await tmp.writeAsBytes(bytes, flush: true);
        if (!mounted) return;
        await DvcrShare.shareLocalFiles(
          [XFile(tmp.path, mimeType: 'image/png', name: name)],
          text: caption,
          subject: 'Story DVCR',
          context: context,
        );
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec du partage. Réessaie.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null || bytes.isEmpty) throw StateError('capture');
      final name = '$_fileBase.png';
      if (kIsWeb) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le visuel',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const ['png'],
          bytes: bytes,
        );
        if (!mounted) return;
        if (path == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visuel enregistré.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        );
        return;
      }

      final result = await saveImageToGallery(bytes, name: _fileBase);
      if (!mounted) return;
      switch (result) {
        case SaveImageToGalleryResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Enregistré dans la galerie',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
        case SaveImageToGalleryResult.denied:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Autorise l’accès à la galerie pour enregistrer.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
        case SaveImageToGalleryResult.unsupported:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Échec de l’enregistrement. Réessaie.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de l’enregistrement. Réessaie.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, widget.payload.appBarTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Visuel portrait 9:16 — à publier en story.',
              style: ProfileType.caption,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const aspect = kMatchStoryW / kMatchStoryH;
                  final maxW = constraints.maxWidth.clamp(0.0, 360.0);
                  final maxH = constraints.maxHeight;
                  var w = maxW;
                  var h = w / aspect;
                  if (h > maxH && maxH > 0) {
                    h = maxH;
                    w = h * aspect;
                  }
                  return Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _storyWhite,
                        border: Border.all(color: _storyInk, width: 1),
                      ),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: kMatchStoryW,
                            height: kMatchStoryH,
                            child: RepaintBoundary(
                              key: _boundaryKey,
                              child: MatchStoryCard(payload: widget.payload),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _PaperAction(
                      label: 'Enregistrer',
                      icon: Icons.download_outlined,
                      onTap: _busy ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaperAction(
                      label: 'Partager',
                      icon: Icons.ios_share_outlined,
                      ink: true,
                      onTap: _busy ? null : _share,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool ink;

  const _PaperAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.ink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ink ? profileGreen : profileSurface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: ink ? profileGreen : profileHairline,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: ink ? Colors.white : profileGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ink ? Colors.white : profileGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchStoryCard extends StatelessWidget {
  final MatchStoryPayload payload;

  const MatchStoryCard({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return _StoryChrome(
      headline: payload.chromeHeadline,
      footer: payload.storyFooter,
      headerCrestUrl:
          payload.kind == MatchStoryKind.lineup ? payload.cssaLogoUrl : null,
      showHeaderCrest: payload.kind == MatchStoryKind.lineup,
      body: switch (payload.kind) {
        MatchStoryKind.kickoff => _KickoffBody(payload: payload),
        MatchStoryKind.lineup => _LineupBody(payload: payload),
        MatchStoryKind.goal => _GoalBody(payload: payload),
        MatchStoryKind.halfTime ||
        MatchStoryKind.fullTime =>
          _ScoreRecapBody(payload: payload),
      },
    );
  }
}

class _StoryChrome extends StatelessWidget {
  final String headline;
  final String footer;
  final Widget body;
  final String? headerCrestUrl;
  final bool showHeaderCrest;

  const _StoryChrome({
    required this.headline,
    required this.footer,
    required this.body,
    this.headerCrestUrl,
    this.showHeaderCrest = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _storyWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ColoredBox(color: _storyGreen, child: SizedBox(height: 14)),
          ColoredBox(
            color: _storyGreen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 8, 44, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DVCR',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: _storyWhite,
                            height: 1,
                          ),
                        ),
                        if (headline.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              headline,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: headline.contains('!!!') ? 148 : 92,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: _storyWhite,
                                height: 0.88,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showHeaderCrest) ...[
                    const SizedBox(width: 20),
                    _StoryRoundCrest(
                      url: headerCrestUrl,
                      fallbackName: 'CSSA',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const ColoredBox(color: _storyInk, child: SizedBox(height: 3)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(44, 36, 44, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: body),
                  const ColoredBox(
                    color: _storyGreen,
                    child: SizedBox(height: 3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    footer,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: _storyGreen,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          const ColoredBox(color: _storyGreen, child: SizedBox(height: 14)),
        ],
      ),
    );
  }
}

class _KickoffBody extends StatelessWidget {
  final MatchStoryPayload payload;

  const _KickoffBody({required this.payload});

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('d MMMM yyyy', 'fr_FR').format(payload.date).toUpperCase();
    final meta = [
      if (payload.competition.isNotEmpty) payload.competition,
      dateLabel,
    ].join('  ·  ').toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: _StoryTeamCol(name: payload.team1, logoUrl: payload.logo1),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'VS',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: _storyGreen,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _StoryTeamCol(
                name: payload.team2,
                logoUrl: payload.logo2,
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          meta,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: _storyInk,
          ),
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'C’EST PARTI',
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 136,
              fontWeight: FontWeight.w900,
              color: _storyGreen,
              height: 0.9,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 40),
        const _KickoffYoutubeCta(),
        const Spacer(),
      ],
    );
  }
}

class _KickoffYoutubeCta extends StatelessWidget {
  const _KickoffYoutubeCta();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _YoutubePlayMark(size: 92),
            const SizedBox(width: 22),
            Flexible(
              child: Text(
                'RENDEZ-VOUS SUR YOUTUBE',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: _storyInk,
                  height: 0.95,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'DÈS MAINTENANT',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 52,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
            color: _storyGreen,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _YoutubePlayMark extends StatelessWidget {
  final double size;

  const _YoutubePlayMark({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.42,
      height: size,
      child: const CustomPaint(painter: _YoutubePlayPainter()),
    );
  }
}

class _YoutubePlayPainter extends CustomPainter {
  const _YoutubePlayPainter();

  static const _red = Color(0xFFFF0000);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.22),
    );
    canvas.drawRRect(rrect, Paint()..color = _red);
    final play = Path()
      ..moveTo(size.width * 0.38, size.height * 0.28)
      ..lineTo(size.width * 0.38, size.height * 0.72)
      ..lineTo(size.width * 0.74, size.height * 0.50)
      ..close();
    canvas.drawPath(play, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineupBody extends StatelessWidget {
  final MatchStoryPayload payload;

  const _LineupBody({required this.payload});

  @override
  Widget build(BuildContext context) {
    final opp = payload.opponentXiPlayers;
    if (opp.isEmpty) {
      return _StoryXiPitch(players: payload.xiPlayers);
    }
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _StoryXiPitch(
            players: payload.xiPlayers,
            faceSize: 132,
            nameSize: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          payload.opponentName.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: _storyInk,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: _StoryXiPitch(
            players: opp,
            faceSize: 108,
            nameSize: 22,
            genericAll: true,
          ),
        ),
      ],
    );
  }
}

class _StoryXiPitch extends StatelessWidget {
  final List<SedanSquadPlayer> players;
  final double faceSize;
  final double nameSize;
  final bool genericAll;

  const _StoryXiPitch({
    required this.players,
    this.faceSize = 168,
    this.nameSize = 30,
    this.genericAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final slots = List<SedanSquadPlayer?>.from(xiFormationSlots(players));
    while (slots.length < 11) {
      slots.add(null);
    }

    Widget face(SedanSquadPlayer? p) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoryPlayerDisc(
            player: p,
            size: faceSize,
            generic: genericAll || p == null || !p.hasPhoto,
          ),
          const SizedBox(height: 8),
          Text(
            p == null ? '' : matchStoryLastName(p.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: nameSize,
              fontWeight: FontWeight.w800,
              color: _storyWhite,
              height: 1,
              shadows: const [
                Shadow(blurRadius: 8, color: Color(0xCC000000)),
              ],
            ),
          ),
        ],
      );
    }

    Widget row(int start, int count) {
      return Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: Center(child: face(slots[start + i]))),
          ],
        ],
      );
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF234D2B)),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Transform.scale(
              scale: 1.08,
              child: Image.asset(
                XiMiniPitch.pitchAsset,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.78),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
            child: Column(
              children: [
                row(0, 1),
                const Spacer(),
                row(1, 4),
                const Spacer(),
                row(5, 3),
                const Spacer(),
                row(8, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBody extends StatelessWidget {
  final MatchStoryPayload payload;

  const _GoalBody({required this.payload});

  @override
  Widget build(BuildContext context) {
    final g = payload.goal;
    final name = (g?.player ?? '').trim();
    final minute = g?.minute ?? 0;
    final minuteLabel = minute > 0 ? "$minute'" : '';

    return Column(
      children: [
        const Spacer(),
        _GoalFace(goal: g),
        const SizedBox(height: 28),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 84,
              fontWeight: FontWeight.w900,
              color: _storyInk,
              height: 0.9,
            ),
          ),
        ),
        if (minuteLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            minuteLabel,
            style: GoogleFonts.barlowCondensed(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: _storyGreen,
              height: 0.92,
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _StoryRoundCrest(
                  url: payload.logo1,
                  fallbackName: payload.team1,
                  size: 140,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                payload.scoreLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 88,
                  fontWeight: FontWeight.w900,
                  color: _storyInk,
                  height: 0.9,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StoryRoundCrest(
                  url: payload.logo2,
                  fallbackName: payload.team2,
                  size: 140,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _GoalFace extends StatelessWidget {
  final MatchStoryGoal? goal;

  const _GoalFace({required this.goal});

  @override
  Widget build(BuildContext context) {
    const size = 520.0;
    final url = (goal?.photoUrl ?? '').trim();
    final show = url.isNotEmpty && !shouldSkipNetworkImageUrl(url);
    final raw = (goal?.player ?? '').trim();
    final last = matchStoryLastName(raw);
    final initial = last.isNotEmpty
        ? last.substring(0, 1)
        : (raw.isNotEmpty ? raw.substring(0, 1).toUpperCase() : '?');

    Widget fallback = ColoredBox(
      color: _storyGreen,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.barlowCondensed(
            fontSize: 220,
            fontWeight: FontWeight.w900,
            color: _storyWhite,
            height: 1,
          ),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _storyGreen,
        border: Border.all(color: _storyGreen, width: 8),
      ),
      clipBehavior: Clip.antiAlias,
      child: show
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              filterQuality: FilterQuality.high,
              headers: kDvcrImageHttpHeaders,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}

class _ScoreRecapBody extends StatelessWidget {
  final MatchStoryPayload payload;

  const _ScoreRecapBody({required this.payload});

  @override
  Widget build(BuildContext context) {
    final rows = storyRecapGoalRows(payload);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: _StoryTeamCol(
                name: payload.team1,
                logoUrl: payload.logo1,
                compact: true,
                yellow: payload.yellow1,
                red: payload.red1,
              ),
            ),
            Expanded(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  payload.scoreLabel,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 168,
                    fontWeight: FontWeight.w900,
                    color: _storyInk,
                    height: 0.9,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _StoryTeamCol(
                name: payload.team2,
                logoUrl: payload.logo2,
                alignEnd: true,
                compact: true,
                yellow: payload.yellow2,
                red: payload.red2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const ColoredBox(color: _storyInk, child: SizedBox(height: 1)),
        const SizedBox(height: 20),
        if (rows.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'AUCUN BUT',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: _storyInk,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final face = storyRecapFaceSize(
                  count: rows.length,
                  maxHeight: constraints.maxHeight,
                );
                if (rows.length == 1) {
                  return Center(
                    child: _RecapScorerHero(
                      payload: payload,
                      row: rows.first,
                      face: face,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final row in rows)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _RecapScorerRow(
                            payload: payload,
                            row: row,
                            face: face,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        if (payload.kind == MatchStoryKind.fullTime) ...[
          const SizedBox(height: 18),
          const _AfterMatchYoutubeCta(),
        ],
      ],
    );
  }
}

class _AfterMatchYoutubeCta extends StatelessWidget {
  const _AfterMatchYoutubeCta();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _storyGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _storyGreen, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 26, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _YoutubePlayMark(size: 72),
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    'RESTEZ AVEC NOUS',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: _storyWhite,
                      height: 0.95,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'POUR L’APRÈS-MATCH',
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: _storyWhite,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapScorerHero extends StatelessWidget {
  final MatchStoryPayload payload;
  final ({MatchSheetScorer scorer, bool cssa}) row;
  final double face;

  const _RecapScorerHero({
    required this.payload,
    required this.row,
    required this.face,
  });

  @override
  Widget build(BuildContext context) {
    final s = row.scorer;
    final minute = s.minute > 0 ? "${s.minute}'" : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RecapPlayerDisc(payload: payload, row: row, size: face),
        const SizedBox(height: 18),
        _StoryRoundCrest(
          url: row.cssa ? payload.cssaLogoUrl : payload.opponentLogoUrl,
          fallbackName: row.cssa ? payload.scoringTeamName : payload.opponentName,
          size: 72,
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            s.player.trim().toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: GoogleFonts.barlowCondensed(
              fontSize: 86,
              fontWeight: FontWeight.w900,
              color: _storyInk,
              height: 0.9,
            ),
          ),
        ),
        if (minute.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            minute,
            style: GoogleFonts.barlowCondensed(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: _storyGreen,
              height: 0.92,
            ),
          ),
        ],
      ],
    );
  }
}

class _RecapScorerRow extends StatelessWidget {
  final MatchStoryPayload payload;
  final ({MatchSheetScorer scorer, bool cssa}) row;
  final double face;

  const _RecapScorerRow({
    required this.payload,
    required this.row,
    required this.face,
  });

  @override
  Widget build(BuildContext context) {
    final s = row.scorer;
    final nameSize = (face * 0.42).clamp(28.0, 64.0);
    final minute = s.minute > 0 ? "${s.minute}'" : '';
    return Row(
      children: [
        _RecapPlayerDisc(payload: payload, row: row, size: face),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.player.trim().toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.barlowCondensed(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w900,
                  color: _storyInk,
                  height: 1.0,
                ),
              ),
              if (minute.isNotEmpty)
                Text(
                  minute,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: (nameSize * 0.78).clamp(22.0, 48.0),
                    fontWeight: FontWeight.w800,
                    color: _storyGreen,
                    height: 1.05,
                  ),
                ),
            ],
          ),
        ),
        _StoryRoundCrest(
          url: row.cssa ? payload.cssaLogoUrl : payload.opponentLogoUrl,
          fallbackName: row.cssa ? payload.scoringTeamName : payload.opponentName,
          size: (face * 0.48).clamp(40.0, 72.0),
        ),
      ],
    );
  }
}

class _RecapPlayerDisc extends StatelessWidget {
  final MatchStoryPayload payload;
  final ({MatchSheetScorer scorer, bool cssa}) row;
  final double size;

  const _RecapPlayerDisc({
    required this.payload,
    required this.row,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final player = storyFaceForScorer(
      payload.squad,
      row.scorer,
      cssa: row.cssa,
    );
    return _StoryPlayerDisc(
      player: player,
      size: size,
      generic: !row.cssa || !player.hasPhoto,
    );
  }
}

class _StoryPlayerDisc extends StatelessWidget {
  final SedanSquadPlayer? player;
  final double size;
  final bool generic;

  const _StoryPlayerDisc({
    required this.player,
    required this.size,
    this.generic = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!generic && player != null && player!.hasPhoto) {
      return SedanPlayerFace(
        player: player,
        size: size,
        occupied: true,
        background: _storyWhite,
        foreground: _storyInk,
        border: _storyGreen,
        borderWidth: size >= 120 ? 3 : 2,
      );
    }
    if (player == null) {
      return SedanPlayerFace(
        player: null,
        size: size,
        occupied: false,
        background: _storyWhite,
        foreground: _storyInk,
        border: _storyGreen,
        borderWidth: size >= 120 ? 3 : 2,
      );
    }
    return _StoryGenericFace(size: size);
  }
}

class _StoryGenericFace extends StatelessWidget {
  final double size;

  const _StoryGenericFace({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EEE9),
        border: Border.all(
          color: _storyGreen,
          width: size >= 120 ? 3 : 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: const Alignment(0, 0.42),
        child: Icon(
          Icons.person_rounded,
          size: size * 0.92,
          color: _storyInk.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _StoryRoundCrest extends StatelessWidget {
  final String? url;
  final String fallbackName;
  final double size;

  const _StoryRoundCrest({
    this.url,
    this.fallbackName = 'CSSA',
    this.size = 196,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = (url ?? '').trim();
    final show = trimmed.isNotEmpty && !shouldSkipNetworkImageUrl(trimmed);
    final fallback = _StoryCrestFallback(name: fallbackName, size: size);
    final pad = size * 0.07;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _storyWhite,
        shape: BoxShape.circle,
        border: Border.all(color: _storyWhite, width: size >= 160 ? 6 : 4),
      ),
      child: ClipOval(
        child: show
            ? Padding(
                padding: EdgeInsets.all(pad),
                child: DvcrNetworkImage(
                  trimmed,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => fallback,
                ),
              )
            : fallback,
      ),
    );
  }
}

class _StoryCrestFallback extends StatelessWidget {
  final String name;
  final double size;

  const _StoryCrestFallback({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _storyGreen,
        shape: BoxShape.circle,
        border: Border.all(color: _storyInk, width: 2),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            child: Text(
              storyTeamInitials(name),
              style: GoogleFonts.barlowCondensed(
                fontWeight: FontWeight.w900,
                color: _storyWhite,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryTeamCol extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool alignEnd;
  final bool compact;
  final int yellow;
  final int red;

  const _StoryTeamCol({
    required this.name,
    this.logoUrl,
    this.alignEnd = false,
    this.compact = false,
    this.yellow = 0,
    this.red = 0,
  });

  @override
  Widget build(BuildContext context) {
    final url = (logoUrl ?? '').trim();
    final align =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final size = compact ? 120.0 : 176.0;
    final showNet = url.isNotEmpty && !shouldSkipNetworkImageUrl(url);
    final fallback = _StoryCrestFallback(name: name, size: size);
    final crest = SizedBox(
      width: size,
      height: size,
      child: showNet
          ? DvcrNetworkImage(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
    final hasCards = yellow > 0 || red > 0;
    return Column(
      crossAxisAlignment: align,
      children: [
        if (!hasCards)
          crest
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: alignEnd
                ? [
                    crest,
                    const SizedBox(width: 14),
                    _StoryCardSticks(yellow: yellow, red: red),
                  ]
                : [
                    _StoryCardSticks(yellow: yellow, red: red),
                    const SizedBox(width: 14),
                    crest,
                  ],
          ),
        const SizedBox(height: 12),
        Text(
          name.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.barlowCondensed(
            fontSize: compact ? 32 : 40,
            fontWeight: FontWeight.w800,
            color: _storyInk,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StoryCardSticks extends StatelessWidget {
  final int yellow;
  final int red;

  const _StoryCardSticks({
    required this.yellow,
    required this.red,
  });

  static const _yellow = Color(0xFFFFC107);
  static const _red = Color(0xFFC1121F);

  @override
  Widget build(BuildContext context) {
    final y = yellow.clamp(0, 5);
    final r = red.clamp(0, 3);
    if (y == 0 && r == 0) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < y; i++) const _StoryCardStick(color: _yellow),
        for (var i = 0; i < r; i++) const _StoryCardStick(color: _red),
      ],
    );
  }
}

class _StoryCardStick extends StatelessWidget {
  final Color color;

  const _StoryCardStick({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x66000000), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
