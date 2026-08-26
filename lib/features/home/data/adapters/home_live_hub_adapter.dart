/// Home hub adapter → legacy [LiveStateService] (Live hors périmètre Home).
library;

import 'package:dvcr/services/live_state_service.dart';

class HomeLiveHubAdapter {
  const HomeLiveHubAdapter();
  Stream<LiveHubState> watch() => LiveStateService.watch();
  LiveHubState get latest => LiveStateService.latest;
}
