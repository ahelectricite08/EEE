import 'dart:math';

import 'match_lineup.dart';
import 'sedan_squad.dart';

/// Une annonce de compo = un `playKey` (match + `lineupsUpdatedAt`).
abstract final class LineupCinematicWindow {
  static String playKey(String matchId, DateTime savedAt) {
    final sec = savedAt.millisecondsSinceEpoch ~/ 1000;
    return '${matchId.trim()}_$sec';
  }
}

/// Auto-play réel (pas le ping TEST admin).
abstract final class LineupCinematicGate {
  static bool shouldPlay({
    required bool flagOn,
    required bool liveRunning,
    required bool alreadyPlayed,
    required DateTime? lineupAnnouncedAt,
  }) {
    if (!flagOn) return false;
    if (!liveRunning) return false;
    if (alreadyPlayed) return false;
    return lineupAnnouncedAt != null;
  }
}

/// Occupancy du Host : le splash adhésion attend `idle`.
enum LineupCinematicOccupancy { resolving, playing, idle }

abstract final class LineupCinematicSplashHold {
  /// Masquer « Devenez adhérent » tant que le XI va jouer ou joue.
  static bool blocksAdhesionSplash(LineupCinematicOccupancy occupancy) =>
      occupancy != LineupCinematicOccupancy.idle;

  static LineupCinematicOccupancy afterEvaluate({
    required bool overlayPlaying,
    bool launchInputsReady = true,
  }) {
    if (overlayPlaying) return LineupCinematicOccupancy.playing;
    if (!launchInputsReady) return LineupCinematicOccupancy.resolving;
    return LineupCinematicOccupancy.idle;
  }
}

class LineupCinematicPlayer {
  final String name;
  final int? number;

  const LineupCinematicPlayer({required this.name, this.number});

  factory LineupCinematicPlayer.parse(String raw) {
    final t = raw.trim();
    final m = RegExp(r'^(\d{1,3})\s+(.+)$').firstMatch(t);
    if (m != null) {
      return LineupCinematicPlayer(
        name: m.group(2)!.trim(),
        number: int.tryParse(m.group(1)!),
      );
    }
    return LineupCinematicPlayer(name: t);
  }

  String get displayNumber =>
      number == null ? '' : number!.toString();
}

class LineupCinematicLine {
  final String label;
  final List<LineupCinematicPlayer> players;

  const LineupCinematicLine({required this.label, required this.players});
}

/// Un côté (Sedan ou adversaire) découpé selon la formation saisie.
class LineupCinematicTeamPlan {
  final String teamName;
  final String formation;
  final bool isSedan;
  final LineupCinematicLine keepers;
  final List<LineupCinematicLine> outfieldLines;
  final LineupCinematicLine substitutes;

  const LineupCinematicTeamPlan({
    required this.teamName,
    required this.formation,
    required this.isSedan,
    required this.keepers,
    required this.outfieldLines,
    required this.substitutes,
  });

  bool get hasKeepers => keepers.players.isNotEmpty;
  bool get hasOutfield => outfieldLines.any((l) => l.players.isNotEmpty);
  bool get hasSubs => substitutes.players.isNotEmpty;
  bool get hasContent => hasKeepers || hasOutfield || hasSubs;

  static List<int> parseFormationDigits(String formation) {
    return formation
        .split(RegExp(r'[-–—./\s]+'))
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((n) => n > 0 && n <= 11)
        .toList();
  }

