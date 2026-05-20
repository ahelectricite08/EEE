import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../models/fff_season_config.dart';
import '../../../../services/season_config_service.dart';
import '../../admin_palette.dart';

/// Données dérivées d’un doc `matches` — partagées entre la vue tableau et les cartes.
class _MatchRowData {
  _MatchRowData({
    required this.doc,
    required this.d,
    required this.s,
    required this.t1,
    required this.t2,
    required this.date,
    required this.score,
    required this.hasStats,
    required this.goals,
    required this.goalStr,
    required this.yH,
    required this.yA,
    required this.rH,
    required this.rA,
  });

  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> d;
  final Map<String, dynamic> s;
  final String t1;
  final String t2;
  final String date;
  final String score;
  final bool hasStats;
  final List<Map<String, dynamic>> goals;
  final String goalStr;
  final int yH;
  final int yA;
  final int rH;
  final int rA;

  String sv(String k1, String k2) =>
      s.containsKey(k1) ? '${s[k1]}-${s[k2]}' : '-';

  String get crossLine {
    final a1 = (s['crossAcc1'] as int?) ?? 0;
    final a2 = (s['crossAcc2'] as int?) ?? 0;
    final t1c = a1 + ((s['crossInacc1'] as int?) ?? 0);
    final t2c = a2 + ((s['crossInacc2'] as int?) ?? 0);
    if (t1c + t2c == 0) return '-';
    return '$a1/$t1c – $a2/$t2c';
  }

  String get possessionLine => s.containsKey('possession1')
      ? '${s['possession1']}% / ${s['possession2'] ?? 0}%'
      : '';

  factory _MatchRowData.from(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final s = d['stats'] as Map<String, dynamic>? ?? {};
    final t1 = (d['team1'] as String? ?? '');
    final t2 = (d['team2'] as String? ?? '');
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final date = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : '-';
    final score = '${d['scoreHome'] ?? '-'}-${d['scoreAway'] ?? '-'}';
    final hasStats = s.isNotEmpty;
    final rawEvents = d['events'];
    final goals = rawEvents is List
        ? rawEvents
              .whereType<Map<String, dynamic>>()
              .where((e) => e['type'] == 'goal')
              .toList()
        : <Map<String, dynamic>>[];
    final goalStr = goals.isEmpty
        ? '-'
        : goals
              .map((e) {
                final p = (e['player'] as String? ?? '').split(' ').last;
                final m = e['minute'] ?? '?';
                return '$p $m\'';
              })
              .join('  ');
    final yH =
        (d['yellowHome'] as int?) ?? (d['yellow_home'] as int?) ?? 0;
    final yA =
        (d['yellowAway'] as int?) ?? (d['yellow_away'] as int?) ?? 0;
    final rH = (d['redHome'] as int?) ?? (d['red_home'] as int?) ?? 0;
    final rA = (d['redAway'] as int?) ?? (d['red_away'] as int?) ?? 0;
    return _MatchRowData(
      doc: doc,
      d: d,
      s: s,
      t1: t1,
      t2: t2,
      date: date,
      score: score,
      hasStats: hasStats,
      goals: goals,
      goalStr: goalStr,
      yH: yH,
      yA: yA,
      rH: rH,
      rA: rA,
    );
  }
}

class StatsTab extends StatefulWidget {
  const StatsTab();

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  static final _db = FirebaseFirestore.instance;
  final _hHeader = ScrollController();
  final _hBody = ScrollController();

  /// Filtre tableau stats matchs (saison FFF + archives).
  String _adminStatsSeason = FffSeasonConfig.defaults.seasonLabel;

  static const _headers = [
    '',
    'MATCH',
    'DATE',
    'SCORE',
    'BUTEURS',
    '🟡',
    '🔴',
    'POSS',
    'TIRS',
    'CADRÉS',
    'POTEAUX',
    'CONTRÉES',
    'PASSES ✓',
    'PASSES ✗',
    'CENTRES',
    'CORN.',
    'HJ',
    'FAUTES',
    'ARRÊTS',
    'DUELS',
    'ACTIONS',
  ];
  static const double _tableBreakpoint = 860;

