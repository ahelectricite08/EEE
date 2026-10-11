import 'package:cloud_functions/cloud_functions.dart';

import '../models/benevole_availability.dart';

class BenevoleAvailabilityService {
  BenevoleAvailabilityService._();
  static final instance = BenevoleAvailabilityService._();

  static FirebaseFunctions get _fn => FirebaseFunctions.instance;

  Future<BenevoleAvailabilityBoard> loadBoard() async {
    final res = await _fn.httpsCallable('listBenevoleMatches').call();
    final data = Map<String, dynamic>.from(res.data as Map);
    return BenevoleAvailabilityBoard.fromMap(data);
  }

  Future<void> submit({
    required String matchId,
    required String status,
    List<String> wishes = const [],
  }) async {
    await _fn.httpsCallable('submitBenevoleAvailability').call({
      'matchId': matchId,
      'status': status,
      'wishes': wishes,
    });
  }

  static String friendlyError(Object e) {
    if (e is FirebaseFunctionsException) {
      final msg = (e.message ?? '').trim();
      if (msg.isNotEmpty) return msg;
      switch (e.code) {
        case 'unauthenticated':
          return 'Reconnecte-toi pour envoyer ta dispo.';
        case 'permission-denied':
          return 'Réservé à la Team DVCR.';
        case 'not-found':
          return 'Match ou email introuvable chez Antoine.';
        case 'failed-precondition':
          return 'Planning bénévoles indisponible pour le moment.';
        default:
          return 'Impossible d’envoyer la dispo.';
      }
    }
    return 'Impossible d’envoyer la dispo.';
  }
}
