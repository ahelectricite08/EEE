import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/home/home_palette.dart';
import '../services/live_match_phase.dart';
import '../services/seed_service.dart';

/// Panneau profil (admin / CM) : score, chrono, faits de jeu — même logique
/// que l’admin Direct, sans stats live.
class LiveMatchQuickPanel extends StatelessWidget {
  const LiveMatchQuickPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        return _LiveMatchQuickPanelBody(data: d);
      },
    );
  }
}

class _LiveMatchQuickPanelBody extends StatefulWidget {
  final Map<String, dynamic> data;

  const _LiveMatchQuickPanelBody({required this.data});

  @override
  State<_LiveMatchQuickPanelBody> createState() =>
      _LiveMatchQuickPanelBodyState();
}

class _LiveMatchQuickPanelBodyState extends State<_LiveMatchQuickPanelBody> {
  Timer? _chronoTimer;
  Timer? _remoteTick;
  int _elapsedSeconds = 0;
  bool _running = false;
  int _lastSavedMinute = -1;

  void _applyFirestoreChrono(Map<String, dynamic> data, {bool force = false}) {
    final base = (data['chronoBaseSeconds'] as int?) ?? 0;
    final minute = (data['minute'] as int?) ?? 0;
    final target = base > 0 ? base : minute * 60;
    if (force || target != _elapsedSeconds) {
      _elapsedSeconds = target;
      _lastSavedMinute = target ~/ 60;
    }
  }

  @override
  void initState() {
    super.initState();
    _applyFirestoreChrono(widget.data, force: true);
  }

  @override
  void didUpdateWidget(covariant _LiveMatchQuickPanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remoteRunning = (widget.data['chronoRunning'] as bool?) ?? false;
    final phase = LiveMatchPhase((widget.data['lastEvent'] ?? '').toString());
    final phaseLocked = phase.chronoLocked;

    if (_running && (!remoteRunning || phaseLocked)) {
      _chronoTimer?.cancel();
      _chronoTimer = null;
      setState(() {
        _running = false;
        _applyFirestoreChrono(widget.data, force: true);
      });
    } else if (!_running && remoteRunning && !phaseLocked) {
      setState(() {
        _running = true;
        _applyFirestoreChrono(widget.data, force: true);
      });
      _runChronoTimer();
    } else if (!_running && !remoteRunning) {
      final base = (widget.data['chronoBaseSeconds'] as int?) ?? 0;
      final minute = (widget.data['minute'] as int?) ?? 0;
      final target = base > 0 ? base : minute * 60;
      if (target != _elapsedSeconds) {
        setState(() => _applyFirestoreChrono(widget.data, force: true));
      }
    }
    _syncRemoteDisplayTimer();
  }

  void _syncRemoteDisplayTimer() {
    final remoteOn = (widget.data['chronoRunning'] as bool?) ?? false;
    if (remoteOn && !_running) {
      _remoteTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _remoteTick?.cancel();
      _remoteTick = null;
    }
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
    _remoteTick?.cancel();
    super.dispose();
  }

  int get _displayElapsedSeconds {
    if (_running) {
      return _elapsedSeconds;
    }
    final remoteRunning = (widget.data['chronoRunning'] as bool?) ?? false;
    if (remoteRunning) {
      final base = (widget.data['chronoBaseSeconds'] as int?) ?? 0;
      final startedAtMs = (widget.data['chronoStartedAtMs'] as int?) ?? 0;
      if (startedAtMs > 0) {
        return base +
            (DateTime.now().millisecondsSinceEpoch - startedAtMs) ~/ 1000;
      }
      return base;
    }
    return _elapsedSeconds;
  }

