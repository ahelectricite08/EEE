import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/fff_season_config.dart';
import '../../../../services/match_service.dart';
import '../../../../utils/match_competition.dart';
import '../../../../models/user_role.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../../../services/season_config_service.dart';
import '../../admin_controller.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../../admin_navigation.dart';
import '../../widgets/admin_match_flow_guide.dart';
import '../../widgets/match_admin_context_banner.dart';
import 'stats_admin_helpers.dart';
import 'stats_compare_screen.dart';
import 'stats_workflow_ui.dart';

/// Stats match — parcours jour de match : Préparer → En direct → Officiel.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with SingleTickerProviderStateMixin {
  static final _db = FirebaseFirestore.instance;
  String _adminStatsSeason = FffSeasonConfig.defaults.seasonLabel;
  String _adminStatsCompetition = 'all';
  String? _adminStatsChampionshipLevel;
  final Set<String> _selected = {};
  late final TabController _subTabs;

  @override
  void initState() {
    super.initState();
    _subTabs = TabController(length: 3, vsync: this);
    _subTabs.addListener(() {
      if (_subTabs.indexIsChanging) return;
      if (_subTabs.index != 2) {
        setState(_selected.clear);
      }
    });
  }

  @override
  void dispose() {
    _subTabs.dispose();
    super.dispose();
  }

  Future<void> _prepareAndOpen(BuildContext ctx, AdminMatchRowData row) async {
    try {
      await MatchStatsSheetService.instance.prepareSession(row.id);
    } catch (_) {}
    if (ctx.mounted) _openWorkbench(ctx, row);
  }

  void _openWorkbench(BuildContext ctx, AdminMatchRowData row) {
    AdminNavigation.openStatsWorkbench(
      ctx,
      matchId: row.id,
      team1: row.t1,
      team2: row.t2,
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

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('match_stats').snapshots(),
              builder: (ctx, sheetsSnap) {
                final sheetsById = <String, Map<String, dynamic>>{};
                for (final doc in sheetsSnap.data?.docs ?? const []) {
                  sheetsById[doc.id] = doc.data();
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
                final docs = MatchService.dedupeMatchDocuments(
                  snap.data!.docs
                      .cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
                  preferManualInDuplicates: true,
                ).where((doc) {
                  final d = doc.data();
                  if (!FffSeasonConfig.matchDocBelongsToSeason(
                    d,
                    displaySeason,
                    activeSeasonLabel: cfg.seasonLabel,
                  )) {
                    return false;
                  }
                  final t1 = (d['team1'] as String? ?? '').toUpperCase();
                  final t2 = (d['team2'] as String? ?? '').toUpperCase();
                  return t1.contains('SEDAN') ||
                      t1.contains('CSSA') ||
                      t2.contains('SEDAN') ||
                      t2.contains('CSSA');
                }).toList();

                final allRows = docs
                    .map(
                      (d) => AdminMatchRowData.fromDoc(
                        d,
                        sheet: sheetsById[d.id],
                      ),
                    )
                    .toList();
                final rows = allRows
                    .where(
                      (r) => MatchCompetition.matchesStatsFilter(
                        r.d['competition'] as String?,
                        categoryId: _adminStatsCompetition,
                        championshipLevel: _adminStatsChampionshipLevel,
                      ),
                    )
                    .toList();
                sortStatsMatchRows(
                  rows,
                  groupByCompetition: _adminStatsCompetition == 'all',
                );
                final isAdmin = _isAdmin(ctx);
                final averages = computeSedanSeasonAverages(rows);
                final filterSummary = MatchCompetition.statsFilterSummaryLabel(
                  categoryId: _adminStatsCompetition,
                  championshipLevel: _adminStatsChampionshipLevel,
                );

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _db.doc('live/current').snapshots(),
                  builder: (ctx, liveSnap) {
                    final liveMatchId =
                        (liveSnap.data?.data()?['matchId'] as String? ?? '')
                            .trim();
                    final session = pickStatsEnDirectSession(
                      rows,
                      sheetsById: sheetsById,
                      liveMatchId: liveMatchId,
                    );
                    StatsWorkflowStep? sessionStep;
                    if (session != null) {
                      sessionStep = statsWorkflowStep(
                        session.d,
                        sheetState:
                            sheetsById[session.id]?['state']?.toString(),
                      );
                    }
                    final upcoming = pickUpcomingStatsEntry(
                      rows,
                      sheetsById: sheetsById,
                    )
                        .where((r) => session == null || r.id != session.id)
                        .toList();
                    final compareRows = rows
                        .where(
                          (r) => isStatsSessionClosed(
                            r,
                            sheetsById: sheetsById,
                          ),
                        )
                        .toList();

                    return Column(
                      children: [
                        _buildHeader(ctx, chips, isAdmin),
                        const AdminMatchFlowGuide(active: 'stats'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TabBar(
                            controller: _subTabs,
                            indicatorColor: adminGold,
                            labelColor: adminTextPrimary,
                            unselectedLabelColor: adminGrey,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            tabs: const [
                              Tab(text: 'EN DIRECT'),
                              Tab(text: 'ARCHIVE'),
                              Tab(text: 'COMPARER'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: TabBarView(
                            controller: _subTabs,
                            children: [
                              _buildLiveSubTab(
                                ctx,
                                session: session,
                                sessionStep: sessionStep,
                                upcoming: upcoming,
                              ),
                              _buildArchiveSubTab(
                                ctx,
                                rows: rows,
                                averages: averages,
                                filterSummary: filterSummary,
                                sheetsById: sheetsById,
                              ),
                              _buildCompareSubTab(
                                ctx,
                                rows: compareRows,
                                sheetsById: sheetsById,
                              ),
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
          },
        );
      },
    );
  }

  Widget _buildLiveSubTab(
    BuildContext ctx, {
    required AdminMatchRowData? session,
    required StatsWorkflowStep? sessionStep,
    required List<AdminMatchRowData> upcoming,
  }) {
    if (session == null && upcoming.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer_outlined, size: 48, color: adminGrey),
              const SizedBox(height: 12),
              Text(
                'Aucun match à saisir',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Les matchs terminés sont dans Archive. '
                'Quand un match est programmé, il apparaît ici pour commencer la saisie.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (session != null && sessionStep != null) {
      children.addAll([
        StatsMatchDayHero(
          row: session,
          step: sessionStep,
          heroTitle: 'SAISIE EN COURS',
          onPrimary: () => _handleHeroPrimary(ctx, session, sessionStep),
          onSync: sessionStep != StatsWorkflowStep.official
              ? () => _syncNow(ctx, session.id)
              : null,
          onFinalize: sessionStep != StatsWorkflowStep.official
              ? () => _finalizeMatch(ctx, session)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MatchAdminContextBanner(
            matchId: session.id,
            team1: session.t1,
            team2: session.t2,
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }

    if (upcoming.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            session != null ? 'AUTRES MATCHS À VENIR' : 'MATCHS À VENIR',
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              letterSpacing: 1,
            ),
          ),
        ),
      );
      for (final row in upcoming) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _UpcomingStatsEntryCard(
              row: row,
              onStart: () => _prepareAndOpen(ctx, row),
            ),
          ),
        );
      }
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          'Saisie chiffrée dans le workbench · bandeau stats ON/OFF depuis l’onglet Live.',
          style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.4),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: children,
    );
  }

  Widget _buildArchiveSubTab(
    BuildContext ctx, {
    required List<AdminMatchRowData> rows,
    required Map<String, Map<String, dynamic>> sheetsById,
    required List<SedanSeasonAverage> averages,
    required String filterSummary,
  }) {
    if (rows.isEmpty) return _buildEmpty();
    final historyRows = rows
        .where((r) => isStatsSessionClosed(r, sheetsById: sheetsById))
        .toList();
    sortStatsMatchRows(
      historyRows,
      groupByCompetition: _adminStatsCompetition == 'all',
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (averages.any((a) => a.count > 0))
          _buildSeasonAveragesCard(averages, filterSummary),
        if (historyRows.isNotEmpty)
          _buildSeasonPlayerFactsCard(historyRows),
        if (historyRows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Row(
              children: [
                Text(
                  'HISTORIQUE — ${filterSummary.toUpperCase()}',
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
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
              ],
            ),
          ),
          ..._buildHistoryList(
            ctx,
            historyRows,
            groupSections: _adminStatsCompetition == 'all',
            sheetsById: sheetsById,
            compareMode: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCompareSubTab(
    BuildContext ctx, {
    required List<AdminMatchRowData> rows,
    required Map<String, Map<String, dynamic>> sheetsById,
  }) {
    if (rows.isEmpty) return _buildEmpty();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _buildCompareBanner(ctx, rows),
        ..._buildHistoryList(
          ctx,
          rows,
          groupSections: _adminStatsCompetition == 'all',
          sheetsById: sheetsById,
          compareMode: true,
        ),
      ],
    );
  }

  List<Widget> _buildHistoryList(
    BuildContext ctx,
    List<AdminMatchRowData> historyRows, {
    required bool groupSections,
    Map<String, Map<String, dynamic>> sheetsById = const {},
    required bool compareMode,
  }) {
    final widgets = <Widget>[];
    String? lastSection;

    for (final row in historyRows) {
      if (groupSections) {
        final section = statsHistorySectionLabel(row);
        if (section != lastSection) {
          lastSection = section;
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                section.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: adminGold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          );
        }
      }

      final step = statsWorkflowStep(
        row.d,
        sheetState: sheetsById[row.id]?['state']?.toString(),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _StatsMatchRow(
            row: row,
            step: step,
            compareMode: compareMode,
            selected: _selected.contains(row.id),
            onTap: () {
              if (compareMode) {
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
        ),
      );
    }
    return widgets;
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
          const SizedBox(height: 6),
          Text(
            'En direct = prochain match ou live en cours · Archive = matchs terminés · Comparer = analyse',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            'SAISON',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: adminGrey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 12),
          Text(
            'COMPÉTITION',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: adminGrey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in MatchCompetition.statsCategoryFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: _adminStatsCompetition == f.id
                          ? adminGold.withAlpha(35)
                          : adminCard,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: () => setState(() {
                          _adminStatsCompetition = f.id;
                          if (f.id != 'championship') {
                            _adminStatsChampionshipLevel = null;
                          }
                        }),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            f.label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _adminStatsCompetition == f.id
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
          if (_adminStatsCompetition == 'championship') ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChampionshipLevelChip('Tous niveaux', null),
                  for (final level in MatchCompetition.regularSeason)
                    _buildChampionshipLevelChip(level, level),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChampionshipLevelChip(String label, String? level) {
    final sel = _adminStatsChampionshipLevel == level;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: sel ? adminSurface : adminCard,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _adminStatsChampionshipLevel = level),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? adminGold.withAlpha(140) : adminBorder,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: sel ? adminGold : adminGrey,
              ),
            ),
          ),
        ),
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

  Widget _buildSeasonAveragesCard(
    List<SedanSeasonAverage> averages,
    String filterSummary,
  ) {
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
                Expanded(
                  child: Text(
                    'MOYENNES SEDAN — ${filterSummary.toUpperCase()}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      letterSpacing: 0.8,
                    ),
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

  Widget _buildSeasonPlayerFactsCard(List<AdminMatchRowData> rows) {
    final facts = aggregateSedanPlayerFacts(rows);
    if (facts.isEmpty) return const SizedBox.shrink();

    final top = facts.entries.toList()
      ..sort((a, b) {
        final g = (b.value['goals'] ?? 0).compareTo(a.value['goals'] ?? 0);
        if (g != 0) return g;
        return a.key.compareTo(b.key);
      });

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
            Text(
              'BUTEURS & CARTONS SEDAN (SAISON)',
              style: GoogleFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cumul des faits saisis au live / fiche match — filtre actuel.',
              style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.3),
            ),
            const SizedBox(height: 10),
            ...top.take(12).map((e) {
              final g = e.value['goals'] ?? 0;
              final y = e.value['yellow'] ?? 0;
              final r = e.value['red'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    if (g > 0)
                      Text(
                        '$g but${g > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: adminGold,
                        ),
                      ),
                    if (y > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$y J',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFFE8C82A),
                        ),
                      ),
                    ],
                    if (r > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$r R',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminRed,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final comp = MatchCompetition.statsFilterSummaryLabel(
      categoryId: _adminStatsCompetition,
      championshipLevel: _adminStatsChampionshipLevel,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Aucun match Sedan pour cette saison\n($comp)',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: adminGrey, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}

class _UpcomingStatsEntryCard extends StatelessWidget {
  final AdminMatchRowData row;
  final VoidCallback onStart;

  const _UpcomingStatsEntryCard({
    required this.row,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adminCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${row.t1} vs ${row.t2}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  AdminStatusChip(label: row.date, color: adminGrey),
                  const SizedBox(width: 6),
                  AdminStatusChip(
                    label: row.competition,
                    color: adminGrey.withAlpha(200),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Commencer la saisie'),
                style: FilledButton.styleFrom(
                  backgroundColor: adminGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
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
                          const SizedBox(width: 5),
                          AdminStatusChip(
                            label: row.competition,
                            color: adminGrey.withAlpha(200),
                          ),
                          if (row.showScoreChip) ...[
                            const SizedBox(width: 5),
                            AdminStatusChip(label: row.score, color: adminGold),
                          ],
                          if (row.goalStr != '-') ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                row.goalStr,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
