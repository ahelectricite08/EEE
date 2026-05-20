import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../screens/prono/prono_palette.dart';
import '../../../../screens/prono_screen.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';

/// Hub social : ligues, duels, amis, classements (écrans existants jusqu’à fusion complète).
class PronoSocialHubPage extends StatelessWidget {
  final String uid;
  final String displayName;

  const PronoSocialHubPage({
    super.key,
    required this.uid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      slivers: [
        PronoTabHeroSliver.build(
          context,
          title: 'Communauté',
          subtitle:
              'La tribu DVCR : ligues entre potes, duels de fierté, et ceux qui grimpent au classement.',
        ),
        PronoTabHeroSliver.sheetLeadInSliver(),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              PronoGamifiedTipCard.socialArena(),
              const SizedBox(height: 16),
              const _HubSectionHeader(
                eyebrow: 'MULTIJOUEUR',
                title: 'Ligues, duels & amis',
                icon: Icons.groups_rounded,
                accent: PronoIconAccent.social,
              ),
              const SizedBox(height: 14),
              _HubTile(
                accent: PronoIconAccent.progress,
                outerStripeColor: pronoSocialLeague,
                innerTintColor: pronoGreen,
                icon: Icons.groups_rounded,
                title: 'Ligues privées',
                subtitle: 'Crée ou rejoins une ligue entre potes.',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PronoLeaguesPage(
                      currentUid: uid,
                      displayName: displayName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              _HubTile(
                accent: PronoIconAccent.competitive,
                icon: Icons.sports_martial_arts_rounded,
                title: 'Duels',
                subtitle:
                    'Voir tes défis. Pour en créer : Amis → Défier → match.',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PronoDuelsPage(
                      currentUid: uid,
                      displayName: displayName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              _HubTile(
                accent: PronoIconAccent.social,
                outerStripeColor: pronoSocialFriend,
                innerTintColor: pronoGreen,
                icon: Icons.people_rounded,
                title: 'Amis',
                subtitle: 'Réseau pour inviter en ligue ou en duel.',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PronoFriendsPage(
                      currentUid: uid,
                      displayName: displayName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const _HubSectionHeader(
                eyebrow: 'PALMARÈS',
                title: 'Classements',
                icon: Icons.emoji_events_rounded,
                accent: PronoIconAccent.ranking,
              ),
              const SizedBox(height: 14),
              _HubTile(
                accent: PronoIconAccent.ranking,
                icon: Icons.leaderboard_rounded,
                title: 'Classement global',
                subtitle: 'Top pronostiqueurs DVCR.',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PronoLeaderboardPage(currentUid: uid),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              _HubTile(
                accent: PronoIconAccent.schedule,
                outerStripeColor: pronoSocialTopLeaguesBlue,
                innerTintColor: pronoGreen,
                icon: Icons.public_rounded,
                title: 'Top ligues',
                subtitle: 'Ligues les plus actives.',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PronoTopLeaguesPage(currentUid: uid),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData icon;
  final PronoIconAccent accent;

  const _HubSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.icon,
    this.accent = PronoIconAccent.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd + 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFCF8),
            PronoTokens.surface,
            const Color(0xFFEEF4F1),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: Color.lerp(
                PronoTokens.accentGold,
                PronoTokens.border,
                0.62,
              )!
              .withAlpha(100),
        ),
        boxShadow: [
          BoxShadow(
            color: PronoTokens.accentDeep.withAlpha(14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: PronoTokens.accentBarStripeColors(accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: PronoTokens.iconBadgeCircleDecoration(accent: accent),
            child: Icon(
              icon,
              size: 22,
              color: PronoTokens.iconAccentColors(accent).$3,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color.lerp(
                      PronoTokens.iconAccentColors(accent).$3,
                      PronoTokens.accentGold,
                      0.35,
                    )!,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                    height: 0.98,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final PronoIconAccent accent;
  /// Barre gauche + bordure : violet, bleu… (défaut = teinte de [accent]).
  final Color? outerStripeColor;
  /// Dégradé intérieur de la tuile (ex. vert prono).
  final Color? innerTintColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.accent,
    this.outerStripeColor,
    this.innerTintColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = PronoTokens.radiusLg;
    final tone = PronoTokens.iconAccentColors(accent);
    final edgeColor = outerStripeColor ?? tone.$3;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius + 1),
        splashColor: edgeColor.withAlpha(30),
        highlightColor: edgeColor.withAlpha(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius + 1),
            border: Border.all(
              color: Color.lerp(
                    edgeColor,
                    PronoTokens.border,
                    0.48,
                  )!
                  .withAlpha(98),
            ),
            boxShadow: [
              ...PronoTokens.cardShadow(context),
              BoxShadow(
                color: edgeColor.withAlpha(18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius + 1),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: pronoAccentStripeColors(edgeColor),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            PronoTokens.surface,
                            innerTintColor != null
                                ? Color.lerp(
                                      PronoTokens.surface,
                                      innerTintColor,
                                      0.1,
                                    )!
                                : const Color(0xFFF6FAF8),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 17, 12, 17),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: PronoTokens.iconBadgeDecoration(
                                radius: 18,
                                accent: accent,
                              ),
                              child: Icon(
                                icon,
                                color: PronoTokens.iconAccentColors(accent).$3,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                      color: PronoTokens.text,
                                      height: 1.02,
                                      letterSpacing: 0.35,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: PronoTokens.textMuted,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: PronoTokens.chevronCircleDecoration(),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