  String get _displayTime {
    final sec = _displayElapsedSeconds;
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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

  LiveMatchPhase get _phase =>
      LiveMatchPhase((widget.data['lastEvent'] ?? '').toString());

  Future<void> _startChrono() async {
    if (_running) {
      return;
    }
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
    FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .update({'lastEvent': ''});
    _startChrono();
  }

  Future<void> _editMinuteDialog() async {
    final controller =
        TextEditingController(text: '${_displayElapsedSeconds ~/ 60}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: homeSurface,
        title: Text(
          'Minute',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: homeText,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            color: homeText,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            suffixText: "'",
            filled: true,
            fillColor: homeSurfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: homeBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: homeBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: homeMutedText),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null) {
                Navigator.pop(ctx, v);
              }
            },
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: homeGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      setState(() {
        _elapsedSeconds = result * 60;
        _lastSavedMinute = result;
      });
      SeedService.updateMinute(result);
    }
  }

  int _currentChronoMinute() {
    final base = (widget.data['chronoBaseSeconds'] as int?) ?? 0;
    final startedAtMs = (widget.data['chronoStartedAtMs'] as int?) ?? 0;
    final running = (widget.data['chronoRunning'] as bool?) ?? false;
    if (running && startedAtMs > 0) {
      final elapsed = base +
          (DateTime.now().millisecondsSinceEpoch - startedAtMs) ~/ 1000;
      return elapsed ~/ 60;
    }
    return base ~/ 60;
  }

  void _showAddEventSheet(String type) {
    final playerCtrl = TextEditingController();
    final currentMin = _currentChronoMinute();
    final minuteCtrl = TextEditingController(
      text: currentMin > 0 ? '$currentMin' : '',
    );
    String team = widget.data['team1'] ?? 'DOM';
    final title = switch (type) {
      'yellow' => 'Carton jaune',
      'red' => 'Carton rouge',
      _ => 'But',
    };
    final playerLabel = switch (type) {
      'goal' => 'Buteur',
      _ => 'Joueur',
    };
    final t1 = '${widget.data['team1'] ?? 'Domicile'}';
    final t2 = '${widget.data['team2'] ?? 'Extérieur'}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: homeSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: homeBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: homeGold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TeamChip(
                      label: t1,
                      selected: team == (widget.data['team1'] ?? 'DOM'),
                      onTap: () => setSt(() => team = widget.data['team1'] ?? 'DOM'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TeamChip(
                      label: t2,
                      selected: team == (widget.data['team2'] ?? 'EXT'),
                      onTap: () => setSt(() => team = widget.data['team2'] ?? 'EXT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: playerCtrl,
                decoration: InputDecoration(
                  labelText: type == 'goal' ? '$playerLabel *' : playerLabel,
                  filled: true,
                  fillColor: homeSurfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: minuteCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Minute",
                  filled: true,
                  fillColor: homeSurfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final min = int.tryParse(minuteCtrl.text) ?? 0;
                  final player = playerCtrl.text.trim();
                  if (type == 'goal' && !SeedService.isGoalScorerValid(player)) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Indique le nom du buteur.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.orange.shade800,
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
                            'Indique le nom du buteur.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.orange.shade800,
                        ),
                      );
                    }
                    return;
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: homeGreen,
                  foregroundColor: homeSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'VALIDER',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearFacts() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: homeSurface,
        title: Text(
          'Vider les faits de jeu ?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: homeText,
          ),
        ),
        content: Text(
          'Buts, cartons et fil d’événements seront remis à zéro sur le live.',
          style: GoogleFonts.inter(fontSize: 13, color: homeMutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: homeMutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Vider',
              style: GoogleFonts.inter(
                color: homeRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SeedService.clearLiveFacts();
    }
  }

  void _showRevokeGoalPicker(String revokeType) {
    final rawEvents = widget.data['events'];
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
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final title = revokeType == 'goal_disallowed'
        ? 'Quel but est refusé ?'
        : 'Quel but est annulé ?';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: homeSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: homeBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: homeGold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...goals.reversed.map((g) {
              final player = (g['player'] ?? 'Inconnu').toString();
              final team = (g['team'] ?? '').toString();
              final min = g['minute'] ?? '?';
              return ListTile(
                leading: const Icon(Icons.sports_soccer_rounded, color: homeGold),
                title: Text(
                  player,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: homeText,
                  ),
                ),
                subtitle: Text(
                  '$team • $min\'',
                  style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
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

  @override
  Widget build(BuildContext context) {
    _syncRemoteDisplayTimer();
    final d = widget.data;
    final t1 = (d['team1'] as String?)?.toUpperCase() ?? 'DOM.';
    final t2 = (d['team2'] as String?)?.toUpperCase() ?? 'EXT.';
    final home = (d['scoreHome'] as int?) ?? 0;
    final away = (d['scoreAway'] as int?) ?? 0;
    final yH = (d['yellowHome'] as int?) ?? 0;
    final yA = (d['yellowAway'] as int?) ?? 0;
    final rH = (d['redHome'] as int?) ?? 0;
    final rA = (d['redAway'] as int?) ?? 0;
    final phase = LiveMatchPhase((d['lastEvent'] ?? '').toString());
    final chronoLocked = phase.chronoLocked;

    final rawEvents = d['events'];
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LIVE — PILOTAGE RAPIDE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: homeMutedText,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'EN COURS',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF4CAF50),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: homeSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: homeBorder),
            boxShadow: [
              BoxShadow(
                color: homeGreen.withAlpha(14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Score',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: homeMutedText,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ScoreColumn(
                      label: t1.length > 12 ? '${t1.substring(0, 12)}.' : t1,
                      score: home,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'VS',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18,
                          color: homeBorder,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (phase.isRegularFulltime)
                        _MiniStatus('FIN MATCH', homeRed)
                      else if (phase.isExtraFulltime)
                        _MiniStatus('FIN PROLONG.', homeRed)
                      else if (phase.isHalftime)
                        _MiniStatus('MI-TEMPS', const Color(0xFFFF9800))
                      else if (phase.isExtraHalftime)
                        _MiniStatus('MT PROLONG.', const Color(0xFFFF9800))
                      else if (phase.isExtraTimePlaying)
                        _MiniStatus('PROLONG.', Colors.deepPurple.shade300)
                      else
                        const SizedBox(height: 20),
                    ],
                  ),
                  Expanded(
                    child: _ScoreColumn(
                      label: t2.length > 12 ? '${t2.substring(0, 12)}.' : t2,
                      score: away,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Buts via AJOUTER BUT (buteur obligatoire)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: homeMutedText,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cartons  ·  $yH J / $rH R  —  $yA J / $rA R',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: homeMutedText,
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: homeBorder),
              const SizedBox(height: 12),
              Text(
                'Chrono',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: homeMutedText,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: phase.isMatchEnded
                        ? null
                        : (_running ? _pauseChrono : _startChrono),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: phase.isMatchEnded
                            ? homeBorder
                            : (_running
                                ? homeGold.withAlpha(40)
                                : homeGreen),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        phase.isMatchEnded
                            ? Icons.lock_rounded
                            : (_running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                        size: 26,
                        color: phase.isMatchEnded
                            ? homeMutedText
                            : (_running ? homeGreen : homeSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _editMinuteDialog,
                    child: Column(
                      children: [
                        Text(
                          _displayTime,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: chronoLocked
                                ? const Color(0xFFFF9800)
                                : (_running ? homeText : homeMutedText),
                            height: 1,
                          ),
                        ),
                        Text(
                          'tap pour la minute',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: homeMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TinyChip(
                    label: '0′',
                    onTap: phase.isMatchEnded ? null : () => _resetAndStart(0),
                  ),
                  _TinyChip(
                    label: '45′',
                    onTap: phase.isMatchEnded ? null : () => _resetAndStart(45),
                  ),
                  if (phase.isHalftime)
                    _TinyChip(
                      label: '2e MT',
                      accent: homeGreen,
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
                    _TinyChip(
                      label: '2e MT PROL',
                      accent: homeGreen,
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
                    _TinyChip(
                      label: 'PROLONG.',
                      accent: Colors.deepPurple.shade300,
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
                    ),
                  if (!phase.isMatchEnded && !phase.isExtraHalftime)
                    _TinyChip(
                      label: phase.isExtraTimePlaying ? 'MT PROL.' : 'MI-TEMPS',
                      accent: const Color(0xFFFF9800),
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
                    ),
                  if (phase.showFinMatchButton)
                    _TinyChip(
                      label: 'FIN MATCH',
                      accent: homeRed,
                      onTap: () async {
                        _pauseChrono();
                        final min = _displayElapsedSeconds ~/ 60;
                        await SeedService.notifyFulltime(min);
                        setState(() {
                          _elapsedSeconds = min * 60;
                          _lastSavedMinute = min;
                        });
                      },
                    ),
                  if (phase.showFinProlongationButton)
                    _TinyChip(
                      label: 'FIN PROLONG.',
                      accent: homeRed,
                      onTap: () async {
                        _pauseChrono();
                        final min = _displayElapsedSeconds ~/ 60;
                        await SeedService.notifyExtraFulltime(min);
                        setState(() {
                          _elapsedSeconds = min * 60;
                          _lastSavedMinute = min;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: homeBorder),
              const SizedBox(height: 12),
              Text(
                'FAITS DE JEU',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: homeMutedText,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ActionPill(
                    label: 'AJOUTER BUT',
                    bg: homeGold,
                    fg: homeText,
                    onTap: () => _showAddEventSheet('goal'),
                  ),
                  _ActionPill(
                    label: '+ JAUNE',
                    bg: Colors.amber.shade600,
                    fg: homeText,
                    onTap: () => _showAddEventSheet('yellow'),
                  ),
                  _ActionPill(
                    label: '+ ROUGE',
                    bg: homeRed,
                    fg: homeSurface,
                    onTap: () => _showAddEventSheet('red'),
                  ),
                  _ActionPill(
                    label: 'BUT ANNULÉ',
                    bg: homeSurfaceMuted,
                    fg: Colors.orange.shade800,
                    border: Colors.orange.shade700,
                    onTap: () => _showRevokeGoalPicker('goal_cancelled'),
                  ),
                  _ActionPill(
                    label: 'BUT REFUSÉ',
                    bg: homeSurfaceMuted,
                    fg: Colors.deepPurple.shade300,
                    border: Colors.deepPurple.shade400,
                    onTap: () => _showRevokeGoalPicker('goal_disallowed'),
                  ),
                  _ActionPill(
                    label: 'HORS-JEU',
                    bg: homeSurfaceMuted,
                    fg: const Color(0xFF5C6BC0),
                    border: const Color(0xFF5C6BC0),
                    onTap: () => _showRevokeGoalPicker('offside'),
                  ),
                  _ActionPill(
                    label: 'VIDER',
                    bg: homeSurfaceMuted,
                    fg: homeMutedText,
                    border: homeBorder,
                    onTap: _confirmClearFacts,
                  ),
                ],
              ),
              if (events.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Aucun fait de jeu',
                  style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
                ),
              ] else ...[
                const SizedBox(height: 10),
                ...events.reversed.take(6).map((g) {
                  final typ = (g['type'] ?? '').toString();
                  final col = _eventColor(typ);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            "${g['minute'] ?? '?'}′",
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: col,
                            ),
                          ),
                        ),
                        Icon(_eventIcon(typ), size: 14, color: col),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${g['player'] ?? '?'} · ${_eventLabel(typ)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: homeText,
                            ),
                          ),
                        ),
                        if (typ != 'goal')
                          GestureDetector(
                            onTap: () => SeedService.removeMatchEvent(g),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: homeMutedText,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                if (events.length > 6)
                  Text(
                    '+ ${events.length - 6}… (admin Direct pour la liste complète)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: homeMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreColumn({
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: homeMutedText,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          '$score',
          style: GoogleFonts.barlowCondensed(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: homeText,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _RoundIconBtn({
    required this.icon,
    this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: disabled
              ? homeSurfaceMuted
              : primary
                  ? homeGreen.withAlpha(35)
                  : homeSurfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? homeBorder
                : primary
                    ? homeGreen.withAlpha(120)
                    : homeBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: disabled
              ? homeMutedText
              : primary
                  ? homeGreen
                  : homeText.withAlpha(200),
        ),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatus(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(180)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color? accent;
  final VoidCallback? onTap;

  const _TinyChip({
    required this.label,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? homeGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.withAlpha(140)),
          borderRadius: BorderRadius.circular(8),
          color: c.withAlpha(22),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TeamChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? homeGold.withAlpha(35) : homeSurfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? homeGold : homeBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? homeText : homeMutedText,
          ),
        ),
      ),
    );
  }
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
      return Colors.amber.shade800;
    case 'red':
      return homeRed;
    case 'offside':
      return const Color(0xFF5C6BC0);
    case 'goal_cancelled':
      return Colors.orange.shade800;
    case 'goal_disallowed':
      return Colors.deepPurple.shade300;
    default:
      return homeGold;
  }
}

String _eventLabel(String type) {
  switch (type) {
    case 'yellow':
      return 'Jaune';
    case 'red':
      return 'Rouge';
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
