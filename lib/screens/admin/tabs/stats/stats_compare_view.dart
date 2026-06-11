import 'dart:math' show max;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';

// Couleurs par match (adversaire)
const _matchColors = [
  Color(0xFF5BA3F5), // bleu clair
  Color(0xFF56D399), // vert menthe
  Color(0xFFE57373), // rouge doux
  Color(0xFFBA68C8), // violet
  Color(0xFF4DD0E1), // cyan
  Color(0xFFFFB74D), // orange
];

const _cssaGold = Color(0xFFC8A436);
const _cssaGoldLight = Color(0xFFFFD700);

/// Comparaison graphique de plusieurs matchs Sedan (inline ou dialog).
class StatsCompareView extends StatefulWidget {
  final List<AdminMatchRowData> selectedRows;

  const StatsCompareView({super.key, required this.selectedRows});

  @override
  State<StatsCompareView> createState() => _StatsCompareViewState();
}

class _StatsCompareViewState extends State<StatsCompareView> {
  bool _byMatch = false; // false = moyennes, true = par match
  bool _showRadar = false;

  final _chartKey = GlobalKey();
  Uint8List? _pngBytes;

  static const _allStats = [
    ('tirs1', 'tirs2', 'Tirs'),
    ('tirsCadres1', 'tirsCadres2', 'Tirs cadrés'),
    ('possession1', 'possession2', 'Possession %'),
    ('passes1', 'passes2', 'Passes'),
    ('corners1', 'corners2', 'Corners'),
    ('horsJeu1', 'horsJeu2', 'Hors-jeu'),
    ('fautes1', 'fautes2', 'Fautes'),
    ('arretsGardien1', 'arretsGardien2', 'Arrêts gardien'),
    ('duelWon1', 'duelWon2', 'Duels gagnés'),
  ];

  // Retourne (valeur CSSA, valeur adversaire) orienté correctement
  static (double cssa, double opp) _oriented(
    AdminMatchRowData row,
    String k1,
    String k2,
  ) {
    final s = row.s;
    final t1 = row.t1.toUpperCase();
    final t2 = row.t2.toUpperCase();
    final clubHome = t1.contains('SEDAN') || t1.contains('CSSA');
    final clubAway = t2.contains('SEDAN') || t2.contains('CSSA');
    final isClubHome = clubHome || !clubAway;
    final cssa = isClubHome
        ? (s[k1] as num? ?? 0).toDouble()
        : (s[k2] as num? ?? 0).toDouble();
    final opp = isClubHome
        ? (s[k2] as num? ?? 0).toDouble()
        : (s[k1] as num? ?? 0).toDouble();
    return (cssa, opp);
  }

  static String _oppName(AdminMatchRowData row) {
    final d = row.d;
    final t1 = row.t1.toUpperCase();
    final clubHome = t1.contains('SEDAN') || t1.contains('CSSA');
    final raw = clubHome
        ? (d['team2'] as String? ?? '')
        : (d['team1'] as String? ?? '');
    final parts = raw.trim().split(' ');
    return parts.isNotEmpty ? parts.first : raw;
  }

