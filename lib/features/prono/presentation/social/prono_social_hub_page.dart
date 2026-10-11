import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../models/league_avatars.dart';
import '../../../../models/private_league.dart';
import '../../../../screens/prono_screen.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/prono_social_service.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/league_emblem_picker.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';

Future<void> _requestHubLeagueEmblemEdit({
  required BuildContext context,
  required String uid,
  required String leagueId,
  required Map<String, dynamic> league,
}) async {
  PronoSocialService.backfillLeagueOwnerIfMissing(
    leagueId: leagueId,
    uid: uid,
    league: league,
  );
  final stored = leagueAvatarIdFromData(league);
  await requestLeagueEmblemChange(
    context: context,
    canEdit: canEditPrivateLeagueEmblem(league, uid),
    selectedId: stored,
    onSelected: (id) async {
      final ok = await PronoSocialService.updateLeagueAvatar(
        leagueId: leagueId,
        ownerUid: uid,
        avatarId: id,
      );
      if (!context.mounted || ok) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de changer l’emblème.'),
        ),
      );
    },
  );
}

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
  final bool compact;

  const PronoSocialHubBody({
    super.key,
    required this.uid,
    required this.displayName,
    this.showTip = true,
    this.compact = false,
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
        if (showTip && !compact) ...[
          PronoGamifiedTipCard.socialArena(),
          const SizedBox(height: 22),
        ],
        PronoMyLeaguesShortcut(
          uid: uid,
          pageAccent: pageAccent,
          padding: const EdgeInsets.only(bottom: 26),
          onOpenLeagues: () => _push(
            context,
            PronoLeaguesPage(currentUid: uid, displayName: displayName),
          ),
        ),
        PronoSectionHeader(
          title: compact ? 'Entre potes' : 'Multijoueur',
          pageAccent: pageAccent,
        ),
        const SizedBox(height: 2),
        PronoNavTile(
          icon: Icons.shield_outlined,
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
        if (compact) ...[
          PronoNavTile(
            icon: Icons.leaderboard_rounded,
            indexLabel: '04',
            title: 'Classement global',
            subtitle: 'Top pronostiqueurs DVCR.',
            pageAccent: pageAccent,
            onTap: () => _push(
              context,
              PronoLeaderboardPage(currentUid: uid),
            ),
          ),
          PronoNavTile(
            icon: Icons.flag_outlined,
            indexLabel: '05',
            title: 'Top ligues',
            subtitle: 'Les vestiaires les plus forts, à la moyenne.',
            pageAccent: pageAccent,
            onTap: () => _push(
              context,
              PronoTopLeaguesPage(currentUid: uid),
            ),
          ),
        ] else ...[
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
      ],
    );
  }
}

/// Vestiaire « Ta ligue » — panneau papier même à vide (plus un raccourci fantôme).
class PronoMyLeaguesShortcut extends StatelessWidget {
  final String uid;
  final PronoPageAccent pageAccent;
  final EdgeInsetsGeometry padding;
  final VoidCallback onOpenLeagues;

