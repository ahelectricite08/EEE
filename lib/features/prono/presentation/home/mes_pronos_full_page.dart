import 'package:flutter/material.dart';

import '../../../../services/prono_social_service.dart';
import '../../domain/my_prono.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_date_header.dart';
import '../widgets/prono_page_header.dart';
import '../widgets/prono_ui.dart';
import 'mes_prono_line.dart';

/// Toutes les journées de pronos posés (depuis « Voir plus »).
class MesPronosFullPage extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.accueil;

  final String uid;

  const MesPronosFullPage({super.key, required this.uid});

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
            title: 'Mes pronos',
            subtitle: 'Toutes tes journées posées.',
            kicker: 'Arène',
            pageAccent: _pageAccent,
          ),
          body: StreamBuilder<List<MyPronoItem>>(
            stream: PronoSocialService.watchMyRecentPredictions(uid, limit: 50),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const SingleChildScrollView(
                  child: PronoLoadingTape(rows: 5),
                );
              }
              if (snap.hasError) {
                return const PronoErrorState(
                  title: 'Pronos indisponibles',
                  body:
                      'Impossible de charger tes journées pour le moment. Réessaie dans un instant.',
                  pageAccent: _pageAccent,
                );
              }
              final items = snap.data ?? const <MyPronoItem>[];
              if (items.isEmpty) {
                return const PronoEmptyState(
                  icon: Icons.sports_soccer_outlined,
                  title: 'Aucun prono posé',
                  body: 'Va sur Match pour jouer une journée.',
                  pageAccent: _pageAccent,
                );
              }
              final groups = groupMyPronos(
                items,
                dateLabel: (d) => PronoDateHeader.labelFor(d),
              );
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
                        g.label.toUpperCase(),
                        style: PronoType.kicker,
                      ),
                    ),
                    for (final row in g.items) MesPronoLine(item: row),
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
