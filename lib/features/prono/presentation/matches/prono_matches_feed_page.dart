import 'package:flutter/material.dart';

import '../../../../services/app_settings_service.dart';
import '../../data/firestore_prono_repository.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_gamified_encart.dart';
import '../widgets/prono_tab_hero_sliver.dart';
import '../widgets/prono_ui.dart';
import 'prono_match_list_tile.dart';

/// Calendrier des pronos — langage RÉGLURE : aucune carte, des filets.
class PronoMatchesFeedPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.matchs;

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

  static Widget _note() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        PronoArenaTheme.gutter,
        4,
        PronoArenaTheme.gutter,
        6,
      ),
      sliver: SliverToBoxAdapter(child: PronoGamifiedTipCard.matchWindow()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = PronoTokens.bottomContentInset(context);

    // RefreshIndicator toujours là : waiting → data ne doit pas remplacer
    // un CustomScrollView nu par un autre parent (ça détruisait le hero).
    return RefreshIndicator(
      color: _pageAccent.color,
      displacement: 72,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: StreamBuilder<List<PronoMatchListItem>>(
        stream: repo.watchUpcomingMatches(),
        builder: (context, snap) {
          return CustomScrollView(
            key: const PageStorageKey<String>('prono-matches-feed'),
            physics: _physics,
            clipBehavior: Clip.hardEdge,
            slivers: [
              PronoTabHeroSliver.build(
                context,
                title: 'Prochains matchs',
                subtitle: 'Tire vers le bas pour rafraîchir.',
                pageAccent: _pageAccent,
                bannerSlot: PronoBannerSlot.matches,
              ),
              PronoTabHeroSliver.sheetLeadInSliver(),
              ..._bodySlivers(snap, bottomInset),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bodySlivers(
    AsyncSnapshot<List<PronoMatchListItem>> snap,
    double bottomInset,
  ) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(0, 14, 0, bottomInset),
          sliver: const SliverToBoxAdapter(
            child: PronoLoadingTape(rows: 6),
          ),
        ),
      ];
    }
    if (snap.hasError) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: PronoErrorState(
            title: 'Calendrier indisponible',
            body:
                'Impossible de charger les matchs. Réessaie dans un instant.',
            pageAccent: _pageAccent,
          ),
        ),
      ];
    }
    final rows = snap.data ?? const <PronoMatchListItem>[];
    if (rows.isEmpty) {
      return [
        _note(),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: PronoEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Aucun match à venir',
            body: 'Dès qu’un match est au calendrier, tu le verras ici.',
            pageAccent: _pageAccent,
          ),
        ),
      ];
    }
    return [
      _note(),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        sliver: SliverList(
          delegate: SliverChildListDelegate(
            _groupedMatchChildren(rows, uid),
          ),
        ),
      ),
    ];
  }

  static List<Widget> _groupedMatchChildren(
    List<PronoMatchListItem> rows,
    String uid,
  ) {
    final groups = <String, List<PronoMatchListItem>>{};
    final order = <String>[];
    for (final m in rows) {
      final key =
          '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}-${m.date.day.toString().padLeft(2, '0')}';
      if (!groups.containsKey(key)) {
        order.add(key);
        groups[key] = <PronoMatchListItem>[];
      }
      groups[key]!.add(m);
    }
    final out = <Widget>[];
    for (final key in order) {
      final list = groups[key]!;
      out.add(PronoDateHeader(date: list.first.date));
      for (final m in list) {
        out.add(PronoMatchListTile(match: m, uid: uid));
      }
    }
    return out;
  }
}
