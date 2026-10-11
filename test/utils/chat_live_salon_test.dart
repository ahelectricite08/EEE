import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/utils/chat_live_salon.dart';

void main() {
  test('coupe de France → salon coupe', () {
    expect(
      ChatLiveSalon.kindFor(competition: 'Coupe de France Crédit Agricole'),
      ChatLiveSalonKind.coupe,
    );
  });

  test('R1 Homiris → salon R1', () {
    expect(
      ChatLiveSalon.kindFor(competition: 'RÉGIONAL 1 HOMIRIS'),
      ChatLiveSalonKind.r1,
    );
  });

  test('équipe réserve / R2 → salon réserve', () {
    expect(
      ChatLiveSalon.kindFor(competition: 'Équipe réserve'),
      ChatLiveSalonKind.reserve,
    );
    expect(
      ChatLiveSalon.kindFor(competition: 'Régional 2'),
      ChatLiveSalonKind.reserve,
    );
  });

  test('pickSalonId matches names without creating live_ docs', () {
    const salons = [
      (id: 'general', name: 'Général'),
      (id: 'abc', name: 'Coupe de France'),
      (id: 'def', name: 'R1 Homiris'),
      (id: 'ghi', name: 'Réserve'),
      (id: 'live_old', name: '🔴 Live — Sedan vs X'),
    ];
    expect(
      ChatLiveSalon.pickSalonId(
        kind: ChatLiveSalonKind.coupe,
        salons: salons,
      ),
      'abc',
    );
    expect(
      ChatLiveSalon.pickSalonId(kind: ChatLiveSalonKind.r1, salons: salons),
      'def',
    );
    expect(
      ChatLiveSalon.pickSalonId(
        kind: ChatLiveSalonKind.reserve,
        salons: salons,
      ),
      'ghi',
    );
  });

  test('isTemporaryId only matches live_ prefix', () {
    expect(ChatLiveSalon.isTemporaryId('live_abc'), isTrue);
    expect(ChatLiveSalon.isTemporaryId('coupe-de-france'), isFalse);
  });
}
