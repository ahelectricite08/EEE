import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/features/prono/presentation/theme/prono_theme.dart';
import 'package:dvcr/features/prono/presentation/widgets/prono_page_header.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('pronoPageMarkLetters : un mot → 2 lettres', () {
    expect(pronoPageMarkLetters('Ligues'), 'LI');
    expect(pronoPageMarkLetters('Amis'), 'AM');
    expect(pronoPageMarkLetters('Duels'), 'DU');
  });

  test('pronoPageMarkLetters : deux mots → initiales', () {
    expect(pronoPageMarkLetters('Top ligues'), 'TL');
    expect(pronoPageMarkLetters('Détail duel'), 'DD');
  });

  testWidgets('PronoPageHeader : kicker, titre, retour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: PronoPageHeader.asAppBar(
              context: context,
              title: 'Ligues',
              subtitle: 'Mini-championnat entre amis.',
              kicker: 'Vestiaire',
              pageAccent: PronoPageAccent.social,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('VESTIAIRE'), findsOneWidget);
    expect(find.text('Ligues'), findsOneWidget);
    expect(find.text('Mini-championnat entre amis.'), findsOneWidget);
    expect(find.text('LI'), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
  });
}
