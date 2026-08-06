import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match_stats_schema.dart';
import '../navigation/main_shell_insets.dart';
import '../models/match_model.dart';
import '../models/user_role.dart';
import '../services/seed_service.dart';
import '../services/user_service.dart';

/// Ouvre le menu stats live (buts, cartons, chiffres) depuis la carte match ou ailleurs.
void showLiveStatsBottomSheet(BuildContext context) {
  showDvcrModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => const _LiveStatsSheetStream(),
  );
}

/// Écoute `live/current` + `matches/{matchId}` pour refléter les saisies admin en direct.
class _LiveStatsSheetStream extends StatefulWidget {
  const _LiveStatsSheetStream();

  @override
  State<_LiveStatsSheetStream> createState() => _LiveStatsSheetStreamState();
}

class _LiveStatsSheetStreamState extends State<_LiveStatsSheetStream> {
  bool _staffControls = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final roles = await UserService.getCurrentRoles();
    if (!mounted) return;
    setState(() {
      _staffControls = roles.contains(UserRole.admin) ||
          roles.contains(UserRole.communityManager);
    });
  }

  static List<Map<String, dynamic>> _eventsFrom(Map<String, dynamic> d) =>
      MatchStatsSchema.parseGameEvents(d['events']);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, liveSnap) {
        final live = liveSnap.data?.data() as Map<String, dynamic>? ?? {};
        final matchId = (live['matchId'] as String? ?? '').trim();
        if (matchId.isEmpty) {
          return _sheetFrom(live, null);
        }
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .snapshots(),
          builder: (context, matchSnap) {
            final match = matchSnap.data?.data() as Map<String, dynamic>?;
            return _sheetFrom(live, match);
          },
        );
      },
    );
  }

  Widget _sheetFrom(Map<String, dynamic> live, Map<String, dynamic>? match) {
    final stats = MatchStatsSchema.resolveFromLiveHub(live: live, match: match);
    final statsEnabled = (live['statsEnabled'] as bool?) ?? false;
    final liveEvents = _eventsFrom(live);
    final matchEvents = match != null ? _eventsFrom(match) : const <Map<String, dynamic>>[];
    // En direct : n’afficher que `live/current` pour éviter doublons avec `matches.events`.
    final events = liveEvents.isNotEmpty
        ? liveEvents
        : MatchStatsSchema.mergeGameEvents(liveEvents, matchEvents);

    int pickCard(String key) {
      final lv = (live[key] as num?)?.toInt() ?? 0;
      if (match == null) return lv;
      final mv = (match[key] as num?)?.toInt() ?? 0;
      return mv > lv ? mv : lv;
    }

    final team1 = (live['team1'] as String? ?? match?['team1'] as String? ?? '')
        .trim();
    final team2 = (live['team2'] as String? ?? match?['team2'] as String? ?? '')
        .trim();
    var scoreHome = (live['scoreHome'] as num?)?.toInt();
    var scoreAway = (live['scoreAway'] as num?)?.toInt();
    if (match != null) {
      scoreHome ??=
          MatchModel.parseScoreField(match['score1'] ?? match['homeScore']) ?? 0;
      scoreAway ??=
          MatchModel.parseScoreField(match['score2'] ?? match['awayScore']) ?? 0;
    } else {
      scoreHome ??= 0;
      scoreAway ??= 0;
    }

    return LiveStatsSheet(
      stats: stats,
      team1: team1,
      team2: team2,
      logo1: live['logo1'] as String? ?? match?['logo1'] as String? ?? '',
      logo2: live['logo2'] as String? ?? match?['logo2'] as String? ?? '',
      yellowHome: pickCard('yellowHome'),
      yellowAway: pickCard('yellowAway'),
      redHome: pickCard('redHome'),
      redAway: pickCard('redAway'),
      scoreHome: scoreHome,
      scoreAway: scoreAway,
      events: events,
      statsDisabled: !statsEnabled && events.isEmpty,
      showStaffControls: _staffControls,
    );
  }

}

