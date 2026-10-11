import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/official_sedan_lineup_draft.dart';
import 'package:dvcr/models/sedan_squad.dart';
import 'package:dvcr/widgets/official_sedan_lineup_picker.dart';

SedanSquadPlayer _p(String id, String name, String pos, int number) {
  return SedanSquadPlayer(
    id: id,
    name: name,
    position: pos,
    number: number,
  );
}

SedanSquad _squad() {
  return SedanSquad(
    players: [
      _p('g', 'Gros', 'GB', 1),
      _p('d1', 'Martin', 'DEF', 4),
      _p('d2', 'Diallo', 'DEF', 5),
      _p('d3', 'Bernard', 'DEF', 2),
      _p('d4', 'Petit', 'DEF', 3),
      _p('m1', 'Lopez', 'MIL', 6),
      _p('m2', 'Ndiaye', 'MIL', 8),
      _p('m3', 'Roux', 'MIL', 10),
      _p('a1', 'Koffi', 'ATT', 9),
      _p('a2', 'Leroy', 'ATT', 7),
      _p('a3', 'Moreau', 'ATT', 11),
      _p('b1', 'Blanc', 'MIL', 12),
    ],
  );
}

void main() {
  testWidgets('après 11 taps, le picker passe aux remplaçants', (tester) async {
    final squad = _squad();
    final draft = OfficialSedanLineupDraft();
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OfficialSedanLineupPicker(
              squad: squad,
              draft: draft,
              onChanged: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Compose le XI'), findsOneWidget);
    expect(find.text('11/11'), findsNothing);

    for (final p in squad.players.take(11)) {
      await tester.tap(find.byKey(Key('official-sedan-${p.id}')));
      await tester.pump();
    }

    expect(find.text('Sélectionne les remplaçants'), findsOneWidget);
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('Terminer le banc'), findsOneWidget);

    await tester.tap(find.byKey(const Key('official-sedan-b1')));
    await tester.pump();
    expect(find.text('1/7'), findsOneWidget);
    expect(draft.benchIds, ['b1']);
  });
}
