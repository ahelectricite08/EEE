import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/admin/widgets/motm_vote_admin_panel.dart';

import '../models/match_stats_schema.dart';
import '../models/match_model.dart';
import '../screens/home/home_palette.dart';
import '../services/live_banner_format.dart';
import '../services/live_match_phase.dart';
import '../services/live_start_service.dart';
import '../services/match_lineup_service.dart';
import '../services/match_stats_sheet_service.dart';
import '../services/seed_service.dart';
import '../services/live_radio_service.dart';
import 'live_start_match_picker.dart';
import 'match_lineup_editor_sheet.dart';
import 'match_media_after_event.dart';
import 'match_commentary_record_sheet.dart';
import 'match_event_audio_play_button.dart';
import 'match_event_video_play_button.dart';
import 'match_highlight_attach_sheet.dart';
import 'sedan_squad_player_picker.dart';
import '../utils/youtube_parser.dart';
import '../screens/admin/admin_palette.dart';

/// Couleurs du pilotage live — thème app (home) ou admin.
class LivePilotageThemeData {
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color gold;
  final Color red;

  const LivePilotageThemeData({
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.gold,
    required this.red,
  });

  static final app = LivePilotageThemeData(
    surface: homeSurface,
    surfaceMuted: homeSurfaceMuted,
    text: homeText,
    muted: homeMutedText,
    border: homeBorder,
    accent: homeGreen,
    gold: homeGold,
    red: homeRed,
  );

  static final admin = LivePilotageThemeData(
    surface: adminCard,
    surfaceMuted: adminSurface,
    text: adminTextPrimary,
    muted: adminGrey,
    border: adminBorder,
    accent: adminGreenAccent,
    gold: adminGold,
    red: adminRed,
  );
}

class LivePilotageTheme extends InheritedWidget {
  final LivePilotageThemeData data;

  const LivePilotageTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static LivePilotageThemeData of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<LivePilotageTheme>();
    return w?.data ?? LivePilotageThemeData.app;
  }

  @override
  bool updateShouldNotify(LivePilotageTheme oldWidget) =>
      data != oldWidget.data;
}

/// Panneau profil (admin / CM) : démarrer / piloter un live.
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
          return const _LiveMatchQuickStartPanel();
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        return LiveMatchQuickPilotageBody(
          data: d,
          showMotmVotePanel: kIsWeb,
        );
      },
    );
  }
}

/// Affiché quand aucun direct n’est actif.
class _LiveMatchQuickStartPanel extends StatefulWidget {
  const _LiveMatchQuickStartPanel();

  @override
  State<_LiveMatchQuickStartPanel> createState() =>
      _LiveMatchQuickStartPanelState();
}

class _LiveMatchQuickStartPanelState extends State<_LiveMatchQuickStartPanel> {
  bool _starting = false;