  const PronoMyLeaguesShortcut({
    super.key,
    required this.uid,
    required this.pageAccent,
    required this.onOpenLeagues,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PronoSocialService.leaguesForUser(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PronoSectionHeader(
                  title: 'Ta ligue',
                  pageAccent: pageAccent,
                ),
                const PronoLoadingTape(rows: 1, horizontalPadding: 0),
              ],
            ),
          );
        }

        final leagues = snap.data?.docs ?? const [];
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
              const SizedBox(height: 8),
              if (leagues.isEmpty)
                PronoRoomPanel(
                  eyebrow: 'Vestiaire',
                  accent: pageAccent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pas encore de salon',
                        style: PronoType.headline.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crée ta ligue ou entre le code d’un pote — le vestiaire '
                        's’ouvre ici, avec le classement et le code d’invitation.',
                        style: PronoType.caption,
                      ),
                      const SizedBox(height: 18),
                      PronoInkCta(
                        label: 'Créer ou rejoindre',
                        icon: Icons.groups_rounded,
                        onTap: onOpenLeagues,
                      ),
                    ],
                  ),
                )
              else if (leagues.length == 1)
                _LeagueVestiaireHero(
                  uid: uid,
                  leagueId: leagues.first.id,
                  league: leagues.first.data(),
                )
              else
                PronoRoomPanel(
                  eyebrow: 'Tes salons',
                  accent: pageAccent,
                  trailing: Text(
                    '${leagues.length}',
                    style: PronoType.meta,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < leagues.length; i++)
                        _LeagueVestiaireRow(
                          uid: uid,
                          leagueId: leagues[i].id,
                          league: leagues[i].data(),
                          last: i == leagues.length - 1,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LeagueVestiaireHero extends StatelessWidget {
  final String uid;
  final String leagueId;
  final Map<String, dynamic> league;

  const _LeagueVestiaireHero({
    required this.uid,
    required this.leagueId,
    required this.league,
  });

  @override
  Widget build(BuildContext context) {
    final name = (league['name'] ?? 'Ligue privée').toString();
    final members = (league['memberCount'] as num?)?.toInt() ??
        ((league['memberIds'] as List?)?.length ?? 0);
    final memberLabel = members > 0
        ? '$members membre${members > 1 ? 's' : ''}'
        : 'Salon privé';
    final avg = pronoLeagueAvgPtsLabel(league);
    final meta = avg == null ? memberLabel : '$memberLabel · moy. $avg pts';

    return PronoRoomPanel(
      eyebrow: 'Ta ligue',
      trailing: Text(
        'TA LIGUE',
        style: PronoType.kickerGoldPaper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => openPronoLeagueSalon(
              context: context,
              currentUid: uid,
              leagueId: leagueId,
              league: league,
            ),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PronoIdentityMark(
                  name: name,
                  size: 56,
                  highlighted: true,
                  avatarUrl: leagueAvatarSrcFromData(league),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.headline.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(meta, style: PronoType.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: PronoTokens.textSoft,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<String>(
            stream: PronoSocialService.watchLeagueInviteCode(leagueId),
            builder: (context, snap) {
              return PronoCodeStamp(
                code: snap.data ?? '',
                wide: true,
              );
            },
          ),
          const SizedBox(height: 12),
          LeagueHubEmblemEditAffordance(
            onTap: () => _requestHubLeagueEmblemEdit(
              context: context,
              uid: uid,
              leagueId: leagueId,
              league: league,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueVestiaireRow extends StatelessWidget {
  final String uid;
  final String leagueId;
  final Map<String, dynamic> league;
  final bool last;

  const _LeagueVestiaireRow({
    required this.uid,
    required this.leagueId,
    required this.league,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final name = (league['name'] ?? 'Ligue privée').toString();
    final members = (league['memberCount'] as num?)?.toInt() ??
        ((league['memberIds'] as List?)?.length ?? 0);
    final memberLabel = members > 0
        ? '$members membre${members > 1 ? 's' : ''}'
        : 'Salon privé';
    final avg = pronoLeagueAvgPtsLabel(league);
    final meta = avg == null ? memberLabel : '$memberLabel · moy. $avg pts';

    return Container(
      decoration: last ? const BoxDecoration() : PronoArenaTheme.fixtureTape(),
      padding: EdgeInsets.only(bottom: last ? 0 : 12, top: last ? 12 : 4),
      child: GestureDetector(
        onTap: () => openPronoLeagueSalon(
          context: context,
          currentUid: uid,
          leagueId: leagueId,
          league: league,
        ),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            PronoIdentityMark(
              name: name,
              size: 40,
              highlighted: true,
              avatarUrl: leagueAvatarSrcFromData(league),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.title.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 3),
                  Text(meta, style: PronoType.caption),
                ],
              ),
            ),
            LeagueHubEmblemEditAffordance(
              iconOnly: true,
              onTap: () => _requestHubLeagueEmblemEdit(
                context: context,
                uid: uid,
                leagueId: leagueId,
                league: league,
              ),
            ),
            StreamBuilder<String>(
              stream: PronoSocialService.watchLeagueInviteCode(leagueId),
              builder: (context, snap) {
                return PronoCodeStamp(code: snap.data ?? '');
              },
            ),
          ],
        ),
      ),
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
                    avatarUrl: top[i].avatarSrc,
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