  static const _widths = [
    36.0,
    188.0,
    86.0,
    60.0,
    160.0,
    45.0,
    45.0,
    75.0,
    65.0,
    65.0,
    65.0,
    70.0,
    70.0,
    70.0,
    70.0,
    55.0,
    45.0,
    65.0,
    70.0,
    65.0,
    140.0,
  ];

  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hHeader.jumpTo(_hBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  void _showChart(BuildContext ctx, List<QueryDocumentSnapshot> docs) {
    final sel = docs.where((d) => _selected.contains(d.id)).toList();
    if (sel.isEmpty) return;
    showDialog(
      context: ctx,
      builder: (_) => _StatsChartDialog(matches: sel),
    );
  }

  Future<void> _importFromLive(String matchId) async {
    final snap = await _db.collection('live').doc('current').get();
    final stats = snap.data()?['stats'] as Map<String, dynamic>? ?? {};
    if (stats.isEmpty) return;
    await _db.collection('matches').doc(matchId).set({
      'stats': stats,
      'showStats': true,
    }, SetOptions(merge: true));
  }

  Future<void> _deleteStats(String matchId, BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Supprimer les stats ?',
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('SUPPRIMER', style: GoogleFonts.inter(color: adminRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.collection('matches').doc(matchId).update({
        'stats': FieldValue.delete(),
      });
    }
  }

  void _openEdit(
    BuildContext ctx,
    String matchId,
    String team1,
    String team2,
    Map<String, dynamic> stats, [
    Map<String, dynamic>? doc,
  ]) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Material(
        color: Colors.transparent,
        child: _StatsEditSheet(
          matchId: matchId,
          team1: team1,
          team2: team2,
          initial: stats,
          doc: doc ?? {},
        ),
      ),
    );
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

                final rows = docs.map(_MatchRowData.from).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: adminBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'STATISTIQUES',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: adminTextPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '($displaySeason)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: adminGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (_selected.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showChart(ctx, docs),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: adminGold.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: adminGold.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.bar_chart_rounded,
                                          size: 14,
                                          color: adminGold,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'GRAPHIQUE (${_selected.length})',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: adminGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                                      color: s == displaySeason
                                          ? adminGold.withAlpha(35)
                                          : adminCard,
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _adminStatsSeason = s,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                              color: s == displaySeason
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
                          const SizedBox(height: 6),
                          Text(
                            '${docs.length} matchs Sedan',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: adminGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: adminBorder),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= _tableBreakpoint;
                  if (!wide) {
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                      itemCount: rows.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildMatchCard(ctx, rows[i]),
                    );
                  }
                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              adminGold.withAlpha(38),
                              adminCardHigh,
                              adminGold.withAlpha(28),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(color: adminBorder.withAlpha(200)),
                            bottom: BorderSide(color: adminBorder),
                          ),
                        ),
                        child: SingleChildScrollView(
                          controller: _hHeader,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: List.generate(
                              _headers.length,
                              (i) => SizedBox(
                                width: _widths[i],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 11,
                                  ),
                                  child: Text(
                                    _headers[i],
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: adminTextPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            controller: _hBody,
                            scrollDirection: Axis.horizontal,
                            child: _buildRows(ctx, rows),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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

  Widget _buildRows(BuildContext ctx, List<_MatchRowData> rows) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var i = 0; i < _widths.length; i++)
          i: FixedColumnWidth(_widths[i]),
      },
      children: [
        ...rows.map((row) {
          final d = row.d;
          final s = row.s;
          final isSelected = _selected.contains(row.doc.id);

          Widget c(String v) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Text(
              v,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: v == '-' ? adminGrey : adminTextPrimary,
              ),
            ),
          );

          return TableRow(
            decoration: BoxDecoration(
              color: isSelected
                  ? adminGold.withAlpha(25)
                  : row.hasStats
                  ? adminGold.withAlpha(8)
                  : Colors.transparent,
              border: const Border(
                bottom: BorderSide(color: adminBorder, width: 1),
              ),
            ),
            children: [
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(row.doc.id);
                    } else {
                      _selected.remove(row.doc.id);
                    }
                  }),
                  activeColor: adminGold,
                  checkColor: Colors.black,
                  side: const BorderSide(color: adminGrey),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Text(
                  '${row.t1} vs ${row.t2}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              c(row.date),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  row.score,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: row.hasStats ? adminTextPrimary : adminGrey,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  row.goalStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: row.goals.isEmpty ? adminGrey : adminTextPrimary,
                  ),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Text(
                  row.yH + row.yA > 0 ? '${row.yH}-${row.yA}' : '-',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: row.yH + row.yA > 0
                        ? const Color(0xFFE8C82A)
                        : adminGrey,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Text(
                  row.rH + row.rA > 0 ? '${row.rH}-${row.rA}' : '-',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: row.rH + row.rA > 0 ? adminRed : adminGrey,
                  ),
                ),
              ),
              c(s.containsKey('possession1')
                  ? '${s['possession1']}% – ${s['possession2'] ?? 0}%'
                  : '-'),
              c(row.sv('tirs1', 'tirs2')),
              c(row.sv('tirsCadres1', 'tirsCadres2')),
              c(row.sv('poteau1', 'poteau2')),
              c(row.sv('blocked1', 'blocked2')),
              c(row.sv('passes1', 'passes2')),
              c(row.sv('passInacc1', 'passInacc2')),
              c(row.crossLine),
              c(row.sv('corners1', 'corners2')),
              c(row.sv('horsJeu1', 'horsJeu2')),
              c(row.sv('fautes1', 'fautes2')),
              c(row.sv('arretsGardien1', 'arretsGardien2')),
              c(row.sv('duelWon1', 'duelWon2')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _btn(
                      'ÉDITER',
                      adminGold,
                      () => _openEdit(
                        ctx,
                        row.doc.id,
                        d['team1'] ?? '',
                        d['team2'] ?? '',
                        s,
                        d,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _btn('LIVE', const Color(0xFF4A90D9), () async {
                      await _importFromLive(row.doc.id);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Stats live importées',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: const Color(0xFF4A90D9),
                          ),
                        );
                      }
                    }),
                    if (row.hasStats) ...[
                      const SizedBox(width: 4),
                      _btn('✕', adminRed, () => _deleteStats(row.doc.id, ctx)),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildMatchCard(BuildContext ctx, _MatchRowData row) {
    const liveBlue = Color(0xFF4A90D9);
    final isSelected = _selected.contains(row.doc.id);

    Widget statChip(String label, String value) {
      if (value.isEmpty || value == '-') return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        decoration: BoxDecoration(
          color: adminSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: adminBorder.withAlpha(200)),
        ),
        child: Text(
          '$label $value',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: adminTextPrimary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? adminGold : adminBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: adminCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: isSelected,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(row.doc.id);
                        } else {
                          _selected.remove(row.doc.id);
                        }
                      }),
                      activeColor: adminGold,
                      checkColor: Colors.black,
                      side: const BorderSide(color: adminGrey),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.t1,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                          height: 1.15,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'vs',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: adminGrey,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        row.t2,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 15, color: adminGrey),
                          const SizedBox(width: 6),
                          Text(
                            row.date,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: adminTextPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: row.hasStats
                                  ? adminGold.withAlpha(40)
                                  : adminSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: row.hasStats
                                    ? adminGold.withAlpha(120)
                                    : adminBorder,
                              ),
                            ),
                            child: Text(
                              row.score,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: row.hasStats
                                    ? adminTextPrimary
                                    : adminGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (row.goalStr != '-') ...[
              const SizedBox(height: 10),
              Text(
                'Buteurs',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                row.goalStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: adminTextPrimary,
                ),
              ),
            ],
            if (row.hasStats) ...[
              const SizedBox(height: 10),
              Text(
                'Aperçu stats',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                children: [
                  if (row.possessionLine.isNotEmpty)
                    statChip('Poss.', row.possessionLine),
                  statChip('Tirs', row.sv('tirs1', 'tirs2')),
                  statChip('Cadrés', row.sv('tirsCadres1', 'tirsCadres2')),
                  statChip('Corners', row.sv('corners1', 'corners2')),
                  if (row.yH + row.yA > 0)
                    statChip('Jaunes', '${row.yH}-${row.yA}'),
                  if (row.rH + row.rA > 0)
                    statChip('Rouges', '${row.rH}-${row.rA}'),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: adminSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: adminBorder.withAlpha(180)),
                ),
                child: Text(
                  'Pas encore de stats — touche Éditer pour saisir.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _btn(
                  'ÉDITER',
                  adminGold,
                  () => _openEdit(
                    ctx,
                    row.doc.id,
                    row.d['team1'] ?? '',
                    row.d['team2'] ?? '',
                    row.s,
                    row.d,
                  ),
                ),
                _btn('LIVE', liveBlue, () async {
                  await _importFromLive(row.doc.id);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stats live importées',
                          style: GoogleFonts.inter(),
                        ),
                        backgroundColor: liveBlue,
                      ),
                    );
                  }
                }),
                if (row.hasStats)
                  _btn('✕ STATS', adminRed, () => _deleteStats(row.doc.id, ctx)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ),
  );
}

