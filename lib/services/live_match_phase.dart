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
}
