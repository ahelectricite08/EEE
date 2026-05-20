import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widgets/dvcr_skeleton.dart';
import '../../data/firestore_prono_repository.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import 'prono_match_list_tile.dart';

/// Feed matchs à pronostiquer (mobile-first, scroll fluide).
class PronoMatchesFeedPage extends StatelessWidget {
  final String uid;
  final FirestorePronoRepository repo;

  const PronoMatchesFeedPage({
    super.key,
    required this.uid,
    required this.repo,
  });

  static const _physics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    return StreamBuilder(
      stream: repo.watchUpcomingMatches(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return CustomScrollView(
            physics: _physics,
            clipBehavior: Clip.hardEdge,
            slivers: [
              PronoTabHeroSliver.build(
                context,
                title: 'Prochains matchs',
                subtitle: 'Tire vers le bas pour rafraîchir.',
              ),
              PronoTabHeroSliver.sheetLeadInSliver(),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(const [
                    DVCRCardSkeleton(),
                    SizedBox(height: 12),
                    DVCRCardSkeleton(),
                  ]),
                ),
              ),
            ],
          );
        }
        if (snap.hasError) {
          return CustomScrollView(
            physics: _physics,
            clipBehavior: Clip.hardEdge,
            slivers: [
              PronoTabHeroSliver.build(
                context,
                title: 'Prochains matchs',
                subtitle: 'Tire vers le bas pour rafraîchir.',
              ),
              PronoTabHeroSliver.sheetLeadInSliver(),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: PronoTokens.panelDecoration(
                        context,
                        radius: PronoTokens.radiusLg,
                      ),
                      child: Text(
                        'Impossible de charger les matchs.\nRéessaie dans un instant.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: PronoTokens.textMuted,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return CustomScrollView(
            physics: _physics,
            clipBehavior: Clip.hardEdge,
            slivers: [
              PronoTabHeroSliver.build(
                context,
                title: 'Prochains matchs',
                subtitle: 'Tire vers le bas pour rafraîchir.',
              ),
              PronoTabHeroSliver.sheetLeadInSliver(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: PronoGamifiedTipCard.matchWindow(),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: PronoTokens.panelDecoration(
                          context,
                          radius: PronoTokens.radiusLg,
                          strongGold: true,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: PronoTokens.accent.withAlpha(22),
                                border: Border.all(
                                  color: PronoTokens.accentGold.withAlpha(90),
                                ),
                              ),
                              child: Icon(
                                Icons.event_busy_rounded,
                                size: 40,
                                color: PronoTokens.accent,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Aucun match à venir',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: PronoTokens.text,
                                height: 1.02,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Dès qu’un match est au calendrier, tu le verras ici.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: PronoTokens.textMuted,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          color: PronoTokens.accent,
          displacement: 72,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: _physics,
            clipBehavior: Clip.hardEdge,
            slivers: [
              PronoTabHeroSliver.build(
                context,
                title: 'Prochains matchs',
                subtitle: 'Tire vers le bas pour rafraîchir.',
              ),
              PronoTabHeroSliver.sheetLeadInSliver(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: PronoGamifiedTipCard.matchWindow(),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        PronoMatchListTile(match: rows[i], uid: uid),
                    childCount: rows.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
