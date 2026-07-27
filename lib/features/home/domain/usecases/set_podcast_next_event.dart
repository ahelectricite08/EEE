import 'package:dvcr/core/core.dart';

import '../repositories/home_repository.dart';

class SetPodcastNextEvent {
  const SetPodcastNextEvent(this._repository);

  final HomeRepository _repository;

  Future<Result<void>> call(DateTime dateTime) {
    return _repository.setPodcastNextEvent(dateTime);
  }
}
