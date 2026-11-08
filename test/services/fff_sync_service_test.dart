import 'package:dvcr/services/fff_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto due après 8 h, pas pendant un claim', () {
    final now = DateTime(2026, 10, 20, 21, 15);
    expect(fffDailyAutoIsDue(null, now), isTrue);
    expect(
      fffDailyAutoIsDue(now.subtract(const Duration(hours: 9)), now),
      isTrue,
    );
    expect(
      fffDailyAutoIsDue(now.subtract(const Duration(hours: 2)), now),
      isFalse,
    );
    expect(
      fffDailyAutoIsDue(
        now.subtract(const Duration(hours: 9)),
        now,
        claimAt: now.subtract(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    expect(
      fffDailyAutoIsDue(
        now.subtract(const Duration(hours: 9)),
        now,
        claimAt: now.subtract(const Duration(minutes: 30)),
      ),
      isTrue,
    );
  });

  test('snackbar liste scores, classement et pronos', () {
    expect(
      fffAdminSyncSnackMessage(
        const FffAdminSyncReport(
          scores: 7,
          rankingWrites: 14,
          journee: 8,
          reason: 'matches',
          pronosScored: 7,
        ),
      ),
      '7 scores R1/R2 · classement recalculé (J8) · 7 matchs prono',
    );
  });

  test('snackbar vide si rien n’a bougé', () {
    expect(
      fffAdminSyncSnackMessage(const FffAdminSyncReport(journee: 7)),
      'Rien de nouveau (J7). Scores et pronos déjà à jour, ou pas encore sur l’API FFF.',
    );
  });
}
