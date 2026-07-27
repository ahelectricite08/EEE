import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/fff_season_config.dart';
import '../../services/season_config_service.dart';
import 'admin_module_colors.dart';
import 'admin_palette.dart';

/// Compteur matchs joués — mode dense (ligne KPI) ou legacy carte.
class DashboardMatchesFinishedBySeason extends StatefulWidget {
  final bool dense;

  const DashboardMatchesFinishedBySeason({super.key, this.dense = false});

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
                if (mounted) setState(() => _season = cfg.seasonLabel);
              });
            }

            return FutureBuilder<String>(
              key: ValueKey(display),
              future: _countFinished(display),
              builder: (context, snap) {
                final loading = snap.connectionState ==
                        ConnectionState.waiting &&
                    snap.data == null;
                final valueChild = snap.hasError
                    ? Icon(Icons.warning_amber_rounded,
                        color: adminRed, size: 16)
                    : loading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminModuleColors.pilotage,
                            ),
                          )
                        : Text(
                            snap.data ?? '–',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: widget.dense ? 18 : 26,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              height: 1,
                            ),
                          );

                if (widget.dense) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 15, color: AdminModuleColors.pilotage),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Matchs joués',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: adminTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _SeasonChips(
                                chips: chips,
                                selected: display,
                                onSelect: (s) => setState(() => _season = s),
                              ),
                            ],
                          ),
                        ),
                        valueChild,
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SeasonChips(
                      chips: chips,
                      selected: display,
                      onSelect: (s) => setState(() => _season = s),
                    ),
                    const SizedBox(height: 8),
                    valueChild,
                    const SizedBox(height: 4),
                    Text(
                      'MATCHS JOUÉS ($display)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: adminGrey,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SeasonChips extends StatelessWidget {
  final List<String> chips;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SeasonChips({
    required this.chips,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in chips)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => onSelect(s),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: s == selected
                        ? AdminModuleColors.pilotage.withAlpha(28)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: s == selected
                          ? AdminModuleColors.pilotage.withAlpha(90)
                          : adminBorder,
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: s == selected
                          ? AdminModuleColors.pilotage
                          : adminGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
