import 'package:flutter/material.dart';

import '../../../../screens/prono_screen.dart';
import '../../../../services/app_settings_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';

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
          padding: EdgeInsets.fromLTRB(
            PronoArenaTheme.gutter,
            10,
            PronoArenaTheme.gutter,
            bottomInset,
          ),
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
///
/// Deux poids distincts : le multijoueur est un annuaire réglé (on y passe),
/// les classements sont un panneau de vestiaire (on y va).
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

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PronoThemeScope(
          pageAccent: PronoPageAccent.social,
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTip) ...[
          PronoGamifiedTipCard.socialArena(),
          const SizedBox(height: 22),
        ],
        const PronoSectionHeader(
          title: 'Multijoueur',
          pageAccent: pageAccent,
        ),
        const SizedBox(height: 2),
        PronoNavTile(
          icon: Icons.groups_rounded,
          indexLabel: '01',
          title: 'Ligues privées',
          subtitle: 'Crée ou rejoins une ligue entre potes.',
          pageAccent: pageAccent,
          onTap: () => _push(
            context,
            PronoLeaguesPage(currentUid: uid, displayName: displayName),
          ),
        ),
        PronoNavTile(
          icon: Icons.sports_martial_arts_rounded,
          indexLabel: '02',
          title: 'Duels',
          subtitle: 'Voir tes défis. Pour en créer : Amis → Défier.',
          pageAccent: pageAccent,
          onTap: () => _push(
            context,
            PronoDuelsPage(currentUid: uid, displayName: displayName),
          ),
        ),
        PronoNavTile(
          icon: Icons.people_rounded,
          indexLabel: '03',
          title: 'Amis',
          subtitle: 'Réseau pour inviter en ligue ou en duel.',
          pageAccent: pageAccent,
          onTap: () => _push(
            context,
            PronoFriendsPage(currentUid: uid, displayName: displayName),
          ),
        ),
        const SizedBox(height: 26),
        PronoRoomPanel(
          eyebrow: 'Classements',
          accent: pageAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StandingsRow(
                icon: Icons.leaderboard_rounded,
                title: 'Classement global',
                subtitle: 'Top pronostiqueurs DVCR.',
                onTap: () => _push(
                  context,
                  PronoLeaderboardPage(currentUid: uid),
                ),
              ),
              const PronoRule(top: 6, bottom: 6),
              _StandingsRow(
                icon: Icons.public_rounded,
                title: 'Top ligues',
                subtitle: 'Moyenne de points par membre.',
                onTap: () => _push(
                  context,
                  PronoTopLeaguesPage(currentUid: uid),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne de classement — compacte, dans le panneau. Une destination, pas une tâche.
class _StandingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StandingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = PronoSocialHubBody.pageAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.color.withValues(alpha: 0.06),
        highlightColor: accent.color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 20, color: accent.color),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.title.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: PronoTokens.textSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
