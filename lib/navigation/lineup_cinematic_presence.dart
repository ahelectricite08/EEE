import 'package:flutter/foundation.dart';

import '../models/lineup_cinematic_plan.dart';

/// Host → splash : défaut `resolving` pour ne pas flasher l’adhésion au cold start.
class LineupCinematicPresence {
  LineupCinematicPresence._();
  static final instance = LineupCinematicPresence._();

  final ValueNotifier<LineupCinematicOccupancy> occupancy =
      ValueNotifier(LineupCinematicOccupancy.resolving);

  bool get blocksAdhesionSplash =>
      LineupCinematicSplashHold.blocksAdhesionSplash(occupancy.value);

  void setOccupancy(LineupCinematicOccupancy next) {
    if (occupancy.value == next) return;
    occupancy.value = next;
  }

  @visibleForTesting
  void resetForTest([
    LineupCinematicOccupancy to = LineupCinematicOccupancy.idle,
  ]) {
    occupancy.value = to;
  }
}
