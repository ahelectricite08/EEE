import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/features/prono/presentation/widgets/league_emblem_picker.dart';
import 'package:dvcr/models/league_avatars.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('bloc salon : emblème + bouton visibles sans if(owner)',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeagueSalonEmblemBlock(
            leagueName: 'Team DVCR',
            emblemSrc: null,
            onChangeTap: () => tapped++,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('league-salon-emblem-block')),
        findsOneWidget);
    expect(find.text('EMBLÈME DE LA LIGUE'), findsOneWidget);
    expect(find.text('CHANGER L’EMBLÈME'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('league-salon-emblem-change')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('bouton lecture seule : snackbar créateur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return LeagueSalonEmblemBlock(
                leagueName: 'Team DVCR',
                emblemSrc: null,
                onChangeTap: () => requestLeagueEmblemChange(
                  context: context,
                  canEdit: false,
                  selectedId: 'sanglier',
                  onSelected: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('league-salon-emblem-change')));
    await tester.pump();
    expect(find.text(kLeagueEmblemLockedMessage), findsOneWidget);
    expect(find.byType(LeagueEmblemPicker), findsNothing);
  });

  testWidgets('hub : affordance Changer l’emblème toujours là', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeagueHubEmblemEditAffordance(onTap: () => tapped++),
        ),
      ),
    );
    expect(
        find.byKey(const ValueKey('league-hub-emblem-edit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('league-hub-emblem-edit')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('catalogue vide : message admin, jamais les mascottes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LeagueEmblemPicker(
            selectedId: '',
            catalog: LeagueAvatarCatalog.empty,
          ),
        ),
      ),
    );
    expect(find.text(kLeagueEmblemCatalogEmptyMessage), findsOneWidget);
    expect(find.text('SANGLIER'), findsNothing);
    expect(find.text('SUPPORTER'), findsNothing);
    expect(find.text('TACTICIEN'), findsNothing);
    expect(find.text('ARBITRE'), findsNothing);
    expect(find.text('COMMENTATEUR'), findsNothing);
  });
}
