import 'package:flutter_test/flutter_test.dart';
import 'package:dvcr/screens/admin/tabs/stats/stats_bench.dart';

void main() {
  test('solo : les deux équipes, pas de passes', () {
    const b = StatsBench(size: 1, seat: 1);
    expect(b.showPossession, isTrue);
    expect(b.teams, [1, 2]);
    expect(b.showPasses, isFalse);
    expect(b.blocks.contains(StatBlock.passes), isFalse);
    expect(b.blocks.contains(StatBlock.shots), isTrue);
    expect(b.blocks.contains(StatBlock.events), isTrue);
    expect(b.caption('Sedan', 'CSSA'), 'Seul — les deux équipes, sans passes');
  });

  test('duo : split par boulot, pas par équipe', () {
    final p1 = StatsBench.clamp(size: 2, seat: 1);
    expect(p1.teams, [1, 2]);
    expect(p1.showPossession, isTrue);
    expect(p1.showPasses, isFalse);
    expect(p1.blocks, {StatBlock.shots});
    expect(p1.caption('Sedan', 'CSSA'),
        'Poste 1 — possession + tirs (les deux équipes)');
    expect(p1.seatLabel(1, 'Sedan', 'CSSA'), 'TIRS');

    final p2 = StatsBench.clamp(size: 2, seat: 2);
    expect(p2.teams, [1, 2]);
    expect(p2.showPossession, isFalse);
    expect(p2.showPasses, isFalse);
    expect(p2.blocks, {
      StatBlock.crosses,
      StatBlock.duels,
      StatBlock.events,
    });
    expect(p2.caption('Sedan', 'CSSA'),
        'Poste 2 — centres, duels, faits (les deux équipes)');
    expect(p2.seatLabel(2, 'Sedan', 'CSSA'), 'FAITS');
  });

  test('trio : 1 tirs, 2 passes, 3 faits — les deux équipes', () {
    final a = StatsBench.clamp(size: 3, seat: 1);
    expect(a.teams, [1, 2]);
    expect(a.blocks, {StatBlock.shots});
    expect(a.showPossession, isTrue);
    expect(a.showPasses, isFalse);

    final b = StatsBench.clamp(size: 3, seat: 2);
    expect(b.blocks, {
      StatBlock.passes,
      StatBlock.crosses,
      StatBlock.duels,
    });
    expect(b.showPasses, isTrue);
    expect(b.showPossession, isFalse);

    final c = StatsBench.clamp(size: 3, seat: 3);
    expect(c.blocks, {StatBlock.events});
    expect(c.showPossession, isFalse);
  });

  test('seat se recale si on passe de 3 à 2 personnes', () {
    final b = StatsBench.clamp(size: 2, seat: 3);
    expect(b.size, 2);
    expect(b.seat, 2);
  });
}
