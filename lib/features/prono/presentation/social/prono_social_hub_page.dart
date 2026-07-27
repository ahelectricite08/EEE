import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../screens/prono_screen.dart';
import '../../../../services/app_settings_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';

/// Hub social : ligues, duels, amis, classements (écrans existants jusqu’à fusion complète).
///
/// Contenu métier aussi embarqué sur Accueil via [PronoSocialHubBody].
class PronoSocialHubPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.social;

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
          subtitle: 'Ligues, duels et amis.',
          pageAccent: _pageAccent,
          bannerSlot: PronoBannerSlot.social,
        ),
        PronoTabHeroSliver.sheetLeadInSliver(),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
          sliver: SliverToBoxAdapter(
            child: PronoSocialHubBody(
              uid: uid,
              displayName: displayName,
            ),
          ),
        ),
      ],
    );
  }
}

/// Corps multijoueur / classements — sans hero (pour Accueil ou hub standalone).
class PronoSocialHubBody extends StatelessWidget {
  static const pageAccent = PronoPageAccent.social;

  final String uid;
  final String displayName;
  final bool showTip;

  const PronoSocialHubBody({
    super.key,
    required this.uid,
    required this.displayName,
    this.showTip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTip) ...[
          PronoGamifiedTipCard.socialArena(),
          const SizedBox(height: 20),
        ],
        const _HubSectionHeader(
          title: 'Multijoueur',
          pageAccent: pageAccent,
        ),
        const SizedBox(height: 8),
        _HubTile(
          icon: Icons.groups_rounded,
          title: 'Ligues privées',
          subtitle: 'Crée ou rejoins une ligue entre potes.',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PronoThemeScope(
                pageAccent: PronoPageAccent.social,
                child: PronoLeaguesPage(
                  currentUid: uid,
                  displayName: displayName,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HubTile(
          icon: Icons.sports_martial_arts_rounded,
          title: 'Duels',
          subtitle: 'Voir tes défis. Pour en créer : Amis → Défier.',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PronoThemeScope(
                pageAccent: PronoPageAccent.social,
                child: PronoDuelsPage(
                  currentUid: uid,
                  displayName: displayName,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HubTile(
          icon: Icons.people_rounded,
          title: 'Amis',
          subtitle: 'Réseau pour inviter en ligue ou en duel.',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PronoThemeScope(
                pageAccent: PronoPageAccent.social,
                child: PronoFriendsPage(
                  currentUid: uid,
                  displayName: displayName,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _HubSectionHeader(
          title: 'Classements',
          pageAccent: pageAccent,
        ),
        const SizedBox(height: 8),
        _HubTile(
          icon: Icons.leaderboard_rounded,
          title: 'Classement global',
          subtitle: 'Top pronostiqueurs DVCR.',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PronoThemeScope(
                pageAccent: PronoPageAccent.social,
                child: PronoLeaderboardPage(currentUid: uid),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HubTile(
          icon: Icons.public_rounded,
          title: 'Top ligues',
          subtitle: 'Ligues les plus actives.',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PronoThemeScope(
                pageAccent: PronoPageAccent.social,
                child: PronoTopLeaguesPage(currentUid: uid),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  final String title;
  final PronoPageAccent pageAccent;

  const _HubSectionHeader({
    required this.title,
    required this.pageAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PronoArenaTheme.sectionAccentMark(pageAccent, size: 7),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: PronoTokens.text,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: PronoTokens.border,
          ),
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        child: Ink(
          decoration: PronoTheme.cardDecoration(
            radius: PronoTokens.radiusMd,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PronoTheme.cardPadding,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: PronoTokens.iconBadgeDecoration(
                  radius: 8,
                  accent: PronoIconAccent.social,
                ),
                child: Icon(
                  icon,
                  color: PronoSocialHubBody.pageAccent.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PronoTokens.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: PronoTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: PronoTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
