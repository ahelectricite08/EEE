import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/sedan_squad.dart';
import 'package:dvcr/widgets/xi_mini_pitch.dart';

void main() {
  test('xiFormationSlots pose un 1-4-3-3', () {
    final slots = xiFormationSlots([
      const SedanSquadPlayer(id: 'g', name: 'Gros', number: 1, position: 'GB'),
      const SedanSquadPlayer(id: 'd1', name: 'D1', number: 2, position: 'DEF'),
      const SedanSquadPlayer(id: 'd2', name: 'D2', number: 3, position: 'DEF'),
      const SedanSquadPlayer(id: 'd3', name: 'D3', number: 4, position: 'DEF'),
      const SedanSquadPlayer(id: 'd4', name: 'D4', number: 5, position: 'DEF'),
      const SedanSquadPlayer(id: 'm1', name: 'M1', number: 6, position: 'MIL'),
      const SedanSquadPlayer(id: 'm2', name: 'M2', number: 8, position: 'MIL'),
      const SedanSquadPlayer(id: 'm3', name: 'M3', number: 10, position: 'MIL'),
      const SedanSquadPlayer(id: 'a1', name: 'A1', number: 7, position: 'ATT'),
      const SedanSquadPlayer(id: 'a2', name: 'A2', number: 9, position: 'ATT'),
      const SedanSquadPlayer(id: 'a3', name: 'A3', number: 11, position: 'ATT'),
    ]);
    expect(slots.length, 11);
    expect(slots[0]?.id, 'g');
    expect(slots[1]?.id, 'd1');
    expect(slots[4]?.id, 'd4');
    expect(slots[5]?.id, 'm1');
    expect(slots[7]?.id, 'm3');
    expect(slots[8]?.id, 'a1');
    expect(slots[10]?.id, 'a3');
  });
}
