import 'package:flutter/material.dart';

import '../models/crowd_xi.dart';
import '../models/lineup_xi_verdict.dart';
import '../models/sedan_squad.dart';
import '../utils/player_name_normalize.dart';
import 'xi_mini_pitch.dart';

/// Trois mini-terrains après l’officiel : toi / vestiaire / la bonne.
/// Or = bon, rouge = à côté. Pas de liste de noms.
class XiComparePitches extends StatelessWidget {
  final List<LineupXiPlayerMark> userMarks;
  final CrowdXi? crowd;
  final List<String> officialSedanStarters;
  final SedanSquad squad;

  const XiComparePitches({
    super.key,
    required this.userMarks,
    required this.officialSedanStarters,
    this.crowd,
    this.squad = SedanSquad.empty,
  });

  static List<SedanSquadPlayer> playersFromLabels(
    SedanSquad squad,
    Iterable<String> labels,
  ) {
    return [
      for (final raw in labels)
        if (raw.trim().isNotEmpty)
          squad.matchLineupLabel(raw) ??
              SedanSquad.placeholderFromLabel(raw),
    ];
  }

  static List<LineupXiPlayerMark> crowdMarks({
    required CrowdXi crowd,
    required List<String> officialSedanStarters,
    SedanSquad squad = SedanSquad.empty,
  }) {
    final names = [for (final p in crowd.players) p.name];
    final hits = matchPlayerNames(
      predicted: names,
      official: officialSedanStarters,
    );
    final hitIdx = {for (final h in hits) h.predictedIndex};
    return [
      for (var i = 0; i < crowd.players.length; i++)
        LineupXiPlayerMark(
          player: squad.matchLineupLabel(crowd.players[i].name) ??
              SedanSquad.placeholderFromLabel(crowd.players[i].name),
          validated: hitIdx.contains(i) || crowd.players[i].inOfficial,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final officialPlayers = playersFromLabels(squad, officialSedanStarters);
    if (userMarks.isEmpty && officialPlayers.isEmpty) {
      return const SizedBox.shrink();
    }
    final crowdReady = crowd != null && crowd!.isReady;
    final vestiaire = crowdReady
        ? crowdMarks(
            crowd: crowd!,
            officialSedanStarters: officialSedanStarters,
            squad: squad,
          )
        : const <LineupXiPlayerMark>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (userMarks.isNotEmpty)
          _board(
            caption: 'Ta compo',
            marks: userMarks,
          ),
        if (vestiaire.isNotEmpty) ...[
          const SizedBox(height: 10),
          _board(
            caption: 'Compo des supporters',
            marks: vestiaire,
          ),
        ],
        if (officialPlayers.isNotEmpty) ...[
          const SizedBox(height: 10),
          XiMiniPitch(
            players: xiFormationSlots(officialPlayers),
            faceSize: 48,
            caption: 'La bonne compo',
            showVerdict: true,
            verdictAllCorrect: true,
          ),
        ],
      ],
    );
  }

  Widget _board({
    required String caption,
    required List<LineupXiPlayerMark> marks,
  }) {
    final players = [for (final m in marks) m.player];
    final hitIds = {
      for (final m in marks)
        if (m.validated && m.player.id.isNotEmpty) m.player.id,
    };
    final hitNames = {
      for (final m in marks)
        if (m.validated) normalizePlayerName(m.player.name),
    }..removeWhere((e) => e.isEmpty);
    return XiMiniPitch(
      players: xiFormationSlots(players),
      faceSize: 48,
      caption: caption,
      showVerdict: true,
      validatedPlayerIds: hitIds,
      validatedNames: hitNames,
    );
  }
}
