import 'dart:math' show max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'stats_admin_helpers.dart';
import 'stats_export_stub.dart'
    if (dart.library.html) 'stats_export_web.dart';

// Couleurs broadcast
const _bg = Color(0xFF0D1117);
const _surface = Color(0xFF161B22);
const _gold = Color(0xFFC8A436);
const _goldLight = Color(0xFFFFD700);
const _white = Color(0xFFFFFFFF);
const _grey = Color(0xFF8B949E);
const _border = Color(0xFF30363D);
const _red = Color(0xFFE74C3C);

class StatsMatchDetailScreen extends StatefulWidget {
  final AdminMatchRowData row;

  const StatsMatchDetailScreen({super.key, required this.row});

  @override
  State<StatsMatchDetailScreen> createState() => _StatsMatchDetailScreenState();
}

class _StatsMatchDetailScreenState extends State<StatsMatchDetailScreen> {
  final _exportKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final boundary = _exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final row = widget.row;
      final date = row.matchDate != null
          ? DateFormat('yyyy-MM-dd').format(row.matchDate!)
          : row.date.replaceAll('/', '-');
      final filename = 'stats_${row.t1}_vs_${row.t2}_$date.png'
          .replaceAll(' ', '_')
          .toLowerCase();
      await downloadPng(bytes, filename);
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'FICHE MATCH',
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _gold,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.download_rounded, size: 16, color: _gold),
                    label: Text(
                      'PNG',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _gold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          children: [
            // ── Carte exportable ──────────────────────────────────────────
            RepaintBoundary(
              key: _exportKey,
              child: _BroadcastCard(row: row),
            ),
            const SizedBox(height: 12),
            // ── Timeline buts ─────────────────────────────────────────────
            if (row.goals.isNotEmpty) ...[
              _SectionCard(
                icon: Icons.sports_soccer_rounded,
                title: 'BUTS',
                child: Column(
                  children: [
                    _GoalTimeline(goals: row.goals, row: row),
                    const SizedBox(height: 16),
                    _GoalsBySide(row: row),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ── Cartons ───────────────────────────────────────────────────
            _CardsSection(row: row),
          ],
        ),
      ),
    );
  }
}

// ── Carte broadcast (capturée en PNG) ─────────────────────────────────────────

class _BroadcastCard extends StatelessWidget {
  final AdminMatchRowData row;
  const _BroadcastCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Bande dorée top
          Container(height: 3, color: _gold),
          // Header équipes + score
          _BroadcastHeader(row: row),
          Container(height: 1, color: _border),
          // Corps stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                if (row.s.containsKey('possession1')) ...[
                  _BroadcastPossession(row: row),
                  const SizedBox(height: 14),
                ],
                if (row.hasStats) _BroadcastStats(row: row),
              ],
            ),
          ),
          // Footer
          _BroadcastFooter(row: row),
        ],
      ),
    );
  }
}

class _BroadcastHeader extends StatelessWidget {
  final AdminMatchRowData row;
  const _BroadcastHeader({required this.row});

