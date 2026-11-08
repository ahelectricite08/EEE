import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/screens/admin/admin_interior_hub.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('sommaire puis une seule rubrique ouverte', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminInteriorHub(
            title: 'Page test',
            subtitle: 'Une rubrique à la fois.',
            icon: Icons.home_rounded,
            items: [
              AdminInteriorItem(
                title: 'Rubrique A',
                subtitle: 'Première',
                icon: Icons.looks_one_rounded,
                group: 'Groupe',
                child: Text('BODY-A'),
              ),
              AdminInteriorItem(
                title: 'Rubrique B',
                subtitle: 'Deuxième',
                icon: Icons.looks_two_rounded,
                group: 'Groupe',
                child: Text('BODY-B'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('PAGE TEST'), findsOneWidget);
    expect(find.text('Rubrique A'), findsOneWidget);
    expect(find.text('Rubrique B'), findsOneWidget);
    expect(find.text('BODY-A'), findsNothing);
    expect(find.text('BODY-B'), findsNothing);

    await tester.tap(find.text('Rubrique A'));
    await tester.pumpAndSettle();

    expect(find.text('BODY-A'), findsOneWidget);
    expect(find.text('BODY-B'), findsNothing);
    expect(find.text('Rubrique B'), findsNothing);

    await tester.tap(find.text('Toutes les rubriques'));
    await tester.pumpAndSettle();

    expect(find.text('BODY-A'), findsNothing);
    expect(find.text('Rubrique B'), findsOneWidget);
  });
}
