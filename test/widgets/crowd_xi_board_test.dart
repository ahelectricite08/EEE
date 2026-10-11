import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/models/crowd_xi.dart';
import 'package:dvcr/widgets/crowd_xi_board.dart';

CrowdXi _crowd({required bool official}) {
  return CrowdXi(
    ballots: 40,
    officialHits: official ? 8 : 0,
    officialComputed: official,
    players: List.generate(
      11,
      (i) => CrowdXiPlayer(
        name: 'Joueur$i',
        votes: 12 + i,
        inOfficial: official && i < 8,
      ),
    ),
  );
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('avant le XI officiel : pas de N pronos ni de votes',
      (tester) async {
    await tester.pumpWidget(
      _host(
        CrowdXiBoard(
          crowd: _crowd(official: false),
          tone: CrowdXiBoardTone.prono,
        ),
      ),
    );

    expect(find.text('XI DES SUPPORTERS'), findsOneWidget);
    expect(find.text('Joueur0'), findsOneWidget);
    expect(
      find.text('Le onze du vestiaire, avant la compo officielle.'),
      findsOneWidget,
    );
    expect(find.text('40 PRONOS'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('22'), findsNothing);
  });

  testWidgets('après le XI officiel : N pronos et votes visibles',
      (tester) async {
    await tester.pumpWidget(
      _host(
        CrowdXiBoard(
          crowd: _crowd(official: true),
          tone: CrowdXiBoardTone.prono,
          showCounts: true,
        ),
      ),
    );

    expect(find.text('40 PRONOS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('8/11 aussi dans le onze officiel.'), findsOneWidget);
  });

  testWidgets('sans showCounts, les chiffres restent masqués', (tester) async {
    await tester.pumpWidget(
      _host(
        CrowdXiBoard(
          crowd: _crowd(official: true),
          tone: CrowdXiBoardTone.prono,
        ),
      ),
    );

    expect(find.text('40 PRONOS'), findsNothing);
    expect(find.text('12'), findsNothing);
  });
}
