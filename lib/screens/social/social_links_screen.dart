import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'social_hero_sliver.dart';
import 'social_links_catalog.dart';
import 'social_links_settings.dart';
import 'social_network_cards.dart';

class SocialLinksScreen extends StatelessWidget {
  const SocialLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: kSocialIvory,
      body: StreamBuilder<List<SocialNetworkSpec>>(
        stream: SocialLinksSettings.watchVisible(),
        builder: (context, snap) {
          final links = snap.data ?? SocialLinksOverlay.empty.resolve();
          return CustomScrollView(
            slivers: [
              SocialHeroSliver.build(context),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 28 + bottom),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (links.isEmpty)
                      const _EmptyNetworks()
                    else
                      ..._groupedCards(links),
                    const SizedBox(height: 18),
                    Text(
                      'Appui long sur une carte pour copier le lien.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5C6560).withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<Widget> _groupedCards(List<SocialNetworkSpec> links) {
    final out = <Widget>[];
    String? lastSection;
    for (var i = 0; i < links.length; i++) {
      final spec = links[i];
      if (spec.section.isNotEmpty && spec.section != lastSection) {
        lastSection = spec.section;
        out.add(SocialSectionLabel(spec.section));
      }
      out.add(SocialNetworkCard(spec: spec, index: i));
      out.add(const SizedBox(height: 12));
    }
    return out;
  }
}

class _EmptyNetworks extends StatelessWidget {
  const _EmptyNetworks();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFD8D2C4), width: 1),
        ),
      ),
      child: Text(
        'Aucun réseau à afficher pour le moment.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF5C6560),
          height: 1.4,
        ),
      ),
    );
  }
}