  Future<void> _promptAndStartLive() async {
    setState(() => _starting = true);
    try {
      final pickable = await LiveStartService.loadPickableMatches();
      if (!mounted) return;
      final suggested = LiveStartService.pickSuggestedFrom(pickable);
      var selected = suggested.match;
      if (selected != null && !pickable.any((m) => m.id == selected!.id)) {
        selected = pickable.isNotEmpty ? pickable.first : null;
      }

      final urlCtrl = TextEditingController();
      final team1Ctrl = TextEditingController(text: selected?.team1 ?? '');
      final team2Ctrl = TextEditingController(text: selected?.team2 ?? '');

      if (mounted) setState(() => _starting = false);

      final form = await showDialog<LiveStartFormResult>(
      context: context,
      barrierColor: Colors.black.withAlpha(120),
      builder: (dialogContext) {
        var streamBroadcast = true;
        MatchModel? localSelected = selected;
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            void onMatchPicked(MatchModel? m) {
              if (m == null) return;
              setLocal(() {
                localSelected = m;
                team1Ctrl.text = m.team1;
                team2Ctrl.text = m.team2;
              });
            }

            return AlertDialog(
              backgroundColor: homeSurface,
              title: Text(
                'Démarrer le live',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: homeText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (suggested.message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: homeGreen.withAlpha(14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: homeGreen.withAlpha(60)),
                        ),
                        child: Text(
                          suggested.message!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: homeText,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    LiveStartMatchPicker(
                      matches: pickable,
                      value: localSelected,
                      onChanged: onMatchPicked,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: team1Ctrl,
                      decoration: InputDecoration(
                        labelText: 'Domicile',
                        labelStyle: GoogleFonts.inter(color: homeMutedText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.inter(color: homeText),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: team2Ctrl,
                      decoration: InputDecoration(
                        labelText: 'Extérieur',
                        labelStyle: GoogleFonts.inter(color: homeMutedText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: GoogleFonts.inter(color: homeText),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: !streamBroadcast,
                      activeTrackColor: homeGreen.withAlpha(120),
                      activeThumbColor: homeGreen,
                      onChanged: (notBroadcast) => setLocal(
                        () => streamBroadcast = !notBroadcast,
                      ),
                      title: Text(
                        'Match non retransmis',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: homeText,
                        ),
                      ),
                      subtitle: Text(
                        !streamBroadcast
                            ? 'Score et stats sans bouton vidéo sur l’accueil.'
                            : 'URL YouTube — bouton « Regarder en direct ».',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: homeMutedText,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (streamBroadcast) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          labelText: 'URL YouTube (optionnel)',
                          helperText:
                              'Colle l’URL directe (sans « Partager » YouTube) : sinon YouTube affiche qui a envoyé le lien.',
                          helperMaxLines: 2,
                          hintText:
                              'https://www.youtube.com/@drapeauvertcartonrouge/streams',
                          labelStyle: GoogleFonts.inter(color: homeMutedText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: GoogleFonts.inter(color: homeText),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: Text(
                    'Annuler',
                    style: GoogleFonts.inter(color: homeMutedText),
                  ),
                ),
                FilledButton(
                  onPressed: localSelected == null
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                            LiveStartFormResult(
                              streamBroadcast: streamBroadcast,
                              match: localSelected!,
                            ),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: homeGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Lancer',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

      if (form == null || !mounted) {
        team1Ctrl.dispose();
        team2Ctrl.dispose();
        urlCtrl.dispose();
        return;
      }

      final match = form.match;
      final team1 =
          team1Ctrl.text.trim().isEmpty ? match.team1 : team1Ctrl.text.trim();
      final team2 =
          team2Ctrl.text.trim().isEmpty ? match.team2 : team2Ctrl.text.trim();
      final url = form.streamBroadcast
          ? YoutubeParser.sanitizeShareUrl(
              urlCtrl.text.trim().isEmpty
                  ? 'https://www.youtube.com/@drapeauvertcartonrouge/streams'
                  : urlCtrl.text.trim(),
            )
          : '';
      team1Ctrl.dispose();
      team2Ctrl.dispose();
      urlCtrl.dispose();

      if (mounted) setState(() => _starting = true);
      await SeedService.beginLiveSession(
        url: url,
        team1: team1,
        team2: team2,
        matchId: match.id,
        logo1: match.logo1,
        logo2: match.logo2,
        streamBroadcast: form.streamBroadcast,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live démarré — accueil en direct.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec démarrage : ${e.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeRed,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: homeMutedText,
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
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: homeSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: homeBorder),
          ),
          child: Column(
            children: [
              Icon(Icons.sports_soccer_rounded, size: 36, color: homeMutedText),
              const SizedBox(height: 10),
              Text(
                'Aucun match en direct',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: homeText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lance le live pour n’importe quel match du calendrier : score, chrono, buteurs et stats.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: homeMutedText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _starting ? null : _promptAndStartLive,
                  icon: _starting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withAlpha(200),
                          ),
                        )
                      : const Icon(Icons.play_circle_fill_rounded, size: 22),
                  label: Text(
                    _starting ? 'DÉMARRAGE…' : 'DÉMARRER LE LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: homeGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Corps du pilotage rapide (score, stats toggle, chrono, faits de jeu).
/// Partagé entre le profil mobile et l’admin web.
class LiveMatchQuickPilotageBody extends StatefulWidget {
  final Map<String, dynamic> data;

  /// Masquer l’en-tête « LIVE — PILOTAGE RAPIDE » (ex. admin a déjà « Match en direct »).
  final bool showHeader;

  /// Admin Direct : le bandeau stats est géré par [LiveStatsDisplayControl].
  final bool hideStatsBandeauToggle;

  /// Vote homme du match (admin web profil / pilotage rapide).
  final bool showMotmVotePanel;

  /// Palette admin (onglet Direct) au lieu du thème home profil.
  final bool useAdminStyle;

  const LiveMatchQuickPilotageBody({
    super.key,
    required this.data,
    this.showHeader = true,
    this.hideStatsBandeauToggle = false,
    this.showMotmVotePanel = false,
    this.useAdminStyle = false,
  });

  @override
  State<LiveMatchQuickPilotageBody> createState() =>
      _LiveMatchQuickPilotageBodyState();
}

class _LiveMatchQuickPilotageBodyState extends State<LiveMatchQuickPilotageBody> {
  Timer? _chronoTimer;
  int _elapsedSeconds = 0;
  bool _running = false;
  bool _chronoOpInFlight = false;
  int _lastSavedMinute = -1;
  bool _endingLive = false;
  bool _radioOpInFlight = false;
  late final TextEditingController _radioHlsOverrideCtrl;

  void _onRadioServiceChanged() {
    if (mounted) setState(() {});
  }

  void _applyFirestoreChrono(Map<String, dynamic> data, {bool force = false}) {
    final target = LiveBannerFormat.elapsedSecondsFromMap(data);
    if (force || target != _elapsedSeconds) {
      _elapsedSeconds = target;
      _lastSavedMinute = target ~/ 60;
    }
  }

  @override
  void initState() {
    super.initState();
    _radioHlsOverrideCtrl = TextEditingController(
      text: (widget.data['radioHlsUrl'] ?? '').toString(),
    );
    _applyFirestoreChrono(widget.data, force: true);
    final remoteRunning = (widget.data['chronoRunning'] as bool?) ?? false;
    final phase = LiveMatchPhase((widget.data['lastEvent'] ?? '').toString());
    if (remoteRunning && !phase.chronoLocked) {
      _running = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runChronoTimer();
      });
    }
    _ensureChronoTick();
    LiveRadioService.instance.addListener(_onRadioServiceChanged);
  }

  @override
  void didUpdateWidget(covariant LiveMatchQuickPilotageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_chronoOpInFlight) {
      _ensureChronoTick();
      return;
    }
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
      final target = LiveBannerFormat.elapsedSecondsFromMap(widget.data);
      if (target != _elapsedSeconds) {
        setState(() => _applyFirestoreChrono(widget.data, force: true));
      }
    }
    _ensureChronoTick();
  }

  void _ensureChronoTick() {
    final remoteOn = (widget.data['chronoRunning'] as bool?) ?? false;
    final phase = _phase;
    final shouldTick = (remoteOn || _running) && !phase.chronoLocked;
    if (!shouldTick) {
      _chronoTimer?.cancel();
      _chronoTimer = null;
      return;
    }
    if (_chronoTimer != null) return;
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remoteOnNow = (widget.data['chronoRunning'] as bool?) ?? false;
      var elapsed = LiveBannerFormat.elapsedSecondsFromMap(widget.data);
      if (_running && !remoteOnNow) {
        elapsed = _elapsedSeconds + 1;
      }
      setState(() => _elapsedSeconds = elapsed);
      final minute = elapsed ~/ 60;
      if (minute != _lastSavedMinute && (remoteOnNow || _running)) {
        _lastSavedMinute = minute;
        SeedService.updateMinute(minute);
      }
    });
  }

  @override
  void dispose() {
    LiveRadioService.instance.removeListener(_onRadioServiceChanged);
    _radioHlsOverrideCtrl.dispose();
    _chronoTimer?.cancel();
    super.dispose();
  }

  int get _displayElapsedSeconds {
    final remoteRunning = (widget.data['chronoRunning'] as bool?) ?? false;
    if (remoteRunning) {
      return LiveBannerFormat.elapsedSecondsFromMap(widget.data);
    }
    if (_running) return _elapsedSeconds;
    return LiveBannerFormat.elapsedSecondsFromMap(widget.data);
  }

  String get _displayTime {
    final sec = _displayElapsedSeconds;
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _runChronoTimer() {
    _ensureChronoTick();
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
      startSeconds = 45 * 60;
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

    _chronoOpInFlight = true;
    try {
      await SeedService.startChrono(_elapsedSeconds);
    } finally {
      _chronoOpInFlight = false;
    }
    _runChronoTimer();
  }

  Future<void> _pauseChrono() async {
    _chronoTimer?.cancel();
    _chronoTimer = null;
    final elapsed = _displayElapsedSeconds;
    setState(() {
      _running = false;
      _elapsedSeconds = elapsed;
      _lastSavedMinute = elapsed ~/ 60;
    });
    _chronoOpInFlight = true;
    try {
      await SeedService.pauseChrono(elapsed);
      await SeedService.setMinuteWithChrono(elapsed ~/ 60);
    } finally {
      _chronoOpInFlight = false;
    }
  }

  Future<void> _resetAndStart(int startMinute) async {
    if (_chronoOpInFlight) return;
    _chronoTimer?.cancel();
    _chronoTimer = null;
    final seconds = startMinute * 60;
    setState(() {
      _running = false;
      _elapsedSeconds = seconds;
      _lastSavedMinute = startMinute;
    });
    // Efface halftime/fulltime avant de redémarrer (évite le early-return de _startChrono)
    _chronoOpInFlight = true;
    try {
      await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .update({'lastEvent': '', 'chronoRunning': false});
      setState(() => _running = true);
      await SeedService.startChrono(seconds);
    } finally {
      _chronoOpInFlight = false;
    }
    _runChronoTimer();
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
      SeedService.setMinuteWithChrono(result);
    }
  }

  int _currentChronoMinute() =>
      _displayElapsedSeconds ~/ 60;

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
              Builder(
                builder: (_) {
                  final sedanSide =
                      MatchStatsSchema.isSedanTeamLabel(team);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: playerCtrl,
                          decoration: InputDecoration(
                            labelText:
                                type == 'goal' ? '$playerLabel *' : playerLabel,
                            hintText: sedanSide
                                ? 'Effectif ou saisie manuelle'
                                : null,
                            filled: true,
                            fillColor: homeSurfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (sedanSide) ...[
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Effectif Sedan',
                          onPressed: () async {
                            final p = await showSedanSquadSinglePicker(
                              ctx,
                              title: playerLabel,
                              accent: homeGreen,
                            );
                            if (p != null) {
                              playerCtrl.text = p.lineupName;
                              setSt(() {});
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: homeGreen.withAlpha(40),
                            foregroundColor: homeGreen,
                          ),
                          icon: const Icon(Icons.groups_rounded),
                        ),
                      ],
                    ],
                  );
                },
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
                  Map<String, dynamic>? event;
                  try {
                    event = await SeedService.addMatchEvent(
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
                  if (event != null && context.mounted) {
                    await offerMatchMediaAfterEvent(
                      context,
                      event: event,
                    );
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

  void _showSubstitutionSheet() {
    final outCtrl = TextEditingController();
    final inCtrl = TextEditingController();
    final currentMin = _currentChronoMinute();
    final minuteCtrl = TextEditingController(
      text: currentMin > 0 ? '$currentMin' : '',
    );
    String team = widget.data['team1'] ?? 'DOM';
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
        builder: (ctx, setSt) {
          final sedanSide = MatchStatsSchema.isSedanTeamLabel(team);
          Widget playerRow({
            required TextEditingController ctrl,
            required String label,
            required String pickerTitle,
          }) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      labelText: '$label *',
                      hintText: sedanSide
                          ? 'Effectif ou saisie manuelle'
                          : null,
                      filled: true,
                      fillColor: homeSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (sedanSide) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Effectif Sedan',
                    onPressed: () async {
                      final p = await showSedanSquadSinglePicker(
                        ctx,
                        title: pickerTitle,
                        accent: homeGreen,
                      );
                      if (p != null) {
                        ctrl.text = p.lineupName;
                        setSt(() {});
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: homeGreen.withAlpha(40),
                      foregroundColor: homeGreen,
                    ),
                    icon: const Icon(Icons.groups_rounded),
                  ),
                ],
              ],
            );
          }

          return Padding(
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
                  'REMPLACEMENT',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4A90D9),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sortant (titulaire / sur le terrain) puis entrant. '
                  'Un joueur peut revenir (règle R1).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: homeMutedText,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _TeamChip(
                        label: t1,
                        selected: team == (widget.data['team1'] ?? 'DOM'),
                        onTap: () =>
                            setSt(() => team = widget.data['team1'] ?? 'DOM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TeamChip(
                        label: t2,
                        selected: team == (widget.data['team2'] ?? 'EXT'),
                        onTap: () =>
                            setSt(() => team = widget.data['team2'] ?? 'EXT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                playerRow(
                  ctrl: outCtrl,
                  label: 'Sortant',
                  pickerTitle: 'Joueur sortant',
                ),
                const SizedBox(height: 10),
                playerRow(
                  ctrl: inCtrl,
                  label: 'Entrant',
                  pickerTitle: 'Joueur entrant',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minuteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Minute',
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
                    final out = outCtrl.text.trim();
                    final inn = inCtrl.text.trim();
                    if (out.isEmpty || inn.isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Indique le sortant et l’entrant.',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                      }
                      return;
                    }
                    Map<String, dynamic>? event;
                    try {
                      event = await SeedService.addMatchEvent(
                        type: 'substitution',
                        team: team,
                        player: out,
                        playerIn: inn,
                        minute: min,
                      );
                    } on StateError catch (e) {
                      if (e.message == 'substitution_players_required' &&
                          ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Indique le sortant et l’entrant.',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                      }
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (event != null && context.mounted) {
                      await offerMatchMediaAfterEvent(
                        context,
                        event: event,
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
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
          );
        },
      ),
    );
  }

  Future<void> _setRadioLive(bool enabled) async {
    if (_radioOpInFlight) return;
    setState(() => _radioOpInFlight = true);
    final radio = LiveRadioService.instance;
    final hlsOverride = _radioHlsOverrideCtrl.text.trim();
    // Mode URL (override) : pas de publish WHIP — diffuseur externe.
    final externalOnly = enabled && hlsOverride.isNotEmpty;
    try {
      if (!enabled) {
        await radio.stop();
        await SeedService.setRadioLive(false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Radio commentaire coupée',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: homeGreen,
          ),
        );
        return;
      }

      await SeedService.setRadioLive(
        true,
        hlsUrlOverride: hlsOverride.isEmpty ? null : hlsOverride,
      );

      if (kIsWeb || externalOnly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              externalOnly
                  ? 'Radio ON — URL externe (pas de micro WHIP)'
                  : 'Radio ON — utilise l’app téléphone pour parler (WHIP)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: homeGreen,
          ),
        );
        return;
      }

      await radio.startPublishing();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Radio ON — micro en direct (WHIP)',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      if (enabled) {
        try {
          await SeedService.setRadioLive(false);
        } catch (_) {}
        await radio.stop();
      }
      if (!mounted) return;
      final msg = e is FirebaseFunctionsException
          ? ((e.message ?? '').trim().isNotEmpty
              ? e.message!
              : 'MediaMTX non configuré')
          : e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('MediaMTX') || msg.contains('WHIP') || msg.contains('HLS')
                ? msg
                : 'Radio : $msg',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _radioOpInFlight = false);
    }
  }

  Widget _buildRadioPilotageTile({
    required LivePilotageThemeData pal,
    required bool radioLive,
  }) {
    final radio = LiveRadioService.instance;
    final publishing = radio.isPublishing;
    final connecting = radio.isConnecting || _radioOpInFlight;
    final muted = radio.isMuted;
    final whipUrl = (widget.data['radioWhipUrl'] ?? '').toString().trim();
    final externalMode = radioLive && whipUrl.isEmpty;

    String subtitle;
    if (!radioLive) {
      subtitle =
          'MediaMTX WHIP + HLS — ou colle une URL (mode diffuseur externe)';
    } else if (externalMode) {
      subtitle = 'Radio ON — URL externe (écoute HLS / Icecast)';
    } else if (kIsWeb) {
      subtitle = 'Radio ON — utilise l’app téléphone pour parler (WHIP)';
    } else if (connecting) {
      subtitle = 'Connexion micro WHIP…';
    } else if (publishing) {
      subtitle = muted ? 'Micro coupé' : 'Micro en direct (WHIP → MediaMTX)';
    } else {
      subtitle = 'Radio ON — reconnecte le micro depuis l’app';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: radioLive ? pal.accent.withAlpha(90) : pal.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.podcasts_rounded,
                size: 18,
                color: radioLive ? pal.accent : pal.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RADIO COMMENTAIRE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: pal.text,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: pal.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: radioLive,
                activeTrackColor: pal.accent.withAlpha(120),
                activeThumbColor: pal.accent,
                onChanged: connecting
                    ? null
                    : (v) {
                        _setRadioLive(v);
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _radioHlsOverrideCtrl,
            enabled: !connecting,
            style: GoogleFonts.inter(fontSize: 12, color: pal.text),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'URL HLS / Icecast (optionnel)',
              labelStyle: GoogleFonts.inter(fontSize: 11, color: pal.muted),
              hintText: 'https://…/index.m3u8 — laisse vide = MediaMTX',
              hintStyle: GoogleFonts.inter(fontSize: 10, color: pal.muted),
              filled: true,
              fillColor: pal.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pal.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pal.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          if (radioLive && !kIsWeb && !externalMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: connecting || !publishing
                        ? (connecting
                            ? null
                            : () async {
                                try {
                                  await radio.startPublishing();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst(
                                          RegExp(r'^[^:]+:\s*'),
                                          '',
                                        ),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: homeRed,
                                    ),
                                  );
                                }
                              })
                        : () => radio.toggleMute(),
                    icon: Icon(
                      !publishing
                          ? Icons.mic_rounded
                          : (muted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded),
                      size: 16,
                    ),
                    label: Text(
                      connecting
                          ? 'Connexion…'
                          : !publishing
                              ? 'Activer le micro'
                              : (muted ? 'Réactiver micro' : 'Couper micro'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: muted ? pal.red : pal.accent,
                      side: BorderSide(
                        color: (muted ? pal.red : pal.accent).withAlpha(100),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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

  Future<void> _confirmEndLive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: homeSurface,
        title: Text(
          'Arrêter le live ?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: homeText,
          ),
        ),
        content: Text(
          'Le score et les faits de jeu seront enregistrés sur la fiche match. '
          'L’accueil repasse en mode normal.',
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
              'Arrêter',
              style: GoogleFonts.inter(
                color: homeRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _endingLive = true);
    try {
      await LiveRadioService.instance.stop();
      await SeedService.endLiveSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live arrêté — accueil libéré.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec arrêt live : ${e.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeRed,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _endingLive = false);
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
    _ensureChronoTick();
    final pal = widget.useAdminStyle
        ? LivePilotageThemeData.admin
        : LivePilotageThemeData.app;
    final d = widget.data;
    final t1 = (d['team1'] as String?)?.toUpperCase() ?? 'DOM.';
    final t2 = (d['team2'] as String?)?.toUpperCase() ?? 'EXT.';
    final home = (d['scoreHome'] as int?) ?? 0;
    final away = (d['scoreAway'] as int?) ?? 0;
    final yH = (d['yellowHome'] as int?) ?? 0;
    final yA = (d['yellowAway'] as int?) ?? 0;
    final rH = (d['redHome'] as int?) ?? 0;
    final rA = (d['redAway'] as int?) ?? 0;
    final statsEnabled = (d['statsEnabled'] as bool?) ?? false;
    final showLineupOnCard = d['showLineupOnCard'] == true;
    final streamUrl = (d['url'] as String?)?.trim() ?? '';
    final streamOn = (d['streamBroadcast'] as bool?) ?? streamUrl.isNotEmpty;
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
                'substitution',
                'offside',
                'goal_cancelled',
                'goal_disallowed',
              }.contains(e['type']),
            )
            .toList()
        : <Map<String, dynamic>>[];

    return LivePilotageTheme(
      data: pal,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: pal.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE — PILOTAGE RAPIDE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: pal.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: pal.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'EN COURS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: pal.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
            boxShadow: widget.useAdminStyle
                ? adminCardShadow
                : [
                    BoxShadow(
                      color: pal.accent.withAlpha(14),
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
                  color: pal.muted,
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
                          color: pal.border,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (phase.isRegularFulltime)
                        _MiniStatus('FIN MATCH', pal.red)
                      else if (phase.isExtraFulltime)
                        _MiniStatus('FIN PROLONG.', pal.red)
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
              if (streamOn && streamUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                _LiveYoutubeUrlCleanTile(url: streamUrl),
              ],
              const SizedBox(height: 12),
              _buildRadioPilotageTile(
                pal: pal,
                radioLive: (d['radioLive'] as bool?) == true,
              ),
              const SizedBox(height: 6),
              Text(
                'Buts via AJOUTER BUT (buteur obligatoire)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: pal.muted,
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
                  color: pal.muted,
                ),
              ),
              if (!widget.hideStatsBandeauToggle) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: pal.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statsEnabled
                          ? pal.accent.withAlpha(90)
                          : pal.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 18,
                        color: statsEnabled ? pal.accent : pal.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STATS EN DIRECT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: pal.text,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              statsEnabled
                                  ? 'Bandeau visible — chiffres dans Statistiques match'
                                  : 'Bandeau masqué dans l’app',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: pal.muted,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: statsEnabled,
                        activeTrackColor: pal.accent.withAlpha(120),
                        activeThumbColor: pal.accent,
                        onChanged: (v) async {
                          final mid = (d['matchId'] as String? ?? '').trim();
                          if (mid.isEmpty) return;
                          await MatchStatsSheetService.instance
                              .setLiveStatsDisplay(mid, enabled: v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: pal.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showLineupOnCard && !statsEnabled
                        ? pal.accent.withAlpha(90)
                        : pal.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 18,
                          color: showLineupOnCard && !statsEnabled
                              ? pal.accent
                              : pal.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COMPOSITIONS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: pal.text,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                statsEnabled
                                    ? 'Bandeau stats en bas · compo en petit bandeau si toggle'
                                    : showLineupOnCard
                                        ? 'Compositions en grand sur l’accueil'
                                        : 'Compositions sur la fiche match uniquement',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: pal.muted,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: showLineupOnCard,
                          activeTrackColor: pal.accent.withAlpha(120),
                          activeThumbColor: pal.accent,
                          onChanged: (v) async {
                            await MatchLineupService.instance.setShowOnCard(v);
                            if (v) {
                              try {
                                final matchId = (d['matchId'] as String? ?? '').trim();
                                await FirebaseFunctions.instance
                                    .httpsCallable('notifyLineups')
                                    .call({'matchId': matchId});
                              } catch (_) {}
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => showMatchLineupEditorSheet(context),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(
                        'Éditer compositions (2 équipes)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pal.accent,
                        side: BorderSide(color: pal.accent.withAlpha(100)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showMotmVotePanel) ...[
                const SizedBox(height: 12),
                MotmVoteAdminPanel(data: d),
              ],
              const SizedBox(height: 12),
              Container(height: 1, color: pal.border),
              const SizedBox(height: 12),
              Text(
                'Chrono',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pal.muted,
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
                            ? pal.border
                            : (_running
                                ? pal.gold.withAlpha(40)
                                : pal.accent),
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
                            ? pal.muted
                            : (_running ? pal.accent : pal.surface),
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
                                : (_running ? pal.text : pal.muted),
                            height: 1,
                          ),
                        ),
                        Text(
                          'tap pour la minute',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: pal.muted,
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
                      accent: pal.accent,
                      onTap: () async {
                        await _pauseChrono();
                        await SeedService.resumeSecondHalf();
                        if (!mounted) return;
                        setState(() {
                          _elapsedSeconds = 45 * 60;
                          _lastSavedMinute = 45;
                        });
                      },
                    ),
                  if (phase.isExtraHalftime)
                    _TinyChip(
                      label: '2e MT PROL',
                      accent: pal.accent,
                      onTap: () async {
                        await _pauseChrono();
                        await SeedService.resumeExtraSecondHalf();
                        if (!mounted) return;
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
                        // Capture la minute AVANT de pauser (évite valeur stale)
                        final minAtTap = _displayElapsedSeconds ~/ 60;
                        await _pauseChrono();
                        if (!mounted) return;
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
                            _lastSavedMinute = minAtTap;
                          });
                        }
                      },
                    ),
                  if (phase.showFinMatchButton)
                    _TinyChip(
                      label: 'FIN MATCH',
                      accent: pal.red,
                      onTap: () async {
                        // Capture la minute AVANT pause
                        final min = _displayElapsedSeconds ~/ 60;
                        await _pauseChrono();
                        if (!mounted) return;
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
                      accent: pal.red,
                      onTap: () async {
                        final min = _displayElapsedSeconds ~/ 60;
                        await _pauseChrono();
                        if (!mounted) return;
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
              Container(height: 1, color: pal.border),
              const SizedBox(height: 12),
              Text(
                'FAITS DE JEU',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: pal.muted,
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
                    bg: pal.gold,
                    fg: pal.text,
                    onTap: () => _showAddEventSheet('goal'),
                  ),
                  _ActionPill(
                    label: '+ JAUNE',
                    bg: Colors.amber.shade600,
                    fg: pal.text,
                    onTap: () => _showAddEventSheet('yellow'),
                  ),
                  _ActionPill(
                    label: '+ ROUGE',
                    bg: pal.red,
                    fg: pal.surface,
                    onTap: () => _showAddEventSheet('red'),
                  ),
                  _ActionPill(
                    label: 'REMPLACEMENT',
                    bg: const Color(0xFF4A90D9),
                    fg: Colors.white,
                    onTap: _showSubstitutionSheet,
                  ),
                  _ActionPill(
                    label: 'BUT ANNULÉ',
                    bg: pal.surfaceMuted,
                    fg: Colors.orange.shade800,
                    border: Colors.orange.shade700,
                    onTap: () => _showRevokeGoalPicker('goal_cancelled'),
                  ),
                  _ActionPill(
                    label: 'BUT REFUSÉ',
                    bg: pal.surfaceMuted,
                    fg: Colors.deepPurple.shade300,
                    border: Colors.deepPurple.shade400,
                    onTap: () => _showRevokeGoalPicker('goal_disallowed'),
                  ),
                  _ActionPill(
                    label: 'HORS-JEU',
                    bg: pal.surfaceMuted,
                    fg: const Color(0xFF5C6BC0),
                    border: const Color(0xFF5C6BC0),
                    onTap: () => _showRevokeGoalPicker('offside'),
                  ),
                  _ActionPill(
                    label: 'VIDER',
                    bg: pal.surfaceMuted,
                    fg: pal.muted,
                    border: pal.border,
                    onTap: _confirmClearFacts,
                  ),
                ],
              ),
              if (events.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Aucun fait de jeu',
                  style: GoogleFonts.inter(fontSize: 12, color: pal.muted),
                ),
              ] else ...[
                const SizedBox(height: 10),
                ...events.reversed.take(6).map((g) {
                  final typ = (g['type'] ?? '').toString();
                  final col = _eventColor(typ);
                  final mid =
                      (widget.data['matchId'] ?? '').toString().trim();
                  final eid = (g['id'] ?? '').toString().trim();
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
                            '${MatchStatsSchema.eventPlayerLine(g)} · ${_eventLabel(typ)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pal.text,
                            ),
                          ),
                        ),
                        if (mid.isNotEmpty && eid.isNotEmpty) ...[
                          MatchEventAudioRecordButton(
                            matchId: mid,
                            event: g,
                            accent: pal.gold,
                            onRecord: () async {
                              await showMatchCommentaryRecordSheet(
                                context,
                                matchId: mid,
                                eventId: eid,
                                type: typ,
                                minute: (g['minute'] as num?)?.toInt() ?? 0,
                                player: MatchStatsSchema.eventPlayerLine(g),
                                team: (g['team'] ?? '').toString(),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          MatchEventAudioDeleteButton(
                            matchId: mid,
                            eventId: eid,
                            accent: pal.red,
                          ),
                          const SizedBox(width: 4),
                          MatchEventVideoAttachButton(
                            accent: pal.gold,
                            onAttach: () async {
                              await showMatchHighlightAttachSheet(
                                context,
                                matchId: mid,
                                eventId: eid,
                                type: typ,
                                minute: (g['minute'] as num?)?.toInt() ?? 0,
                                player: MatchStatsSchema.eventPlayerLine(g),
                                team: (g['team'] ?? '').toString(),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (typ != 'goal')
                          GestureDetector(
                            onTap: () => SeedService.removeMatchEvent(g),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: pal.muted,
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
                      color: pal.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _endingLive ? null : _confirmEndLive,
            icon: _endingLive
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: pal.red.withAlpha(180),
                    ),
                  )
                : Icon(Icons.stop_circle_outlined, size: 20, color: pal.red),
            label: Text(
              _endingLive ? 'ARRÊT EN COURS…' : 'ARRÊTER LE LIVE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pal.red,
                letterSpacing: 0.6,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.red,
              side: BorderSide(color: pal.red.withAlpha(160)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
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
    final pal = LivePilotageTheme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: pal.muted,
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
            color: pal.text,
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
    final pal = LivePilotageTheme.of(context);
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: disabled
              ? pal.surfaceMuted
              : primary
                  ? pal.accent.withAlpha(35)
                  : pal.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? pal.border
                : primary
                    ? pal.accent.withAlpha(120)
                    : pal.border,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: disabled
              ? pal.muted
              : primary
                  ? pal.accent
                  : pal.text.withAlpha(200),
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
    final pal = LivePilotageTheme.of(context);
    final c = accent ?? pal.accent;
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
    case 'substitution':
      return Icons.swap_horiz_rounded;
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
    case 'substitution':
      return const Color(0xFF4A90D9);
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

/// Retire le paramètre `si=` (YouTube affiche sinon « partagé par … »).
class _LiveYoutubeUrlCleanTile extends StatefulWidget {
  final String url;
  const _LiveYoutubeUrlCleanTile({required this.url});

  @override
  State<_LiveYoutubeUrlCleanTile> createState() => _LiveYoutubeUrlCleanTileState();
}

class _LiveYoutubeUrlCleanTileState extends State<_LiveYoutubeUrlCleanTile> {
  bool _busy = false;

  bool get _needsClean {
    final u = widget.url.toLowerCase();
    return u.contains('si=') ||
        u.contains('feature=share') ||
        u.contains('utm_');
  }

  Future<void> _clean() async {
    setState(() => _busy = true);
    try {
      await SeedService.updateLiveStreamUrl(widget.url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lien YouTube nettoyé — plus d’attribution « partagé par » côté YouTube.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec : ${e.toString().replaceFirst('Exception: ', '')}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _needsClean ? homeGold.withAlpha(18) : homeGreen.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _needsClean ? homeGold.withAlpha(80) : homeBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_off_rounded,
            size: 16,
            color: _needsClean ? homeGold : homeMutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _needsClean
                  ? 'Ce lien peut afficher ton compte YouTube aux spectateurs (paramètre si=).'
                  : 'Lien stream sans traçage « partagé par ».',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: homeText,
                height: 1.3,
              ),
            ),
          ),
          if (_needsClean)
            TextButton(
              onPressed: _busy ? null : _clean,
              child: Text(
                _busy ? '…' : 'Nettoyer',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: homeGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _eventLabel(String type) {
  switch (type) {
    case 'substitution':
      return 'Remplacement';
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