  @override
  Widget build(BuildContext context) {
    final scores = row.score.split('-');
    final s1 = scores.isNotEmpty ? scores[0].trim() : '?';
    final s2 = scores.length > 1 ? scores[1].trim() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Équipe 1
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  row.t1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Score central
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      s1,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: _gold,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '—',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: _grey,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      s2,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: _white,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withAlpha(80)),
                  ),
                  child: Text(
                    row.competition.isNotEmpty ? row.competition.toUpperCase() : 'OFFICIEL',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _gold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Équipe 2
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  row.t2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _grey,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastPossession extends StatelessWidget {
  final AdminMatchRowData row;
  const _BroadcastPossession({required this.row});

  @override
  Widget build(BuildContext context) {
    final p1 = (row.s['possession1'] as num?)?.toInt() ?? 0;
    final p2 = (row.s['possession2'] as num?)?.toInt() ?? (100 - p1);

    return Column(
      children: [
        Row(
          children: [
            _label('POSSESSION', _grey),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$p1%',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      flex: p1,
                      child: Container(
                        height: 10,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_goldLight, _gold],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 2, height: 10, color: _bg),
                    Expanded(
                      flex: p2,
                      child: Container(height: 10, color: _surface),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$p2%',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BroadcastStats extends StatelessWidget {
  final AdminMatchRowData row;
  const _BroadcastStats({required this.row});

  @override
  Widget build(BuildContext context) {
    final s = row.s;
    final lines = <_StatLine>[
      _StatLine('Tirs', s['tirs1'], s['tirs2']),
      _StatLine('Tirs cadrés', s['tirsCadres1'], s['tirsCadres2']),
      _StatLine('Corners', s['corners1'], s['corners2']),
      _StatLine('Fautes', s['fautes1'], s['fautes2']),
      _StatLine('Arrêts gardien', s['arretsGardien1'], s['arretsGardien2']),
      _StatLine('Hors-jeu', s['horsJeu1'], s['horsJeu2']),
      _StatLine('Passes clés', s['keyPass1'], s['keyPass2']),
      _StatLine('Duels gagnés', s['duelWon1'], s['duelWon2']),
    ].where((l) => l.hasData).toList();

    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // En-tête équipes
        Row(
          children: [
            Expanded(
              child: Text(
                row.t1,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _gold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _label('STATISTIQUES', _grey),
            Expanded(
              child: Text(
                row.t2,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lines.map((l) => _BroadcastStatRow(line: l)),
      ],
    );
  }
}

class _StatLine {
  final String label;
  final num? v1;
  final num? v2;
  const _StatLine(this.label, this.v1, this.v2);
  bool get hasData => v1 != null || v2 != null;
  int get i1 => (v1 ?? 0).toInt();
  int get i2 => (v2 ?? 0).toInt();
}

class _BroadcastStatRow extends StatelessWidget {
  final _StatLine line;
  const _BroadcastStatRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final total = max(line.i1 + line.i2, 1);
    final frac1 = line.i1 / total;
    final win1 = line.i1 > line.i2;
    final win2 = line.i2 > line.i1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          // Score gauche
          SizedBox(
            width: 32,
            child: Text(
              '${line.i1}',
              textAlign: TextAlign.left,
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: win1 ? _gold : _white,
              ),
            ),
          ),
          // Barre + label
          Expanded(
            child: Column(
              children: [
                Text(
                  line.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: frac1,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: win1
                                    ? const LinearGradient(
                                        colors: [_gold, _goldLight],
                                      )
                                    : null,
                                color: win1 ? null : _surface,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  bottomLeft: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 2, height: 8, color: _bg),
                      Expanded(
                        child: FractionallySizedBox(
                          widthFactor: 1.0 - frac1,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: win2 ? _grey : _surface,
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
          // Score droite
          SizedBox(
            width: 32,
            child: Text(
              '${line.i2}',
              textAlign: TextAlign.right,
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: win2 ? _white.withAlpha(200) : _grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastFooter extends StatelessWidget {
  final AdminMatchRowData row;
  const _BroadcastFooter({required this.row});

  @override
  Widget build(BuildContext context) {
    final dateStr = row.matchDate != null
        ? DateFormat('EEEE d MMMM y', 'fr_FR').format(row.matchDate!)
        : row.date;

    // Résumé des buts
    final goalsLine = _buildGoalsLine(row);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D12),
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          if (goalsLine.isNotEmpty) ...[
            Text(
              goalsLine,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DVCR · CS Sedan Ardennes',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _gold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                dateStr,
                style: GoogleFonts.inter(fontSize: 11, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _buildGoalsLine(AdminMatchRowData row) {
    if (row.goals.isEmpty) return '';
    final home = <String>[];
    final away = <String>[];
    for (final g in row.goals) {
      final team = (g['team'] as String? ?? '').toLowerCase();
      final min = g['minute'] ?? '?';
      final player = _playerName(g);
      final entry = '$player $min\'';
      final isHome = team == 'home' || team == '1' || row.sedanIsHome;
      if (isHome) {
        home.add(entry);
      } else {
        away.add(entry);
      }
    }
    final parts = <String>[];
    if (home.isNotEmpty) parts.add('⚽ ${home.join(', ')}');
    if (away.isNotEmpty) parts.add('${away.join(', ')} ⚽');
    return parts.join('   ·   ');
  }

  static String _playerName(Map<String, dynamic> g) {
    final line = (g['player'] as String? ?? g['playerName'] as String? ?? '').trim();
    if (line.isEmpty) return '?';
    final parts = line.split(' ');
    return parts.length > 1 ? parts.last : line;
  }
}

// ── Timeline buts (section extra, non exportée) ────────────────────────────

class _GoalTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final AdminMatchRowData row;
  const _GoalTimeline({required this.goals, required this.row});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Ligne de base
              Positioned(
                top: 28,
                left: 0,
                right: 0,
                child: Container(height: 2, color: _border),
              ),
              // Marque mi-temps
              Positioned(
                top: 17,
                left: (45 / 90) * w - 1,
                child: Container(width: 2, height: 24, color: _grey.withAlpha(60)),
              ),
              Positioned(
                top: 37,
                left: (45 / 90) * w - 8,
                child: Text("45'", style: GoogleFonts.inter(fontSize: 9, color: _grey)),
              ),
              // Labels 0 / 90
              Positioned(
                top: 37,
                left: 0,
                child: Text("0'", style: GoogleFonts.inter(fontSize: 9, color: _grey)),
              ),
              Positioned(
                top: 37,
                right: 0,
                child: Text("90'", style: GoogleFonts.inter(fontSize: 9, color: _grey)),
              ),
              // Marqueurs
              for (final g in goals)
                Builder(builder: (ctx) {
                  final minute = _parseMin(g['minute']);
                  final frac = (minute / 90).clamp(0.02, 0.98);
                  final isHome = _isHome(g, row);
                  return Positioned(
                    left: frac * w - 9,
                    top: isHome ? 2 : 28,
                    child: _GoalDot(isHome: isHome, minute: minute),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  static int _parseMin(dynamic m) {
    if (m is int) return m.clamp(0, 90);
    if (m is String) return int.tryParse(m.replaceAll("'", ''))?.clamp(0, 90) ?? 45;
    return 45;
  }

  static bool _isHome(Map<String, dynamic> g, AdminMatchRowData row) {
    final team = (g['team'] as String? ?? '').toLowerCase();
    if (team == 'home' || team == '1') return true;
    if (team == 'away' || team == '2') return false;
    return row.sedanIsHome;
  }
}

class _GoalDot extends StatelessWidget {
  final bool isHome;
  final int minute;
  const _GoalDot({required this.isHome, required this.minute});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isHome) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
              border: Border.all(color: _bg, width: 2),
              boxShadow: [
                BoxShadow(color: _gold.withAlpha(100), blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.sports_soccer, size: 9, color: Colors.black),
          ),
          Container(width: 1, height: 8, color: _gold.withAlpha(100)),
        ] else ...[
          Container(width: 1, height: 8, color: _grey.withAlpha(100)),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _grey, width: 2),
            ),
            child: const Icon(Icons.sports_soccer, size: 9, color: _grey),
          ),
        ],
      ],
    );
  }
}

class _GoalsBySide extends StatelessWidget {
  final AdminMatchRowData row;
  const _GoalsBySide({required this.row});

  @override
  Widget build(BuildContext context) {
    final goals = row.goals;
    final home = goals.where((g) {
      final t = (g['team'] as String? ?? '').toLowerCase();
      return t == 'home' || t == '1' || row.sedanIsHome;
    }).toList();
    final away = goals.where((g) => !home.contains(g)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _GoalList(goals: home, isHome: true)),
        Container(width: 1, color: _border, margin: const EdgeInsets.symmetric(horizontal: 16)),
        Expanded(child: _GoalList(goals: away, isHome: false)),
      ],
    );
  }
}

class _GoalList extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final bool isHome;
  const _GoalList({required this.goals, required this.isHome});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Text(
        '—',
        textAlign: isHome ? TextAlign.left : TextAlign.right,
        style: GoogleFonts.inter(fontSize: 13, color: _grey),
      );
    }
    return Column(
      crossAxisAlignment:
          isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: goals.map((g) {
        final min = g['minute'] ?? '?';
        final player = _playerName(g);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment:
                isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isHome) ...[
                const Icon(Icons.sports_soccer, size: 13, color: _gold),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  "$player $min'",
                  textAlign: isHome ? TextAlign.left : TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _white,
                  ),
                ),
              ),
              if (!isHome) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sports_soccer, size: 13, color: _grey),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _playerName(Map<String, dynamic> g) {
    final line = (g['player'] as String? ?? g['playerName'] as String? ?? '').trim();
    if (line.isEmpty) return '?';
    final parts = line.split(' ');
    return parts.length > 1 ? parts.last : line;
  }
}

// ── Cartons ───────────────────────────────────────────────────────────────────

class _CardsSection extends StatelessWidget {
  final AdminMatchRowData row;
  const _CardsSection({required this.row});

  @override
  Widget build(BuildContext context) {
    final yH = row.yH;
    final yA = row.yA;
    final rH = row.rH;
    final rA = row.rA;
    if (yH + yA + rH + rA == 0) return const SizedBox.shrink();

    return _SectionCard(
      icon: Icons.style_rounded,
      title: 'CARTONS',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.t1,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _CardChips(yellow: yH, red: rH),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  row.t2,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _CardChips(yellow: yA, red: rA, right: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardChips extends StatelessWidget {
  final int yellow;
  final int red;
  final bool right;
  const _CardChips({required this.yellow, required this.red, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: right ? WrapAlignment.end : WrapAlignment.start,
      children: [
        if (yellow > 0) _CardPill(count: yellow, color: const Color(0xFFE8C82A), label: 'Jaune'),
        if (red > 0) _CardPill(count: red, color: _red, label: 'Rouge'),
        if (yellow == 0 && red == 0)
          Text('—', style: GoogleFonts.inter(fontSize: 13, color: _grey)),
      ],
    );
  }
}

class _CardPill extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _CardPill({required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '×$count',
            style: GoogleFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared section card ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _label(String text, Color color) {
  return Text(
    text,
    style: GoogleFonts.barlowCondensed(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: color,
      letterSpacing: 1.2,
    ),
  );
}