  static List<String> _nonEmpty(List<String> raw) =>
      raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Découpe le XI : gardien, puis les lignes du schéma (pas de 4-3-3 fantôme).
  factory LineupCinematicTeamPlan.fromSide({
    required MatchLineupSide side,
    required String teamName,
    required bool isSedan,
    SedanSquad? sedanSquad,
  }) {
    var starters = _nonEmpty(side.starters);
    if (isSedan && sedanSquad != null && !sedanSquad.isEmpty) {
      starters = sedanSquad.sortLineupLabels(starters);
    }
    final subs = _nonEmpty(side.substitutes)
        .map(LineupCinematicPlayer.parse)
        .toList();

    final digits = parseFormationDigits(side.formation);
    final sliced = _sliceStarters(starters, digits);

    return LineupCinematicTeamPlan(
      teamName: teamName.trim().isEmpty ? 'Équipe' : teamName.trim(),
      formation: side.formation.trim(),
      isSedan: isSedan,
      keepers: LineupCinematicLine(
        label: sliced.keepers.length <= 1 ? 'GARDIEN' : 'GARDIENS',
        players: sliced.keepers.map(LineupCinematicPlayer.parse).toList(),
      ),
      outfieldLines: [
        for (var i = 0; i < sliced.outfield.length; i++)
          if (sliced.outfield[i].isNotEmpty)
            LineupCinematicLine(
              label: _outfieldLabel(sliced.outfield.length, i),
              players: sliced.outfield[i]
                  .map(LineupCinematicPlayer.parse)
                  .toList(),
            ),
      ],
      substitutes: LineupCinematicLine(
        label: 'REMPLAÇANTS',
        players: subs,
      ),
    );
  }

  static String _outfieldLabel(int lineCount, int index) {
    if (lineCount <= 1) return 'TITULAIRES';
    if (lineCount == 2) {
      return index == 0 ? 'DÉFENSE' : 'ATTAQUE';
    }
    if (lineCount == 3) {
      return const ['DÉFENSE', 'MILIEU', 'ATTAQUE'][index];
    }
    if (lineCount == 4) {
      return const [
        'DÉFENSE',
        'MILIEU',
        'MILIEU OFFENSIF',
        'ATTAQUE',
      ][index];
    }
    if (index == 0) return 'DÉFENSE';
    if (index == lineCount - 1) return 'ATTAQUE';
    return 'LIGNE ${index + 1}';
  }

  static ({List<String> keepers, List<List<String>> outfield}) _sliceStarters(
    List<String> starters,
    List<int> digits,
  ) {
    if (starters.isEmpty) {
      return (keepers: const <String>[], outfield: const <List<String>>[]);
    }

    var gkCount = 1;
    var lines = digits;

    if (digits.isEmpty) {
      return (
        keepers: [starters.first],
        outfield: starters.length > 1
            ? [starters.sublist(1)]
            : const <List<String>>[],
      );
    }

    final sum = digits.fold<int>(0, (a, b) => a + b);
    if (digits.first == 1 && sum == starters.length) {
      gkCount = 1;
      lines = digits.sublist(1);
    } else if (sum == starters.length - 1) {
      gkCount = 1;
      lines = digits;
    } else if (sum == starters.length && digits.first != 1) {
      gkCount = 0;
      lines = digits;
    } else {
      gkCount = 1;
      lines = digits;
    }

    gkCount = gkCount.clamp(0, starters.length);
    final keepers = starters.take(gkCount).toList();
    var rest = starters.skip(gkCount).toList();
    final outfield = <List<String>>[];
    for (final n in lines) {
      if (rest.isEmpty) break;
      final take = n.clamp(0, rest.length);
      outfield.add(rest.take(take).toList());
      rest = rest.skip(take).toList();
    }
    if (rest.isNotEmpty) {
      if (outfield.isEmpty) {
        outfield.add(rest);
      } else {
        outfield[outfield.length - 1] = [
          ...outfield.last,
          ...rest,
        ];
      }
    }
    return (keepers: keepers, outfield: outfield);
  }
}

class LineupCinematicStep {
  final bool isSedan;
  final String teamName;
  final String formation;
  final String lineLabel;
  final List<LineupCinematicPlayer> players;
  final bool isTeamIntro;
  final bool isSubstitutes;

  const LineupCinematicStep({
    required this.isSedan,
    required this.teamName,
    required this.formation,
    required this.lineLabel,
    required this.players,
    this.isTeamIntro = false,
    this.isSubstitutes = false,
  });
}

/// `logo1` / `logo2` du match (domicile / extérieur), pas un inventaire parallèle.
abstract final class LineupCinematicCrests {
  static ({String sedan, String opponent}) fromHomeAway({
    required bool sedanIsHome,
    required String logo1,
    required String logo2,
  }) {
    final a = logo1.trim();
    final b = logo2.trim();
    if (sedanIsHome) return (sedan: a, opponent: b);
    return (sedan: b, opponent: a);
  }