  static String _matchLabel(AdminMatchRowData row) {
    final d = row.d;
    final ts = d['date'] as Timestamp?;
    final dt = ts?.toDate();
    final date = dt != null ? '${dt.day}/${dt.month}' : '?';
    return '${_oppName(row)} $date';
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

  @override
  Widget build(BuildContext context) {
    if (widget.selectedRows.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sélectionnez au moins 2 matchs pour comparer.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_pngBytes != null) {
      return _PngPreview(
        bytes: _pngBytes!,
        onClose: () => setState(() => _pngBytes = null),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
          child: Row(
            children: [
              Text(
                'COMPARAISON',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                '${widget.selectedRows.length} matchs',
                color: adminGold,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _exportPng,
                icon: const Icon(Icons.download_rounded, size: 16, color: adminGreenAccent),
                label: Text(
                  'PNG',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: adminGreenAccent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Chips matchs ─────────────────────────────────────────────────────
        _MatchChips(rows: widget.selectedRows),
        const SizedBox(height: 16),

        // ── Toggle mode ──────────────────────────────────────────────────────
        Row(
          children: [
            _ToggleChip(
              label: 'Moyenne',
              selected: !_byMatch,
              onTap: () => setState(() => _byMatch = false),
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: 'Par match',
              selected: _byMatch,
              onTap: () => setState(() => _byMatch = true),
            ),
            const Spacer(),
            _ToggleChip(
              label: 'Radar',
              icon: Icons.hub_outlined,
              selected: _showRadar,
              onTap: () => setState(() => _showRadar = !_showRadar),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Tableau stats ────────────────────────────────────────────────────
        RepaintBoundary(
          key: _chartKey,
          child: Container(
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: adminBorder),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _byMatch ? _ByMatchTable(rows: widget.selectedRows) : _AvgTable(rows: widget.selectedRows),
          ),
        ),

        // ── Radar ─────────────────────────────────────────────────────────
        if (_showRadar) ...[
          const SizedBox(height: 12),
          _RadarSection(rows: widget.selectedRows),
        ],
      ],
    );
  }
}

// ── Vue moyenne CSSA vs adversaires ──────────────────────────────────────────

class _AvgTable extends StatelessWidget {
  final List<AdminMatchRowData> rows;
  const _AvgTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    // Calculer les stats disponibles
    final availableStats = _StatsCompareViewState._allStats.where((s) {
      return rows.any((r) => r.s.containsKey(s.$1) || r.s.containsKey(s.$2));
    }).toList();

    if (availableStats.isEmpty) {
      return Text(
        'Aucune statistique disponible.',
        style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
      );
    }

    return Column(
      children: [
        // En-tête
        Row(
          children: [
            Expanded(
              child: Text(
                'CSSA (moy.)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _cssaGold,
                ),
              ),
            ),
            Text(
              'STATISTIQUES',
              style: GoogleFonts.barlowCondensed(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: adminGrey,
                letterSpacing: 1.2,
              ),
            ),
            Expanded(
              child: Text(
                'Adversaires',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...availableStats.map((s) {
          // Calculer les moyennes
          double cssaTotal = 0;
          double oppTotal = 0;
          var count = 0;
          for (final row in rows) {
            final (cssa, opp) = _StatsCompareViewState._oriented(row, s.$1, s.$2);
            cssaTotal += cssa;
            oppTotal += opp;
            count++;
          }
          final cssaAvg = count > 0 ? cssaTotal / count : 0.0;
          final oppAvg = count > 0 ? oppTotal / count : 0.0;
          // Per-match mini values
          final perMatch = rows
              .map((r) => _StatsCompareViewState._oriented(r, s.$1, s.$2))
              .toList();
          return _AvgStatRow(
            label: s.$3,
            cssaAvg: cssaAvg,
            oppAvg: oppAvg,
            perMatch: perMatch,
          );
        }),
      ],
    );
  }
}

class _AvgStatRow extends StatelessWidget {
  final String label;
  final double cssaAvg;
  final double oppAvg;
  final List<(double, double)> perMatch;

  const _AvgStatRow({
    required this.label,
    required this.cssaAvg,
    required this.oppAvg,
    required this.perMatch,
  });

  @override
  Widget build(BuildContext context) {
    final total = max(cssaAvg + oppAvg, 0.01);
    final cssaFrac = (cssaAvg / total).clamp(0.0, 1.0);
    final cssaWins = cssaAvg > oppAvg;
    final oppWins = oppAvg > cssaAvg;

    // Formater : si valeur entière afficher sans décimale
    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Valeur CSSA
              SizedBox(
                width: 36,
                child: Text(
                  fmt(cssaAvg),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: cssaWins ? _cssaGold : adminTextPrimary,
                  ),
                ),
              ),
              // Barre double
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: adminGrey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          // Barre CSSA (gauche → centre)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: cssaFrac,
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: cssaWins
                                        ? const LinearGradient(
                                            colors: [_cssaGold, _cssaGoldLight],
                                          )
                                        : null,
                                    color: cssaWins ? null : adminSurface,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      bottomLeft: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 2, height: 10, color: adminBg),
                          // Barre adversaire (centre → droite)
                          Expanded(
                            child: FractionallySizedBox(
                              widthFactor: 1.0 - cssaFrac,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: oppWins
                                      ? _matchColors[0]
                                      : adminSurface,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
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
              ),
              // Valeur adversaire
              SizedBox(
                width: 36,
                child: Text(
                  fmt(oppAvg),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: oppWins
                        ? _matchColors[0].withAlpha(220)
                        : adminGrey,
                  ),
                ),
              ),
            ],
          ),
          // Mini valeurs par match
          if (perMatch.length > 1) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < perMatch.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _MiniMatchDot(
                          cssa: perMatch[i].$1,
                          opp: perMatch[i].$2,
                          color: _matchColors[i % _matchColors.length],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMatchDot extends StatelessWidget {
  final double cssa;
  final double opp;
  final Color color;

  const _MiniMatchDot({
    required this.cssa,
    required this.opp,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cssaWins = cssa >= opp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: cssaWins ? _cssaGold : adminGrey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '${cssa.toInt()}–${opp.toInt()}',
          style: GoogleFonts.inter(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Vue par match ─────────────────────────────────────────────────────────────

class _ByMatchTable extends StatelessWidget {
  final List<AdminMatchRowData> rows;
  const _ByMatchTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final availableStats = _StatsCompareViewState._allStats.where((s) {
      return rows.any((r) => r.s.containsKey(s.$1) || r.s.containsKey(s.$2));
    }).toList();

    if (availableStats.isEmpty) {
      return Text(
        'Aucune statistique disponible.',
        style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Légende
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'Match',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: adminGrey,
                ),
              ),
            ),
            ...availableStats.map(
              (s) => Expanded(
                flex: 2,
                child: Text(
                  s.$3.split(' ').first,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: adminGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(height: 1, color: adminBorder),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final color = _matchColors[i % _matchColors.length];
          return _ByMatchRow(
            row: row,
            color: color,
            stats: availableStats,
          );
        }),
        const SizedBox(height: 4),
        // Légende couleurs
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _InlineLegend(color: _cssaGold, label: 'CSSA'),
            _InlineLegend(color: adminGrey.withAlpha(120), label: 'Adversaire'),
          ],
        ),
      ],
    );
  }
}

class _ByMatchRow extends StatelessWidget {
  final AdminMatchRowData row;
  final Color color;
  final List<(String, String, String)> stats;

  const _ByMatchRow({
    required this.row,
    required this.color,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final label = _StatsCompareViewState._matchLabel(row);
    final score = row.score;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom du match
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                score,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barres stats
          ...stats.map((s) {
            final (cssa, opp) = _StatsCompareViewState._oriented(row, s.$1, s.$2);
            final total = max(cssa + opp, 0.01);
            final cssaFrac = (cssa / total).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      s.$3,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: adminGrey,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 22,
                    child: Text(
                      cssa.toInt().toString(),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: cssa >= opp ? _cssaGold : adminTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: cssaFrac,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: cssa >= opp
                                        ? const LinearGradient(
                                            colors: [_cssaGold, _cssaGoldLight],
                                          )
                                        : null,
                                    color: cssa < opp ? adminSurface : null,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 2, height: 8, color: adminBg),
                          Expanded(
                            child: FractionallySizedBox(
                              widthFactor: 1.0 - cssaFrac,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: opp > cssa
                                      ? color.withAlpha(160)
                                      : adminSurface,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 22,
                    child: Text(
                      opp.toInt().toString(),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: opp > cssa ? color : adminGrey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          Container(height: 1, color: adminBorder.withAlpha(80)),
        ],
      ),
    );
  }
}

// ── Radar profil ──────────────────────────────────────────────────────────────

class _RadarSection extends StatelessWidget {
  final List<AdminMatchRowData> rows;

  const _RadarSection({required this.rows});

  static const _radarStats = [
    ('tirs1', 'tirs2', 'TIRS'),
    ('tirsCadres1', 'tirsCadres2', 'TIR.CAD'),
    ('possession1', 'possession2', 'POSS%'),
    ('corners1', 'corners2', 'CORNERS'),
    ('fautes1', 'fautes2', 'FAUTES'),
    ('arretsGardien1', 'arretsGardien2', 'ARRÊTS'),
    ('duelWon1', 'duelWon2', 'DUELS'),
  ];

  static List<double> _avgByStat(
    List<AdminMatchRowData> rows,
    bool cssa,
  ) {
    return _radarStats.map((s) {
      if (rows.isEmpty) return 0.0;
      double total = 0;
      for (final row in rows) {
        final (c, o) = _StatsCompareViewState._oriented(row, s.$1, s.$2);
        total += cssa ? c : o;
      }
      return total / rows.length;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clubAvg = _avgByStat(rows, true);
    final oppAvg = _avgByStat(rows, false);

    // Normaliser 0–100 par indicateur
    final clubNorm = <double>[];
    final oppNorm = <double>[];
    for (var i = 0; i < clubAvg.length; i++) {
      final mx = max(clubAvg[i], oppAvg[i]).clamp(1.0, double.infinity);
      clubNorm.add((clubAvg[i] / mx * 100).clamp(0, 100));
      oppNorm.add((oppAvg[i] / mx * 100).clamp(0, 100));
    }

    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 14, color: adminGold),
              const SizedBox(width: 8),
              Text(
                'PROFIL DE JEU',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(
                    fillColor: _cssaGold.withAlpha(60),
                    borderColor: _cssaGold,
                    borderWidth: 2.5,
                    entryRadius: 4,
                    dataEntries:
                        clubNorm.map((v) => RadarEntry(value: v)).toList(),
                  ),
                  RadarDataSet(
                    fillColor: _matchColors[0].withAlpha(40),
                    borderColor: _matchColors[0],
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries:
                        oppNorm.map((v) => RadarEntry(value: v)).toList(),
                  ),
                ],
                radarBackgroundColor: adminCard,
                radarBorderData: BorderSide(color: adminBorder.withAlpha(200)),
                gridBorderData: BorderSide(color: adminBorder.withAlpha(160)),
                tickBorderData: BorderSide(color: adminBorder.withAlpha(100)),
                tickCount: 3,
                ticksTextStyle: GoogleFonts.inter(
                  fontSize: 8,
                  color: adminGrey,
                ),
                titleTextStyle: GoogleFonts.inter(
                  fontSize: 9,
                  color: adminTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
                getTitle: (index, angle) {
                  if (index < 0 || index >= _radarStats.length) {
                    return const RadarChartTitle(text: '');
                  }
                  return RadarChartTitle(
                    text: _radarStats[index].$3,
                    angle: angle,
                  );
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
            runSpacing: 6,
            children: [
              _InlineLegend(color: _cssaGold, label: 'CSSA — moyenne'),
              _InlineLegend(color: _matchColors[0], label: 'Adversaires — moyenne'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Match chips ───────────────────────────────────────────────────────────────

class _MatchChips extends StatelessWidget {
  final List<AdminMatchRowData> rows;
  const _MatchChips({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        final color = _matchColors[i % _matchColors.length];
        final opp = _StatsCompareViewState._oppName(row);
        final d = row.d;
        final ts = d['date'] as Timestamp?;
        final dt = ts?.toDate();
        final date = dt != null ? '${dt.day}/${dt.month}' : '?';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(100)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'vs $opp $date',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                row.score,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? adminGold.withAlpha(30) : adminSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? adminGold.withAlpha(150) : adminBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? adminGold : adminGrey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? adminGold : adminGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: adminTextPrimary,
        ),
      ),
    );
  }
}

class _InlineLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _InlineLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: adminTextPrimary,
          ),
        ),
      ],
    );
  }
}

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
