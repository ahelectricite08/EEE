import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/live_event_player_source.dart';
import 'package:dvcr/widgets/live_event_player_picker.dart';
import 'package:dvcr/widgets/live_event_team_pick.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('after picking a team, scorer chips come from that lineup',
      (tester) async {
    const live = {
      'team1': 'CSSA Sedan',
      'team2': 'Épinal',
      'lineupHome': {
        'starters': ['9 Koffi', '10 Lopez'],
        'substitutes': <String>[],
      },
      'lineupAway': {
        'starters': ['7 Martin', '9 Durand'],
        'substitutes': ['12 Bernard'],
      },
    };
    final ctrl = TextEditingController();
    final src = LiveEventPlayerSource.fromLive(
      live: live,
      selectedTeam: 'Épinal',
    );

    await tester.pumpWidget(
      _host(
        LiveEventPlayerPicker(
          controller: ctrl,
          label: 'Buteur',
          source: src,
          onChanged: () {},
        ),
      ),
    );

    expect(find.text('7 Martin'), findsOneWidget);
    expect(find.text('9 Durand'), findsOneWidget);
    expect(find.text('12 Bernard'), findsOneWidget);
    expect(find.text('9 Koffi'), findsNothing);
    expect(find.text('But adverse'), findsNothing);
  });

  testWidgets('opponent without XI keeps quiet free text, no But adverse',
      (tester) async {
    const live = {
      'team1': 'CSSA Sedan',
      'team2': 'Épinal',
      'lineupHome': {
        'starters': ['9 Koffi'],
        'substitutes': <String>[],
      },
    };
    final ctrl = TextEditingController();
    final src = LiveEventPlayerSource.fromLive(
      live: live,
      selectedTeam: 'Épinal',
    );

    await tester.pumpWidget(
      _host(
        LiveEventPlayerPicker(
          controller: ctrl,
          label: 'Buteur',
          source: src,
          onChanged: () {},
        ),
      ),
    );

    expect(find.text('But adverse'), findsNothing);
    expect(find.text(LiveEventPlayerSource.quietOpponentHint), findsWidgets);
  });

  testWidgets('team pick shows both crests and names', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _host(
        LiveEventTeamPick(
          team1: 'CSSA Sedan',
          team2: 'Épinal',
          selectedTeam: selected,
          onSelect: (name) => selected = name,
        ),
      ),
    );

    expect(find.text('ÉQUIPE'), findsOneWidget);
    expect(find.text('CSSA Sedan'), findsOneWidget);
    expect(find.text('Épinal'), findsOneWidget);

    await tester.tap(find.text('Épinal'));
    await tester.pump();
    expect(selected, 'Épinal');
  });
}