// ── Feuille d'édition des stats ───────────────────────────────────────────────
class _StatsEditSheet extends StatefulWidget {
  final String matchId, team1, team2;
  final Map<String, dynamic> initial;
  final Map<String, dynamic> doc;

  const _StatsEditSheet({
    required this.matchId,
    required this.team1,
    required this.team2,
    required this.initial,
    this.doc = const {},
  });

  @override
  State<_StatsEditSheet> createState() => _StatsEditSheetState();
}

enum _AutosaveUi { synced, pending, saving, error }

class _StatsEditSheetState extends State<_StatsEditSheet> {
  static final _db = FirebaseFirestore.instance;
  late Map<String, TextEditingController> _c;
  bool _showOnCard = true;
  /// Après le premier frame : évite un merge Firestore au montage des contrôleurs.
  bool _readyForAutosave = false;
  Timer? _debounce;
  static const Duration _debounceDelay = Duration(milliseconds: 700);
  _AutosaveUi _autosaveUi = _AutosaveUi.synced;
  DateTime? _lastSyncedAt;
  bool _isFlushing = false;
  final List<
    (TextEditingController, TextEditingController, TextEditingController)
  >
  _custom = [];

  static const _fields = [
    ('possession1', 'possession2', 'POSSESSION %'),
    ('tirs1', 'tirs2', 'TIRS'),
    ('tirsCadres1', 'tirsCadres2', 'TIRS CADRÉS'),
    ('poteau1', 'poteau2', 'POTEAUX'),
    ('blocked1', 'blocked2', 'CONTRÉES'),
    ('passes1', 'passes2', 'PASSES ✓'),
    ('passInacc1', 'passInacc2', 'PASSES ✗'),
    ('crossAcc1', 'crossAcc2', 'CENTRES ✓'),
    ('crossInacc1', 'crossInacc2', 'CENTRES ✗'),
    ('corners1', 'corners2', 'CORNERS'),
    ('horsJeu1', 'horsJeu2', 'HORS-JEU'),
    ('fautes1', 'fautes2', 'FAUTES'),
    ('arretsGardien1', 'arretsGardien2', 'ARRÊTS'),
    ('duelWon1', 'duelWon2', 'DUELS GAGNÉS'),
  ];

  late TextEditingController _yellowHome, _yellowAway, _redHome, _redAway;
  late TextEditingController _seScoreHome, _seScoreAway;
  final List<Map<String, TextEditingController>> _seGoals = [];