  static String forTeam(LineupCinematicShow show, {required bool isSedan}) {
    return isSedan ? show.sedanLogoUrl : show.opponentLogoUrl;
  }
}

class LineupCinematicShow {
  final String matchId;
  final DateTime? savedAt;
  final LineupCinematicTeamPlan sedan;
  final LineupCinematicTeamPlan? opponent;
  final bool force;
  final String sedanLogoUrl;
  final String opponentLogoUrl;

  const LineupCinematicShow({
    required this.matchId,
    required this.sedan,
    this.savedAt,
    this.opponent,
    this.force = false,
    this.sedanLogoUrl = '',
    this.opponentLogoUrl = '',
  });

  LineupCinematicShow copyWith({
    String? sedanLogoUrl,
    String? opponentLogoUrl,
  }) {
    return LineupCinematicShow(
      matchId: matchId,
      savedAt: savedAt,
      sedan: sedan,
      opponent: opponent,
      force: force,
      sedanLogoUrl: sedanLogoUrl ?? this.sedanLogoUrl,
      opponentLogoUrl: opponentLogoUrl ?? this.opponentLogoUrl,
    );
  }

  List<LineupCinematicStep> get steps {
    final out = <LineupCinematicStep>[];
    void addTeam(LineupCinematicTeamPlan plan) {
      out.add(
        LineupCinematicStep(
          isSedan: plan.isSedan,
          teamName: plan.teamName,
          formation: '',
          lineLabel: plan.isSedan ? 'COMPOSITION CSSA' : 'COMPOSITION ADVERSE',
          players: const [],
          isTeamIntro: true,
        ),
      );
      if (plan.hasKeepers) {
        out.add(
          LineupCinematicStep(
            isSedan: plan.isSedan,
            teamName: plan.teamName,
            formation: '',
            lineLabel: plan.keepers.label,
            players: plan.keepers.players,
          ),
        );
      }
      for (final line in plan.outfieldLines) {
        out.add(
          LineupCinematicStep(
            isSedan: plan.isSedan,
            teamName: plan.teamName,
            formation: '',
            lineLabel: line.label,
            players: line.players,
          ),
        );
      }
      if (plan.hasSubs) {
        out.add(
          LineupCinematicStep(
            isSedan: plan.isSedan,
            teamName: plan.teamName,
            formation: '',
            lineLabel: plan.substitutes.label,
            players: plan.substitutes.players,
            isSubstitutes: true,
          ),
        );
      }
    }

    addTeam(sedan);
    final opp = opponent;
    if (opp != null && opp.hasContent) addTeam(opp);
    return out;
  }

  static const _formations = ['4-3-3', '4-4-2', '3-5-2', '5-3-2', '4-2-3-1'];

  static const _cssaFallback = [
    '1 Martin',
    '16 Petit',
    '4 Dubois',
    '5 Leroy',
    '2 Moreau',
    '3 Simon',
    '6 Laurent',
    '8 Michel',
    '10 Bernard',
    '7 Lefèvre',
    '11 Roux',
    '9 Garcia',
    '12 Fournier',
    '14 Girard',
    '17 Bonnet',
    '18 Dupont',
    '20 Lambert',
    '21 Fontaine',
  ];

  static const _oppFallback = [
    '1 Kovacs',
    '2 Silva',
    '3 Rossi',
    '4 Nowak',
    '5 Berg',
    '6 Costa',
    '8 Petrov',
    '10 Müller',
    '7 Santos',
    '11 Ndiaye',
    '9 Alvarez',
    '12 Chen',
    '14 Olsen',
    '16 Vargas',
    '17 Koné',
    '18 Ibrahim',
    '19 Diallo',
    '21 Benali',
  ];

  static const _oppClubs = [
    'Épinal',
    'Belfort',
    'Thionville',
    'Haguenau',
    'Furiani',
    'Colmar',
  ];

