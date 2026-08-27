/// Phases du direct (`live/current.lastEvent`).
class LiveMatchPhase {
  final String lastEvent;

  const LiveMatchPhase(this.lastEvent);

  bool get isHalftime => lastEvent == 'halftime';
  bool get isExtraHalftime => lastEvent == 'extra_halftime';
  bool get isRegularFulltime => lastEvent == 'fulltime';
  bool get isExtraFulltime => lastEvent == 'extra_fulltime';
  bool get isExtraTimePlaying => lastEvent == 'extra_time';

  /// Prolongations démarrées (admin a appuyé PROLONG.).
  bool get inExtraTimePhase =>
      isExtraTimePlaying || isExtraHalftime || isExtraFulltime;

  bool get isMatchEnded => isRegularFulltime || isExtraFulltime;

  bool get chronoLocked =>
      isHalftime || isExtraHalftime || isMatchEnded;

  bool get canStartProlongation =>
      !inExtraTimePhase && !isMatchEnded && !isHalftime;

  bool get showFinMatchButton => !inExtraTimePhase && !isMatchEnded;

  bool get showFinProlongationButton =>
      inExtraTimePhase && !isExtraFulltime && !isRegularFulltime;

  /// Chip minute : phase en clair (FIN / MI-TEMPS), sinon minute de jeu.
  /// [elapsedSeconds] = chrono (base + elapsed) ; ignoré si la phase est figée.
  static String minuteChip({
    required String lastEvent,
    required int elapsedSeconds,
    required int storedMinute,
    required bool chronoRunning,
  }) {
    final phase = LiveMatchPhase(lastEvent);
    if (phase.isRegularFulltime) return 'FIN';
    if (phase.isExtraFulltime) return 'FIN PROL.';
    if (phase.isHalftime) return 'MI-TEMPS';
    if (phase.isExtraHalftime) return 'MT PROL.';

    if (elapsedSeconds > 0) {
      final m = elapsedSeconds ~/ 60;
      if (phase.isExtraTimePlaying) return "P$m'";
      return "$m'";
    }
    if (phase.isExtraTimePlaying) return 'PROL.';
    if (storedMinute > 0) return "$storedMinute'";
    if (chronoRunning) return "0'";
    return 'LIVE';
  }
}
