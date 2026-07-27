/// Home hub adapter → legacy [MatchController] (Matchs hors périmètre Home).
library;

import 'package:flutter/foundation.dart';
import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/services/match_controller.dart';

class HomeMatchCatalogAdapter {
  const HomeMatchCatalogAdapter();
  MatchController get _ctrl => MatchController.instance;
  Listenable get listenable => _ctrl;
  List<MatchModel> get upcoming => _ctrl.upcoming;
  List<MatchModel> get results => _ctrl.results;
  Future<void> forceRefresh() => _ctrl.forceRefresh();
}
