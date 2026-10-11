import 'sedan_squad.dart';

/// Phase opérateur : d’abord les 11 titulaires, puis le banc.
enum OfficialSedanLineupPhase { xi, bench }

/// Brouillon de la **compo officielle** Sedan (pas le jeu fan « XI probable »).
///
/// Plafond banc = 7 (slots historiques de l’éditeur admin). Sauvegarde en
/// GB → DEF → MIL → ATT via [SedanSquad.sortLineupLabels].
class OfficialSedanLineupDraft {
  static const int xiSize = 11;
  static const int benchMax = 7;

  OfficialSedanLineupPhase phase;
  final List<String> starterIds;
  final List<String> benchIds;
  final Map<String, String> cachedLineupNames;
  final List<String> unmatchedStarters;
  final List<String> unmatchedBench;

  OfficialSedanLineupDraft({
    OfficialSedanLineupPhase? phase,
    List<String>? starterIds,
    List<String>? benchIds,
    Map<String, String>? cachedLineupNames,
    List<String>? unmatchedStarters,
    List<String>? unmatchedBench,
  })  : starterIds = [...?starterIds],
        benchIds = [...?benchIds],
        cachedLineupNames = {...?cachedLineupNames},
        unmatchedStarters = [...?unmatchedStarters],
        unmatchedBench = [...?unmatchedBench],
        phase = phase ??
            ((starterIds != null && starterIds.length >= xiSize)
                ? OfficialSedanLineupPhase.bench
                : OfficialSedanLineupPhase.xi);

  bool get xiComplete => starterIds.length >= xiSize;
  bool get benchFull => benchIds.length >= benchMax;
  int get xiCount => starterIds.length;
  int get benchCount => benchIds.length;

  factory OfficialSedanLineupDraft.fromNames({
    required List<String> starters,
    required List<String> substitutes,
    required SedanSquad squad,
  }) {
    final draft = OfficialSedanLineupDraft();
    for (final raw in starters) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final player = squad.matchLineupLabel(name);
      if (player == null) {
        draft.unmatchedStarters.add(name);
        continue;
      }
      if (draft.starterIds.contains(player.id)) continue;
      if (draft.starterIds.length >= xiSize) {
        draft.unmatchedStarters.add(name);
        continue;
      }
      draft.starterIds.add(player.id);
      draft.cachedLineupNames[player.id] = player.lineupName;
    }
    for (final raw in substitutes) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final player = squad.matchLineupLabel(name);
      if (player == null) {
        draft.unmatchedBench.add(name);
        continue;
      }
      if (draft.starterIds.contains(player.id) ||
          draft.benchIds.contains(player.id)) {
        continue;
      }
      if (draft.benchIds.length >= benchMax) {
        draft.unmatchedBench.add(name);
        continue;
      }
      draft.benchIds.add(player.id);
      draft.cachedLineupNames[player.id] = player.lineupName;
    }
    if (draft.xiComplete) {
      draft.phase = OfficialSedanLineupPhase.bench;
    }
    return draft;
  }

  /// Reprend les noms saisis à la main une fois l’effectif chargé.
  bool resolveUnmatched(SedanSquad squad) {
    if (squad.isEmpty) return false;
    var changed = false;

    bool absorb(String name, {required bool preferXi}) {
      final player = squad.matchLineupLabel(name);
      if (player == null) return false;
      cachedLineupNames[player.id] = player.lineupName;
      if (starterIds.contains(player.id) || benchIds.contains(player.id)) {
        return true;
      }
      if (preferXi && starterIds.length < xiSize) {
        starterIds.add(player.id);
        return true;
      }
      if (benchIds.length < benchMax) {
        benchIds.add(player.id);
        return true;
      }
      return false;
    }

    unmatchedStarters.removeWhere((name) {
      final hit = absorb(name, preferXi: true);
      if (hit) changed = true;
      return hit;
    });
    unmatchedBench.removeWhere((name) {
      final hit = absorb(name, preferXi: false);
      if (hit) changed = true;
      return hit;
    });
    if (xiComplete && phase == OfficialSedanLineupPhase.xi) {
      phase = OfficialSedanLineupPhase.bench;
      changed = true;
    }
    return changed;
  }

  bool isStarter(String playerId) => starterIds.contains(playerId);
  bool isBench(String playerId) => benchIds.contains(playerId);
  bool isPicked(String playerId) => isStarter(playerId) || isBench(playerId);

  bool get remainingXiLocked =>
      phase == OfficialSedanLineupPhase.xi && xiComplete;
  bool get remainingBenchLocked =>
      phase == OfficialSedanLineupPhase.bench && benchCount >= benchMax;

  /// Tape un joueur de l’effectif. Retourne false si le tap est ignoré.
  bool tapPlayer(SedanSquadPlayer player) {
    final id = player.id;
    if (id.isEmpty) return false;
    cachedLineupNames[id] = player.lineupName;

    if (phase == OfficialSedanLineupPhase.xi) {
      if (starterIds.contains(id)) {
        starterIds.remove(id);
        return true;
      }
      if (starterIds.length >= xiSize) return false;
      benchIds.remove(id);
      unmatchedStarters.removeWhere(
        (n) => n.trim().toLowerCase() == player.lineupName.toLowerCase(),
      );
      starterIds.add(id);
      if (starterIds.length >= xiSize) {
        phase = OfficialSedanLineupPhase.bench;
      }
      return true;
    }

    if (starterIds.contains(id)) {
      starterIds.remove(id);
      phase = OfficialSedanLineupPhase.xi;
      return true;
    }
    if (benchIds.contains(id)) {
      benchIds.remove(id);
      return true;
    }
    if (benchIds.length >= benchMax) return false;
    unmatchedBench.removeWhere(
      (n) => n.trim().toLowerCase() == player.lineupName.toLowerCase(),
    );
    benchIds.add(id);
    return true;
  }

  void dismissUnmatchedStarter(String name) {
    unmatchedStarters.remove(name);
  }

  void dismissUnmatchedBench(String name) {
    unmatchedBench.remove(name);
  }

  void resetXi() {
    starterIds.clear();
    unmatchedStarters.clear();
    phase = OfficialSedanLineupPhase.xi;
  }

  void resetAll() {
    starterIds.clear();
    benchIds.clear();
    unmatchedStarters.clear();
    unmatchedBench.clear();
    phase = OfficialSedanLineupPhase.xi;
  }

  List<String> starterLineupNames(SedanSquad squad) {
    return _resolvedNames(starterIds, unmatchedStarters, squad, xiSize);
  }

  List<String> benchLineupNames(SedanSquad squad) {
    return _resolvedNames(benchIds, unmatchedBench, squad, benchMax);
  }

  List<String> _resolvedNames(
    List<String> ids,
    List<String> unmatched,
    SedanSquad squad,
    int cap,
  ) {
    final names = <String>[];
    for (final id in ids) {
      final live = squad.byId(id)?.lineupName;
      final cached = cachedLineupNames[id];
      final name = (live ?? cached)?.trim() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    for (final extra in unmatched) {
      final n = extra.trim();
      if (n.isNotEmpty) names.add(n);
    }
    final sorted = squad.isEmpty ? names : squad.sortLineupLabels(names);
    if (sorted.length <= cap) return sorted;
    return sorted.sublist(0, cap);
  }
}