  @override
  void initState() {
    super.initState();
    _showOnCard = widget.initial['showStats'] != false;
    _c = {
      for (final f in _fields) ...{
        f.$1: TextEditingController(text: '${widget.initial[f.$1] ?? 0}'),
        f.$2: TextEditingController(text: '${widget.initial[f.$2] ?? 0}'),
      },
    };
    // Auto-balance possession : quand possession1 change, possession2 = 100 - possession1
    _c['possession1']!.addListener(() {
      final v1 = int.tryParse(_c['possession1']!.text) ?? 0;
      final v2 = (100 - v1).clamp(0, 100);
      final cur2 = _c['possession2']!.text;
      if (cur2 != '$v2') _c['possession2']!.text = '$v2';
    });
    _yellowHome = TextEditingController(
      text: '${widget.doc['yellowHome'] ?? 0}',
    );
    _yellowAway = TextEditingController(
      text: '${widget.doc['yellowAway'] ?? 0}',
    );
    _redHome = TextEditingController(text: '${widget.doc['redHome'] ?? 0}');
    _redAway = TextEditingController(text: '${widget.doc['redAway'] ?? 0}');
    _seScoreHome = TextEditingController(
      text: '${widget.doc['scoreHome'] ?? widget.doc['score1'] ?? ''}',
    );
    _seScoreAway = TextEditingController(
      text: '${widget.doc['scoreAway'] ?? widget.doc['score2'] ?? ''}',
    );
    final events = widget.doc['events'];
    if (events is List) {
      for (final e in events) {
        if (e is Map && e['type'] == 'goal') {
          _seGoals.add({
            'player': TextEditingController(
              text: e['player']?.toString() ?? '',
            ),
            'minute': TextEditingController(
              text: e['minute']?.toString() ?? '',
            ),
            'team': TextEditingController(text: e['team']?.toString() ?? ''),
          });
        }
      }
    }
    final raw = widget.initial['customStats'];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map<String, dynamic>) {
          _custom.add((
            TextEditingController(text: row['label']?.toString() ?? ''),
            TextEditingController(text: row['value1']?.toString() ?? ''),
            TextEditingController(text: row['value2']?.toString() ?? ''),
          ));
        }
      }
    }

    for (final f in _fields) {
      _listen(_c[f.$1]!);
      _listen(_c[f.$2]!);
    }
    _listen(_yellowHome);
    _listen(_yellowAway);
    _listen(_redHome);
    _listen(_redAway);
    _listen(_seScoreHome);
    _listen(_seScoreAway);
    for (final g in _seGoals) {
      _listen(g['player']!);
      _listen(g['minute']!);
      _listen(g['team']!);
    }
    for (final r in _custom) {
      _listen(r.$1);
      _listen(r.$2);
      _listen(r.$3);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readyForAutosave = true;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final matchId = widget.matchId;
    final snapshot = _readyForAutosave ? _buildPayload() : null;
    for (final c in _c.values) c.dispose();
    for (final r in _custom) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
    _yellowHome.dispose();
    _yellowAway.dispose();
    _redHome.dispose();
    _redAway.dispose();
    _seScoreHome.dispose();
    _seScoreAway.dispose();
    for (final g in _seGoals) {
      g['player']!.dispose();
      g['minute']!.dispose();
      g['team']!.dispose();
    }
    super.dispose();
    if (snapshot != null) {
      unawaited(
        _db.collection('matches').doc(matchId).set(snapshot, SetOptions(merge: true)).catchError(
          (Object e, StackTrace st) {
            debugPrint('StatsTab dispose flush: $e\n$st');
          },
        ),
      );
    }
  }

  void _listen(TextEditingController c) {
    c.addListener(_scheduleAutosave);
  }

  void _scheduleAutosave() {
    if (!_readyForAutosave || !mounted) return;
    if (_autosaveUi != _AutosaveUi.saving) {
      setState(() => _autosaveUi = _AutosaveUi.pending);
    }
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      unawaited(_flushPendingSave());
    });
  }

  Future<void> _flushPendingSave() async {
    while (_isFlushing) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
    }
    if (!mounted) return;
    _isFlushing = true;
    setState(() => _autosaveUi = _AutosaveUi.saving);
    try {
      final payload = _buildPayload();
      await _db.collection('matches').doc(widget.matchId).set(payload, SetOptions(merge: true));
      if (!mounted) return;
      _lastSyncedAt = DateTime.now();
      _autosaveUi = _AutosaveUi.synced;
    } catch (e, st) {
      debugPrint('StatsTab autosave: $e\n$st');
      if (mounted) _autosaveUi = _AutosaveUi.error;
    } finally {
      _isFlushing = false;
      if (mounted) setState(() {});
    }
  }

  Map<String, dynamic> _buildPayload() {
    final stats = <String, dynamic>{};
    for (final f in _fields) {
      stats[f.$1] = int.tryParse(_c[f.$1]!.text) ?? 0;
      stats[f.$2] = int.tryParse(_c[f.$2]!.text) ?? 0;
    }
    final customList = _custom
        .where((r) => r.$1.text.trim().isNotEmpty)
        .map(
          (r) => {
            'label': r.$1.text.trim(),
            'value1': r.$2.text.trim(),
            'value2': r.$3.text.trim(),
          },
        )
        .toList();
    if (customList.isNotEmpty) stats['customStats'] = customList;

    final goalEvents = _seGoals
        .where((g) => g['player']!.text.trim().isNotEmpty)
        .map(
          (g) => {
            'type': 'goal',
            'player': g['player']!.text.trim(),
            'minute': int.tryParse(g['minute']!.text.trim()) ?? 0,
            'team': g['team']!.text.trim(),
          },
        )
        .toList();
    final payload = <String, dynamic>{
      'stats': stats,
      'showStats': _showOnCard,
      'yellowHome': int.tryParse(_yellowHome.text) ?? 0,
      'yellowAway': int.tryParse(_yellowAway.text) ?? 0,
      'redHome': int.tryParse(_redHome.text) ?? 0,
      'redAway': int.tryParse(_redAway.text) ?? 0,
      'events': goalEvents,
    };
    final sh = int.tryParse(_seScoreHome.text.trim());
    final sa = int.tryParse(_seScoreAway.text.trim());
    if (sh != null) {
      payload['scoreHome'] = sh;
      payload['score1'] = sh;
    }
    if (sa != null) {
      payload['scoreAway'] = sa;
      payload['score2'] = sa;
    }
    return payload;
  }

  Future<void> _closeAfterFlush() async {
    _debounce?.cancel();
    try {
      await _flushPendingSave().timeout(const Duration(seconds: 12));
    } on Object catch (e, st) {
      debugPrint('StatsTab close flush: $e\n$st');
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _addCustomRow() {
    final row = (
      TextEditingController(),
      TextEditingController(text: '0'),
      TextEditingController(text: '0'),
    );
    setState(() => _custom.add(row));
    _listen(row.$1);
    _listen(row.$2);
    _listen(row.$3);
  }

  Future<void> _importLive() async {
    final snap = await _db.collection('live').doc('current').get();
    final s = snap.data()?['stats'] as Map<String, dynamic>? ?? {};
    if (s.isEmpty) return;
    _debounce?.cancel();
    setState(() {
      for (final f in _fields) {
        _c[f.$1]!.text = '${s[f.$1] ?? 0}';
        _c[f.$2]!.text = '${s[f.$2] ?? 0}';
      }
    });
    await _flushPendingSave();
  }

  String _autosaveLabel() {
    switch (_autosaveUi) {
      case _AutosaveUi.pending:
        return "En attente d'enregistrement...";
      case _AutosaveUi.saving:
        return 'Enregistrement…';
      case _AutosaveUi.error:
        return 'Erreur réseau — vérifie la connexion';
      case _AutosaveUi.synced:
        if (_lastSyncedAt == null) {
          return 'Auto-sauvegarde : le tableau se met à jour tout seul';
        }
        final s = DateTime.now().difference(_lastSyncedAt!).inSeconds;
        if (s < 3) return "Enregistré à l'instant";
        if (s < 60) return 'Enregistré il y a ${s}s';
        return 'Enregistré';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t1 = widget.team1.split(' ').first;
    final t2 = widget.team2.split(' ').first;
    const liveBlue = Color(0xFF3B7DD8);
    return Container(
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: adminCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(100),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: adminCardDecoration(radius: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => unawaited(_closeAfterFlush()),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: adminTextPrimary,
                          size: 26,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: adminGold.withAlpha(26),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.sports_soccer_rounded,
                          color: adminGold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STATISTIQUES MATCH',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: adminGrey,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$t1  ·  $t2',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: adminTextPrimary,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: liveBlue.withAlpha(28),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: _importLive,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: liveBlue.withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_download_rounded, size: 16, color: liveBlue),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: liveBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: adminCardDecoration(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 108),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: adminGold.withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: adminGold.withAlpha(55)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                t1,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: adminTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: adminGold.withAlpha(18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: adminGold.withAlpha(55)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                t2,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: adminTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 108,
                            child: Text(
                              'SCORE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                          Expanded(child: _input(_seScoreHome)),
                          const SizedBox(width: 8),
                          Expanded(child: _input(_seScoreAway)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: adminBorder.withAlpha(180)),
                      ),
                      ..._fields.map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 108,
                                child: Text(
                                  f.$3,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: adminGrey,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              Expanded(child: _input(_c[f.$1]!)),
                              const SizedBox(width: 8),
                              Expanded(child: _input(_c[f.$2]!)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Buteurs
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: adminCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: adminGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BUTEURS',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: adminGold.withAlpha(35),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              final g = <String, TextEditingController>{
                                'player': TextEditingController(),
                                'minute': TextEditingController(text: '0'),
                                'team': TextEditingController(text: widget.team1),
                              };
                              setState(() => _seGoals.add(g));
                              _listen(g['player']!);
                              _listen(g['minute']!);
                              _listen(g['team']!);
                              if (_readyForAutosave) _scheduleAutosave();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 16, color: adminGold),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ajouter un but',
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_seGoals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: adminSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: adminBorder.withAlpha(160)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Aucun but saisi',
                          style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                        ),
                      )
                    else
                      ...List.generate(_seGoals.length, (i) {
                        final g = _seGoals[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: adminSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: adminBorder.withAlpha(180)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _inputText(g['player']!, hint: 'Joueur…'),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(width: 48, child: _input(g['minute']!)),
                                const SizedBox(width: 6),
                                _TeamToggleLocal(
                                  current: g['team']!.text,
                                  team1: widget.team1,
                                  team2: widget.team2,
                                  onChanged: (v) {
                                    setState(() => g['team']!.text = v);
                                    if (_readyForAutosave) _scheduleAutosave();
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    setState(() {
                                      g['player']!.dispose();
                                      g['minute']!.dispose();
                                      g['team']!.dispose();
                                      _seGoals.removeAt(i);
                                    });
                                    if (_readyForAutosave) _scheduleAutosave();
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18, color: adminRed),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            // Cartons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: adminCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: adminGrey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CARTONS',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 108,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8C82A),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Text(
                                'Jaunes',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _input(_yellowHome)),
                        const SizedBox(width: 8),
                        Expanded(child: _input(_yellowAway)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 108,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: adminRed,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Text(
                                'Rouges',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _input(_redHome)),
                        const SizedBox(width: 8),
                        Expanded(child: _input(_redAway)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Stats perso
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: adminCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: adminGold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'STATS PERSONNALISÉES',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_custom.length, (i) {
                      final r = _custom[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: _inputText(r.$1, hint: 'Label…')),
                            const SizedBox(width: 6),
                            Expanded(child: _input(r.$2)),
                            const SizedBox(width: 6),
                            Expanded(child: _input(r.$3)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                setState(() {
                                  r.$1.dispose();
                                  r.$2.dispose();
                                  r.$3.dispose();
                                  _custom.removeAt(i);
                                });
                                if (_readyForAutosave) _scheduleAutosave();
                              },
                              icon: const Icon(Icons.close_rounded, size: 18, color: adminRed),
                            ),
                          ],
                        ),
                      );
                    }),
                    Material(
                      color: adminGold.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _addCustomRow,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: adminGold.withAlpha(70)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: adminGold),
                              const SizedBox(width: 8),
                              Text(
                                'Ajouter une ligne',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: adminGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: adminCardDecoration(radius: 14),
                child: Row(
                  children: [
                    Switch(
                      value: _showOnCard,
                      onChanged: (v) {
                        setState(() => _showOnCard = v);
                        if (_readyForAutosave) _scheduleAutosave();
                      },
                      activeThumbColor: adminGold,
                      activeTrackColor: adminGold.withAlpha(80),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Afficher les stats sur la carte match',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: adminCardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_autosaveUi == _AutosaveUi.saving)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: adminGold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _autosaveLabel(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _autosaveUi == _AutosaveUi.error
                                  ? adminRed
                                  : adminTextPrimary,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            unawaited(_closeAfterFlush());
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: adminGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'FERMER',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sauvegarde automatique après une courte pause (~0,7 s). '
                      'La grille STATISTIQUES se met à jour en direct.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminGrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _input(TextEditingController ctrl) => TextField(
    controller: ctrl,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.center,
    style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
    decoration: _inputDeco(),
  );

  Widget _inputText(TextEditingController ctrl, {String hint = ''}) =>
      TextField(
        controller: ctrl,
        style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
        decoration: _inputDeco(hint: hint),
      );

  InputDecoration _inputDeco({String hint = ''}) => InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 11, color: adminGreyLight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    filled: true,
    fillColor: adminCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: adminBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: adminBorder.withAlpha(200)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: adminGold, width: 1.5),
    ),
  );
}

// ── Toggle équipe (local) ─────────────────────────────────────────────────────
class _TeamToggleLocal extends StatelessWidget {
  final String current, team1, team2;
  final ValueChanged<String> onChanged;

  const _TeamToggleLocal({
    required this.current,
    required this.team1,
    required this.team2,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t1 = team1.split(' ').first.toUpperCase();
    final t2 = team2.split(' ').first.toUpperCase();
    final isTeam1 =
        current.trim().toUpperCase() == team1.trim().toUpperCase() ||
        current.trim().isEmpty;
    return GestureDetector(
      onTap: () => onChanged(isTeam1 ? team2 : team1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminGold.withAlpha(70)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t1,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isTeam1 ? adminGold : adminGrey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '/',
                style: GoogleFonts.inter(fontSize: 10, color: adminBorder),
              ),
            ),
            Text(
              t2,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: !isTeam1 ? adminGold : adminGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Graphique statistiques ────────────────────────────────────────────────────
class _StatsChartDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> matches;

  const _StatsChartDialog({required this.matches});

  @override
  State<_StatsChartDialog> createState() => _StatsChartDialogState();
}

class _StatsChartDialogState extends State<_StatsChartDialog>
    with SingleTickerProviderStateMixin {
  /// 0 = radar profil (synthèse), 1 = barres par match / adversaire
  int _toutVizMode = 0;

  static const _tabs = [
    ('__tout__', '__tout__', 'TOUT'),
    ('tirs1', 'tirs2', 'TIRS'),
    ('tirsCadres1', 'tirsCadres2', 'TIRS CADRÉS'),
    ('possession1', 'possession2', 'POSSESSION %'),
    ('passes1', 'passes2', 'PASSES'),
    ('corners1', 'corners2', 'CORNERS'),
    ('horsJeu1', 'horsJeu2', 'HORS-JEU'),
    ('fautes1', 'fautes2', 'FAUTES'),
    ('arretsGardien1', 'arretsGardien2', 'ARRÊTS'),
    ('duelWon1', 'duelWon2', 'DUELS GAGNÉS'),
  ];

  static const _allStats = [
    ('tirs1', 'tirs2', 'TIRS'),
    ('tirsCadres1', 'tirsCadres2', 'TIR.CAD'),
    ('possession1', 'possession2', 'POSS%'),
    ('passes1', 'passes2', 'PASSES'),
    ('corners1', 'corners2', 'CORNERS'),
    ('horsJeu1', 'horsJeu2', 'HJ'),
    ('fautes1', 'fautes2', 'FAUTES'),
    ('arretsGardien1', 'arretsGardien2', 'ARRÊTS'),
    ('duelWon1', 'duelWon2', 'DUELS'),
  ];

  static const _advColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFFEF6C00),
  ];

  /// Or DVCR + bleu marine « adversaire » (contraste sur fond clair)
  static const _oppNavy = Color(0xFF1B365D);

  late final TabController _tabCtrl;
  final _chartKey = GlobalKey();
  Uint8List? _pngBytes;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPng() async {
    try {
      final boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      setState(() => _pngBytes = data.buffer.asUint8List());
    } catch (_) {}
  }

  /// DVCR/CSSA côté « club » vs adversaire (domicile = team1 dans les stats).
  List<({String label, double club, double opp})> _getOrientedData(
    String k1,
    String k2,
  ) =>
      widget.matches.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final s = d['stats'] as Map<String, dynamic>? ?? {};
        final ts = d['date'] as Timestamp?;
        final dt = ts?.toDate();
        final t1 = (d['team1'] as String? ?? '').toUpperCase();
        final t2 = (d['team2'] as String? ?? '').toUpperCase();
        final clubHome = t1.contains('SEDAN') || t1.contains('CSSA');
        final clubAway = t2.contains('SEDAN') || t2.contains('CSSA');
        final isClubHome = clubHome || (!clubAway);
        final clubVal = isClubHome
            ? (s[k1] as num? ?? 0).toDouble()
            : (s[k2] as num? ?? 0).toDouble();
        final oppVal = isClubHome
            ? (s[k2] as num? ?? 0).toDouble()
            : (s[k1] as num? ?? 0).toDouble();
        final oppShort = isClubHome
            ? (d['team2'] as String? ?? '').split(' ').first
            : (d['team1'] as String? ?? '').split(' ').first;
        final date = dt != null
            ? '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}'
            : '?';
        return (
          label: '$oppShort\n$date',
          club: clubVal,
          opp: oppVal,
        );
      }).toList();

  String get _clubLegendLabel {
    for (final doc in widget.matches) {
      final d = doc.data() as Map<String, dynamic>;
      final t1 = (d['team1'] as String? ?? '').toUpperCase();
      if (t1.contains('SEDAN') || t1.contains('CSSA')) return 'DVCR (dom.)';
      final t2 = (d['team2'] as String? ?? '').toUpperCase();
      if (t2.contains('SEDAN') || t2.contains('CSSA')) return 'DVCR (ext.)';
    }
    return 'Équipe 1 (dom.)';
  }

  @override
  Widget build(BuildContext context) {
    final tabIdx = _tabCtrl.index;
    final isTout = _tabs[tabIdx].$1 == '__tout__';
    final screenW = MediaQuery.sizeOf(context).width;

    return Dialog(
      backgroundColor: adminCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: adminBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: _pngBytes != null
          ? _PngPreview(
              bytes: _pngBytes!,
              onClose: () => setState(() => _pngBytes = null),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (screenW - 28).clamp(320.0, 760.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          'ANALYSE',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: adminTextPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: adminGold.withAlpha(28),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: adminGold.withAlpha(90)),
                          ),
                          child: Text(
                            '${widget.matches.length} sélection',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: adminTextPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _exportPng,
                          icon: Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: adminGreenAccent,
                          ),
                          label: Text(
                            'PNG',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: adminGreenAccent,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: adminGrey,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.matches.length > 1
                          ? 'Plusieurs matchs : on compare la moyenne DVCR à chaque adversaire (onglet Tout) ou l’indicateur choisi.'
                          : 'Une rencontre : barres = DVCR vs cet adversaire (axes domicile / extérieur Firestore).',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: adminSurface,
                    borderRadius: BorderRadius.circular(12),
                    child: TabBar(
                      controller: _tabCtrl,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        color: adminGold.withAlpha(35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: adminGold.withAlpha(100)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: adminTextPrimary,
                      unselectedLabelColor: adminGrey,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: _tabs.map((t) => Tab(text: t.$3)).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  RepaintBoundary(
                    key: _chartKey,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: adminBorder),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: isTout
                          ? _buildToutChart()
                          : _buildSingleChart(tabIdx),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
    );
  }

  Widget _buildSingleChart(int tabIdx) {
    final tab = _tabs[tabIdx];
    final data = _getOrientedData(tab.$1, tab.$2);
    final maxY = data.fold(
      0.0,
      (m, e) => [m, e.club, e.opp].reduce((a, b) => a > b ? a : b),
    );
    final capY = maxY > 0 ? (maxY * 1.18).clamp(4.0, double.infinity) : 10.0;
    return Column(
      children: [
        Text(
          tab.$3,
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Par match sélectionné — barres : $_clubLegendLabel · adversaire',
          style: GoogleFonts.inter(fontSize: 9, color: adminGrey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: capY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => adminCard,
                  getTooltipItem: (group, _, rod, rodIdx) {
                    final who = rodIdx == 0 ? _clubLegendLabel : 'Adversaire';
                    return BarTooltipItem(
                      '$who\n${rod.toY.toStringAsFixed(rod.toY == rod.toY.roundToDouble() ? 0 : 1)}',
                      GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: adminGrey,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          data[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: adminGrey,
                            height: 1.15,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: adminBorder.withAlpha(140),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: adminBorder.withAlpha(200)),
                  left: BorderSide(color: adminBorder.withAlpha(200)),
                ),
              ),
              barGroups: List.generate(
                data.length,
                (i) => BarChartGroupData(
                  x: i,
                  barsSpace: 6,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].club,
                      color: adminGold,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                    BarChartRodData(
                      toY: data[i].opp,
                      color: _oppNavy,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            _legend(adminGold, _clubLegendLabel, strong: true),
            _legend(_oppNavy, 'Adversaire', strong: true),
          ],
        ),
      ],
    );
  }

  Widget _buildToutChart() {
    final matchInfos = widget.matches.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final t1 = (d['team1'] as String? ?? '').toUpperCase();
      final t2 = (d['team2'] as String? ?? '').toUpperCase();
      final clubHome = t1.contains('SEDAN') || t1.contains('CSSA');
      final clubAway = t2.contains('SEDAN') || t2.contains('CSSA');
      final isClubHome = clubHome || (!clubAway);
      final advName = isClubHome
          ? (d['team2'] as String? ?? '').split(' ').first
          : (d['team1'] as String? ?? '').split(' ').first;
      final ts = d['date'] as Timestamp?;
      final dt = ts?.toDate();
      final date = dt != null
          ? '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}'
          : '?';
      final s = d['stats'] as Map<String, dynamic>? ?? {};
      return (
        isClubHome: isClubHome,
        name: '$advName $date',
        stats: s,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Profil de jeu',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Radar'),
                  icon: Icon(Icons.hub_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Barres'),
                  icon: Icon(Icons.bar_chart_rounded, size: 16),
                ),
              ],
              selected: {_toutVizMode},
              onSelectionChanged: (s) {
                setState(() => _toutVizMode = s.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _toutVizMode == 0
              ? 'Radar normalisé (0–100) par axe : compare le volume relatif des indicateurs. Idéal avec plusieurs matchs (moyenne DVCR vs moyenne des adversaires).'
              : 'Barres : moyenne DVCR + une barre par adversaire sélectionné, pour chaque indicateur.',
          style: GoogleFonts.inter(fontSize: 9, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 12),
        if (_toutVizMode == 0)
          _buildRadarProfile(matchInfos)
        else
          _buildToutBarChart(matchInfos),
      ],
    );
  }

  List<double> _clubAvgByStat(
    List<
            ({
              bool isClubHome,
              String name,
              Map<String, dynamic> stats,
            })>
        matchInfos,
  ) {
    return List.generate(_allStats.length, (gi) {
      final k1 = _allStats[gi].$1;
      final k2 = _allStats[gi].$2;
      final vals = matchInfos
          .map(
            (m) => (m.isClubHome
                    ? (m.stats[k1] as num? ?? 0)
                    : (m.stats[k2] as num? ?? 0))
                .toDouble(),
          )
          .toList();
      if (vals.isEmpty) return 0.0;
      return vals.reduce((a, b) => a + b) / vals.length;
    });
  }

  List<double> _oppAvgByStat(
    List<
            ({
              bool isClubHome,
              String name,
              Map<String, dynamic> stats,
            })>
        matchInfos,
  ) {
    return List.generate(_allStats.length, (gi) {
      final k1 = _allStats[gi].$1;
      final k2 = _allStats[gi].$2;
      final vals = matchInfos
          .map(
            (m) => (m.isClubHome
                    ? (m.stats[k2] as num? ?? 0)
                    : (m.stats[k1] as num? ?? 0))
                .toDouble(),
          )
          .toList();
      if (vals.isEmpty) return 0.0;
      return vals.reduce((a, b) => a + b) / vals.length;
    });
  }

  List<double> _normalizePair(List<double> a, List<double> b) {
    final outA = <double>[];
    final outB = <double>[];
    for (var i = 0; i < a.length; i++) {
      final mx = (a[i] > b[i] ? a[i] : b[i]).clamp(1.0, double.infinity);
      outA.add(((a[i] / mx) * 100).clamp(0, 100));
      outB.add(((b[i] / mx) * 100).clamp(0, 100));
    }
    return [...outA, ...outB];
  }

  Widget _buildRadarProfile(
    List<
            ({
              bool isClubHome,
              String name,
              Map<String, dynamic> stats,
            })>
        matchInfos,
  ) {
    final clubAvg = _clubAvgByStat(matchInfos);
    final oppAvg = _oppAvgByStat(matchInfos);
    final norm = _normalizePair(clubAvg, oppAvg);
    final n = clubAvg.length;
    final clubNorm = norm.sublist(0, n);
    final oppNorm = norm.sublist(n);

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              dataSets: [
                RadarDataSet(
                  fillColor: adminGold.withAlpha(70),
                  borderColor: adminGold,
                  borderWidth: 2.5,
                  entryRadius: 3,
                  dataEntries:
                      clubNorm.map((v) => RadarEntry(value: v)).toList(),
                ),
                RadarDataSet(
                  fillColor: _oppNavy.withAlpha(45),
                  borderColor: _oppNavy,
                  borderWidth: 2.2,
                  entryRadius: 3,
                  dataEntries:
                      oppNorm.map((v) => RadarEntry(value: v)).toList(),
                ),
              ],
              radarBackgroundColor: adminCard,
              radarBorderData: BorderSide(color: adminBorder.withAlpha(200)),
              gridBorderData: BorderSide(color: adminBorder.withAlpha(160)),
              tickBorderData: BorderSide(color: adminBorder.withAlpha(120)),
              tickCount: 4,
              ticksTextStyle: GoogleFonts.inter(
                fontSize: 8,
                color: adminGrey,
                fontWeight: FontWeight.w600,
              ),
              titleTextStyle: GoogleFonts.inter(
                fontSize: 9,
                color: adminTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              getTitle: (index, angle) {
                if (index < 0 || index >= _allStats.length) {
                  return const RadarChartTitle(text: '');
                }
                return RadarChartTitle(text: _allStats[index].$3, angle: angle);
              },
              titlePositionPercentageOffset: 0.12,
              radarTouchData: RadarTouchData(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _legend(adminGold, 'DVCR — moyenne (${widget.matches.length} mt.)',
                strong: true),
            _legend(_oppNavy, 'Adversaires — moyenne', strong: true),
          ],
        ),
      ],
    );
  }

  Widget _buildToutBarChart(
    List<
            ({
              bool isClubHome,
              String name,
              Map<String, dynamic> stats,
            })>
        matchInfos,
  ) {
    final barGroups = List.generate(_allStats.length, (gi) {
      final k1 = _allStats[gi].$1;
      final k2 = _allStats[gi].$2;
      final clubVals = matchInfos
          .map(
            (m) => (m.isClubHome
                    ? (m.stats[k1] as num? ?? 0)
                    : (m.stats[k2] as num? ?? 0))
                .toDouble(),
          )
          .toList();
      final clubAvg = clubVals.isEmpty
          ? 0.0
          : clubVals.reduce((a, b) => a + b) / clubVals.length;

      return BarChartGroupData(
        x: gi,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: clubAvg,
            color: adminGold,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          ...List.generate(matchInfos.length, (mi) {
            final m = matchInfos[mi];
            final av = (m.isClubHome
                    ? (m.stats[k2] as num? ?? 0)
                    : (m.stats[k1] as num? ?? 0))
                .toDouble();
            return BarChartRodData(
              toY: av,
              color: _advColors[mi % _advColors.length],
              width: 9,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            );
          }),
        ],
      );
    });

    final maxY = barGroups.fold(
      0.0,
      (m, g) => g.barRods.fold(m, (mm, r) => r.toY > mm ? r.toY : mm),
    );

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (_allStats.length * (11.0 * (1 + matchInfos.length) + 22))
                  .clamp(480.0, 920.0),
              child: BarChart(
                BarChartData(
                  maxY: maxY > 0 ? maxY * 1.2 : 10,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => adminCard,
                      getTooltipItem: (group, _, rod, rodIdx) {
                        final statLbl = _allStats[group.x.toInt()].$3;
                        final who = rodIdx == 0
                            ? 'DVCR (moy.)'
                            : matchInfos[rodIdx - 1].name;
                        return BarTooltipItem(
                          '$statLbl\n$who : ${rod.toY.toStringAsFixed(1)}',
                          GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: adminTextPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _allStats.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _allStats[i].$3,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: adminGrey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: adminBorder.withAlpha(140),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: adminBorder.withAlpha(200)),
                      left: BorderSide(color: adminBorder.withAlpha(200)),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _legend(adminGold, 'DVCR (moy.)', strong: true),
            ...List.generate(
              matchInfos.length,
              (i) => _legend(
                _advColors[i % _advColors.length],
                matchInfos[i].name,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, {bool strong = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: adminBorder.withAlpha(100)),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          color: adminTextPrimary,
        ),
      ),
    ],
  );
}

// ── Aperçu PNG ────────────────────────────────────────────────────────────────
class _PngPreview extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onClose;

  const _PngPreview({required this.bytes, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text(
                'APERÇU PNG',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Clic droit → Enregistrer',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: adminGrey),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes),
          ),
        ),
      ],
    );
  }
}