  /// TEST admin : XI + banc tirés au hasard (effectif CSSA si dispo).
  factory LineupCinematicShow.randomTest({
    SedanSquad squad = SedanSquad.empty,
    Random? random,
  }) {
    final rng = random ?? Random();
    final sedanForm = _formations[rng.nextInt(_formations.length)];
    var oppForm = _formations[rng.nextInt(_formations.length)];
    if (oppForm == sedanForm) {
      oppForm = _formations[(rng.nextInt(_formations.length - 1) + 1) %
          _formations.length];
    }
    final sedanSide = _randomSide(
      formation: sedanForm,
      squad: squad,
      fallback: _cssaFallback,
      rng: rng,
    );
    final oppSide = _randomSide(
      formation: oppForm,
      squad: SedanSquad.empty,
      fallback: _oppFallback,
      rng: rng,
    );
    return LineupCinematicShow(
      matchId: 'cinematic_test',
      sedan: LineupCinematicTeamPlan.fromSide(
        side: sedanSide,
        teamName: 'CSSA',
        isSedan: true,
        sedanSquad: squad.isEmpty ? null : squad,
      ),
      opponent: LineupCinematicTeamPlan.fromSide(
        side: oppSide,
        teamName: _oppClubs[rng.nextInt(_oppClubs.length)],
        isSedan: false,
      ),
      force: true,
    );
  }

  static MatchLineupSide _randomSide({
    required String formation,
    required SedanSquad squad,
    required List<String> fallback,
    required Random rng,
  }) {
    var lines = LineupCinematicTeamPlan.parseFormationDigits(formation);
    if (lines.isEmpty) lines = const [4, 3, 3];
    final sum = lines.fold<int>(0, (a, b) => a + b);
    if (lines.first == 1 && sum == 11) {
      lines = lines.sublist(1);
    }
    final defNeed = lines.first;
    final attNeed = lines.last;
    final milNeed = lines.length <= 2
        ? 0
        : lines.sublist(1, lines.length - 1).fold(0, (a, b) => a + b);

    final buckets = <String, List<SedanSquadPlayer>>{
      'GB': [],
      'DEF': [],
      'MIL': [],
      'ATT': [],
      '_': [],
    };
    for (final p in squad.players) {
      final key = SedanSquadPositions.normalize(p.position);
      (buckets.containsKey(key) ? buckets[key]! : buckets['_']!).add(p);
    }
    for (final list in buckets.values) {
      list.shuffle(rng);
    }

    String take(String pos) {
      final bucket = buckets[pos]!;
      if (bucket.isNotEmpty) return bucket.removeAt(0).lineupName;
      for (final k in const ['ATT', 'MIL', 'DEF', 'GB', '_']) {
        if (k == pos) continue;
        final b = buckets[k]!;
        if (b.isNotEmpty) return b.removeAt(0).lineupName;
      }
      return '';
    }

    final starters = <String>[
      take('GB'),
      for (var i = 0; i < defNeed; i++) take('DEF'),
      for (var i = 0; i < milNeed; i++) take('MIL'),
      for (var i = 0; i < attNeed; i++) take('ATT'),
    ];

    var fi = 0;
    final used = <String>{};
    for (var i = 0; i < starters.length; i++) {
      if (starters[i].isNotEmpty) {
        used.add(starters[i]);
        continue;
      }
      while (fi < fallback.length && used.contains(fallback[fi])) {
        fi++;
      }
      final name = fi < fallback.length ? fallback[fi++] : '${i + 1} Joueur';
      starters[i] = name;
      used.add(name);
    }

    final remaining = <String>[
      for (final k in const ['GB', 'DEF', 'MIL', 'ATT', '_'])
        for (final p in buckets[k]!) p.lineupName,
    ]..shuffle(rng);

    final subCount = 5 + rng.nextInt(3);
    final subs = <String>[];
    for (final r in remaining) {
      if (subs.length >= subCount) break;
      if (used.add(r)) subs.add(r);
    }
    while (subs.length < subCount) {
      while (fi < fallback.length && used.contains(fallback[fi])) {
        fi++;
      }
      if (fi >= fallback.length) break;
      final name = fallback[fi++];
      used.add(name);
      subs.add(name);
    }

    return MatchLineupSide(
      formation: formation,
      starters: starters,
      substitutes: subs,
    );
  }
}