class LiveStatsSheet extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String team1, team2;
  final String logo1, logo2;
  final int yellowHome, yellowAway, redHome, redAway, scoreHome, scoreAway;
  final List<Map<String, dynamic>> events;
  final bool statsDisabled;
  final bool showStaffControls;
  const LiveStatsSheet({
    required this.stats,
    required this.team1,
    required this.team2,
    this.logo1 = '',
    this.logo2 = '',
    this.yellowHome = 0,
    this.yellowAway = 0,
    this.redHome = 0,
    this.redAway = 0,
    this.scoreHome = 0,
    this.scoreAway = 0,
    this.events = const [],
    this.statsDisabled = false,
    this.showStaffControls = false,
  });

  @override
  State<LiveStatsSheet> createState() => _LiveStatsSheetState();
}

class _LiveStatsSheetState extends State<LiveStatsSheet> {
  bool _resetting = false;

  static const _green = Color(0xFF0A4438);
  static const _gold = Color(0xFFC8A436);
  static const _ink = Color(0xFF173C31);
  static const _muted = Color(0xFF5C6862);
  static const _track = Color(0xFFE4DFD4);
  static const _scoreBg = Color(0xFFF3F0EA);
  static const _yellow = Color(0xFFE8C82A);
  static const _red = Color(0xFFBA203C);

  int _i(dynamic v) => (v is num) ? v.toInt() : 0;

