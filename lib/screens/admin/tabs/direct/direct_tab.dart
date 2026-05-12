import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_model.dart';
import '../../../../services/seed_service.dart';
import '../../../../services/match_controller.dart';
import '../../../../services/emission_poll_service.dart';
import '../../../../services/motm_vote_service.dart';
import '../../../../services/sponsor_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import 'direct_live_salon_panel.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ONGLET DIRECT
// ═══════════════════════════════════════════════════════════════════════════════

class DirectTab extends StatefulWidget {
  const DirectTab();

  @override
  State<DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends State<DirectTab> {
  static const Duration _matchDurationFallback = Duration(hours: 2);
  static const Duration _nextMatchDelayAfterEnd = Duration(hours: 3);

  bool _loadingLive = false;
  bool _loadingEmission = false;
  bool _statsEnabled = false;

  void _openStatsLiveFocus(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => _StatsLiveFocusRoute(
            onClose: () => Navigator.of(ctx, rootNavigator: true).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AdminModuleHeader(
          title: 'Direct DVCR',
          subtitle:
              'Match en ligne, salon, émission et votes — pilotage du flux live.',
          icon: Icons.live_tv_rounded,
          accent: adminRed,
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Temps réel',
          title: 'Match en direct',
          subtitle:
              'Activer le live, score, buts, stats et homme du match. '
              'Le match du calendrier proposé est enregistré au démarrage (matchId) : '
              'l’accueil et les cartes ne suivent le flux live que pour ce match. '
              'Terminer le live libère l’accueil.',
          accent: adminRed,
          wrapInCard: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('live')
                .doc('current')
                .snapshots(),
            builder: (context, snap) {
              final isLive = snap.hasData && snap.data!.exists;
              final data = isLive
                  ? snap.data!.data() as Map<String, dynamic>
                  : null;
              final statsEnabled =
                  (data?['statsEnabled'] as bool?) ?? _statsEnabled;
              return Column(
                children: [
                  _LiveCard(
                    title: 'MATCH EN DIRECT',
                    subtitle: isLive
                        ? '${data?['team1'] ?? ''} vs ${data?['team2'] ?? ''}'
                        : 'Aucun match en cours',
                    icon: Icons.sports_soccer_rounded,
                    isActive: isLive,
                    loading: _loadingLive,
                    onToggle: () => _handleLiveMatch(isLive, data),
                  ),
                  if (isLive && data != null) ...[
                    const SizedBox(height: 12),
                    _ScorePanel(data: data),
                    const SizedBox(height: 12),
                    _GoalFeed(data: data),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: adminCard,
                        border: Border.all(color: adminBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bar_chart_rounded,
                            size: 15,
                            color: adminGold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STATS EN DIRECT',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: adminTextPrimary,
                                  ),
                                ),
                                Text(
                                  statsEnabled
                                      ? 'Statisticien présent'
                                      : 'Désactivées — non affichées',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: adminGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: statsEnabled,
                            onChanged: (v) async {
                              setState(() => _statsEnabled = v);
                              final patch = <String, dynamic>{'statsEnabled': v};
                              // Vider seulement le flux live — pas `matches/{id}` (les stats
                              // restent sur la fiche match ; suppression via onglet Stats).
                              if (!v) {
                                patch['stats'] = <String, dynamic>{};
                              }
                              await FirebaseFirestore.instance
                                  .collection('live')
                                  .doc('current')
                                  .update(patch);
                            },
                            activeThumbColor: adminGold,
                            inactiveThumbColor: adminGrey,
                            inactiveTrackColor: adminBorder,
                          ),
                        ],
                      ),
                    ),
                    if (statsEnabled) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openStatsLiveFocus(context),
                          icon: Icon(
                            Icons.center_focus_strong_rounded,
                            size: 20,
                            color: adminGold,
                          ),
                          label: Text(
                            'Mode focus — plein écran',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: adminTextPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: adminTextPrimary,
                            side: BorderSide(color: adminGold.withAlpha(120)),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LiveStatsPanel(data: data),
                    ],
                    const SizedBox(height: 12),
                    _ManOfTheMatchTeamVotePanel(data: data),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Chat app',
          title: 'Salon live',
          subtitle: 'Salons marqués live et archivage.',
          accent: const Color(0xFF00BCD4),
          wrapInCard: false,
          child: const DirectLiveSalonPanel(),
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Studio',
          title: 'Émission & sondage',
          subtitle: 'Antenne DVCR et sondage lié à l’émission.',
          accent: adminGold,
          wrapInCard: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('live')
                    .doc('emission')
                    .snapshots(),
                builder: (context, snap) {
                  final isLive = snap.hasData && snap.data!.exists;
                  final data = isLive
                      ? snap.data!.data() as Map<String, dynamic>
                      : null;
                  return _LiveCard(
                    title: 'ÉMISSION DVCR',
                    subtitle: isLive
                        ? (data?['title'] ?? 'En antenne')
                        : 'Studio prêt',
                    icon: Icons.mic_rounded,
                    isActive: isLive,
                    loading: _loadingEmission,
                    onToggle: () => _handleEmission(isLive),
                  );
                },
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('live')
                    .doc('emission')
                    .snapshots(),
                builder: (context, snap) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _EmissionPollPanel(
                    emissionLive: snap.data?.exists == true,
                    data: snap.data?.data(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleLiveMatch(bool isLive, Map<String, dynamic>? data) async {
    if (isLive) {
      final ok = await adminConfirm(context, 'Terminer le match en direct ?');
      if (!ok) return;
      setState(() => _loadingLive = true);
      try {
        await Future.wait([SeedService.clearLive(), _archiveLiveSalon()]);
      } finally {
        setState(() => _loadingLive = false);
      }
      return;
    }

    // Garde encore le match termine comme reference admin pendant 3h
    // avant de proposer automatiquement le suivant.
    final allUpcoming = MatchController.instance.upcoming;
    final allResults = MatchController.instance.results;
    final sedanMatches = allUpcoming.where(_isSedanMatch).toList();
    final sedanResults = allResults.where(_isSedanMatch).toList();
    final suggested = _pickSuggestedAdminMatch(
      upcomingMatches: sedanMatches,
      recentResults: sedanResults,
    );
    final next = suggested.match;

    final urlCtrl = TextEditingController();
    final team1Ctrl = TextEditingController(
      text: next?.team1 ?? 'SEDAN ARDENNES CS',
    );
    final team2Ctrl = TextEditingController(text: next?.team2 ?? '');

    final ok = await adminShowFormDialog(context, 'DÉMARRER UN MATCH', [
      if (suggested.message != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: adminBlue.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBlue.withAlpha(70)),
          ),
          child: Text(
            suggested.message!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
              height: 1.45,
            ),
          ),
        ),
      if (suggested.message != null) const SizedBox(height: 10),
      AdminField(ctrl: urlCtrl, label: 'URL YouTube du stream'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: AdminField(ctrl: team1Ctrl, label: 'Domicile'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AdminField(ctrl: team2Ctrl, label: 'Extérieur'),
          ),
        ],
      ),
    ]);

    if (!ok) return;
    setState(() => _loadingLive = true);
    try {
      final nextId = (next?.id ?? '').trim();
      final matchId = nextId.isNotEmpty
          ? nextId
          : 'live_${DateTime.now().millisecondsSinceEpoch}';
      await SeedService.startLive(
        url: urlCtrl.text.isEmpty
            ? 'https://www.youtube.com/@drapeauvertcartonrouge/streams'
            : urlCtrl.text,
        team1: team1Ctrl.text,
        team2: team2Ctrl.text,
        matchId: matchId,
        logo1: next?.logo1,
        logo2: next?.logo2,
      );
      await _createLiveSalon(
          matchId, '🔴 Live — ${team1Ctrl.text} vs ${team2Ctrl.text}');
    } finally {
      setState(() => _loadingLive = false);
    }
  }

  Future<void> _createLiveSalon(String matchId, String name) async {
    final db = FirebaseFirestore.instance;
    // Archive any existing live salon
    final existing = await db
        .collection('chat_salons')
        .where('isLive', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.update({
        'archived': true,
        'isLive': false,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
    // Create the new live salon
    await db.collection('chat_salons').doc('live_$matchId').set({
      'name': name,
      'isLive': true,
      'archived': false,
      'matchId': matchId,
      'order': -1,
      'createdAt': FieldValue.serverTimestamp(),
      'archivedAt': null,
    });
  }

  Future<void> _archiveLiveSalon() async {
    final db = FirebaseFirestore.instance;
    final existing = await db
        .collection('chat_salons')
        .where('isLive', isEqualTo: true)
        .where('archived', isEqualTo: false)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.update({
        'archived': true,
        'isLive': false,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  bool _isSedanMatch(MatchModel match) {
    final team1 = match.team1.toUpperCase();
    final team2 = match.team2.toUpperCase();
    return team1.contains('SEDAN') ||
        team2.contains('SEDAN') ||
        team1.contains('CS SEDAN') ||
        team2.contains('CS SEDAN') ||
        team1.contains('ARDENNES') ||
        team2.contains('ARDENNES');
  }

  _AdminSuggestedMatch _pickSuggestedAdminMatch({
    required List<MatchModel> upcomingMatches,
    required List<MatchModel> recentResults,
  }) {
    final now = DateTime.now();
    final recent = recentResults.isNotEmpty ? recentResults.first : null;

    if (recent != null) {
      final switchAt = recent.date
          .add(_matchDurationFallback)
          .add(_nextMatchDelayAfterEnd);
      if (now.isBefore(switchAt)) {
        final remaining = switchAt.difference(now);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final timerLabel = hours > 0
            ? '${hours}h${minutes.toString().padLeft(2, '0')}'
            : '${minutes} min';
        return _AdminSuggestedMatch(
          match: recent,
          message:
              'Tu restes sur le dernier match pour les stats live. '
              'Le prochain match sera propose automatiquement dans $timerLabel.',
        );
      }
    }

    final next = upcomingMatches.isNotEmpty ? upcomingMatches.first : null;
    return _AdminSuggestedMatch(
      match: next,
      message: next != null
          ? 'Le delai post-match est passe, tu peux maintenant basculer sur le prochain match.'
          : null,
    );
  }

  Future<void> _handleEmission(bool isLive) async {
    if (isLive) {
      final ok = await adminConfirm(context, 'Terminer l\'émission ?');
      if (!ok) return;
      setState(() => _loadingEmission = true);
      try {
        await FirebaseFirestore.instance
            .collection('live')
            .doc('emission')
            .delete();
      } finally {
        setState(() => _loadingEmission = false);
      }
      return;
    }

    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'ÉMISSION DVCR');

    final ok = await adminShowFormDialog(context, 'DÉMARRER UNE ÉMISSION', [
      AdminField(ctrl: titleCtrl, label: 'Titre'),
      const SizedBox(height: 10),
      AdminField(ctrl: urlCtrl, label: 'URL Stream'),
    ]);

    if (!ok) return;
    setState(() => _loadingEmission = true);
    try {
      await FirebaseFirestore.instance.collection('live').doc('emission').set({
        'url': urlCtrl.text,
        'title': titleCtrl.text,
        'viewers': 0,
        'startedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      setState(() => _loadingEmission = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Match suggéré (démarrage live admin)
// ═══════════════════════════════════════════════════════════════════════════════

class _AdminSuggestedMatch {
  final MatchModel? match;
  final String? message;

  const _AdminSuggestedMatch({required this.match, this.message});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCORE PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _ScorePanel extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ScorePanel({required this.data});

  @override
  State<_ScorePanel> createState() => _ScorePanelState();
}

class _ScorePanelState extends State<_ScorePanel> {
  Timer? _chronoTimer;
  int _elapsedSeconds = 0;
  bool _running = false;
  int _lastSavedMinute = -1;

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = ((widget.data['minute'] ?? 0) as int) * 60;
    _lastSavedMinute = _elapsedSeconds ~/ 60;
  }

  @override
  void didUpdateWidget(_ScorePanel old) {
    super.didUpdateWidget(old);
    // Si le doc Firestore change la minute depuis l'extérieur et qu'on ne tourne pas, sync
    final firestoreMinute = ((widget.data['minute'] ?? 0) as int);
    if (!_running && firestoreMinute != _lastSavedMinute) {
      setState(() {
        _elapsedSeconds = firestoreMinute * 60;
        _lastSavedMinute = firestoreMinute;
      });
    }
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    super.dispose();
  }

  void _startChrono() {
    if (_running) return;
    setState(() => _running = true);
    // Efface l'état halftime/fulltime au redémarrage du chrono
    final lastEvent = widget.data['lastEvent'] ?? '';
    if (lastEvent == 'fulltime' || lastEvent == 'halftime') {
      FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .update({'lastEvent': ''});
    }
    SeedService.startChrono(_elapsedSeconds);
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
      final minute = _elapsedSeconds ~/ 60;
      if (minute != _lastSavedMinute) {
        _lastSavedMinute = minute;
        SeedService.updateMinute(minute);
      }
    });
  }

  void _pauseChrono() {
    _chronoTimer?.cancel();
    _chronoTimer = null;
    setState(() => _running = false);
    SeedService.pauseChrono(_elapsedSeconds);
    SeedService.updateMinute(_elapsedSeconds ~/ 60);
  }

  void _resetAndStart(int startMinute) {
    _chronoTimer?.cancel();
    _elapsedSeconds = startMinute * 60;
    _lastSavedMinute = startMinute;
    _running = false;
    SeedService.updateMinute(startMinute);
    // Efface aussi le statut MI-TEMPS / FIN DE MATCH
    FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .update({'lastEvent': ''});
    _startChrono();
  }

  void _editManually() async {
    final controller = TextEditingController(text: '${_elapsedSeconds ~/ 60}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text('Modifier la minute',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: adminTextPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: adminTextPrimary, fontSize: 20),
          decoration: InputDecoration(
            suffixText: "'",
            suffixStyle: const TextStyle(color: adminGreyLight),
            filled: true,
            fillColor: adminBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: adminBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: adminBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGreyLight))),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null) Navigator.pop(ctx, v);
            },
            child: Text('OK', style: GoogleFonts.inter(color: adminGold, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    // Différer le dispose — le dialog anime encore sa sortie et rebuild le TextField
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      setState(() {
        _elapsedSeconds = result * 60;
        _lastSavedMinute = result;
      });
      SeedService.updateMinute(result);
    }
  }

  String get _display {
    final m = _elapsedSeconds ~/ 60;
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final home = (widget.data['scoreHome'] ?? 0) as int;
    final away = (widget.data['scoreAway'] ?? 0) as int;
    final lastEvent = widget.data['lastEvent'] ?? '';
    final isHalftime = lastEvent == 'halftime';
    final isFulltime = lastEvent == 'fulltime';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          Text(
            'SCORE EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: adminGold, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreCtrl(
                team: widget.data['team1'] ?? 'DOM',
                score: home,
                onMinus: home > 0 ? () => SeedService.updateLiveScore(home - 1, away) : null,
                onPlus: () => SeedService.updateLiveScore(home + 1, away),
              ),
              Column(
                children: [
                  Text('VS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22, color: adminGreyLight, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  // Statut MI-TEMPS / FIN
                  if (isFulltime)
                    _StatusChip('FIN', Colors.red)
                  else if (isHalftime)
                    _StatusChip('MI-TEMPS', Colors.orange)
                  else
                    const SizedBox(height: 24),
                ],
              ),
              _ScoreCtrl(
                team: widget.data['team2'] ?? 'EXT',
                score: away,
                onMinus: away > 0 ? () => SeedService.updateLiveScore(home, away - 1) : null,
                onPlus: () => SeedService.updateLiveScore(home, away + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: adminBorder),
          const SizedBox(height: 14),

          // ── CHRONO ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play / Pause
              GestureDetector(
                onTap: _running ? _pauseChrono : _startChrono,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _running ? adminGold.withAlpha(30) : adminGold,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: _running ? adminGold : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Affichage chrono (tap = édition manuelle)
              GestureDetector(
                onTap: _editManually,
                child: Column(
                  children: [
                    Text(
                      _display,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: _running ? adminTextPrimary : adminGreyLight),
                    ),
                    Text(
                      'appuyer pour éditer',
                      style: GoogleFonts.inter(fontSize: 7, color: adminGreyLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── RACCOURCIS ───────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallBtn(label: '0', onTap: () => _resetAndStart(0)),
              const SizedBox(width: 6),
              _SmallBtn(label: '45', onTap: () => _resetAndStart(45)),
              const SizedBox(width: 12),
              // MI-TEMPS
              GestureDetector(
                onTap: () async {
                  _pauseChrono();
                  if (isHalftime) {
                    await FirebaseFirestore.instance
                        .collection('live').doc('current')
                        .update({'lastEvent': ''});
                  } else {
                    await SeedService.notifyHalftime();
                    setState(() => _elapsedSeconds = 45 * 60);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHalftime ? Colors.orange.withAlpha(30) : Colors.transparent,
                    border: Border.all(color: Colors.orange.withAlpha(isHalftime ? 200 : 100)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('MI-TEMPS',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.orange, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 6),
              // FIN DE MATCH
              GestureDetector(
                onTap: () async {
                  _pauseChrono();
                  await SeedService.notifyFulltime(_elapsedSeconds ~/ 60);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFulltime ? Colors.red.withAlpha(30) : Colors.transparent,
                    border: Border.all(color: Colors.red.withAlpha(isFulltime ? 200 : 100)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('FIN',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.red, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Text(label, style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _ScoreCtrl extends StatelessWidget {
  final String team;
  final int score;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const _ScoreCtrl({
    required this.team,
    required this.score,
    this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          team.length > 8 ? '${team.substring(0, 8)}…' : team,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: adminGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            GestureDetector(
              onTap: onMinus,
              child: Icon(
                Icons.remove_circle_rounded,
                color: onMinus != null ? adminGreyLight : adminBorder,
                size: 28,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$score',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  height: 1,
                ),
              ),
            ),
            GestureDetector(
              onTap: onPlus,
              child: const Icon(
                Icons.add_circle_rounded,
                color: adminGold,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip équipe (bottom sheet buts / cartons) — largeur bornée + ellipse.
class _AdminTeamPickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdminTeamPickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? adminGold.withAlpha(30) : Colors.transparent,
          border: Border.all(color: selected ? adminGold : adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? adminGold : adminGrey,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL FEED
// ═══════════════════════════════════════════════════════════════════════════════

class _GoalFeed extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GoalFeed({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawEvents = data['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map<String, dynamic>>()
              .where((e) => const {'goal', 'yellow', 'red'}.contains(e['type']))
              .toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.flag_rounded, color: adminGold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FAITS DE JEU',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: adminGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () => _showAddEvent(context, 'goal'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminGold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ BUT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddEvent(context, 'yellow'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ JAUNE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddEvent(context, 'red'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ ROUGE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminTextPrimary,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => SeedService.clearLiveFacts(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminBg,
                    border: Border.all(color: adminBorder),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'VIDER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (events.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aucun fait de jeu',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ...events.reversed
                .map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _eventColor(
                              (g['type'] ?? '').toString(),
                            ).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              "${g['minute'] ?? '?'}'",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _eventColor(
                                  (g['type'] ?? '').toString(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            _eventIcon((g['type'] ?? '').toString()),
                            size: 15,
                            color: _eventColor((g['type'] ?? '').toString()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g['player'] ?? 'Inconnu',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: adminTextPrimary,
                                ),
                              ),
                              Text(
                                '${g['team'] ?? ''} • ${_eventLabel((g['type'] ?? '').toString())}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await SeedService.removeMatchEvent(g);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: adminRed.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: adminRed,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  int _currentChronoMinute() {
    final base = (data['chronoBaseSeconds'] as int?) ?? 0;
    final startedAtMs = (data['chronoStartedAtMs'] as int?) ?? 0;
    final running = (data['chronoRunning'] as bool?) ?? false;
    if (running && startedAtMs > 0) {
      final elapsed = base +
          (DateTime.now().millisecondsSinceEpoch - startedAtMs) ~/ 1000;
      return elapsed ~/ 60;
    }
    return base ~/ 60;
  }

  void _showAddEvent(BuildContext context, String type) {
    final playerCtrl = TextEditingController();
    final currentMin = _currentChronoMinute();
    final minuteCtrl = TextEditingController(
      text: currentMin > 0 ? '$currentMin' : '',
    );
    String team = data['team1'] ?? 'DOM';
    final title = switch (type) {
      'yellow' => 'AJOUTER UN CARTON JAUNE',
      'red' => 'AJOUTER UN CARTON ROUGE',
      _ => 'AJOUTER UN BUT',
    };
    final playerLabel = type == 'goal' ? 'Buteur' : 'Joueur';

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              adminBottomSheetHandle(),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminGold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AdminTeamPickChip(
                      label: '${data['team1'] ?? 'DOM'}',
                      selected: team == (data['team1'] ?? 'DOM'),
                      onTap: () =>
                          setSt(() => team = data['team1'] ?? 'DOM'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminTeamPickChip(
                      label: '${data['team2'] ?? 'EXT'}',
                      selected: team == (data['team2'] ?? 'EXT'),
                      onTap: () =>
                          setSt(() => team = data['team2'] ?? 'EXT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AdminField(ctrl: playerCtrl, label: playerLabel),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: AdminField(
                      ctrl: minuteCtrl,
                      label: "Min' (chrono)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final min = int.tryParse(minuteCtrl.text) ?? 0;
                  await SeedService.addMatchEvent(
                    type: type,
                    team: team,
                    player: playerCtrl.text.trim().isEmpty
                        ? 'Inconnu'
                        : playerCtrl.text.trim(),
                    minute: min,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: adminGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'VALIDER',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'yellow':
      case 'red':
        return Icons.crop_portrait_rounded;
      default:
        return Icons.sports_soccer_rounded;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'yellow':
        return Colors.amber;
      case 'red':
        return adminRed;
      default:
        return adminGold;
    }
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'yellow':
        return 'Carton jaune';
      case 'red':
        return 'Carton rouge';
      default:
        return 'But';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMISSION POLL PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _EmissionPollPanel extends StatelessWidget {
  final bool emissionLive;
  final Map<String, dynamic>? data;

  const _EmissionPollPanel({required this.emissionLive, required this.data});

  Future<void> _showQuickEditSheet(BuildContext context) async {
    final pollData = data ?? const <String, dynamic>{};
    final titleCtrl = TextEditingController(
      text: (pollData['pollTitle'] as String? ?? '').trim(),
    );
    final subtitleCtrl = TextEditingController(
      text: (pollData['pollSubtitle'] as String? ?? '').trim(),
    );
    final sponsorCtrl = TextEditingController(
      text: (pollData['pollSponsorName'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (pollData['pollBackgroundImage'] as String? ?? '').trim(),
    );
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  adminBottomSheetHandle(),
                  Text(
                    'VISUEL DU SONDAGE',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminGold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu peux changer le titre, le sous-titre et l image sans relancer le sondage.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  ),
                  const SizedBox(height: 14),
                  AdminField(ctrl: titleCtrl, label: 'Titre du sondage'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: subtitleCtrl, label: 'Sous-titre'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: backgroundCtrl,
                    label: 'Image de fond (URL, optionnel)',
                  ),
                  if (backgroundCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: Image.network(
                          backgroundCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: adminBg,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: adminGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: saving ? null : () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: adminBorder),
                            ),
                            child: Center(
                              child: Text(
                                'ANNULER',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: adminGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('live')
                                        .doc('emission')
                                        .set({
                                          'pollTitle': titleCtrl.text.trim(),
                                          'pollSubtitle': subtitleCtrl.text
                                              .trim(),
                                          'pollSponsorName': sponsorCtrl.text
                                              .trim(),
                                          'pollBackgroundImage': backgroundCtrl
                                              .text
                                              .trim(),
                                        }, SetOptions(merge: true));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Visuel du sondage mis a jour.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => saving = false);
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminGold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      'ENREGISTRER',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    titleCtrl.dispose();
    subtitleCtrl.dispose();
    sponsorCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pollData = data ?? const <String, dynamic>{};
    final status = (pollData['pollStatus'] as String? ?? '').trim();
    final active = EmissionPollService.isPollActive(pollData);
    final options = EmissionPollService.optionMaps(pollData);
    final counts = EmissionPollService.optionCounts(pollData);
    final totalVotes = EmissionPollService.totalVotes(pollData);
    final title = (pollData['pollTitle'] as String? ?? '').trim();
    final subtitle = (pollData['pollSubtitle'] as String? ?? '').trim();
    final winnerLabel = (pollData['pollWinnerLabel'] as String? ?? '').trim();
    final sponsorName = (pollData['pollSponsorName'] as String? ?? '').trim();

    if (active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        EmissionPollService.ensurePollState(pollData);
      });
    }

    final rankedOptions = [...options]
      ..sort((a, b) {
        final aVotes = counts[(a['id'] as String? ?? '').trim()] ?? 0;
        final bVotes = counts[(b['id'] as String? ?? '').trim()] ?? 0;
        return bVotes.compareTo(aVotes);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.poll_rounded, color: adminGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SONDAGE ÉMISSION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: adminGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? adminRed.withAlpha(20)
                      : status == 'closed'
                      ? adminGold.withAlpha(20)
                      : adminBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? adminRed.withAlpha(90)
                        : status == 'closed'
                        ? adminGold.withAlpha(90)
                        : adminBorder,
                  ),
                ),
                child: Text(
                  active
                      ? 'ACTIF'
                      : status == 'closed'
                      ? 'CLOS'
                      : 'INACTIF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? adminRed
                        : status == 'closed'
                        ? adminGold
                        : adminGrey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showQuickEditSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 12,
                        color: adminGold,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'VISUEL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!emissionLive)
            Text(
              'Démarre d\'abord l\'émission avant de lancer un sondage.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else if (options.isEmpty)
            Text(
              'Prépare ton titre, tes choix et la durée. Le public votera sans voir les résultats pendant le direct.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else ...[
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
            ],
            if (sponsorName.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MiniInfoPill(icon: Icons.campaign_rounded, label: sponsorName),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _VoteMetaColumnV2(
                      label: 'CHOIX',
                      value: '${options.length}',
                    ),
                  ),
                  Expanded(
                    child: _VoteMetaColumnV2(
                      label: 'VOTES',
                      value: '$totalVotes',
                    ),
                  ),
                  Expanded(
                    child: _VoteMetaColumnV2(
                      label: active ? 'TEMPS RESTANT' : 'STATUT',
                      value: active ? _remainingLabel(pollData) : 'Clos',
                      accent: active ? adminRed : adminGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rankedOptions.map((option) {
              final optionId = (option['id'] as String? ?? '').trim();
              final label = (option['label'] as String? ?? '').trim();
              final votes = counts[optionId] ?? 0;
              final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
              final isWinner = winnerLabel.isNotEmpty && winnerLabel == label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWinner ? adminGold : adminBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$votes vote${votes > 1 ? 's' : ''} · ${(percent * 100).round()}%',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: adminBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWinner ? adminGold : adminRed.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: !emissionLive || active
                      ? null
                      : () => _showCreatePollSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: !emissionLive || active ? adminBg : adminGold,
                      borderRadius: BorderRadius.circular(10),
                      border: !emissionLive || active
                          ? Border.all(color: adminBorder)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        active ? 'SONDAGE EN COURS' : 'LANCER LE SONDAGE',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: !emissionLive || active
                              ? adminGrey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await EmissionPollService.stopPoll(reason: 'manual');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sondage émission arrêté manuellement.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Center(
                        child: Text(
                          'ARRÊTER',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePollSheet(BuildContext context) async {
    final titleCtrl = TextEditingController(
      text: (data?['pollTitle'] as String? ?? '').trim(),
    );
    final subtitleCtrl = TextEditingController(
      text: (data?['pollSubtitle'] as String? ?? '').trim(),
    );
    final durationCtrl = TextEditingController(text: '10');
    final sponsorCtrl = TextEditingController(
      text: (data?['pollSponsorName'] as String? ?? '').trim(),
    );
    final sponsorLogoCtrl = TextEditingController(
      text: (data?['pollSponsorLogo'] as String? ?? '').trim(),
    );
    final sponsorColorCtrl = TextEditingController(
      text: (data?['pollSponsorColorHex'] as String? ?? '').trim(),
    );
    final sponsorLinkCtrl = TextEditingController(
      text: (data?['pollSponsorLinkUrl'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data?['pollBackgroundImage'] as String? ?? '').trim(),
    );
    final optionCtrls = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];
    var revealResults = data?['pollRevealResults'] != false;
    var selectedSponsorId = (data?['pollSponsorId'] as String? ?? '').trim();
    var saving = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                adminBottomSheetHandle(),
                Text(
                  'CRÉER UN SONDAGE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tu remplis librement le titre, le sous-titre et les choix du direct.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                const SizedBox(height: 14),
                AdminField(ctrl: titleCtrl, label: 'Titre du sondage'),
                const SizedBox(height: 10),
                AdminField(ctrl: subtitleCtrl, label: 'Sous-titre (optionnel)'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: durationCtrl,
                  label: 'Durée en minutes (1 à 30)',
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SponsorService.stream(),
                  builder: (context, sponsorSnap) {
                    final sponsors =
                        sponsorSnap.data ?? const <Map<String, dynamic>>[];
                    final activeSponsors = sponsors
                        .where((item) => item['active'] != false)
                        .toList();
                    if (activeSponsors.isEmpty) return const SizedBox.shrink();
                    final availableIds = activeSponsors
                        .map((item) => (item['id'] as String? ?? '').trim())
                        .where((id) => id.isNotEmpty)
                        .toList();
                    final currentValue =
                        availableIds.contains(selectedSponsorId)
                        ? selectedSponsorId
                        : null;
                    return DropdownButtonFormField<String>(
                      initialValue: currentValue,
                      dropdownColor: adminCard,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: adminTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sponsor enregistré (optionnel)',
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminGrey,
                        ),
                        filled: true,
                        fillColor: adminBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: adminBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: adminBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: adminGold),
                        ),
                      ),
                      items: activeSponsors.map((sponsor) {
                        final id = (sponsor['id'] as String? ?? '').trim();
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            (sponsor['name'] as String? ?? '').trim(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedSponsorId = value ?? '';
                          final selected = activeSponsors.firstWhere(
                            (item) =>
                                (item['id'] as String? ?? '').trim() ==
                                selectedSponsorId,
                            orElse: () => const <String, dynamic>{},
                          );
                          sponsorCtrl.text = (selected['name'] as String? ?? '')
                              .trim();
                          sponsorLogoCtrl.text =
                              (selected['logoUrl'] as String? ?? '').trim();
                          sponsorColorCtrl.text =
                              (selected['colorHex'] as String? ?? '').trim();
                          sponsorLinkCtrl.text =
                              (selected['linkUrl'] as String? ?? '').trim();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: sponsorCtrl,
                  label: 'Nom du sponsor (optionnel)',
                ),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: backgroundCtrl,
                  label: 'Image de fond (URL, optionnel)',
                ),
                if (backgroundCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: Image.network(
                        backgroundCtrl.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: adminBg,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Afficher le résultat final au public',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              revealResults
                                  ? 'Le gagnant sera visible après clôture.'
                                  : 'Le résultat restera visible seulement dans l admin.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: revealResults,
                        onChanged: (value) =>
                            setModalState(() => revealResults = value),
                        activeThumbColor: adminGold,
                        inactiveThumbColor: adminGrey,
                        inactiveTrackColor: adminBorder,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'CHOIX DU SONDAGE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                ...optionCtrls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdminField(
                            ctrl: ctrl,
                            label: 'Choix ${index + 1}',
                          ),
                        ),
                        if (optionCtrls.length > 2) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                optionCtrls[index].dispose();
                                optionCtrls.removeAt(index);
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: adminBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: adminBorder),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: adminGrey,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (optionCtrls.length < 6)
                  GestureDetector(
                    onTap: () => setModalState(() {
                      optionCtrls.add(TextEditingController());
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: adminGold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AJOUTER UN CHOIX',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: adminGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Center(
                            child: Text(
                              'ANNULER',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: adminGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final options = optionCtrls
                                    .map((ctrl) => ctrl.text.trim())
                                    .where((option) => option.isNotEmpty)
                                    .toList();
                                setModalState(() => saving = true);
                                try {
                                  await EmissionPollService.startPoll(
                                    title: titleCtrl.text.trim(),
                                    subtitle: subtitleCtrl.text.trim(),
                                    sponsorId: selectedSponsorId,
                                    sponsorName: sponsorCtrl.text.trim(),
                                    sponsorLogo: sponsorLogoCtrl.text.trim(),
                                    sponsorColorHex: sponsorColorCtrl.text
                                        .trim(),
                                    sponsorLinkUrl: sponsorLinkCtrl.text.trim(),
                                    backgroundImageUrl: backgroundCtrl.text
                                        .trim(),
                                    options: options,
                                    durationMinutes:
                                        int.tryParse(
                                          durationCtrl.text.trim(),
                                        ) ??
                                        10,
                                    revealResults: revealResults,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sondage émission lancé.'),
                                    ),
                                  );
                                } on StateError catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error.message.toString()),
                                    ),
                                  );
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    'LANCER',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    titleCtrl.dispose();
    subtitleCtrl.dispose();
    durationCtrl.dispose();
    sponsorCtrl.dispose();
    sponsorLogoCtrl.dispose();
    sponsorColorCtrl.dispose();
    sponsorLinkCtrl.dispose();
    backgroundCtrl.dispose();
    for (final ctrl in optionCtrls) {
      ctrl.dispose();
    }
  }

  String _remainingLabel(Map<String, dynamic> data) {
    final endsAt = data['pollEndsAt'];
    if (endsAt is! Timestamp) return '10:00';
    final remaining = endsAt.toDate().difference(DateTime.now());
    if (remaining.isNegative) return '00:00';
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOMME DU MATCH VOTE PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _ManOfTheMatchTeamVotePanel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ManOfTheMatchTeamVotePanel({required this.data});

  Future<void> _showQuickEditSheet(BuildContext context) async {
    final titleCtrl = TextEditingController(
      text: (data['motmVoteTitle'] as String? ?? '').trim(),
    );
    final sponsorCtrl = TextEditingController(
      text: (data['motmVoteSponsorName'] as String? ?? '').trim(),
    );
    final sponsorLogoCtrl = TextEditingController(
      text: (data['motmVoteSponsorLogo'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
    );
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  adminBottomSheetHandle(),
                  Text(
                    'VISUEL DU VOTE',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminGold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu peux changer le titre, le sponsor et l\'image de fond sans relancer le vote.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  ),
                  const SizedBox(height: 14),
                  AdminField(ctrl: titleCtrl, label: 'Titre de la carte'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: sponsorLogoCtrl,
                    label: 'Logo sponsor (URL)',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: backgroundCtrl,
                    label: 'Image de fond (URL, optionnel)',
                  ),
                  if (backgroundCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: Image.network(
                          backgroundCtrl.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: adminBg,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: adminGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: saving ? null : () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: adminBorder),
                            ),
                            child: Center(
                              child: Text(
                                'ANNULER',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: adminGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('live')
                                        .doc('current')
                                        .set({
                                          'motmVoteTitle': titleCtrl.text
                                              .trim(),
                                          'motmVoteSponsorName': sponsorCtrl
                                              .text
                                              .trim(),
                                          'motmVoteSponsorLogo': sponsorLogoCtrl
                                              .text
                                              .trim(),
                                          'motmVoteBackgroundImage':
                                              backgroundCtrl.text.trim(),
                                        }, SetOptions(merge: true));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Visuel joueur du match mis a jour.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => saving = false);
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: adminGold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      'ENREGISTRER',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    titleCtrl.dispose();
    sponsorCtrl.dispose();
    sponsorLogoCtrl.dispose();
    backgroundCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['motmVoteStatus'] as String? ?? '').trim();
    final active = MotmVoteService.isVoteActive(data);
    final teams = MotmVoteService.teamMaps(data);
    final counts = MotmVoteService.candidateCounts(data);
    final teamTotals = MotmVoteService.teamVoteTotals(data);
    final totalVotes = MotmVoteService.totalVotes(data);
    final title = (data['motmVoteTitle'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultTitle
        : (data['motmVoteTitle'] as String).trim();
    final sponsorName =
        (data['motmVoteSponsorName'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultSponsorName
        : (data['motmVoteSponsorName'] as String).trim();
    final sponsorLogo =
        (data['motmVoteSponsorLogo'] as String? ?? '').trim().isEmpty
        ? MotmVoteService.defaultSponsorLogo
        : (data['motmVoteSponsorLogo'] as String).trim();
    final team1Default = (data['team1'] as String? ?? 'Équipe 1').trim();
    final team2Default = (data['team2'] as String? ?? 'Equipe 2').trim();
    final revealWinner = MotmVoteService.shouldRevealWinner(data);
    final winnerName = (data['motmVoteWinnerName'] as String? ?? '').trim();
    final winnerTeamName = (data['motmVoteWinnerTeamName'] as String? ?? '')
        .trim();

    if (status == 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MotmVoteService.ensureVoteState(data);
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(
                Icons.emoji_events_rounded,
                color: adminGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'HOMME DU MATCH',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminGold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? adminRed.withAlpha(20)
                      : status == 'closed'
                      ? adminGold.withAlpha(20)
                      : adminBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? adminRed.withAlpha(100)
                        : status == 'closed'
                        ? adminGold.withAlpha(100)
                        : adminBorder,
                  ),
                ),
                child: Text(
                  active
                      ? 'VOTE EN COURS'
                      : status == 'closed'
                      ? 'VOTE CLOS'
                      : 'INACTIF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? adminRed
                        : status == 'closed'
                        ? adminGold
                        : adminGrey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showQuickEditSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 12,
                        color: adminGold,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'VISUEL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (sponsorLogo.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    sponsorLogo,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        size: 18,
                        color: adminGreyLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    Text(
                      'Sponsor : $sponsorName',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: adminBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: adminBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _VoteMetaColumnV2(
                    label: 'Votes',
                    value: '$totalVotes',
                  ),
                ),
                Expanded(
                  child: _VoteMetaColumnV2(
                    label: active ? 'Temps restant' : 'Statut',
                    value: active
                        ? _remainingLabel(data)
                        : (status.isEmpty ? 'Pret' : 'Clos'),
                    accent: active ? adminRed : adminGold,
                  ),
                ),
                Expanded(
                  child: _VoteMetaColumnV2(
                    label: 'Publication',
                    value: revealWinner ? 'Vainqueur public' : 'Votes prives',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (teams.isEmpty)
            Text(
              'Prepare les 2 equipes puis lance le vote. Chaque supporter choisira une equipe, puis un seul joueur.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else
            Column(
              children: teams.map((team) {
                final teamId = (team['id'] as String? ?? '').trim();
                final teamName = (team['name'] as String? ?? '').trim();
                final teamCandidates =
                    MotmVoteService.candidatesForTeam(data, teamId)
                      ..sort((a, b) {
                        final aVotes =
                            counts[(a['id'] as String? ?? '').trim()] ?? 0;
                        final bVotes =
                            counts[(b['id'] as String? ?? '').trim()] ?? 0;
                        return bVotes.compareTo(aVotes);
                      });
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                teamName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: adminTextPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${teamTotals[teamId] ?? 0} vote${(teamTotals[teamId] ?? 0) > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...teamCandidates.map((candidate) {
                          final candidateId = (candidate['id'] as String? ?? '')
                              .trim();
                          final candidateName =
                              (candidate['name'] as String? ?? '').trim();
                          final votes = counts[candidateId] ?? 0;
                          final percent = totalVotes == 0
                              ? 0.0
                              : votes / totalVotes;
                          final isWinner = winnerName == candidateName;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isWinner ? adminGold : adminBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          candidateName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: adminTextPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$votes vote${votes > 1 ? 's' : ''} • ${(percent * 100).round()}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: adminGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 7,
                                      backgroundColor: adminBorder,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isWinner
                                            ? adminGold
                                            : adminRed.withAlpha(180),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 2),
          if (winnerName.isNotEmpty && status == 'closed') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminGold.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adminGold.withAlpha(100)),
              ),
              child: Text(
                revealWinner
                    ? 'Vainqueur public : $winnerName${winnerTeamName.isEmpty ? '' : ' • $winnerTeamName'}'
                    : 'Vainqueur admin : $winnerName${winnerTeamName.isEmpty ? '' : ' • $winnerTeamName'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: active
                      ? null
                      : () => _showStartVoteSheet(
                          context,
                          sponsorName: sponsorName,
                          sponsorLogo: sponsorLogo,
                          team1Name: teams.isNotEmpty
                              ? (teams.first['name'] as String? ?? '').trim()
                              : team1Default,
                          team2Name: teams.length > 1
                              ? (teams[1]['name'] as String? ?? '').trim()
                              : team2Default,
                          team1Players: teams.isNotEmpty
                              ? MotmVoteService.candidatesForTeam(
                                      data,
                                      'team_1',
                                    )
                                    .map(
                                      (c) =>
                                          (c['name'] as String? ?? '').trim(),
                                    )
                                    .toList()
                              : const [],
                          team2Players: teams.length > 1
                              ? MotmVoteService.candidatesForTeam(
                                      data,
                                      'team_2',
                                    )
                                    .map(
                                      (c) =>
                                          (c['name'] as String? ?? '').trim(),
                                    )
                                    .toList()
                              : const [],
                          revealWinner: revealWinner,
                        ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: active ? adminBg : adminGold,
                      borderRadius: BorderRadius.circular(10),
                      border: active ? Border.all(color: adminBorder) : null,
                    ),
                    child: Center(
                      child: Text(
                        active ? 'VOTE EN COURS' : 'LANCER LE VOTE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active ? adminGrey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await MotmVoteService.stopVote(reason: 'manual');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vote homme du match arrete manuellement.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Center(
                        child: Text(
                          'ARRETER',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showStartVoteSheet(
    BuildContext context, {
    required String sponsorName,
    required String sponsorLogo,
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    required bool revealWinner,
  }) async {
    final team1Ctrl = TextEditingController(text: team1Name);
    final team2Ctrl = TextEditingController(text: team2Name);
    final sponsorCtrl = TextEditingController(
      text: sponsorName.isEmpty
          ? MotmVoteService.defaultSponsorName
          : sponsorName,
    );
    final logoCtrl = TextEditingController(
      text: sponsorLogo.isEmpty
          ? MotmVoteService.defaultSponsorLogo
          : sponsorLogo,
    );
    final sponsorColorCtrl = TextEditingController(
      text: (data['motmVoteSponsorColorHex'] as String? ?? '').trim(),
    );
    final sponsorLinkCtrl = TextEditingController(
      text: (data['motmVoteSponsorLinkUrl'] as String? ?? '').trim(),
    );
    final backgroundCtrl = TextEditingController(
      text: (data['motmVoteBackgroundImage'] as String? ?? '').trim(),
    );
    final team1Ctrls = _buildPlayerControllers(team1Players);
    final team2Ctrls = _buildPlayerControllers(team2Players);
    var saving = false;
    var revealWinnerValue = revealWinner;
    var selectedSponsorId = (data['motmVoteSponsorId'] as String? ?? '').trim();

    await showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                adminBottomSheetHandle(),
                Text(
                  'LANCER LE VOTE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Le supporter choisit d\'abord une équipe, puis un seul joueur. Les votes restent invisibles au public.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SponsorService.stream(),
                  builder: (context, sponsorSnap) {
                    final sponsors =
                        sponsorSnap.data ?? const <Map<String, dynamic>>[];
                    final activeSponsors = sponsors
                        .where((item) => item['active'] != false)
                        .toList();
                    if (activeSponsors.isEmpty) return const SizedBox.shrink();
                    final availableIds = activeSponsors
                        .map((item) => (item['id'] as String? ?? '').trim())
                        .where((id) => id.isNotEmpty)
                        .toList();
                    final currentValue =
                        availableIds.contains(selectedSponsorId)
                        ? selectedSponsorId
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: currentValue,
                        dropdownColor: adminCard,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: adminTextPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Sponsor enregistré (optionnel)',
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                          ),
                          filled: true,
                          fillColor: adminBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: adminGold),
                          ),
                        ),
                        items: activeSponsors.map((sponsor) {
                          final id = (sponsor['id'] as String? ?? '').trim();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              (sponsor['name'] as String? ?? '').trim(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedSponsorId = value ?? '';
                            final selected = activeSponsors.firstWhere(
                              (item) =>
                                  (item['id'] as String? ?? '').trim() ==
                                  selectedSponsorId,
                              orElse: () => const <String, dynamic>{},
                            );
                            sponsorCtrl.text =
                                (selected['name'] as String? ?? '').trim();
                            logoCtrl.text =
                                (selected['logoUrl'] as String? ?? '').trim();
                            sponsorColorCtrl.text =
                                (selected['colorHex'] as String? ?? '').trim();
                            sponsorLinkCtrl.text =
                                (selected['linkUrl'] as String? ?? '').trim();
                          });
                        },
                      ),
                    );
                  },
                ),
                AdminField(ctrl: sponsorCtrl, label: 'Nom du sponsor'),
                const SizedBox(height: 10),
                AdminField(ctrl: logoCtrl, label: 'Logo sponsor (URL)'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: backgroundCtrl,
                  label: 'Image de fond (URL, optionnel)',
                ),
                if (backgroundCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: Image.network(
                        backgroundCtrl.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: adminBg,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: adminGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Publier le vainqueur au public',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              revealWinnerValue
                                  ? 'Le gagnant sera affiche a la cloture.'
                                  : 'Le resultat restera visible seulement dans l admin.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: revealWinnerValue,
                        onChanged: (value) =>
                            setModalState(() => revealWinnerValue = value),
                        activeThumbColor: adminGold,
                        inactiveThumbColor: adminGrey,
                        inactiveTrackColor: adminBorder,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _TeamEditorBlock(
                  title: 'EQUIPE 1',
                  teamCtrl: team1Ctrl,
                  playerCtrls: team1Ctrls,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _TeamEditorBlock(
                  title: 'EQUIPE 2',
                  teamCtrl: team2Ctrl,
                  playerCtrls: team2Ctrls,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: adminBorder),
                          ),
                          child: Center(
                            child: Text(
                              'ANNULER',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: adminGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final players1 = _readPlayers(team1Ctrls);
                                final players2 = _readPlayers(team2Ctrls);
                                if (players1.isEmpty || players2.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Ajoute au moins un joueur dans chaque equipe.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => saving = true);
                                try {
                                  await MotmVoteService.startVote(
                                    team1Name: team1Ctrl.text.trim(),
                                    team2Name: team2Ctrl.text.trim(),
                                    team1Players: players1,
                                    team2Players: players2,
                                    sponsorId: selectedSponsorId,
                                    sponsorName: sponsorCtrl.text.trim(),
                                    sponsorLogo: logoCtrl.text.trim(),
                                    sponsorColorHex: sponsorColorCtrl.text
                                        .trim(),
                                    sponsorLinkUrl: sponsorLinkCtrl.text.trim(),
                                    backgroundImageUrl: backgroundCtrl.text
                                        .trim(),
                                    revealWinner: revealWinnerValue,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vote homme du match lance pour 10 minutes.',
                                      ),
                                    ),
                                  );
                                } on StateError catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error.message.toString()),
                                    ),
                                  );
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: adminGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    'LANCER',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    team1Ctrl.dispose();
    team2Ctrl.dispose();
    sponsorCtrl.dispose();
    logoCtrl.dispose();
    sponsorColorCtrl.dispose();
    sponsorLinkCtrl.dispose();
    backgroundCtrl.dispose();
    for (final ctrl in [...team1Ctrls, ...team2Ctrls]) {
      ctrl.dispose();
    }
  }

  List<TextEditingController> _buildPlayerControllers(List<String> players) {
    final values = players.isEmpty ? <String>['', ''] : [...players, ''];
    return values
        .take(20)
        .map((player) => TextEditingController(text: player))
        .toList();
  }

  List<String> _readPlayers(List<TextEditingController> ctrls) {
    return ctrls
        .map((ctrl) => ctrl.text.trim())
        .where((player) => player.isNotEmpty)
        .toSet()
        .toList();
  }

  String _remainingLabel(Map<String, dynamic> data) {
    final endsAt = data['motmVoteEndsAt'];
    if (endsAt is! Timestamp) return '10:00';
    final remaining = endsAt.toDate().difference(DateTime.now());
    if (remaining.isNegative) return '00:00';
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM EDITOR BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

class _TeamEditorBlock extends StatelessWidget {
  final String title;
  final TextEditingController teamCtrl;
  final List<TextEditingController> playerCtrls;
  final VoidCallback onChanged;

  const _TeamEditorBlock({
    required this.title,
    required this.teamCtrl,
    required this.playerCtrls,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          AdminField(ctrl: teamCtrl, label: 'Nom de l equipe'),
          const SizedBox(height: 10),
          ...playerCtrls.asMap().entries.map((entry) {
            final index = entry.key;
            final ctrl = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: AdminField(ctrl: ctrl, label: 'Joueur ${index + 1}'),
                  ),
                  if (playerCtrls.length > 2) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        playerCtrls[index].dispose();
                        playerCtrls.removeAt(index);
                        onChanged();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: adminBorder),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: adminGrey,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (playerCtrls.length < 20)
            GestureDetector(
              onTap: () {
                playerCtrls.add(TextEditingController());
                onChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: adminGold),
                    const SizedBox(width: 6),
                    Text(
                      'AJOUTER UN JOUEUR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS LIVE — MODE FOCUS (plein écran, sans barre admin / onglets)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatsLiveFocusRoute extends StatelessWidget {
  final VoidCallback onClose;

  const _StatsLiveFocusRoute({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (context, snap) {
            // Ne jamais fermer pendant l’attente du 1er snapshot : `hasData` est
            // faux au chargement, ce qui fermait la route instantanément (bug).
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: adminGold),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible de charger le live.\nFerme avec × et réessaie.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: adminGrey,
                    ),
                  ),
                ),
              );
            }
            final doc = snap.data;
            if (doc == null || !doc.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onClose();
              });
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Plus de match en direct — fermeture…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: adminGrey,
                    ),
                  ),
                ),
              );
            }
            final data = Map<String, dynamic>.from(
              doc.data() as Map? ?? const <String, dynamic>{},
            );
            final statsEnabled = (data['statsEnabled'] as bool?) ?? false;
            if (!statsEnabled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onClose();
              });
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Stats en direct désactivées — fermeture…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: adminGrey,
                    ),
                  ),
                ),
              );
            }
            final t1 = (data['team1'] as String? ?? '').trim();
            final t2 = (data['team2'] as String? ?? '').trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Quitter le mode focus',
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: adminTextPrimary,
                          size: 26,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MODE FOCUS — STATS LIVE',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: adminTextPrimary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t1.isEmpty && t2.isEmpty
                                    ? 'Match en cours'
                                    : '$t1  ·  $t2',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: adminGrey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: _LiveStatsPanel(data: data),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE STATS PANEL
// ═══════════════════════════════════════════════════════════════════════════════

class _LiveStatsPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  const _LiveStatsPanel({required this.data});
  @override
  State<_LiveStatsPanel> createState() => _LiveStatsPanelState();
}

class _LiveStatsPanelState extends State<_LiveStatsPanel> {
  bool _showStats = false;
  Map<String, dynamic>? _undo;
  final FocusNode _shortcutFocusNode = FocusNode();
  late Map<String, LogicalKeyboardKey> _keyBindings = _defaultBindings();
  String? _remappingAction;
  Timer? _possessionTicker;
  int _possessionMillis1 = 0, _possessionMillis2 = 0;
  int? _activePossessionTeam;
  int _pendingPossessionSaveMs = 0;

  int _shots1 = 0, _shots2 = 0;
  int _onTarget1 = 0, _onTarget2 = 0;
  int _blocked1 = 0, _blocked2 = 0;
  int _poteau1 = 0, _poteau2 = 0;
  double _xg1 = 0, _xg2 = 0;
  int _passAcc1 = 0, _passAcc2 = 0;
  int _passInacc1 = 0, _passInacc2 = 0;
  int _keyPass1 = 0, _keyPass2 = 0;
  int _crossAcc1 = 0, _crossAcc2 = 0;
  int _crossInacc1 = 0, _crossInacc2 = 0;
  int _tackleWon1 = 0, _tackleWon2 = 0;
  int _tackleLost1 = 0, _tackleLost2 = 0;
  int _duelWon1 = 0, _duelWon2 = 0;
  int _aerialWon1 = 0, _aerialWon2 = 0;
  int _corners1 = 0, _corners2 = 0;
  int _offsides1 = 0, _offsides2 = 0;
  int _fouls1 = 0, _fouls2 = 0;
  int _saves1 = 0, _saves2 = 0;

  @override
  void initState() {
    super.initState();
    _loadFromData(widget.data['stats']);
    _loadBindings();
  }

  @override
  void dispose() {
    _possessionTicker?.cancel();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveStatsPanel old) {
    super.didUpdateWidget(old);
    final oldJson = jsonEncode(old.data['stats'] ?? {});
    final newJson = jsonEncode(widget.data['stats'] ?? {});
    if (oldJson != newJson) {
      _loadFromData(widget.data['stats']);
    }
  }

  void _loadFromData(dynamic raw) {
    if (raw is! Map<String, dynamic>) return;
    final s = raw;
    setState(() {
      _shots1 = _gi(s['tirs1'] ?? s['shots1']);
      _shots2 = _gi(s['tirs2'] ?? s['shots2']);
      _onTarget1 = _gi(s['tirsCadres1'] ?? s['onTarget1']);
      _onTarget2 = _gi(s['tirsCadres2'] ?? s['onTarget2']);
      _blocked1 = _gi(s['blocked1']);
      _blocked2 = _gi(s['blocked2']);
      _poteau1 = _gi(s['poteau1']);
      _poteau2 = _gi(s['poteau2']);
      _xg1 = (s['xg1'] is num) ? (s['xg1'] as num).toDouble() : 0;
      _xg2 = (s['xg2'] is num) ? (s['xg2'] as num).toDouble() : 0;
      _passAcc1 = _gi(s['passes1'] ?? s['passAcc1']);
      _passAcc2 = _gi(s['passes2'] ?? s['passAcc2']);
      _passInacc1 = _gi(s['passInacc1']);
      _passInacc2 = _gi(s['passInacc2']);
      _keyPass1 = _gi(s['keyPass1']);
      _keyPass2 = _gi(s['keyPass2']);
      _crossAcc1 = _gi(s['crossAcc1']);
      _crossAcc2 = _gi(s['crossAcc2']);
      _crossInacc1 = _gi(s['crossInacc1']);
      _crossInacc2 = _gi(s['crossInacc2']);
      _tackleWon1 = _gi(s['tackleWon1']);
      _tackleWon2 = _gi(s['tackleWon2']);
      _tackleLost1 = _gi(s['tackleLost1']);
      _tackleLost2 = _gi(s['tackleLost2']);
      _duelWon1 = _gi(s['duelWon1']);
      _duelWon2 = _gi(s['duelWon2']);
      _aerialWon1 = _gi(s['aerialWon1']);
      _aerialWon2 = _gi(s['aerialWon2']);
      _corners1 = _gi(s['corners1']);
      _corners2 = _gi(s['corners2']);
      _offsides1 = _gi(s['horsJeu1'] ?? s['offsides1']);
      _offsides2 = _gi(s['horsJeu2'] ?? s['offsides2']);
      _fouls1 = _gi(s['fautes1'] ?? s['fouls1']);
      _fouls2 = _gi(s['fautes2'] ?? s['fouls2']);
      _saves1 = _gi(s['arretsGardien1'] ?? s['saves1']);
      _saves2 = _gi(s['arretsGardien2'] ?? s['saves2']);
      _possessionMillis1 = _gi(s['possessionMs1']);
      _possessionMillis2 = _gi(s['possessionMs2']);
      _activePossessionTeam = switch (s['possessionActiveTeam']) {
        1 => 1,
        2 => 2,
        _ => null,
      };
    });
    _syncPossessionTicker();
  }

  int _gi(dynamic v) => (v is num) ? v.toInt() : 0;

  String get _t1 => (widget.data['team1'] as String? ?? 'DOM').trim();
  String get _t2 => (widget.data['team2'] as String? ?? 'EXT').trim();

  int get _poss1 {
    final total = _possessionMillis1 + _possessionMillis2;
    if (total == 0) return 50;
    return ((_possessionMillis1 / total) * 100).round();
  }

  int get _poss2 => 100 - _poss1;

  Map<String, dynamic> _captureSnapshot() => {
    'shots1': _shots1,
    'shots2': _shots2,
    'onTarget1': _onTarget1,
    'onTarget2': _onTarget2,
    'blocked1': _blocked1,
    'blocked2': _blocked2,
    'poteau1': _poteau1,
    'poteau2': _poteau2,
    'xg1': _xg1,
    'xg2': _xg2,
    'passAcc1': _passAcc1,
    'passAcc2': _passAcc2,
    'passInacc1': _passInacc1,
    'passInacc2': _passInacc2,
    'keyPass1': _keyPass1,
    'keyPass2': _keyPass2,
    'crossAcc1': _crossAcc1,
    'crossAcc2': _crossAcc2,
    'crossInacc1': _crossInacc1,
    'crossInacc2': _crossInacc2,
    'tackleWon1': _tackleWon1,
    'tackleWon2': _tackleWon2,
    'tackleLost1': _tackleLost1,
    'tackleLost2': _tackleLost2,
    'duelWon1': _duelWon1,
    'duelWon2': _duelWon2,
    'aerialWon1': _aerialWon1,
    'aerialWon2': _aerialWon2,
    'corners1': _corners1,
    'corners2': _corners2,
    'offsides1': _offsides1,
    'offsides2': _offsides2,
    'fouls1': _fouls1,
    'fouls2': _fouls2,
    'saves1': _saves1,
    'saves2': _saves2,

    'possessionMillis1': _possessionMillis1,
    'possessionMillis2': _possessionMillis2,
    'activePossessionTeam': _activePossessionTeam,
  };

  void _restoreSnapshot(Map<String, dynamic> s) {
    _shots1 = _gi(s['shots1']);
    _shots2 = _gi(s['shots2']);
    _onTarget1 = _gi(s['onTarget1']);
    _onTarget2 = _gi(s['onTarget2']);
    _blocked1 = _gi(s['blocked1']);
    _blocked2 = _gi(s['blocked2']);
    _poteau1 = _gi(s['poteau1']);
    _poteau2 = _gi(s['poteau2']);
    _xg1 = (s['xg1'] is num) ? (s['xg1'] as num).toDouble() : 0;
    _xg2 = (s['xg2'] is num) ? (s['xg2'] as num).toDouble() : 0;
    _passAcc1 = _gi(s['passAcc1']);
    _passAcc2 = _gi(s['passAcc2']);
    _passInacc1 = _gi(s['passInacc1']);
    _passInacc2 = _gi(s['passInacc2']);
    _keyPass1 = _gi(s['keyPass1']);
    _keyPass2 = _gi(s['keyPass2']);
    _crossAcc1 = _gi(s['crossAcc1']);
    _crossAcc2 = _gi(s['crossAcc2']);
    _crossInacc1 = _gi(s['crossInacc1']);
    _crossInacc2 = _gi(s['crossInacc2']);
    _tackleWon1 = _gi(s['tackleWon1']);
    _tackleWon2 = _gi(s['tackleWon2']);
    _tackleLost1 = _gi(s['tackleLost1']);
    _tackleLost2 = _gi(s['tackleLost2']);
    _duelWon1 = _gi(s['duelWon1']);
    _duelWon2 = _gi(s['duelWon2']);
    _aerialWon1 = _gi(s['aerialWon1']);
    _aerialWon2 = _gi(s['aerialWon2']);
    _corners1 = _gi(s['corners1']);
    _corners2 = _gi(s['corners2']);
    _offsides1 = _gi(s['offsides1']);
    _offsides2 = _gi(s['offsides2']);
    _fouls1 = _gi(s['fouls1']);
    _fouls2 = _gi(s['fouls2']);
    _saves1 = _gi(s['saves1']);
    _saves2 = _gi(s['saves2']);

    _possessionMillis1 = _gi(s['possessionMillis1']);
    _possessionMillis2 = _gi(s['possessionMillis2']);
    _activePossessionTeam = switch (s['activePossessionTeam']) {
      1 => 1,
      2 => 2,
      _ => null,
    };
    _syncPossessionTicker();
  }

  Future<void> _save() async {
    await SeedService.setLiveStats({
      'tirs1': _shots1,
      'tirs2': _shots2,
      'tirsCadres1': _onTarget1,
      'tirsCadres2': _onTarget2,
      'blocked1': _blocked1,
      'blocked2': _blocked2,
      'poteau1': _poteau1,
      'poteau2': _poteau2,
      'passes1': _passAcc1,
      'passes2': _passAcc2,
      'corners1': _corners1,
      'corners2': _corners2,
      'horsJeu1': _offsides1,
      'horsJeu2': _offsides2,
      'fautes1': _fouls1,
      'fautes2': _fouls2,
      'arretsGardien1': _saves1,
      'arretsGardien2': _saves2,
      'possession1': _poss1,
      'possession2': _poss2,
      'passInacc1': _passInacc1,
      'passInacc2': _passInacc2,
      'keyPass1': _keyPass1,
      'keyPass2': _keyPass2,
      'crossAcc1': _crossAcc1,
      'crossAcc2': _crossAcc2,
      'crossInacc1': _crossInacc1,
      'crossInacc2': _crossInacc2,
      'duelWon1': _duelWon1,
      'duelWon2': _duelWon2,
      'possessionMs1': _possessionMillis1,
      'possessionMs2': _possessionMillis2,
      'possessionActiveTeam': _activePossessionTeam,
    });
  }

  void _shot(int team, String outcome) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _shots1++;
        if (outcome == 'cadre') {
          _onTarget1++;
        } else if (outcome == 'blocked') {
          _blocked1++;
        } else if (outcome == 'poteau') {
          _poteau1++;
        }
      } else {
        _shots2++;
        if (outcome == 'cadre') {
          _onTarget2++;
        } else if (outcome == 'blocked') {
          _blocked2++;
        } else if (outcome == 'poteau') {
          _poteau2++;
        }
      }
    });
    _save();
  }

  void _decShot(int team, String outcome) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        final missed = (_shots1 - _onTarget1 - _blocked1 - _poteau1).clamp(0, 999);
        if (outcome == 'cadre' && _onTarget1 > 0) {
          _onTarget1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'blocked' && _blocked1 > 0) {
          _blocked1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'poteau' && _poteau1 > 0) {
          _poteau1--;
          _shots1 = (_shots1 - 1).clamp(0, 999);
        } else if (outcome == 'manque' && missed > 0) {
          _shots1 = (_shots1 - 1).clamp(0, 999);
        }
      } else {
        final missed = (_shots2 - _onTarget2 - _blocked2 - _poteau2).clamp(0, 999);
        if (outcome == 'cadre' && _onTarget2 > 0) {
          _onTarget2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'blocked' && _blocked2 > 0) {
          _blocked2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'poteau' && _poteau2 > 0) {
          _poteau2--;
          _shots2 = (_shots2 - 1).clamp(0, 999);
        } else if (outcome == 'manque' && missed > 0) {
          _shots2 = (_shots2 - 1).clamp(0, 999);
        }
      }
    });
    _save();
  }

  void _duel(int team) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _duelWon1++;
      } else {
        _duelWon2++;
      }
    });
    _save();
  }

  void _decDuel(int team) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        _duelWon1 = (_duelWon1 - 1).clamp(0, 999);
      } else {
        _duelWon2 = (_duelWon2 - 1).clamp(0, 999);
      }
    });
    _save();
  }

  void _pass(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate)
          _passAcc1++;
        else
          _passInacc1++;
      } else {
        if (accurate)
          _passAcc2++;
        else
          _passInacc2++;
      }
    });
    _save();
  }

  void _decPass(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _passAcc1 = (_passAcc1 - 1).clamp(0, 999);
        } else {
          _passInacc1 = (_passInacc1 - 1).clamp(0, 999);
        }
      } else {
        if (accurate) {
          _passAcc2 = (_passAcc2 - 1).clamp(0, 999);
        } else {
          _passInacc2 = (_passInacc2 - 1).clamp(0, 999);
        }
      }
    });
    _save();
  }

  void _cross(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _crossAcc1++;
        } else {
          _crossInacc1++;
        }
      } else {
        if (accurate) {
          _crossAcc2++;
        } else {
          _crossInacc2++;
        }
      }
    });
    _save();
  }

  void _decCross(int team, bool accurate) {
    _undo = _captureSnapshot();
    setState(() {
      if (team == 1) {
        if (accurate) {
          _crossAcc1 = (_crossAcc1 - 1).clamp(0, 999);
        } else {
          _crossInacc1 = (_crossInacc1 - 1).clamp(0, 999);
        }
      } else {
        if (accurate) {
          _crossAcc2 = (_crossAcc2 - 1).clamp(0, 999);
        } else {
          _crossInacc2 = (_crossInacc2 - 1).clamp(0, 999);
        }
      }
    });
    _save();
  }

  void _inc(int team, String stat) {
    _undo = _captureSnapshot();
    setState(() {
      switch (stat) {
        case 'corners':
          if (team == 1)
            _corners1++;
          else
            _corners2++;
          break;
        case 'offsides':
          if (team == 1)
            _offsides1++;
          else
            _offsides2++;
          break;
        case 'fouls':
          if (team == 1)
            _fouls1++;
          else
            _fouls2++;
          break;
        case 'saves':
          if (team == 1)
            _saves1++;
          else
            _saves2++;
          break;
      }
    });
    _save();
  }

  void _dec(int team, String stat) {
    _undo = _captureSnapshot();
    setState(() {
      switch (stat) {
        case 'corners':
          if (team == 1)
            _corners1 = (_corners1 - 1).clamp(0, 999);
          else
            _corners2 = (_corners2 - 1).clamp(0, 999);
          break;
        case 'offsides':
          if (team == 1)
            _offsides1 = (_offsides1 - 1).clamp(0, 999);
          else
            _offsides2 = (_offsides2 - 1).clamp(0, 999);
          break;
        case 'fouls':
          if (team == 1)
            _fouls1 = (_fouls1 - 1).clamp(0, 999);
          else
            _fouls2 = (_fouls2 - 1).clamp(0, 999);
          break;
        case 'saves':
          if (team == 1)
            _saves1 = (_saves1 - 1).clamp(0, 999);
          else
            _saves2 = (_saves2 - 1).clamp(0, 999);
          break;
      }
    });
    _save();
  }

  void _syncPossessionTicker() {
    if (_activePossessionTeam == null) {
      _possessionTicker?.cancel();
      _possessionTicker = null;
      return;
    }
    if (_possessionTicker != null) return;
    _possessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activePossessionTeam == null) return;
      setState(() {
        if (_activePossessionTeam == 1) {
          _possessionMillis1 += 1000;
        } else {
          _possessionMillis2 += 1000;
        }
        _pendingPossessionSaveMs += 1000;
      });
      if (_pendingPossessionSaveMs >= 5000) {
        _pendingPossessionSaveMs = 0;
        _save();
      }
    });
  }

  void _startPossession(int team) {
    _undo = _captureSnapshot();
    setState(() {
      _activePossessionTeam = team;
      _pendingPossessionSaveMs = 0;
    });
    _syncPossessionTicker();
    _save();
  }

  void _stopPossession() {
    _undo = _captureSnapshot();
    setState(() {
      _activePossessionTeam = null;
      _pendingPossessionSaveMs = 0;
    });
    _syncPossessionTicker();
    _save();
  }

  String _formatPossessionTimer(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static const _kBindingsKey = 'liveStats_keyBindings_v2';

  static Map<String, LogicalKeyboardKey> _defaultBindings() => {
    't1_on':       LogicalKeyboardKey.keyA,
    't1_off':      LogicalKeyboardKey.keyZ,
    't1_poteau':   LogicalKeyboardKey.keyS,
    't1_block':    LogicalKeyboardKey.keyE,
    't1_pass_ok':  LogicalKeyboardKey.keyR,
    't1_pass_bad': LogicalKeyboardKey.keyT,
    't1_cross_ok': LogicalKeyboardKey.keyY,
    't1_cross_bad':LogicalKeyboardKey.keyU,
    't1_duel':     LogicalKeyboardKey.keyQ,
    't2_on':       LogicalKeyboardKey.keyJ,
    't2_off':      LogicalKeyboardKey.keyK,
    't2_poteau':   LogicalKeyboardKey.keyH,
    't2_block':    LogicalKeyboardKey.keyL,
    't2_pass_ok':  LogicalKeyboardKey.keyI,
    't2_pass_bad': LogicalKeyboardKey.keyO,
    't2_cross_ok': LogicalKeyboardKey.keyP,
    't2_cross_bad':LogicalKeyboardKey.keyM,
    't2_duel':     LogicalKeyboardKey.keyN,
    'poss1':       LogicalKeyboardKey.digit1,
    'poss2':       LogicalKeyboardKey.digit2,
    'poss_stop':   LogicalKeyboardKey.digit0,
  };

  static const _actionLabels = <String, String>{
    't1_on':       'CADRE — équipe 1',
    't1_off':      'NON CADRE — équipe 1',
    't1_poteau':   'POTEAU — équipe 1',
    't1_block':    'CONTREE — équipe 1',
    't1_pass_ok':  'PASSE RÉUSSIE — équipe 1',
    't1_pass_bad': 'PASSE RATÉE — équipe 1',
    't1_cross_ok': 'CENTRE RÉUSSI — équipe 1',
    't1_cross_bad':'CENTRE RATÉ — équipe 1',
    't1_duel':     'DUEL GAGNÉ — équipe 1',
    't2_on':       'CADRE — équipe 2',
    't2_off':      'NON CADRE — équipe 2',
    't2_poteau':   'POTEAU — équipe 2',
    't2_block':    'CONTREE — équipe 2',
    't2_pass_ok':  'PASSE RÉUSSIE — équipe 2',
    't2_pass_bad': 'PASSE RATÉE — équipe 2',
    't2_cross_ok': 'CENTRE RÉUSSI — équipe 2',
    't2_cross_bad':'CENTRE RATÉ — équipe 2',
    't2_duel':     'DUEL GAGNÉ — équipe 2',
    'poss1':       'POSSESSION — équipe 1',
    'poss2':       'POSSESSION — équipe 2',
    'poss_stop':   'PAUSE possession',
  };

  Future<void> _loadBindings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBindingsKey);
    final defaults = _defaultBindings();
    if (saved != null) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        final loaded = <String, LogicalKeyboardKey>{};
        for (final e in map.entries) {
          loaded[e.key] = LogicalKeyboardKey(e.value as int);
        }
        // fill missing with defaults
        for (final e in defaults.entries) {
          loaded.putIfAbsent(e.key, () => e.value);
        }
        if (mounted) setState(() => _keyBindings = loaded);
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _keyBindings = defaults);
  }

  Future<void> _saveBindings() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (final e in _keyBindings.entries) e.key: e.value.keyId};
    await prefs.setString(_kBindingsKey, jsonEncode(map));
  }

  String _keyLabel(String action) {
    final key = _keyBindings[action];
    if (key == null) return '?';
    final label = key.keyLabel;
    if (label.length == 1) return label.toUpperCase();
    if (key == LogicalKeyboardKey.digit0) return '0';
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    return label.toUpperCase();
  }

  Widget _buildRemapOverlay() {
    final action = _remappingAction ?? '';
    final label = _actionLabels[action] ?? action;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black.withAlpha(220),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_rounded, color: adminGold, size: 36),
              const SizedBox(height: 12),
              Text(
                'Appuyez sur une touche',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800, color: adminTextPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: adminGold),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() => _remappingAction = null),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGreyLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runShortcut(String action) {
    switch (action) {
      case 't1_on':
        _shot(1, 'cadre');
        break;
      case 't1_off':
        _shot(1, 'manque');
        break;
      case 't1_block':
        _shot(1, 'blocked');
        break;
      case 't1_poteau':
        _shot(1, 'poteau');
        break;
      case 't1_pass_ok':
        _pass(1, true);
        break;
      case 't1_pass_bad':
        _pass(1, false);
        break;
      case 't1_cross_ok':
        _cross(1, true);
        break;
      case 't1_cross_bad':
        _cross(1, false);
        break;
      case 't1_duel':
        _duel(1);
        break;
      case 't2_on':
        _shot(2, 'cadre');
        break;
      case 't2_off':
        _shot(2, 'manque');
        break;
      case 't2_block':
        _shot(2, 'blocked');
        break;
      case 't2_poteau':
        _shot(2, 'poteau');
        break;
      case 't2_pass_ok':
        _pass(2, true);
        break;
      case 't2_pass_bad':
        _pass(2, false);
        break;
      case 't2_cross_ok':
        _cross(2, true);
        break;
      case 't2_cross_bad':
        _cross(2, false);
        break;
      case 't2_duel':
        _duel(2);
        break;
      case 'poss1':
        _startPossession(1);
        break;
      case 'poss2':
        _startPossession(2);
        break;
      case 'poss_stop':
        _stopPossession();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _shortcutFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        // Mode remap : capture la prochaine touche
        if (_remappingAction != null) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _remappingAction = null);
            return KeyEventResult.handled;
          }
          setState(() {
            _keyBindings[_remappingAction!] = event.logicalKey;
            _remappingAction = null;
          });
          _saveBindings();
          return KeyEventResult.handled;
        }
        // Mode normal : déclenche le raccourci associé
        for (final e in _keyBindings.entries) {
          if (e.value == event.logicalKey) {
            _runShortcut(e.key);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            decoration: BoxDecoration(
              color: adminCard,
              border: Border.all(color: adminBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1, color: adminBorder),
                _showStats ? _buildStatsDisplayV2() : _buildActionsZone(),
                _buildResetBar(),
              ],
            ),
          ),
          if (_remappingAction != null) _buildRemapOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, size: 16, color: adminGold),
          const SizedBox(width: 8),
          Text(
            'STATS LIVE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showStats = !_showStats),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showStats ? adminGold.withAlpha(30) : adminBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _showStats ? adminGold : adminBorder),
              ),
              child: Text(
                _showStats ? '⚡ ACTIONS' : '📊 STATS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _showStats ? adminGold : adminGrey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          _buildPossessionPanel(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTeamColV2(1)),
              const SizedBox(width: 8),
              Expanded(child: _buildTeamColV2(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPossessionPanel() {
    final active = _activePossessionTeam;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: adminBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 15, color: adminGold),
              const SizedBox(width: 6),
              Text(
                'POSSESSION',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800, color: adminGold, letterSpacing: 0.5),
              ),
              const Spacer(),
              // Long press → remap poss_stop
              GestureDetector(
                onLongPress: () => setState(() => _remappingAction = 'poss_stop'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: adminBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _keyLabel('poss_stop'),
                    style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: adminGrey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              children: [
                // Équipe 1
                Expanded(
                  child: GestureDetector(
                    onTap: () => _startPossession(1),
                    onLongPress: () => setState(() => _remappingAction = 'poss1'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: active == 1 ? adminGold.withAlpha(30) : adminCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active == 1 ? adminGold : adminBorder,
                          width: active == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (active == 1)
                            const Icon(Icons.circle, size: 8, color: adminGold),
                          Text(
                            _t1.length > 10 ? '${_t1.substring(0, 10)}.' : _t1,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: active == 1 ? adminGold : adminGreyLight),
                          ),
                          Text(
                            _formatPossessionTimer(_possessionMillis1),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: active == 1 ? adminGold : adminGrey),
                          ),
                          Text(
                            '$_poss1%',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18, fontWeight: FontWeight.w900,
                              color: active == 1 ? adminGold : adminGrey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: adminBorder, borderRadius: BorderRadius.circular(3)),
                            child: Text(
                              _keyLabel('poss1'),
                              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: adminGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bouton PAUSE au centre
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _stopPossession,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active == null ? adminGold.withAlpha(22) : adminCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active == null ? adminGold.withAlpha(100) : adminBorder,
                        width: active == null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pause_rounded,
                          size: 18,
                          color: active == null ? adminTextPrimary : adminGreyLight,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PAUSE',
                          style: GoogleFonts.inter(
                            fontSize: 6, fontWeight: FontWeight.w800,
                            color: active == null ? adminTextPrimary : adminGreyLight),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Équipe 2
                Expanded(
                  child: GestureDetector(
                    onTap: () => _startPossession(2),
                    onLongPress: () => setState(() => _remappingAction = 'poss2'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: active == 2 ? adminGold.withAlpha(30) : adminCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active == 2 ? adminGold : adminBorder,
                          width: active == 2 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (active == 2)
                            const Icon(Icons.circle, size: 8, color: adminGold),
                          Text(
                            _t2.length > 10 ? '${_t2.substring(0, 10)}.' : _t2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: active == 2 ? adminGold : adminGreyLight),
                          ),
                          Text(
                            _formatPossessionTimer(_possessionMillis2),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: active == 2 ? adminGold : adminGrey),
                          ),
                          Text(
                            '$_poss2%',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18, fontWeight: FontWeight.w900,
                              color: active == 2 ? adminGold : adminGrey),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: adminBorder, borderRadius: BorderRadius.circular(3)),
                            child: Text(
                              _keyLabel('poss2'),
                              style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800, color: adminGrey),
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
        ],
      ),
    );
  }

  Widget _buildTeamColV2(int team) {
    final name = team == 1 ? _t1 : _t2;
    final shots = team == 1 ? _shots1 : _shots2;
    final target = team == 1 ? _onTarget1 : _onTarget2;
    final blocked = team == 1 ? _blocked1 : _blocked2;
    final passAcc = team == 1 ? _passAcc1 : _passAcc2;
    final passInacc = team == 1 ? _passInacc1 : _passInacc2;
    final crossAcc = team == 1 ? _crossAcc1 : _crossAcc2;
    final crossInacc = team == 1 ? _crossInacc1 : _crossInacc2;
    // ignore: unused_local_variable
    final crossTot = crossAcc + crossInacc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _SectionLabel('TIRS', color: const Color(0xFF4CAF50), icon: Icons.sports_soccer_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CADRE',
          val: target,
          color: const Color(0xFF4CAF50),
          onInc: () => _shot(team, 'cadre'),
          onDec: () => _decShot(team, 'cadre'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_on' : 't2_on'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_on' : 't2_on'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'NON CADRE',
          val: (shots - target - blocked - (team == 1 ? _poteau1 : _poteau2)).clamp(0, 999),
          color: Colors.orange,
          onInc: () => _shot(team, 'manque'),
          onDec: () => _decShot(team, 'manque'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_off' : 't2_off'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_off' : 't2_off'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'POTEAU',
          val: team == 1 ? _poteau1 : _poteau2,
          color: const Color(0xFFD4A017),
          onInc: () => _shot(team, 'poteau'),
          onDec: () => _decShot(team, 'poteau'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_poteau' : 't2_poteau'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_poteau' : 't2_poteau'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CONTREE',
          val: blocked,
          color: adminGreyLight,
          onInc: () => _shot(team, 'blocked'),
          onDec: () => _decShot(team, 'blocked'),
          shortcutLabel: _keyLabel(team == 1 ? 't1_block' : 't2_block'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_block' : 't2_block'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('PASSES', color: const Color(0xFF42A5F5), icon: Icons.swap_horiz_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'REUSSIE',
          val: passAcc,
          color: const Color(0xFF42A5F5),
          onInc: () => _pass(team, true),
          onDec: () => _decPass(team, true),
          shortcutLabel: _keyLabel(team == 1 ? 't1_pass_ok' : 't2_pass_ok'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_pass_ok' : 't2_pass_ok'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'RATEE',
          val: passInacc,
          color: const Color(0xFFEF5350),
          onInc: () => _pass(team, false),
          onDec: () => _decPass(team, false),
          shortcutLabel: _keyLabel(team == 1 ? 't1_pass_bad' : 't2_pass_bad'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_pass_bad' : 't2_pass_bad'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('CENTRES', color: Colors.orange, icon: Icons.open_with_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'REUSSI',
          val: crossAcc,
          color: Colors.orange,
          onInc: () => _cross(team, true),
          onDec: () => _decCross(team, true),
          shortcutLabel: _keyLabel(team == 1 ? 't1_cross_ok' : 't2_cross_ok'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_cross_ok' : 't2_cross_ok'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'RATE',
          val: crossInacc,
          color: const Color(0xFFEF5350),
          onInc: () => _cross(team, false),
          onDec: () => _decCross(team, false),
          shortcutLabel: _keyLabel(team == 1 ? 't1_cross_bad' : 't2_cross_bad'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_cross_bad' : 't2_cross_bad'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('DUELS', color: const Color(0xFF7B68EE), icon: Icons.sports_mma_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'DUEL GAGNE',
          val: team == 1 ? _duelWon1 : _duelWon2,
          color: const Color(0xFF7B68EE),
          onInc: () => _duel(team),
          onDec: () => _decDuel(team),
          shortcutLabel: _keyLabel(team == 1 ? 't1_duel' : 't2_duel'),
          onRemap: () => setState(() => _remappingAction = team == 1 ? 't1_duel' : 't2_duel'),
        ),
        const SizedBox(height: 6),
        _SectionLabel('ÉVÉNEMENTS', color: const Color(0xFFEF5350), icon: Icons.flag_rounded),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'CORNERS',
          val: team == 1 ? _corners1 : _corners2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'corners'),
          onDec: () => _dec(team, 'corners'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'HORS-JEU',
          val: team == 1 ? _offsides1 : _offsides2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'offsides'),
          onDec: () => _dec(team, 'offsides'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'FAUTES',
          val: team == 1 ? _fouls1 : _fouls2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'fouls'),
          onDec: () => _dec(team, 'fouls'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'ARRETS',
          val: team == 1 ? _saves1 : _saves2,
          color: const Color(0xFFEF5350),
          onInc: () => _inc(team, 'saves'),
          onDec: () => _dec(team, 'saves'),
        ),
      ],
    );
  }

  Widget _buildStatsDisplayV2() {
    final tot1 = _passAcc1 + _passInacc1;
    final tot2 = _passAcc2 + _passInacc2;
    final pct1 = tot1 == 0 ? 0.0 : _passAcc1 / tot1;
    final pct2 = tot2 == 0 ? 0.0 : _passAcc2 / tot2;
    final crossTot1 = _crossAcc1 + _crossInacc1;
    final crossTot2 = _crossAcc2 + _crossInacc2;
    final logo1 = (widget.data['logo1'] as String? ?? '').trim();
    final logo2 = (widget.data['logo2'] as String? ?? '').trim();

    Widget sectionHead(String label, Color color, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: color, letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color.withAlpha(50))),
        ],
      ),
    );

    Widget teamLogo(String url, String name, {bool right = false}) {
      final hasLogo = url.isNotEmpty;
      return Column(
        children: [
          if (hasLogo)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(url, width: 32, height: 32, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, size: 28, color: adminGreyLight)),
            )
          else
            const Icon(Icons.shield_rounded, size: 28, color: adminGreyLight),
          const SizedBox(height: 4),
          Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: GoogleFonts.barlowCondensed(
              fontSize: 11, fontWeight: FontWeight.w800, color: adminGrey),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HEADER ÉQUIPES ───────────────────────────────
          Row(
            children: [
              Expanded(child: teamLogo(logo1, _t1)),
              const SizedBox(width: 8),
              Expanded(child: teamLogo(logo2, _t2, right: true)),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: adminBorder),

          // ── POSSESSION ──────────────────────────────────
          sectionHead('POSSESSION', adminGold, Icons.timer_rounded),
          _SBarRow('POSSESSION', _poss1, _poss2, sfx: '%', color: adminGold),
          _SBarRow2(
            'CHRONO',
            _formatPossessionTimer(_possessionMillis1),
            _formatPossessionTimer(_possessionMillis2),
          ),

          // ── TIRS ─────────────────────────────────────────
          sectionHead('TIRS', const Color(0xFF4CAF50), Icons.sports_soccer_rounded),
          _SBarRow('TOTAL', _shots1, _shots2, color: const Color(0xFF4CAF50)),
          _SBarRow('CADRES', _onTarget1, _onTarget2, color: const Color(0xFF4CAF50)),
          _SBarRow('POTEAUX', _poteau1, _poteau2, color: const Color(0xFFD4A017)),
          _SBarRow('CONTREES', _blocked1, _blocked2, color: adminGreyLight),

          // ── PASSES ───────────────────────────────────────
          sectionHead('PASSES', const Color(0xFF42A5F5), Icons.swap_horiz_rounded),
          _SBarRow('REUSSIES', _passAcc1, _passAcc2, color: const Color(0xFF42A5F5)),
          _SBarRow2(
            'PRECISION',
            '${(pct1 * 100).round()}%',
            '${(pct2 * 100).round()}%',
          ),
          _SBarRow('CLES', _keyPass1, _keyPass2, color: const Color(0xFF42A5F5)),

          // ── CENTRES ──────────────────────────────────────
          sectionHead('CENTRES', Colors.orange, Icons.open_with_rounded),
          _SBarRow2(
            'REUSSIS / TOTAL',
            '$_crossAcc1/$crossTot1',
            '$_crossAcc2/$crossTot2',
          ),

          // ── DUELS ────────────────────────────────────────
          sectionHead('DUELS', const Color(0xFF7B68EE), Icons.sports_mma_rounded),
          _SBarRow('GAGNES', _duelWon1, _duelWon2, color: const Color(0xFF7B68EE)),

          // ── EVENEMENTS ───────────────────────────────────
          sectionHead('ÉVÉNEMENTS', const Color(0xFFEF5350), Icons.flag_rounded),
          _SBarRow('CORNERS', _corners1, _corners2, color: const Color(0xFFEF5350)),
          _SBarRow('HORS-JEU', _offsides1, _offsides2, color: const Color(0xFFEF5350)),
          _SBarRow('FAUTES', _fouls1, _fouls2, color: const Color(0xFFEF5350)),
          _SBarRow('ARRÊTS', _saves1, _saves2, color: const Color(0xFFEF5350)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Legacy panel kept temporarily while the new stat cockpit settles.
  // ignore: unused_element
  Widget _buildTeamCol(int team) {
    final name = team == 1 ? _t1 : _t2;
    final shots = team == 1 ? _shots1 : _shots2;
    final target = team == 1 ? _onTarget1 : _onTarget2;
    final blocked = team == 1 ? _blocked1 : _blocked2;
    final passAcc = team == 1 ? _passAcc1 : _passAcc2;
    final passInacc = team == 1 ? _passInacc1 : _passInacc2;
    final passTot = passAcc + passInacc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name.length > 10 ? '${name.substring(0, 10)}.' : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QStat('TIRS', '$shots'),
              _QStat('CADRÉ', '$target'),
              _QStat('CONTRÉ', '$blocked'),
              _QStat('PASSES', passTot == 0 ? '0' : '$passAcc/$passTot'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _SectionLabel('⚽ TIRS'),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: _MiniBtn(
                'CADRÉ',
                const Color(0xFF4CAF50),
                () => _shot(team, 'cadre'),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn(
                'NON CADRÉ',
                Colors.orange,
                () => _shot(team, 'manque'),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn(
                'CONTRÉE',
                adminGreyLight,
                () => _shot(team, 'blocked'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _SectionLabel('🎯 PASSES'),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: _MiniBtn(
                'RÉUSSIE',
                const Color(0xFF4CAF50),
                () => _pass(team, true),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _MiniBtn('RATÉE', adminRed, () => _pass(team, false)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _SectionLabel('💪 DUELS'),
        const SizedBox(height: 3),
        _MiniBtn('DUEL GAGNÉ', const Color(0xFF7B68EE), () => _duel(team)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: adminBg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${team == 1 ? _duelWon1 : _duelWon2}',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                ),
              ),
              Text(
                ' gagnés  /  ${team == 1 ? _duelWon2 : _duelWon1} perdus',
                style: GoogleFonts.inter(fontSize: 8, color: adminGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _CounterRow(
          label: 'CORNERS',
          val: team == 1 ? _corners1 : _corners2,
          onInc: () => _inc(team, 'corners'),
          onDec: () => _dec(team, 'corners'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'HORS-JEU',
          val: team == 1 ? _offsides1 : _offsides2,
          onInc: () => _inc(team, 'offsides'),
          onDec: () => _dec(team, 'offsides'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'FAUTES',
          val: team == 1 ? _fouls1 : _fouls2,
          onInc: () => _inc(team, 'fouls'),
          onDec: () => _dec(team, 'fouls'),
        ),
        const SizedBox(height: 3),
        _CounterRow(
          label: 'ARRÊTS',
          val: team == 1 ? _saves1 : _saves2,
          onInc: () => _inc(team, 'saves'),
          onDec: () => _dec(team, 'saves'),
        ),
      ],
    );
  }

  // Legacy panel kept temporarily while the new stat cockpit settles.
  // ignore: unused_element
  Widget _buildStatsDisplay() {
    final tot1 = _passAcc1 + _passInacc1;
    final tot2 = _passAcc2 + _passInacc2;
    final pct1 = tot1 == 0 ? 0.0 : _passAcc1 / tot1;
    final pct2 = tot2 == 0 ? 0.0 : _passAcc2 / tot2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          _SBarRow('POSSESSION', _poss1, _poss2, sfx: '%'),
          _SBarRow('TIRS', _shots1, _shots2),
          _SBarRow('TIRS CADRÉS', _onTarget1, _onTarget2),
          _SBarRow('TIRS BLOQUÉS', _blocked1, _blocked2),
          _SBarRow2('xG', _xg1.toStringAsFixed(2), _xg2.toStringAsFixed(2)),
          _SBarRow('PASSES RÉUSSIES', _passAcc1, _passAcc2),
          _SBarRow2(
            'PRÉCISION PASSES',
            '${(pct1 * 100).round()}%',
            '${(pct2 * 100).round()}%',
          ),
          _SBarRow('PASSES CLÉS', _keyPass1, _keyPass2),
          _SBarRow('CENTRES RÉUSSIS', _crossAcc1, _crossAcc2),
          _SBarRow('DUELS GAGNÉS', _duelWon1, _duelWon2),
          _SBarRow('CORNERS', _corners1, _corners2),
          _SBarRow('HORS-JEU', _offsides1, _offsides2),
          _SBarRow('FAUTES', _fouls1, _fouls2),
          _SBarRow('ARRÊTS', _saves1, _saves2),
        ],
      ),
    );
  }

  Widget _buildResetBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (_undo != null) ...[
            GestureDetector(
              onTap: () async {
                final snap = _undo;
                if (snap == null) return;
                setState(() {
                  _restoreSnapshot(snap);
                  _undo = null;
                });
                await _save();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.undo_rounded,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ANNULER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: adminCard,
                    title: Text(
                      'Réinitialiser les stats ?',
                      style: GoogleFonts.inter(
                        color: adminTextPrimary,
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text(
                          'RESET',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok != true || !mounted) return;
                setState(() {
                  _shots1 = _shots2 = _onTarget1 = _onTarget2 = _blocked1 =
                      _blocked2 = 0;
                  _xg1 = _xg2 = 0;
                  _passAcc1 = _passAcc2 = _passInacc1 = _passInacc2 = 0;
                  _keyPass1 = _keyPass2 = _crossAcc1 = _crossAcc2 =
                      _crossInacc1 = _crossInacc2 = 0;
                  _tackleWon1 = _tackleWon2 = _tackleLost1 = _tackleLost2 = 0;
                  _duelWon1 = _duelWon2 = _aerialWon1 = _aerialWon2 = 0;
                  _corners1 = _corners2 = _offsides1 = _offsides2 = _fouls1 =
                      _fouls2 = 0;
                  _saves1 = _saves2 = 0;
                  _possessionMillis1 = _possessionMillis2 = 0;
                  _activePossessionTeam = null;
                  _pendingPossessionSaveMs = 0;
                });
                _syncPossessionTicker();
                await _save();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: adminBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Center(
                  child: Text(
                    'RÉINITIALISER STATS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: adminGrey,
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// VOTE META COLUMN
// ═══════════════════════════════════════════════════════════════════════════════

class _VoteMetaColumnV2 extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _VoteMetaColumnV2({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: adminGrey,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent ?? adminTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SMALL HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

class _LiveCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool isActive, loading;
  final VoidCallback onToggle;
  const _LiveCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.loading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? adminRed.withAlpha(120) : adminBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isActive ? adminRed : adminGreen).withAlpha(40),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive ? adminRed : const Color(0xFF4CAF50),
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: adminTextPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
        ),
        trailing: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isActive ? adminRed : adminGold,
                ),
              )
            : GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? adminRed : adminGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'ARRÊTER' : 'DÉMARRER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: adminTextPrimary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: adminBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: adminGrey,
        ),
      ),
    ),
  );
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: adminBorder.withAlpha(45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: adminBorder.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: adminGold),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: adminGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _SectionLabel(this.label, {this.color = adminGrey, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: color.withAlpha(50))),
        ],
      ),
    );
  }
}

class _QStat extends StatelessWidget {
  final String label, value;
  const _QStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            color: adminGrey,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int val;
  final VoidCallback onInc, onDec;
  final String? shortcutLabel; // ex: 'A', '1'
  final VoidCallback? onRemap; // long press → remap
  final Color color;

  const _CounterRow({
    required this.label,
    required this.val,
    required this.onInc,
    required this.onDec,
    this.shortcutLabel,
    this.onRemap,
    this.color = adminGold,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: adminBg,
          border: Border.all(color: adminBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Bouton —
              GestureDetector(
                onTap: onDec,
                child: Container(
                  width: 44,
                  color: adminBorder.withAlpha(55),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove_rounded, size: 18, color: adminGrey),
                ),
              ),
              // Valeur + label (long press → remap)
              Expanded(
                child: GestureDetector(
                  onLongPress: onRemap,
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$val',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: val > 0 ? color : adminTextPrimary,
                              ),
                            ),
                            if (shortcutLabel != null) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: adminBorder,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  shortcutLabel!,
                                  style: GoogleFonts.inter(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: adminGrey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: adminGrey,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
              // Bouton +
              GestureDetector(
                onTap: onInc,
                child: Container(
                  width: 44,
                  color: color.withAlpha(20),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, size: 18, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SBarRow extends StatelessWidget {
  final String label;
  final int v1, v2;
  final String sfx;
  final Color color;
  const _SBarRow(this.label, this.v1, this.v2,
      {this.sfx = '', this.color = adminGold});

  @override
  Widget build(BuildContext context) {
    final total = v1 + v2;
    final frac1 = total == 0 ? 0.5 : v1 / total;
    final bar1 = (frac1 * 100).round().clamp(1, 99);
    final isLeading = v1 >= v2;
    final isTrailing = v2 > v1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$v1$sfx',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isLeading && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: adminGrey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$v2$sfx',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isTrailing && total > 0 ? color : adminTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 3,
              child: Row(
                children: [
                  Expanded(
                    flex: bar1,
                    child: Container(color: color.withAlpha(180)),
                  ),
                  Expanded(
                    flex: 100 - bar1,
                    child: Container(color: color.withAlpha(40)),
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

class _SBarRow2 extends StatelessWidget {
  final String label, v1, v2;
  const _SBarRow2(this.label, this.v1, this.v2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              v1,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
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
                color: adminGrey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              v2,
              textAlign: TextAlign.right,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
