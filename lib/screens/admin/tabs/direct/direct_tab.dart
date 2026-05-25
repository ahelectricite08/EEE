import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/club_branding.dart';
import '../../../../models/match_model.dart';
import '../../../../services/live_match_phase.dart';
import '../../../../services/seed_service.dart';
import '../../../../services/match_controller.dart';
import '../../../../services/emission_poll_service.dart';
import '../../../../services/motm_vote_service.dart';
import '../../../../services/sponsor_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import '../stats/match_stats_workbench_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AdminModuleHeader(
          title: ClubBranding.liveAdminTitle,
          subtitle:
              'Match ${ClubBranding.displayName} : score, chrono, faits de jeu. '
              'Émission DVCR et salon à part.',
          icon: Icons.live_tv_rounded,
          accent: adminRed,
        ),
        const SizedBox(height: 20),
        AdminModuleSection(
          eyebrow: 'Temps réel',
          title: 'Match en direct',
          subtitle:
              'Activer le live, score, buts et homme du match. '
              'Les statistiques se gèrent dans l’onglet Statistiques match. '
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
                    OutlinedButton.icon(
                      onPressed: () {
                        final matchId =
                            (data['matchId'] as String? ?? '').trim();
                        if (matchId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ouvrez Admin → Statistiques match pour saisir les stats.',
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor: adminGold.withAlpha(220),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MatchStatsWorkbenchScreen(
                              matchId: matchId,
                              team1: data['team1']?.toString() ?? '',
                              team2: data['team2']?.toString() ?? '',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.bar_chart_rounded,
                        size: 18,
                        color: adminGold,
                      ),
                      label: Text(
                        'Statistiques match →',
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
      final ok = await adminConfirm(
        context,
        'Arrêter le direct ?\n(Aucune notif — utilise FIN MATCH ou FIN PROLONG. avant.)',
      );
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
      text: next?.team1 ?? ClubBranding.defaultTeamName,
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
    _applyFirestoreChrono(widget.data, force: true);
  }

  void _applyFirestoreChrono(Map<String, dynamic> data, {bool force = false}) {
    final base = (data['chronoBaseSeconds'] as int?) ?? 0;
    final minute = (data['minute'] as int?) ?? 0;
    final target = base > 0 ? base : minute * 60;
    if (force || target != _elapsedSeconds) {
      _elapsedSeconds = target;
      _lastSavedMinute = target ~/ 60;
    }
  }

  LiveMatchPhase get _phase =>
      LiveMatchPhase((widget.data['lastEvent'] ?? '').toString());

  void _runChronoTimer() {
    _chronoTimer?.cancel();
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
      final minute = _elapsedSeconds ~/ 60;
      if (minute != _lastSavedMinute) {
        _lastSavedMinute = minute;
        SeedService.updateMinute(minute);
      }
    });
  }

  @override
  void didUpdateWidget(_ScorePanel old) {
    super.didUpdateWidget(old);
    final remoteRunning = (widget.data['chronoRunning'] as bool?) ?? false;
    final phase = _phase;

    if (_running && (!remoteRunning || phase.chronoLocked)) {
      _chronoTimer?.cancel();
      _chronoTimer = null;
      setState(() {
        _running = false;
        _applyFirestoreChrono(widget.data, force: true);
      });
      return;
    }

    if (!_running && remoteRunning && !phase.chronoLocked) {
      setState(() {
        _running = true;
        _applyFirestoreChrono(widget.data, force: true);
      });
      _runChronoTimer();
      return;
    }

    if (!_running && !remoteRunning) {
      final base = (widget.data['chronoBaseSeconds'] as int?) ?? 0;
      final minute = (widget.data['minute'] as int?) ?? 0;
      final target = base > 0 ? base : minute * 60;
      if (target != _elapsedSeconds) {
        setState(() => _applyFirestoreChrono(widget.data, force: true));
      }
    }
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    super.dispose();
  }

  Future<void> _startChrono() async {
    if (_running) return;
    final phase = _phase;
    if (phase.isMatchEnded) return;

    var startSeconds = _elapsedSeconds;
    if (phase.isHalftime) {
      startSeconds = 46 * 60;
      await SeedService.resumeSecondHalf();
    } else if (phase.isExtraHalftime) {
      startSeconds = 106 * 60;
      await SeedService.resumeExtraSecondHalf();
    }

    setState(() {
      _running = true;
      _elapsedSeconds = startSeconds;
      _lastSavedMinute = startSeconds ~/ 60;
    });

    await SeedService.startChrono(_elapsedSeconds);
    _runChronoTimer();
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
    final phase = _phase;
    final chronoLocked = phase.chronoLocked;

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
              ),
              Column(
                children: [
                  Text('VS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22, color: adminGreyLight, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  // Statut MI-TEMPS / FIN
                  if (phase.isRegularFulltime)
                    _StatusChip('FIN MATCH', Colors.red)
                  else if (phase.isExtraFulltime)
                    _StatusChip('FIN PROLONG.', Colors.red)
                  else if (phase.isHalftime)
                    _StatusChip('MI-TEMPS', Colors.orange)
                  else if (phase.isExtraHalftime)
                    _StatusChip('MT PROLONG.', Colors.orange)
                  else if (phase.isExtraTimePlaying)
                    _StatusChip('PROLONG.', adminPurple)
                  else
                    const SizedBox(height: 24),
                ],
              ),
              _ScoreCtrl(
                team: widget.data['team2'] ?? 'EXT',
                score: away,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Buts : AJOUTER BUT ci-dessous (buteur obligatoire). Correction : BUT ANNULÉ.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 9, color: adminGrey, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: adminBorder),
          const SizedBox(height: 14),

          // ── CHRONO ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play / Pause
              GestureDetector(
                onTap: phase.isMatchEnded
                    ? null
                    : (_running ? _pauseChrono : _startChrono),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: phase.isMatchEnded
                        ? adminBorder.withAlpha(80)
                        : (_running ? adminGold.withAlpha(30) : adminGold),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    phase.isMatchEnded
                        ? Icons.lock_rounded
                        : (_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    size: 24,
                    color: phase.isMatchEnded
                        ? adminGrey
                        : (_running ? adminGold : Colors.black),
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
                        color: chronoLocked
                            ? adminOrange
                            : (_running ? adminTextPrimary : adminGreyLight)),
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _SmallBtn(
                label: '0',
                onTap: phase.isMatchEnded ? () {} : () => _resetAndStart(0),
              ),
              _SmallBtn(
                label: '45',
                onTap: phase.isMatchEnded ? () {} : () => _resetAndStart(45),
              ),
              if (phase.isHalftime)
                _SmallBtn(
                  label: '2e MT',
                  onTap: () async {
                    _pauseChrono();
                    await SeedService.resumeSecondHalf();
                    setState(() {
                      _elapsedSeconds = 46 * 60;
                      _lastSavedMinute = 46;
                    });
                  },
                ),
              if (phase.isExtraHalftime)
                _SmallBtn(
                  label: '2e MT PROL',
                  onTap: () async {
                    _pauseChrono();
                    await SeedService.resumeExtraSecondHalf();
                    setState(() {
                      _elapsedSeconds = 106 * 60;
                      _lastSavedMinute = 106;
                    });
                  },
                ),
              if (phase.canStartProlongation)
                GestureDetector(
                  onTap: () async {
                    await SeedService.startExtraTime();
                    if (!mounted) return;
                    setState(() {
                      _elapsedSeconds = 90 * 60;
                      _lastSavedMinute = 90;
                      _running = true;
                    });
                    _runChronoTimer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: adminPurple.withAlpha(120)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PROLONG.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: adminPurple,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (!phase.isMatchEnded && !phase.isExtraHalftime)
                GestureDetector(
                  onTap: () async {
                    _pauseChrono();
                    if (phase.isHalftime) {
                      await SeedService.clearMatchPhase();
                    } else if (phase.isExtraTimePlaying) {
                      await SeedService.notifyExtraHalftime();
                      setState(() {
                        _elapsedSeconds = 105 * 60;
                        _lastSavedMinute = 105;
                      });
                    } else {
                      await SeedService.notifyHalftime();
                      setState(() {
                        _elapsedSeconds = 45 * 60;
                        _lastSavedMinute = 45;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (phase.isHalftime || phase.isExtraTimePlaying)
                          ? Colors.orange.withAlpha(30)
                          : Colors.transparent,
                      border: Border.all(
                        color: Colors.orange.withAlpha(
                          (phase.isHalftime || phase.isExtraTimePlaying) ? 200 : 100,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      phase.isExtraTimePlaying ? 'MT PROL.' : 'MI-TEMPS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (phase.showFinMatchButton)
                GestureDetector(
                  onTap: () async {
                    _pauseChrono();
                    final min = _elapsedSeconds ~/ 60;
                    await SeedService.notifyFulltime(min);
                    setState(() {
                      _elapsedSeconds = min * 60;
                      _lastSavedMinute = min;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withAlpha(120)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FIN MATCH',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (phase.showFinProlongationButton)
                GestureDetector(
                  onTap: () async {
                    _pauseChrono();
                    final min = _elapsedSeconds ~/ 60;
                    await SeedService.notifyExtraFulltime(min);
                    setState(() {
                      _elapsedSeconds = min * 60;
                      _lastSavedMinute = min;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: phase.isExtraFulltime
                          ? Colors.red.withAlpha(30)
                          : Colors.transparent,
                      border: Border.all(
                        color: Colors.red.withAlpha(phase.isExtraFulltime ? 200 : 120),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FIN PROLONG.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
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
  const _ScoreCtrl({
    required this.team,
    required this.score,
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
        Text(
          '$score',
          style: GoogleFonts.barlowCondensed(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
            height: 1,
          ),
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
              .where(
                (e) => const {
                  'goal',
                  'yellow',
                  'red',
                  'offside',
                  'goal_cancelled',
                  'goal_disallowed',
                }.contains(e['type']),
              )
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
                    'AJOUTER BUT',
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
                onTap: () => _showRevokeGoalPicker(context, 'goal_cancelled'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminBg,
                    border: Border.all(color: adminOrange.withAlpha(160)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BUT ANNULÉ',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminOrange,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showRevokeGoalPicker(context, 'goal_disallowed'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminBg,
                    border: Border.all(color: adminPurple.withAlpha(160)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BUT REFUSÉ',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: adminPurple,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showRevokeGoalPicker(context, 'offside'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: adminBg,
                    border: Border.all(color: const Color(0xFF5C6BC0).withAlpha(160)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HORS-JEU',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF5C6BC0),
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
                        if ((g['type'] ?? '').toString() != 'goal')
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
    final playerLabel = switch (type) {
      'goal' => 'Buteur',
      _ => 'Joueur',
    };

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
                    child: AdminField(
                      ctrl: playerCtrl,
                      label: type == 'goal' ? '$playerLabel *' : playerLabel,
                    ),
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
                  final player = playerCtrl.text.trim();
                  if (type == 'goal' && !SeedService.isGoalScorerValid(player)) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Indique le nom du buteur pour enregistrer le but.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: adminOrange,
                        ),
                      );
                    }
                    return;
                  }
                  try {
                    await SeedService.addMatchEvent(
                      type: type,
                      team: team,
                      player: player,
                      minute: min,
                    );
                  } on StateError catch (e) {
                    if (e.message == 'goal_scorer_required' && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Indique le nom du buteur pour enregistrer le but.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: adminOrange,
                        ),
                      );
                    }
                    return;
                  }
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

  void _showRevokeGoalPicker(BuildContext context, String revokeType) {
    final rawEvents = data['events'];
    final goals = rawEvents is List
        ? rawEvents
            .whereType<Map<String, dynamic>>()
            .where((e) => (e['type'] ?? '').toString() == 'goal')
            .toList()
        : <Map<String, dynamic>>[];

    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aucun but enregistré dans le fil.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminOrange,
        ),
      );
      return;
    }

    final title = switch (revokeType) {
      'goal_disallowed' => 'QUEL BUT EST REFUSÉ ?',
      'offside' => 'QUEL BUT EST HORS-JEU ?',
      _ => 'QUEL BUT EST ANNULÉ ?',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: adminBorder.withAlpha(140)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            adminBottomSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: adminGold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...goals.reversed.map((g) {
              final player = (g['player'] ?? 'Inconnu').toString();
              final team = (g['team'] ?? '').toString();
              final min = g['minute'] ?? '?';
              return ListTile(
                leading: const Icon(Icons.sports_soccer_rounded, color: adminGold),
                title: Text(
                  player,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
                subtitle: Text(
                  '$team • $min\'',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                ),
                onTap: () async {
                  await SeedService.revokeRegisteredGoal(
                    goalEvent: g,
                    revokeType: revokeType,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'yellow':
      case 'red':
        return Icons.crop_portrait_rounded;
      case 'offside':
        return Icons.flag_rounded;
      case 'goal_cancelled':
        return Icons.block_rounded;
      case 'goal_disallowed':
        return Icons.gpp_bad_rounded;
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
      case 'offside':
        return const Color(0xFF5C6BC0);
      case 'goal_cancelled':
        return adminOrange;
      case 'goal_disallowed':
        return adminPurple;
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
      case 'offside':
        return 'Hors-jeu';
      case 'goal_cancelled':
        return 'But annulé';
      case 'goal_disallowed':
        return 'But refusé';
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

