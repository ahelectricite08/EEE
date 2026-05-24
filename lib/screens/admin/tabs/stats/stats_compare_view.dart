import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';

/// Comparaison graphique de plusieurs matchs Sedan (inline ou dialog).
class StatsCompareView extends StatefulWidget {
  final List<AdminMatchRowData> selectedRows;

  const StatsCompareView({super.key, required this.selectedRows});

  @override
  State<StatsCompareView> createState() => _StatsCompareViewState();
}

class _StatsCompareViewState extends State<StatsCompareView>
    with SingleTickerProviderStateMixin {
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

  List<({String label, double club, double opp})> _getOrientedData(
    String k1,
    String k2,
  ) =>
      widget.selectedRows.map((row) {
        final d = row.d;
        final s = row.s;
        final ts = d['date'] as Timestamp?;
        final dt = ts?.toDate();
        final t1 = row.t1.toUpperCase();
        final t2 = row.t2.toUpperCase();
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
    for (final row in widget.selectedRows) {
      final t1 = row.t1.toUpperCase();
      if (t1.contains('SEDAN') || t1.contains('CSSA')) return 'DVCR (dom.)';
      final t2 = row.t2.toUpperCase();
      if (t2.contains('SEDAN') || t2.contains('CSSA')) return 'DVCR (ext.)';
    }
    return 'Équipe 1 (dom.)';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedRows.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Sélectionnez au moins 2 matchs pour comparer.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final tabIdx = _tabCtrl.index;
    final isTout = _tabs[tabIdx].$1 == '__tout__';

    if (_pngBytes != null) {
      return _PngPreview(
        bytes: _pngBytes!,
        onClose: () => setState(() => _pngBytes = null),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Text(
                'ANALYSE',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
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
                  '${widget.selectedRows.length} sélection',
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.selectedRows.length > 1
                ? 'Plusieurs matchs : moyenne DVCR vs chaque adversaire (onglet Tout) ou l’indicateur choisi.'
                : 'Une rencontre : barres = DVCR vs cet adversaire.',
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
        const SizedBox(height: 8),
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
            child: isTout ? _buildToutChart() : _buildSingleChart(tabIdx),
          ),
        ),
      ],
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
          'Par match — barres : $_clubLegendLabel · adversaire',
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
    final matchInfos = widget.selectedRows.map((row) {
      final d = row.d;
      final t1 = row.t1.toUpperCase();
      final t2 = row.t2.toUpperCase();
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
      return (
        isClubHome: isClubHome,
        name: '$advName $date',
        stats: row.s,
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
              ? 'Radar normalisé (0–100) : volume relatif par indicateur.'
              : 'Barres : moyenne DVCR + une barre par adversaire sélectionné.',
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
            _legend(
              adminGold,
              'DVCR — moyenne (${widget.selectedRows.length} mt.)',
              strong: true,
            ),
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