  Future<void> _confirmReset({required bool waitingMode}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          waitingMode ? 'Mode attente ?' : 'Vider les chiffres ?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _ink),
        ),
        content: Text(
          waitingMode
              ? 'Les stats seront masquées pour les supporters (toggle OFF). '
                  'Tu pourras les réactiver depuis le pilotage ou Admin → Live.'
              : 'Les barres repartent à zéro mais le mode stats reste activé.',
          style: GoogleFonts.inter(fontSize: 13, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Confirmer',
              style: GoogleFonts.inter(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      if (waitingMode) {
        await SeedService.resetLiveStatsToWaiting();
      } else {
        await SeedService.clearLiveStatsOnly();
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  bool _isHomeSide(Map<String, dynamic> event, String team1, String team2) {
    final rawBool = event['isHome'];
    if (rawBool is bool) return rawBool;

    final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (side == 'home' || side == 'left' || side == 'team1') return true;
    if (side == 'away' || side == 'right' || side == 'team2') return false;

    final teamIndex = event['teamIndex'];
    if (teamIndex is num) return teamIndex.toInt() == 0;

    final teamRaw = (event['team'] ?? event['teamName'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final t1 = team1.trim().toUpperCase();
    final t2 = team2.trim().toUpperCase();

    if (teamRaw.isNotEmpty) {
      if (teamRaw == t1) return true;
      if (teamRaw == t2) return false;
      if (t1.isNotEmpty && teamRaw.contains(t1.split(' ').first)) return true;
      if (t2.isNotEmpty && teamRaw.contains(t2.split(' ').first)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _typedEvents(
    String type,
    bool isHome,
    String team1,
    String team2,
  ) {
    return widget.events
        .whereType<Map<String, dynamic>>()
        .where((e) => (e['type'] as String? ?? '').trim().toLowerCase() == type)
        .where((e) => _isHomeSide(e, team1, team2) == isHome)
        .toList()
      ..sort(
        (a, b) => ((a['minute'] as num?)?.toInt() ?? 0).compareTo(
          (b['minute'] as num?)?.toInt() ?? 0,
        ),
      );
  }

  List<Widget> _numericStatsSection(Map<String, dynamic> s) {
    return [
      _sectionLabel(
        'POSSESSION',
        icon: Icons.timer_rounded,
        color: const Color(0xFFC8A436),
      ),
      _row(
        'POSSESSION',
        _i(s['possession1']),
        _i(s['possession2']),
        sfx: '%',
        barColor: const Color(0xFFC8A436),
      ),
      _sectionLabel(
        'TIRS',
        icon: Icons.sports_soccer_rounded,
        color: const Color(0xFF4CAF50),
      ),
      _row(
        'TOTAL',
        _i(s['tirs1']),
        _i(s['tirs2']),
        barColor: const Color(0xFF4CAF50),
      ),
      _row(
        'CADRÉS',
        _i(s['tirsCadres1']),
        _i(s['tirsCadres2']),
        barColor: const Color(0xFF4CAF50),
      ),
      _row(
        'POTEAUX',
        _i(s['poteau1']),
        _i(s['poteau2']),
        barColor: const Color(0xFFD4A017),
      ),
      _row(
        'CONTRÉES',
        _i(s['blocked1']),
        _i(s['blocked2']),
        barColor: _muted,
      ),
      _sectionLabel(
        'PASSES',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF42A5F5),
      ),
      _row(
        'RÉUSSIES',
        _i(s['passes1']),
        _i(s['passes2']),
        barColor: const Color(0xFF42A5F5),
      ),
      _row(
        'RATÉES',
        _i(s['passInacc1']),
        _i(s['passInacc2']),
        barColor: const Color(0xFF42A5F5),
      ),
      _sectionLabel(
        'CENTRES',
        icon: Icons.open_with_rounded,
        color: Colors.orange,
      ),
      _row(
        'RÉUSSIS',
        _i(s['crossAcc1']),
        _i(s['crossAcc2']),
        barColor: Colors.orange,
      ),
      _row(
        'RATÉS',
        _i(s['crossInacc1']),
        _i(s['crossInacc2']),
        barColor: Colors.orange,
      ),
      _sectionLabel(
        'DUELS',
        icon: Icons.sports_mma_rounded,
        color: const Color(0xFF7B68EE),
      ),
      _row(
        'GAGNÉS',
        _i(s['duelWon1']),
        _i(s['duelWon2']),
        barColor: const Color(0xFF7B68EE),
      ),
      _sectionLabel(
        'ÉVÉNEMENTS',
        icon: Icons.flag_rounded,
        color: const Color(0xFFEF5350),
      ),
      _row(
        'CORNERS',
        _i(s['corners1']),
        _i(s['corners2']),
        barColor: const Color(0xFFEF5350),
      ),
      _row(
        'HORS-JEU',
        _i(s['horsJeu1']),
        _i(s['horsJeu2']),
        barColor: const Color(0xFFEF5350),
      ),
      _row(
        'FAUTES',
        _i(s['fautes1']),
        _i(s['fautes2']),
        barColor: const Color(0xFFEF5350),
      ),
      _row(
        'ARRÊTS',
        _i(s['arretsGardien1']),
        _i(s['arretsGardien2']),
        barColor: const Color(0xFFEF5350),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    final t1 = widget.team1.isNotEmpty ? widget.team1 : 'DOM';
    final t2 = widget.team2.isNotEmpty ? widget.team2 : 'EXT';

    final goals1 = _typedEvents('goal', true, t1, t2);
    final goals2 = _typedEvents('goal', false, t1, t2);
    final subs1 = _typedEvents('substitution', true, t1, t2);
    final subs2 = _typedEvents('substitution', false, t1, t2);
    final yellows1 = _typedEvents('yellow', true, t1, t2);
    final yellows2 = _typedEvents('yellow', false, t1, t2);
    final reds1 = _typedEvents('red', true, t1, t2);
    final reds2 = _typedEvents('red', false, t1, t2);
    final hasNumericStats = !MatchStatsSchema.isEmpty(s);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Material(
        color: Colors.white,
        child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _track,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 18, color: _green),
                const SizedBox(width: 8),
                Text(
                  'STATS EN DIRECT',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _green,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (widget.logo1.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.network(
                            widget.logo1,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          t1.length > 9 ? '${t1.substring(0, 9)}.' : t1,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _track),
                  ),
                  child: Text(
                    '${widget.scoreHome}  –  ${widget.scoreAway}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          t2.length > 9 ? '${t2.substring(0, 9)}.' : t2,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                      if (widget.logo2.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Image.network(
                            widget.logo2,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _track),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MainShellInsets.sheetBottom(context, extra: 16),
              ),
              children: [
                if (widget.showStaffControls) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetting
                              ? null
                              : () => _confirmReset(waitingMode: true),
                          icon: const Icon(Icons.hourglass_empty_rounded, size: 16),
                          label: Text(
                            'Mode attente',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _green,
                            side: const BorderSide(color: _green),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetting
                              ? null
                              : () => _confirmReset(waitingMode: false),
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: Text(
                            'Vider chiffres',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _muted,
                            side: const BorderSide(color: _track),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (goals1.isNotEmpty || goals2.isNotEmpty) ...[
                  _sectionLabel(
                    'BUTS',
                    icon: Icons.sports_soccer_rounded,
                    color: const Color(0xFFC8A436),
                  ),
                  _eventsRow(
                    goals1,
                    goals2,
                    Icons.sports_soccer_rounded,
                    iconColor: const Color(0xFFC8A436),
                  ),
                  const SizedBox(height: 12),
                ],
                if (subs1.isNotEmpty || subs2.isNotEmpty) ...[
                  _sectionLabel(
                    'REMPLACEMENTS',
                    icon: Icons.swap_horiz_rounded,
                    color: const Color(0xFF4A90D9),
                  ),
                  _eventsRow(
                    subs1,
                    subs2,
                    Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFF4A90D9),
                  ),
                  const SizedBox(height: 12),
                ],
                if (yellows1.isNotEmpty ||
                    yellows2.isNotEmpty ||
                    reds1.isNotEmpty ||
                    reds2.isNotEmpty ||
                    widget.yellowHome + widget.yellowAway + widget.redHome + widget.redAway > 0) ...[
                  _sectionLabel(
                    'CARTONS',
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFFE8C82A),
                  ),
                  if (yellows1.isNotEmpty || yellows2.isNotEmpty)
                    _eventsRow(
                      yellows1,
                      yellows2,
                      Icons.square_rounded,
                      iconColor: _yellow,
                    ),
                  if (reds1.isNotEmpty || reds2.isNotEmpty)
                    _eventsRow(
                      reds1,
                      reds2,
                      Icons.square_rounded,
                      iconColor: _red,
                    ),
                  if (widget.yellowHome + widget.yellowAway > 0)
                    _row('JAUNES', widget.yellowHome, widget.yellowAway, barColor: _yellow),
                  if (widget.redHome + widget.redAway > 0)
                    _row('ROUGES', widget.redHome, widget.redAway, barColor: _red),
                  const SizedBox(height: 4),
                ],
                if (!widget.statsDisabled && !hasNumericStats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Saisie en cours…',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ),
                  )
                else if (!widget.statsDisabled && hasNumericStats)
                  ..._numericStatsSection(s),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _sectionLabel(String label, {IconData? icon, Color? color}) {
    final col = color ?? _muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: col),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: col,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: col.withAlpha(50))),
        ],
      ),
    );
  }

  Widget _eventsRow(
    List events1,
    List events2,
    IconData icon, {
    Color iconColor = _ink,
  }) {
    Widget side(List evs, bool right) => Expanded(
      child: Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: evs.map((e) {
          final player = MatchStatsSchema.eventPlayerLine(
            Map<String, dynamic>.from(e as Map),
          );
          final min = ((e['minute'] as num?)?.toInt() ?? 0);
          final text = player.isEmpty
              ? (min > 0 ? "$min'" : '')
              : min > 0
              ? "$player $min'"
              : player;
          return Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
            textAlign: right ? TextAlign.right : TextAlign.left,
          );
        }).toList(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          side(events1, false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          side(events2, true),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    int v1,
    int v2, {
    String sfx = '',
    Color? barColor,
  }) {
    final total = v1 + v2;
    final frac = total == 0 ? 0.5 : v1 / total;
    final bar1 = (frac * 100).round().clamp(1, 99);
    final bColor = barColor ?? _gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  '$v1$sfx',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '$v2$sfx',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: bar1,
                    child: Container(color: bColor),
                  ),
                  Expanded(
                    flex: 100 - bar1,
                    child: Container(color: _track),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
