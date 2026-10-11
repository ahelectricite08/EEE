import 'package:flutter/material.dart';

import '../../../../services/lineup_prediction_service.dart';
import '../../domain/my_compo.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_page_header.dart';
import '../widgets/prono_ui.dart';
import 'mes_compo_line.dart';

/// Toutes les compos XI posées (depuis « Voir plus »).
class MesComposFullPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final String uid;

  const MesComposFullPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return PronoThemeScope(
      pageAccent: _pageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PronoPageHeader.asAppBar(
            context: context,
            title: 'Mes compos',
            subtitle: 'Tes XI probables, match après match.',
            kicker: 'Arène',
            pageAccent: _pageAccent,
          ),
          body: StreamBuilder<List<MyCompoItem>>(
            stream: LineupPredictionService.watchMyCompos(uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const SingleChildScrollView(
                  child: PronoLoadingTape(rows: 5),
                );
              }
              if (snap.hasError) {
                return const PronoErrorState(
                  title: 'Compos indisponibles',
                  body:
                      'Impossible de charger tes XI pour le moment. Réessaie dans un instant.',
                  pageAccent: _pageAccent,
                );
              }
              final items = snap.data ?? const <MyCompoItem>[];
              if (items.isEmpty) {
                return const PronoEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Aucune compo posée',
                  body: 'Compose un XI probable Sedan depuis l’accueil Pronos.',
                  pageAccent: _pageAccent,
                );
              }
              final groups = _groupByDate(items);
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  PronoArenaTheme.gutter,
                  12,
                  PronoArenaTheme.gutter,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(
                        g.$1.toUpperCase(),
                        style: PronoType.kicker,
                      ),
                    ),
                    for (final row in g.$2)
                      MesCompoLine(item: row, showPitches: true),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

List<(String, List<MyCompoItem>)> _groupByDate(List<MyCompoItem> items) {
  final buckets = <String, List<MyCompoItem>>{};
  final order = <String>[];
  for (final e in items) {
    final label = PronoDateHeader.labelFor(e.matchDate);
    if (!buckets.containsKey(label)) {
      order.add(label);
      buckets[label] = [];
    }
    buckets[label]!.add(e);
  }
  return [for (final k in order) (k, buckets[k]!)];
}
