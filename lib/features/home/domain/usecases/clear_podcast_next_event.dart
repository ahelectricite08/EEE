import 'package:dvcr/core/core.dart';

import '../repositories/home_repository.dart';

class ClearPodcastNextEvent {
  const ClearPodcastNextEvent(this._repository);

  final HomeRepository _repository;

  Future<Result<void>> call() {
    return _repository.clearPodcastNextEvent();
  }
}
