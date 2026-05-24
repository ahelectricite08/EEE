import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/fff_season_config.dart';
import '../../../../models/user_role.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../../../services/season_config_service.dart';
import '../../admin_controller.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'match_stats_workbench_screen.dart';
import 'stats_admin_helpers.dart';
import 'stats_compare_screen.dart';
import 'stats_workflow_ui.dart';

/// Stats match — parcours jour de match : Préparer → En direct → Officiel.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  static final _db = FirebaseFirestore.instance;
  String _adminStatsSeason = FffSeasonConfig.defaults.seasonLabel;
  bool _compareMode = false;
  final Set<String> _selected = {};

  Future<void> _prepareAndOpen(BuildContext ctx, AdminMatchRowData row) async {
    try {
      await MatchStatsSheetService.instance.prepareSession(row.id);
    } catch (_) {}
    if (ctx.mounted) _openWorkbench(ctx, row);
  }

  void _openWorkbench(BuildContext ctx, AdminMatchRowData row) {
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchStatsWorkbenchScreen(
          matchId: row.id,
          team1: row.t1,
          team2: row.t2,
        ),
      ),
    );
  }

  void _handleHeroPrimary(
    BuildContext ctx,
    AdminMatchRowData row,
    StatsWorkflowStep step,
  ) {
    if (step == StatsWorkflowStep.prepare) {
      _prepareAndOpen(ctx, row);
    } else {
      _openWorkbench(ctx, row);
    }
  }

  void _openCompare(BuildContext ctx, List<AdminMatchRowData> rows) {
    final sel = rows.where((r) => _selected.contains(r.id)).toList();
    if (sel.length < 2) return;
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => StatsCompareScreen(selectedRows: sel),
      ),
    );
  }

  Future<void> _syncNow(BuildContext ctx, String matchId) async {
    try {
      await MatchStatsSheetService.instance.syncNow(matchId);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Publié dans l\'app', style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(220),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  Future<void> _finalizeMatch(BuildContext ctx, AdminMatchRowData row) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Terminer le match ?',
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Text(
          'Les stats deviennent officielles sur la fiche match.',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'TERMINER',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MatchStatsSheetService.instance.finalize(row.id);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Stats officielles', style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(220),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  Future<void> _reopenMatch(BuildContext ctx, AdminMatchRowData row) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Rouvrir pour corriger ?',
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Text(
          'Tu pourras modifier puis terminer à nouveau le match.',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'ROUVRIR',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MatchStatsSheetService.instance.reopen(row.id);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Saisie rouverte', style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(220),
          ),
        );
        _openWorkbench(ctx, row);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  Future<void> _migrateLegacyStats(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Migrer les stats ?',
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Text(
          'Copie les anciennes stats vers le nouveau système.',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('MIGRER', style: GoogleFonts.inter(color: adminGold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await MatchStatsSheetService.instance.migrateFromMatches();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('$n migré(s)', style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(220),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  bool _isAdmin(BuildContext ctx) {
    try {
      return AdminControllerProvider.of(ctx)
          .userRoles
          .contains(UserRole.admin);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FffSeasonConfig>(
      stream: SeasonConfigService.stream(),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? FffSeasonConfig.defaults;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('ranking_archive').snapshots(),
          builder: (context, archSnap) {
            final chips = FffSeasonConfig.seasonChips(
              cfg,
              archSnap.data?.docs.map((d) => d.id) ?? const [],
            );
            final displaySeason = chips.contains(_adminStatsSeason)
                ? _adminStatsSeason
                : cfg.seasonLabel;
            if (!chips.contains(_adminStatsSeason)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _adminStatsSeason = cfg.seasonLabel);
              });
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('matches')
                  .orderBy('date', descending: true)
                  .limit(650)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: adminGold),
                  );
                }
                final seen = <String>{};
                final docs = snap.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  if (!FffSeasonConfig.matchDocBelongsToSeason(
                    d,
                    displaySeason,
                  )) {
                    return false;
                  }
                  final t1 = (d['team1'] as String? ?? '').toUpperCase();
                  final t2 = (d['team2'] as String? ?? '').toUpperCase();
                  if (!t1.contains('SEDAN') && !t2.contains('SEDAN')) {
                    return false;
                  }
                  final ts = d['date'] as Timestamp?;
                  final key = '$t1|$t2|${ts?.seconds ?? doc.id}';
                  if (seen.contains(key)) return false;
                  seen.add(key);
                  return true;
                }).toList();

                final rows = docs.map(AdminMatchRowData.fromDoc).toList();
                final todayMatch = pickLiveMatchCandidate(rows);
                final historyRows = todayMatch == null
                    ? rows
                    : rows.where((r) => r.id != todayMatch.id).toList();
                final isAdmin = _isAdmin(ctx);
                final todayStep = todayMatch == null
                    ? null
                    : statsWorkflowStep(todayMatch.d);
                final averages = computeSedanSeasonAverages(rows);

                return Column(
                  children: [
                    _buildHeader(ctx, chips, isAdmin),
                    if (_compareMode)
                      _buildCompareBanner(ctx, rows)
                    else if (todayMatch != null && todayStep != null)
                      StatsMatchDayHero(
                        row: todayMatch,
                        step: todayStep,
                        onPrimary: () =>
                            _handleHeroPrimary(ctx, todayMatch, todayStep),
                        onSync: todayStep != StatsWorkflowStep.official
                            ? () => _syncNow(ctx, todayMatch.id)
                            : null,
                        onFinalize: todayStep != StatsWorkflowStep.official
                            ? () => _finalizeMatch(ctx, todayMatch)
                            : null,
                        onReopen: todayStep == StatsWorkflowStep.official
                            ? () => _reopenMatch(ctx, todayMatch)
                            : null,
                      ),
                    if (!_compareMode && averages.any((a) => a.count > 0))
                      _buildSeasonAveragesCard(averages),
                    Expanded(
                      child: rows.isEmpty
                          ? _buildEmpty()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                if (historyRows.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'HISTORIQUE SAISON',
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: adminTextPrimary,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${historyRows.length} matchs',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: adminGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...historyRows.map((row) {
                                    final step = statsWorkflowStep(row.d);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _StatsMatchRow(
                                        row: row,
                                        step: step,
                                        compareMode: _compareMode,
                                        selected: _selected.contains(row.id),
                                        onTap: () {
                                          if (_compareMode) {
                                            setState(() {
                                              if (_selected.contains(row.id)) {
                                                _selected.remove(row.id);
                                              } else {
                                                _selected.add(row.id);
                                              }
                                            });
                                          } else {
                                            _handleHeroPrimary(ctx, row, step);
                                          }
                                        },
                                        onReopen: step == StatsWorkflowStep.official
                                            ? () => _reopenMatch(ctx, row)
                                            : null,
                                        onToggleSelect: () => setState(() {
                                          if (_selected.contains(row.id)) {
                                            _selected.remove(row.id);
                                          } else {
                                            _selected.add(row.id);
                                          }
                                        }),
                                      ),
                                    );
                                  }),
                                ],
                              ],
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

  Widget _buildHeader(
    BuildContext ctx,
    List<String> chips,
    bool isAdmin,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'STATS MATCH',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (_compareMode)
                TextButton(
                  onPressed: () => setState(() {
                    _compareMode = false;
                    _selected.clear();
                  }),
                  child: Text(
                    'ANNULER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: adminGrey,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => setState(() {
                    _compareMode = true;
                    _selected.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [adminGold.withAlpha(40), adminGold.withAlpha(20)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminGold.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.compare_arrows_rounded,
                          color: adminGold,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'COMPARER MATCHS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: adminGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Migration',
                  icon: const Icon(Icons.sync_rounded, size: 18, color: adminGrey),
                  onPressed: () => _migrateLegacyStats(ctx),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: s == _adminStatsSeason
                          ? adminGold.withAlpha(35)
                          : adminCard,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: () => setState(() => _adminStatsSeason = s),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: s == _adminStatsSeason
                                  ? adminGold
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
        ],
      ),
    );
  }

  Widget _buildCompareBanner(BuildContext ctx, List<AdminMatchRowData> rows) {
    final n = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: adminGold.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminGold.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode comparaison',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminGold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coche les matchs dans la liste, puis ouvre le graphique.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '$n sélectionné(s)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: n >= 2 ? () => _openCompare(ctx, rows) : null,
                  icon: const Icon(Icons.bar_chart_rounded, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: adminGold,
                    foregroundColor: Colors.black,
                  ),
                  label: Text(
                    'Voir graphique',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonAveragesCard(List<SedanSeasonAverage> averages) {
    final withData = averages.where((a) => a.count > 0).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: adminBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, size: 16, color: adminGold),
                const SizedBox(width: 8),
                Text(
                  'MOYENNES SEDAN — SAISON',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: withData
                  .map(
                    (a) => Container(
                      width: 88,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: adminSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: adminBorder.withAlpha(180)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.label,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: adminGrey,
                            ),
                          ),
                          Text(
                            a.value,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: adminGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'Aucun match Sedan cette saison',
        style: GoogleFonts.inter(color: adminGrey, fontSize: 14),
      ),
    );
  }
}

class _StatsMatchRow extends StatelessWidget {
  final AdminMatchRowData row;
  final StatsWorkflowStep step;
  final bool compareMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onReopen;
  final VoidCallback onToggleSelect;

  const _StatsMatchRow({
    required this.row,
    required this.step,
    required this.compareMode,
    required this.selected,
    required this.onTap,
    this.onReopen,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = statsWorkflowColor(step);
    return Material(
      color: selected ? adminGold.withAlpha(18) : adminCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? adminGold : adminBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (compareMode)
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelect(),
                  activeColor: adminGold,
                ),
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(compareMode ? 0 : 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.t1} vs ${row.t2}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          AdminStatusChip(
                            label: statsWorkflowLabel(step).toUpperCase(),
                            color: color,
                          ),
                          const SizedBox(width: 5),
                          AdminStatusChip(label: row.date, color: adminGrey),
                          if (row.hasStats) ...[
                            const SizedBox(width: 5),
                            AdminStatusChip(label: row.score, color: adminGold),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!compareMode && onReopen != null)
                IconButton(
                  tooltip: 'Rouvrir',
                  icon: const Icon(Icons.lock_open_rounded, size: 18, color: adminGold),
                  onPressed: onReopen,
                )
              else if (!compareMode)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: adminGrey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
