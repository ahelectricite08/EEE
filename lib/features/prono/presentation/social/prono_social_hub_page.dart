import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../screens/prono_screen.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/prono_social_service.dart';
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
/// Même famille presse : annuaire réglé pour y passer (ligues, duels, amis)
/// et pour y aller (classement global, top ligues).
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
        PronoMyLeaguesShortcut(
          uid: uid,
          pageAccent: pageAccent,
          padding: const EdgeInsets.only(bottom: 26),
        ),
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
        const PronoSectionHeader(
          title: 'Classements',
          pageAccent: pageAccent,
        ),
        const SizedBox(height: 2),
        PronoNavTile(
          icon: Icons.leaderboard_rounded,
          indexLabel: '01',
          title: 'Classement global',
          subtitle: 'Top pronostiqueurs DVCR.',
          pageAccent: pageAccent,
          onTap: () => _push(
            context,
            PronoLeaderboardPage(currentUid: uid),
          ),
        ),
        const SizedBox(height: 18),
        PronoSectionHeader(
          title: 'Top ligues',
          pageAccent: pageAccent,
          action: GestureDetector(
            onTap: () => _push(
              context,
              PronoTopLeaguesPage(currentUid: uid),
            ),
            child: Text(
              'TOUT VOIR',
              style: PronoType.kicker.copyWith(
                color: PronoArenaTheme.goldDeep,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _TopLiguePreview(
          uid: uid,
          onOpen: () => _push(
            context,
            PronoTopLeaguesPage(currentUid: uid),
          ),
        ),
      ],
    );
  }
}

/// Raccourci 1 tap vers le salon (classement + pronos). Invisible si aucune ligue.
class PronoMyLeaguesShortcut extends StatelessWidget {
  final String uid;
  final PronoPageAccent pageAccent;
  final EdgeInsetsGeometry padding;

  const PronoMyLeaguesShortcut({
    super.key,
    required this.uid,
    required this.pageAccent,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.leaguesForUser(uid),
      builder: (context, snap) {
        final leagues = snap.data?.docs ?? const [];
        if (leagues.isEmpty) return const SizedBox.shrink();

        final several = leagues.length > 1;
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PronoSectionHeader(
                title: several ? 'Tes ligues' : 'Ta ligue',
                countLabel: several ? '${leagues.length}' : null,
                pageAccent: pageAccent,
              ),
              const SizedBox(height: 2),
              ...leagues.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? 'Ligue privée').toString();
                final members = (data['memberCount'] as num?)?.toInt() ??
                    ((data['memberIds'] as List?)?.length ?? 0);
                final memberLabel = members > 0
                    ? '$members membre${members > 1 ? 's' : ''} · '
                    : '';
                return PronoNavTile(
                  icon: Icons.shield_outlined,
                  title: name,
                  subtitle: '${memberLabel}classement et pronos',
                  pageAccent: pageAccent,
                  onTap: () => openPronoLeagueSalon(
                    context: context,
                    currentUid: uid,
                    leagueId: doc.id,
                    league: data,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Peloton des ligues — même réglure presse que le classement Accueil.
/// Une ligne « TA LIGUE » ouvre le salon ; le reste mène au classement public.
class _TopLiguePreview extends StatelessWidget {
  final String uid;
  final VoidCallback onOpen;

  const _TopLiguePreview({
    required this.uid,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.leaguesForUser(uid),
      builder: (context, mineSnap) {
        final mineById = <String, Map<String, dynamic>>{
          for (final doc in mineSnap.data?.docs ?? const []) doc.id: doc.data(),
        };
        return StreamBuilder<List<TopLeagueRow>>(
          stream: PronoSocialService.topLeaguesByMemberPointsStream(limit: 5),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const PronoLoadingTape(rows: 3, horizontalPadding: 0);
            }
            final rows = snap.data ?? const <TopLeagueRow>[];
            if (snap.hasError || rows.isEmpty) {
              return GestureDetector(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Crée ou rejoins une ligue — elle apparaîtra ici, même à un membre.',
                    style: PronoType.caption,
                  ),
                ),
              );
            }

            final top = rows.take(5).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: onOpen,
                  behavior: HitTestBehavior.opaque,
                  child:
                      const PronoPressRankingHeader(nameLabel: 'Ligue privée'),
                ),
                for (var i = 0; i < top.length; i++)
                  PronoPressRankingRow(
                    rank: i + 1,
                    title: top[i].name,
                    subtitle:
                        '${top[i].memberCount} membre${top[i].memberCount > 1 ? 's' : ''}',
                    valueLabel: top[i].memberPointsAvgLabel,
                    isMe: top[i].memberIds.contains(uid),
                    meLabel: 'TA LIGUE',
                    onTap: top[i].memberIds.contains(uid)
                        ? () => openPronoLeagueSalon(
                              context: context,
                              currentUid: uid,
                              leagueId: top[i].id,
                              league: mineById[top[i].id],
                            )
                        : onOpen,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
