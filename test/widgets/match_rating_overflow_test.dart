import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dvcr/widgets/live_interaction_card_ui.dart';
import 'package:dvcr/widgets/match_rating_summary.dart';
import 'package:dvcr/widgets/square_partner_logo.dart';

const _ratingDoc = {
  'matchRatingTotal': 42,
  'matchRatingAverage': 7.5,
  'matchRatingSum': 315,
};

void _bindOverflows(List<String> into) {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed') ||
        text.contains('OVERFLOWING') ||
        text.contains('RenderFlex')) {
      into.add(text.split('\n').first);
    }
    prev?.call(details);
  };
}

Widget _phone(Widget child, {Size size = const Size(320, 568)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: size.width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('MatchRatingDetailCard 320px', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: MatchRatingDetailCard(matchDoc: _ratingDoc),
        ),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('MatchRatingPanel compact 280px', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        Padding(
          padding: const EdgeInsets.all(14),
          child: MatchRatingPanel(
            rating: MatchRatingSnapshot.fromDoc(_ratingDoc)!,
            lightSurface: true,
            compact: true,
          ),
        ),
        size: const Size(280, 200),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('MatchRatingDetailCard verdict long 320px', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: MatchRatingDetailCard(
            matchDoc: {
              'matchRatingTotal': 8,
              'matchRatingAverage': 5.2,
              'matchRatingSum': 42,
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('hero header + logo partenaire 124px', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 124,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: LiveInteractionHeroHeader(
                eyebrow: 'NOTE DU MATCH',
                title: 'CSSA Sedan Ardennes — Olympique Saint-Quentin',
                isLive: true,
                sponsorLogoUrl: 'https://example.com/partner.png',
                icon: Icons.star_rate_rounded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('hero header + sous-titre + logo 124px', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 124,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: LiveInteractionHeroHeader(
                eyebrow: 'NOTE DU MATCH',
                title: 'CSSA Sedan Ardennes — FC Metz',
                subtitle: 'Donne une note de 1 à 10 pour ce match.',
                isLive: true,
                sponsorLogoUrl: 'https://example.com/partner.png',
                icon: Icons.star_rate_rounded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });

  testWidgets('SquarePartnerLogo non carré borné', (tester) async {
    final overflows = <String>[];
    _bindOverflows(overflows);
    await tester.pumpWidget(
      _phone(
        const Row(
          children: [
            SquarePartnerLogo(
              url: 'https://example.com/p.png',
              lockSquare: false,
              size: 56,
              maxWidth: 112,
              maxHeight: 56,
            ),
            Expanded(child: Text('NOTE DU MATCH')),
          ],
        ),
        size: const Size(200, 80),
      ),
    );
    await tester.pump();
    expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
  });
}
