import 'package:dvcr/screens/admin/widgets/motm_vote_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: MotmVoteLaunchSheet(
          liveData: const {},
          sponsorName: 'Maneo',
          sponsorLogo: '',
          team1Name: 'CSSA',
          team2Name: 'VISITEUR',
          team1Players: const ['Dupont', 'Martin'],
          team2Players: const ['Adversaire 1'],
          revealWinner: true,
          lineupPrefill: true,
          sponsorStream: Stream.value(const []),
        ),
      ),
    );
  }

  Finder playerField(int n) {
    return find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Joueur $n',
    );
  }

  testWidgets('MOTM launch controllers are created once, not in build()', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final state = tester.state<MotmVoteLaunchSheetState>(
      find.byType(MotmVoteLaunchSheet),
    );
    final created = state.controllerBuildCount;
    final teamCtrl = state.team1NameController;
    final firstPlayer = state.team1PlayerControllers.first;
    expect(created, greaterThan(0));
    expect(teamCtrl.text, 'CSSA');
    expect(firstPlayer.text, 'Dupont');

    await tester.pumpWidget(host());
    await tester.pump();

    final afterRebuild = tester.state<MotmVoteLaunchSheetState>(
      find.byType(MotmVoteLaunchSheet),
    );
    expect(afterRebuild.controllerBuildCount, created);
    expect(identical(afterRebuild.team1NameController, teamCtrl), isTrue);
    expect(
      identical(afterRebuild.team1PlayerControllers.first, firstPlayer),
      isTrue,
    );

    await tester.enterText(playerField(1).first, 'Dupont-edit');
    await tester.pumpWidget(host());
    await tester.pump();
    expect(afterRebuild.team1PlayerControllers.first.text, 'Dupont-edit');
  });

  testWidgets('MOTM launch add/remove player does not dispose under the field', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final state = tester.state<MotmVoteLaunchSheetState>(
      find.byType(MotmVoteLaunchSheet),
    );
    final before = state.controllerBuildCount;
    expect(state.team1PlayerControllers, hasLength(3));

    await tester.ensureVisible(find.text('AJOUTER UN JOUEUR').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AJOUTER UN JOUEUR').first);
    await tester.pump();
    expect(state.team1PlayerControllers, hasLength(4));
    expect(state.controllerBuildCount, before + 1);

    await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pump();
    expect(state.team1PlayerControllers, hasLength(3));
    expect(state.controllerBuildCount, before + 1);
    expect(tester.takeException(), isNull);
  });
}
