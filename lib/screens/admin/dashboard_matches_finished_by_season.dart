import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/fff_season_config.dart';
import '../../services/season_config_service.dart';
import 'admin_palette.dart';
import 'admin_stat_widgets.dart';

/// Tuile « matchs joués » avec puces saison (active + archives classement).
class DashboardMatchesFinishedBySeason extends StatefulWidget {
  const DashboardMatchesFinishedBySeason({super.key});

  @override
  State<DashboardMatchesFinishedBySeason> createState() =>
      _DashboardMatchesFinishedBySeasonState();
}

class _DashboardMatchesFinishedBySeasonState
    extends State<DashboardMatchesFinishedBySeason> {
  String _season = FffSeasonConfig.defaults.seasonLabel;

  static Future<String> _countFinished(String season) async {
    final tagged = await FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'finished')
        .where('fffSeason', isEqualTo: season)
        .count()
        .get();
    var total = tagged.count ?? 0;
    if (season == FffSeasonConfig.implicitLegacySeasonLabel) {
      final legacy = await FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .where('fffSeason', isEqualTo: null)
          .count()
          .get();
      total += legacy.count ?? 0;
    }
    return '$total';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ranking_archive')
              .snapshots(),
          builder: (context, archSnap) {
            final chips = FffSeasonConfig.seasonChips(
              cfg,
              archSnap.data?.docs.map((d) => d.id) ?? const [],
            );
            final display =
                chips.contains(_season) ? _season : cfg.seasonLabel;
            if (!chips.contains(_season)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _season = cfg.seasonLabel);
                }
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in chips)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 2),
                          child: Material(
                            color: s == display
                                ? adminGreen.withAlpha(40)
                                : adminCard,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: () => setState(() => _season = s),
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  s,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: s == display
                                        ? adminGreen
                                        : adminTextPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                FutureBuilder<String>(
                  key: ValueKey(display),
                  future: _countFinished(display),
                  builder: (context, snap) {
                    Widget inner;
                    if (snap.hasError) {
                      inner = Tooltip(
                        message: '${snap.error}',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: adminRed,
                          size: 26,
                        ),
                      );
                    } else if (snap.connectionState ==
                        ConnectionState.waiting) {
                      inner = SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: adminGreen,
                        ),
                      );
                    } else {
                      inner = Text(
                        snap.data ?? '–',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: adminTextPrimary,
                          height: 1,
                          letterSpacing: -0.3,
                        ),
                      );
                    }
                    return AdminStatCardShell(
                      color: adminGreen,
                      icon: Icons.emoji_events_rounded,
                      label: 'MATCHS JOUÉS ($display)',
                      child: inner,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
