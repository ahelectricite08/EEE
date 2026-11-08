import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/main_shell_insets.dart';
import '../screens/profile/match_sheet_share_plate.dart';
import '../screens/profile/profile_live_stats_screen.dart';
import '../screens/admin/widgets/motm_vote_admin_panel.dart';

import '../models/live_entry_error.dart';
import '../models/live_event_player_source.dart';
import '../models/match_stats_schema.dart';
import '../models/match_model.dart';
import '../screens/home/home_palette.dart';
import '../services/live_banner_format.dart';
import '../services/live_match_phase.dart';
import '../services/live_start_service.dart';
import '../services/match_lineup_service.dart';
import '../services/match_stats_sheet_service.dart';
import '../services/seed_service.dart';
import '../services/live_broadcast_mode.dart';
import '../services/live_radio_service.dart';
import '../services/live_radio_test_tone.dart';
import '../services/live_sfx_service.dart';
import '../services/motm_vote_service.dart';
import 'live_event_player_picker.dart';
import 'live_event_team_pick.dart';
import 'live_entry_error_sheet.dart';
import 'live_start_match_picker.dart';
import 'match_lineup_editor_sheet.dart';
import '../utils/remote_image_url.dart';
import '../utils/youtube_parser.dart';
import '../screens/admin/admin_palette.dart';
import 'dvcr_network_image.dart';

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
  final double cardRadius;
  final double controlRadius;
  final bool squareControls;
  final bool elevated;

  const LivePilotageThemeData({
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.gold,
    required this.red,
    this.cardRadius = 14,
    this.controlRadius = 8,
    this.squareControls = false,
    this.elevated = true,
  });

  /// Profil app — tribune ivoire, filet 1 px, commandes papier carrées.
  static final app = LivePilotageThemeData(
    surface: homeSurface,
    surfaceMuted: homeSurfaceMuted,
    text: homeText,
    muted: homeMutedText,
    border: homeBorder,
    accent: homeGreen,
    gold: homeGold,
    red: homeRed,
    cardRadius: 6,
    controlRadius: 6,
    squareControls: true,
    elevated: false,
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

TextStyle _pilotKicker(Color color) => GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: color,
    );

class _PilotPlate extends StatelessWidget {
  final LivePilotageThemeData pal;
  final Widget child;
  final bool onAir;

  const _PilotPlate({
    required this.pal,
    required this.child,
    this.onAir = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(pal.cardRadius),
        border: Border.all(
          color: onAir ? pal.accent.withValues(alpha: 0.42) : pal.border,
          width: 1,
        ),
        boxShadow: pal.elevated ? adminCardShadow : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: child,
      ),
    );
  }
}

class _PilotKickerRow extends StatelessWidget {
  final IconData icon;
  final String kicker;
  final String trailing;
  final Color iconColor;
  final Color trailingColor;
  final bool liveDot;

  const _PilotKickerRow({
    required this.icon,
    required this.kicker,
    required this.trailing,
    required this.iconColor,
    required this.trailingColor,
    this.liveDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(kicker, style: _pilotKicker(LivePilotageTheme.of(context).muted)),
        const Spacer(),
        if (liveDot) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: trailingColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(trailing, style: _pilotKicker(trailingColor)),
      ],
    );
  }
}

class _PilotHairline extends StatelessWidget {
  const _PilotHairline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1,
        color: LivePilotageTheme.of(context).border,
      ),
    );
  }
}

class _PilotCrest extends StatelessWidget {
  final String url;
  final String label;
  final double size;

  const _PilotCrest({
    required this.url,
    required this.label,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    final show = url.isNotEmpty && !shouldSkipNetworkImageUrl(url);
    final letter = label.trim().isEmpty
        ? '?'
        : label.trim().substring(0, 1).toUpperCase();
    final initials = ColoredBox(
      color: pal.surfaceMuted,
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.barlowCondensed(
            fontSize: size * 0.48,
            fontWeight: FontWeight.w800,
            color: pal.text,
            height: 1,
          ),
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pal.surface,
          shape: BoxShape.circle,
          border: Border.all(color: pal.border, width: 1),
        ),
        child: ClipOval(
          child: show
              ? Padding(
                  padding: const EdgeInsets.all(5),
                  child: DvcrNetworkImage(
                    url,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    cacheWidth: dvcrCrestCacheWidth(context, size),
                    placeholder: initials,
                    errorBuilder: (_, __, ___) => initials,
                  ),
                )
              : initials,
        ),
      ),
    );
  }
}

class _CardMarks extends StatelessWidget {
  final int yellow;
  final int red;

  const _CardMarks({required this.yellow, required this.red});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tick(const Color(0xFFE6B422), yellow),
        const SizedBox(width: 5),
        _tick(homeRed, red),
      ],
    );
  }

  Widget _tick(Color color, int count) {
    final empty = count <= 0;
    return Row(
      children: [
        Container(
          width: 8,
          height: 12,
          decoration: BoxDecoration(
            color: empty ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(1.5),
            border: Border.all(
              color: empty ? color.withValues(alpha: 0.28) : color,
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: GoogleFonts.barlowCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: empty ? color.withValues(alpha: 0.4) : color,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Panneau profil : chaque poste ne voit que sa partie, sans ouvrir le back.
class LiveMatchQuickPanel extends StatelessWidget {
  /// Saisie stats live (admin + statisticien).
  final bool canEditLiveStats;

  /// Démarrer / arrêter / score / chrono / XI. Admin + CM.
  final bool canPilot;

  /// Vote homme du match depuis le profil (admin + CM).
  final bool canLaunchMotm;

  /// Micro WHIP — commentateur + admin. Jamais le CM seul.
  final bool showRadio;

  /// Kit stories — CM + admin.
  final bool showStoryKit;

  const LiveMatchQuickPanel({
    super.key,
    this.canEditLiveStats = false,
    this.canPilot = true,
    this.canLaunchMotm = false,
    this.showRadio = false,
    this.showStoryKit = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          if (canPilot) return const _LiveMatchQuickStartPanel();
          return _ProfileWaitLiveColumn(
            showRadio: showRadio,
            showStats: canEditLiveStats,
          );
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        final matchId = (d['matchId'] as String? ?? '').trim();
        return LiveMatchQuickPilotageBody(
          key: ValueKey(
            matchId.isEmpty ? 'live-pilotage' : 'live-pilotage-$matchId',
          ),
          data: d,
          showMotmVotePanel: kIsWeb,
          canEditLiveStats: canEditLiveStats,
          canPilot: canPilot,
          canLaunchMotm: canLaunchMotm,
          showRadio: showRadio,
          showStoryKit: showStoryKit,
          radioOnly: showRadio && !canPilot && !canEditLiveStats,
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
    return LivePilotageTheme(
      data: LivePilotageThemeData.app,
      child: _PilotPlate(
        pal: LivePilotageThemeData.app,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PilotKickerRow(
              icon: Icons.sensors_rounded,
              kicker: 'LIVE · PILOTAGE',
              trailing: 'PRÊT',
              iconColor: homeGreenBright,
              trailingColor: homeGold,
            ),
            const _PilotHairline(),
            Text(
              'Aucun match en direct',
              style: GoogleFonts.barlowCondensed(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: homeText,
                height: 1.02,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lance le live : score, chrono, buteurs. Chaque poste ne voit que sa partie.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: homeMutedText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _starting ? null : _promptAndStartLive,
                style: FilledButton.styleFrom(
                  backgroundColor: homeGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: homeGreen.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'DÉMARRER LE MATCH',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
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

  final bool canEditLiveStats;
  final bool canPilot;
  final bool canLaunchMotm;

  /// Radio = poste commentateur / admin. Défaut off (jamais collé au score).
  final bool? showRadio;

  /// Stories = poste CM / admin. Défaut off.
  final bool? showStoryKit;

  /// Uniquement le tile micro / WHIP (desk commentateur).
  final bool radioOnly;

  const LiveMatchQuickPilotageBody({
    super.key,
    required this.data,
    this.showHeader = true,
    this.hideStatsBandeauToggle = false,
    this.showMotmVotePanel = false,
    this.useAdminStyle = false,
    this.canEditLiveStats = false,
    this.canPilot = true,
    this.canLaunchMotm = false,
    this.showRadio,
    this.showStoryKit,
    this.radioOnly = false,
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

  void _onTestToneChanged() {
    if (mounted) setState(() {});
  }

  void _onLiveSfxChanged() {
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
    LiveRadioTestTone.instance.addListener(_onTestToneChanged);
    LiveSfxService.instance.addListener(_onLiveSfxChanged);
    unawaited(LiveSfxService.instance.start());
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
    LiveRadioTestTone.instance.removeListener(_onTestToneChanged);
    LiveSfxService.instance.removeListener(_onLiveSfxChanged);
    _radioHlsOverrideCtrl.dispose();
    _chronoTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerButJingle() async {
    final sfx = LiveSfxService.instance;
    try {
      // Feedback local immédiat (anti-talk-over) — indépendant du retour casque.
      await sfx.playLocalImmediate('but');
      await SeedService.triggerLiveSfx('but');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jingle But — tu l’entends aussi, ne parle pas dessus',
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
            e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeRed,
        ),
      );
    }
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
    String? team;
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
    final logo1 = (widget.data['logo1'] ?? '').toString();
    final logo2 = (widget.data['logo2'] ?? '').toString();

    showModalBottomSheet<void>(
      useRootNavigator: true,
    context: context,
      backgroundColor: homeSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: MainShellInsets.sheetContentPadding(
            ctx,
            left: 16,
            top: 16,
            right: 16,
            extra: 16,
          ),
          child: SingleChildScrollView(
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
              const SizedBox(height: 6),
              Text(
                'Équipe, joueur de la compo, minute.',
                style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
              ),
              const SizedBox(height: 14),
              LiveEventTeamPick(
                team1: t1,
                team2: t2,
                logo1: logo1,
                logo2: logo2,
                selectedTeam: team,
                onSelect: (name) => setSt(() {
                  team = name;
                  playerCtrl.clear();
                }),
              ),
              if (team != null) ...[
                const SizedBox(height: 12),
                LiveEventPlayerPicker(
                  controller: playerCtrl,
                  label: type == 'goal' ? '$playerLabel *' : playerLabel,
                  source: LiveEventPlayerSource.fromLive(
                    live: widget.data,
                    selectedTeam: team!,
                  ),
                  onChanged: () => setSt(() {}),
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
                    final chosenTeam = team;
                    if (chosenTeam == null) return;
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
                        team: chosenTeam,
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
              ] else ...[
                const SizedBox(height: 14),
                Text(
                  'Clique l’équipe pour voir sa compo.',
                  style: GoogleFonts.inter(fontSize: 13, color: homeMutedText),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
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
    String? team;
    final t1 = '${widget.data['team1'] ?? 'Domicile'}';
    final t2 = '${widget.data['team2'] ?? 'Extérieur'}';
    final logo1 = (widget.data['logo1'] ?? '').toString();
    final logo2 = (widget.data['logo2'] ?? '').toString();

    showModalBottomSheet<void>(
      useRootNavigator: true,
    context: context,
      backgroundColor: homeSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final source = team == null
              ? null
              : LiveEventPlayerSource.fromLive(
                  live: widget.data,
                  selectedTeam: team!,
                );
          return Padding(
            padding: MainShellInsets.sheetContentPadding(
              ctx,
              left: 16,
              top: 16,
              right: 16,
              extra: 16,
            ),
            child: SingleChildScrollView(
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
                LiveEventTeamPick(
                  team1: t1,
                  team2: t2,
                  logo1: logo1,
                  logo2: logo2,
                  selectedTeam: team,
                  onSelect: (name) => setSt(() {
                    team = name;
                    outCtrl.clear();
                    inCtrl.clear();
                  }),
                ),
                if (source != null) ...[
                const SizedBox(height: 12),
                LiveEventPlayerPicker(
                  controller: outCtrl,
                  label: 'Sortant *',
                  source: source,
                  onChanged: () => setSt(() {}),
                ),
                const SizedBox(height: 10),
                LiveEventPlayerPicker(
                  controller: inCtrl,
                  label: 'Entrant *',
                  source: source,
                  onChanged: () => setSt(() {}),
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
                    try {
                      final chosenTeam = team;
                      if (chosenTeam == null) return;
                      await SeedService.addMatchEvent(
                        type: 'substitution',
                        team: chosenTeam,
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
                ] else ...[
                const SizedBox(height: 14),
                Text(
                  'Clique l’équipe pour voir sa compo.',
                  style: GoogleFonts.inter(fontSize: 13, color: homeMutedText),
                ),
                ],
                const SizedBox(height: 8),
              ],
            ),
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
    final tone = LiveRadioTestTone.instance;
    final hlsOverride = _radioHlsOverrideCtrl.text.trim();
    // Mode URL (override) : pas de publish WHIP — diffuseur externe.
    final externalOnly = enabled && hlsOverride.isNotEmpty;
    try {
      if (!enabled) {
        await tone.stop();
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

      // Radio ON = état Firestore + HLS seulement — pas de WHIP / micro auto.
      await SeedService.setRadioLive(
        true,
        hlsUrlOverride: hlsOverride.isEmpty ? null : hlsOverride,
      );

      if (!mounted) return;
      final msg = externalOnly
          ? 'Radio ON — URL externe (pas de micro WHIP)'
          : (kIsWeb
              ? 'Radio ON — Son test (web) ou Activer le micro (téléphone)'
              : 'Radio ON — clique Activer le micro pour parler');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
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
        await tone.stop();
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

  Future<void> _toggleSonTest() async {
    if (_radioOpInFlight) return;
    final tone = LiveRadioTestTone.instance;
    if (tone.isRunning) {
      await tone.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Son test arrêté',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
      return;
    }

    setState(() => _radioOpInFlight = true);
    try {
      final radioLive = (widget.data['radioLive'] as bool?) == true;
      if (!radioLive) {
        final hlsOverride = _radioHlsOverrideCtrl.text.trim();
        if (hlsOverride.isNotEmpty) {
          throw StateError(
            'Retire l’URL externe pour tester le WHIP MediaMTX',
          );
        }
        await SeedService.setRadioLive(true);
      }
      await tone.start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Son test en cours (bip → MediaMTX, ~20 s)',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      await tone.stop();
      if (!mounted) return;
      final msg = e is FirebaseFunctionsException
          ? ((e.message ?? '').trim().isNotEmpty
              ? e.message!
              : 'Son test impossible')
          : e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
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
    final tone = LiveRadioTestTone.instance;
    final publishing = radio.isPublishing;
    final connecting = radio.isConnecting || _radioOpInFlight;
    final muted = radio.isMuted;
    final whipUrl = (widget.data['radioWhipUrl'] ?? '').toString().trim();
    final externalMode = radioLive && whipUrl.isEmpty;
    final toneRunning = tone.isRunning;
    final showSonTest = kIsWeb &&
        (radioLive
            ? !externalMode
            : _radioHlsOverrideCtrl.text.trim().isEmpty);

    String subtitle;
    if (!radioLive) {
      subtitle =
          'MediaMTX WHIP + HLS — ou colle une URL (mode diffuseur externe)';
    } else if (externalMode) {
      subtitle = 'Radio ON — URL externe (écoute HLS / Icecast)';
    } else if (kIsWeb && toneRunning) {
      subtitle = 'Son test en cours (bip → MediaMTX)';
    } else if (kIsWeb) {
      subtitle =
          'Radio ON — Son test (web) ou Activer le micro (téléphone)';
    } else if (connecting) {
      subtitle = 'Connexion micro WHIP…';
    } else if (publishing) {
      subtitle = muted ? 'Micro coupé' : 'Micro en direct (WHIP → MediaMTX)';
    } else {
      subtitle = 'Radio ON — clique Activer le micro pour parler';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(pal.controlRadius),
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
                      style: _pilotKicker(pal.text),
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
              pal.squareControls
                  ? _PaperSwitch(
                      value: radioLive,
                      onChanged: connecting
                          ? null
                          : (v) {
                              _setRadioLive(v);
                            },
                    )
                  : Switch.adaptive(
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
            if (publishing) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retour casque',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: pal.text,
                          ),
                        ),
                        Text(
                          'Entends ta voix en local — casque recommandé (larsen HP)',
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
                    value: radio.monitorEnabled,
                    activeTrackColor: pal.accent.withAlpha(120),
                    activeThumbColor: pal.accent,
                    onChanged: connecting
                        ? null
                        : (v) async {
                            try {
                              await radio.setMonitorEnabled(v);
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
                          },
                  ),
                ],
              ),
              if (radio.monitorEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Volume retour',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: pal.muted,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: radio.monitorVolume,
                        onChanged: connecting
                            ? null
                            : (v) => radio.setMonitorVolume(v),
                        activeColor: pal.accent,
                        inactiveColor: pal.border,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
          if (showSonTest) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: connecting ? null : _toggleSonTest,
              icon: Icon(
                toneRunning
                    ? Icons.stop_circle_outlined
                    : Icons.graphic_eq_rounded,
                size: 16,
              ),
              label: Text(
                connecting && !toneRunning
                    ? 'Connexion…'
                    : (toneRunning ? 'Arrêter le son' : 'Son test'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: toneRunning ? pal.red : pal.accent,
                side: BorderSide(
                  color: (toneRunning ? pal.red : pal.accent).withAlpha(100),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'SONS LIVE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pal.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (LiveSfxService.instance.isPlaying) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: pal.gold.withAlpha(36),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.gold.withAlpha(120)),
              ),
              child: Text(
                'Jingle en cours — ne parle pas',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: pal.text,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: connecting || LiveSfxService.instance.isPlaying
                    ? null
                    : _triggerButJingle,
                icon: LiveSfxService.instance.isPlaying
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pal.gold,
                        ),
                      )
                    : const Icon(Icons.sports_soccer_rounded, size: 16),
                label: Text(
                  LiveSfxService.instance.isPlaying ? 'Jingle…' : 'But',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.gold,
                  side: BorderSide(color: pal.gold.withAlpha(120)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
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
        : 'Quel hors-jeu ?';

    showModalBottomSheet<void>(
      useRootNavigator: true,
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

  Future<void> _confirmEntryError(Map<String, dynamic> event) async {
    final ok = await showLiveEntryErrorConfirm(
      context,
      adminStyle: widget.useAdminStyle,
    );
    if (!ok) return;
    await SeedService.markEntryError(event);
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
    final logo1 = (d['logo1'] as String? ?? '').trim();
    final logo2 = (d['logo2'] as String? ?? '').trim();
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

    final showRadio =
        widget.radioOnly || (widget.showRadio ?? false);
    final showStories = widget.showStoryKit ?? false;
    final radioLive = (d['radioLive'] as bool?) == true;
    final showRadioTile =
        showRadio && !LiveBroadcastMode.isRetransmitted(d);

    if (widget.radioOnly) {
      return LivePilotageTheme(
        data: pal,
        child: _PilotPlate(
          pal: pal,
          onAir: radioLive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PilotKickerRow(
                icon: Icons.mic_rounded,
                kicker: 'RADIO',
                trailing: radioLive ? 'ON AIR' : 'MICRO',
                iconColor: pal.accent,
                trailingColor: radioLive ? pal.accent : pal.muted,
                liveDot: radioLive,
              ),
              const _PilotHairline(),
              showRadioTile
                  ? _buildRadioPilotageTile(pal: pal, radioLive: radioLive)
                  : Text(
                      'Radio indisponible sur une retransmission.',
                      style: GoogleFonts.inter(fontSize: 12, color: pal.muted),
                    ),
            ],
          ),
        ),
      );
    }

    if (!widget.canPilot) {
      return LivePilotageTheme(
        data: pal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showRadioTile) ...[
              _PilotPlate(
                pal: pal,
                onAir: radioLive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PilotKickerRow(
                      icon: Icons.mic_rounded,
                      kicker: 'RADIO',
                      trailing: radioLive ? 'ON AIR' : 'MICRO',
                      iconColor: pal.accent,
                      trailingColor: radioLive ? pal.accent : pal.muted,
                      liveDot: radioLive,
                    ),
                    const _PilotHairline(),
                    _buildRadioPilotageTile(pal: pal, radioLive: radioLive),
                  ],
                ),
              ),
              if (widget.canEditLiveStats) const SizedBox(height: 12),
            ],
            if (widget.canEditLiveStats)
              _StatsOnlyPilotageCard(
                showHeader: widget.showHeader && !showRadioTile,
                team1: t1,
                team2: t2,
                logo1: logo1,
                logo2: logo2,
                scoreHome: home,
                scoreAway: away,
                liveData: d,
                canEditLiveStats: true,
              ),
          ],
        ),
      );
    }

    return LivePilotageTheme(
      data: pal,
      child: _PilotPlate(
        pal: pal,
        onAir: true,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader) ...[
                _PilotKickerRow(
                  icon: Icons.sensors_rounded,
                  kicker: 'LIVE · PILOTAGE',
                  trailing: 'EN DIRECT',
                  iconColor: pal.accent,
                  trailingColor: pal.accent,
                  liveDot: true,
                ),
                const _PilotHairline(),
              ],
              _LiveScoreboard(
                team1: t1,
                team2: t2,
                logo1: logo1,
                logo2: logo2,
                home: home,
                away: away,
                yellowHome: yH,
                yellowAway: yA,
                redHome: rH,
                redAway: rA,
                phase: phase,
              ),
              if (streamOn && streamUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LiveYoutubeUrlCleanTile(url: streamUrl),
              ],
              if (showRadioTile) ...[
                const SizedBox(height: 12),
                _buildRadioPilotageTile(
                  pal: pal,
                  radioLive: radioLive,
                ),
              ],
              if (!widget.hideStatsBandeauToggle &&
                  widget.canEditLiveStats) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: pal.surfaceMuted,
                    borderRadius: BorderRadius.circular(pal.controlRadius),
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
                      pal.squareControls
                          ? _PaperSwitch(
                              value: statsEnabled,
                              onChanged: (v) async {
                                final mid =
                                    (d['matchId'] as String? ?? '').trim();
                                if (mid.isEmpty) return;
                                await MatchStatsSheetService.instance
                                    .setLiveStatsDisplay(mid, enabled: v);
                              },
                            )
                          : Switch.adaptive(
                              value: statsEnabled,
                              activeTrackColor: pal.accent.withAlpha(120),
                              activeThumbColor: pal.accent,
                              onChanged: (v) async {
                                final mid =
                                    (d['matchId'] as String? ?? '').trim();
                                if (mid.isEmpty) return;
                                await MatchStatsSheetService.instance
                                    .setLiveStatsDisplay(mid, enabled: v);
                              },
                            ),
                    ],
                  ),
                ),
              ],
              if (widget.canEditLiveStats) ...[
                const SizedBox(height: 8),
                _FaireLesStatsTile(liveData: d),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: pal.surfaceMuted,
                  borderRadius: BorderRadius.circular(pal.controlRadius),
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
                        'Composer le XI (Sedan + extérieur)',
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
              if (showStories) MatchStoryKitStrip(data: d),
              if (widget.canLaunchMotm && !widget.showMotmVotePanel) ...[
                const SizedBox(height: 12),
                _MotmLaunchTile(liveData: d),
              ],
              if (widget.showMotmVotePanel) ...[
                const SizedBox(height: 12),
                MotmVoteAdminPanel(data: d),
              ],
              const _PilotHairline(),
              Text('CHRONO', style: _pilotKicker(pal.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: phase.isMatchEnded
                        ? null
                        : (_running ? _pauseChrono : _startChrono),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: phase.isMatchEnded
                            ? pal.surfaceMuted
                            : (_running ? pal.surface : pal.accent),
                        borderRadius:
                            BorderRadius.circular(pal.controlRadius),
                        border: Border.all(
                          color: phase.isMatchEnded
                              ? pal.border
                              : (_running ? pal.accent : pal.accent),
                        ),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: _editMinuteDialog,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayTime,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: chronoLocked
                                  ? const Color(0xFFC45C12)
                                  : pal.text,
                              height: 0.95,
                              letterSpacing: -0.6,
                            ),
                          ),
                          Text(
                            'Tape pour régler la minute',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: pal.muted,
                            ),
                          ),
                        ],
                      ),
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
                    label: 'Début match',
                    onTap: phase.isMatchEnded ? null : () => _resetAndStart(0),
                  ),
                  _TinyChip(
                    label: 'Reprise match',
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
                        if (!mounted) return;
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
                        if (!mounted) return;
                        setState(() {
                          _elapsedSeconds = min * 60;
                          _lastSavedMinute = min;
                        });
                      },
                    ),
                ],
              ),
              const _PilotHairline(),
              Row(
                children: [
                  Text('FAITS DE JEU', style: _pilotKicker(pal.muted)),
                  const Spacer(),
                  Text(
                    'TAP = OUPS',
                    style: _pilotKicker(pal.muted.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ActionPill(
                label: 'AJOUTER BUT',
                bg: pal.gold,
                fg: pal.text,
                onTap: () => _showAddEventSheet('goal'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      label: 'JAUNE',
                      bg: const Color(0xFFE6B422),
                      fg: pal.text,
                      onTap: () => _showAddEventSheet('yellow'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionPill(
                      label: 'ROUGE',
                      bg: pal.red,
                      fg: pal.surface,
                      onTap: () => _showAddEventSheet('red'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      label: 'REMPLACEMENT',
                      bg: pal.surfaceMuted,
                      fg: pal.text,
                      border: pal.border,
                      onTap: _showSubstitutionSheet,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionPill(
                      label: 'BUT REFUSÉ',
                      bg: pal.surfaceMuted,
                      fg: pal.text,
                      border: pal.border,
                      onTap: () =>
                          _showRevokeGoalPicker('goal_disallowed'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ActionPill(
                      label: 'HORS-JEU',
                      bg: pal.surfaceMuted,
                      fg: pal.text,
                      border: pal.border,
                      onTap: () => _showRevokeGoalPicker('offside'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionPill(
                      label: 'VIDER',
                      bg: pal.surfaceMuted,
                      fg: pal.muted,
                      border: pal.border,
                      onTap: _confirmClearFacts,
                    ),
                  ),
                ],
              ),
              if (events.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Aucun fait de jeu',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: pal.muted,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                ...events.reversed.take(6).map((g) {
                  final typ = (g['type'] ?? '').toString();
                  final col = _eventColor(typ);
                  final canFix = LiveEntryError.canCorrect(typ);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: pal.surfaceMuted,
                      child: InkWell(
                        onTap: canFix ? () => _confirmEntryError(g) : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  "${g['minute'] ?? '?'}′",
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: col,
                                    height: 1,
                                  ),
                                ),
                              ),
                              Icon(_eventIcon(typ), size: 16, color: col),
                              const SizedBox(width: 8),
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
                            ],
                          ),
                        ),
                      ),
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
              const _PilotHairline(),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: _endingLive ? null : _confirmEndLive,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pal.red,
                    side: BorderSide(color: pal.red.withValues(alpha: 0.55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(pal.cardRadius),
                    ),
                  ),
                  child: _endingLive
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: pal.red.withAlpha(180),
                          ),
                        )
                      : Text(
                          'ARRÊTER LE LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: pal.red,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _LiveScoreboard extends StatelessWidget {
  final String team1;
  final String team2;
  final String logo1;
  final String logo2;
  final int home;
  final int away;
  final int yellowHome;
  final int yellowAway;
  final int redHome;
  final int redAway;
  final LiveMatchPhase phase;

  const _LiveScoreboard({
    required this.team1,
    required this.team2,
    required this.logo1,
    required this.logo2,
    required this.home,
    required this.away,
    required this.yellowHome,
    required this.yellowAway,
    required this.redHome,
    required this.redAway,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    final phaseChip = _phaseChip(pal);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _team(
                pal: pal,
                name: team1,
                logo: logo1,
                score: home,
                yellow: yellowHome,
                red: redHome,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 38),
              child: Text(
                '—',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: pal.border,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: _team(
                pal: pal,
                name: team2,
                logo: logo2,
                score: away,
                yellow: yellowAway,
                red: redAway,
              ),
            ),
          ],
        ),
        if (phaseChip != null) ...[
          const SizedBox(height: 10),
          phaseChip,
        ],
      ],
    );
  }

  Widget _team({
    required LivePilotageThemeData pal,
    required String name,
    required String logo,
    required int score,
    required int yellow,
    required int red,
  }) {
    return Column(
      children: [
        _PilotCrest(url: logo, label: name),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: pal.muted,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: GoogleFonts.barlowCondensed(
            fontSize: 52,
            fontWeight: FontWeight.w800,
            color: pal.text,
            height: 0.92,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 4),
        _CardMarks(yellow: yellow, red: red),
      ],
    );
  }

  Widget? _phaseChip(LivePilotageThemeData pal) {
    if (phase.isRegularFulltime) return _MiniStatus('FIN MATCH', pal.red);
    if (phase.isExtraFulltime) return _MiniStatus('FIN PROLONG.', pal.red);
    if (phase.isHalftime) {
      return const _MiniStatus('MI-TEMPS', Color(0xFFC45C12));
    }
    if (phase.isExtraHalftime) {
      return const _MiniStatus('MT PROLONG.', Color(0xFFC45C12));
    }
    if (phase.isExtraTimePlaying) {
      return _MiniStatus('PROLONG.', Colors.deepPurple.shade300);
    }
    return null;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.1,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(pal.controlRadius),
          color: pal.surface,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 0.4,
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
    final pal = LivePilotageTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(pal.controlRadius),
          border: Border.all(color: border ?? bg),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: fg,
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
        borderRadius: BorderRadius.circular(6),
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

class _PaperSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PaperSwitch({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value ? pal.accent : pal.surface,
          border: Border.all(color: value ? pal.accent : pal.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            value ? 'ON' : 'OFF',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: value ? pal.surface : pal.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MotmLaunchTile extends StatefulWidget {
  final Map<String, dynamic> liveData;

  const _MotmLaunchTile({required this.liveData});

  @override
  State<_MotmLaunchTile> createState() => _MotmLaunchTileState();
}

class _MotmLaunchTileState extends State<_MotmLaunchTile> {
  late ({List<String> team1Players, List<String> team2Players, bool ready})
      _lineup;

  @override
  void initState() {
    super.initState();
    _lineup = MotmVoteService.playersFromLineups(widget.liveData);
    _resolve();
  }

  @override
  void didUpdateWidget(_MotmLaunchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lineup = MotmVoteService.playersFromLineups(widget.liveData);
    if (!_lineup.ready) _resolve();
  }

  Future<void> _resolve() async {
    if (_lineup.ready) return;
    try {
      final resolved =
          await MotmVoteService.resolvePlayersFromLineups(widget.liveData);
      if (!mounted) return;
      setState(() => _lineup = resolved);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    final liveData = widget.liveData;
    final lineup = _lineup;
    final active = MotmVoteService.isVoteActive(liveData);
    final ready = lineup.ready;
    final n1 = lineup.team1Players.length;
    final n2 = lineup.team2Players.length;

    String compoLine;
    if (active) {
      compoLine = 'Vote en cours — 10 minutes.';
    } else if (ready) {
      compoLine =
          'Compo OK — $n1 / $n2 joueurs (XI + remplaçants, hors entraîneurs). '
          'Tu peux encore ajuster.';
    } else if (n1 + n2 > 0) {
      compoLine =
          'Compo incomplète ($n1 / $n2). Complète les deux équipes avant de lancer.';
    } else {
      compoLine =
          'Pas de composition : saisis les joueurs à la main dans le formulaire.';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pal.surfaceMuted,
        borderRadius: BorderRadius.circular(pal.controlRadius),
        border: Border.all(
          color: ready && !active ? pal.gold.withAlpha(120) : pal.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: pal.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'HOMME DU MATCH',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: pal.text,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  ready ? 'COMPO OK' : 'À COMPLÉTER',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: ready ? pal.accent : pal.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              compoLine,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: pal.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: active ? pal.surfaceMuted : pal.gold,
              child: InkWell(
                onTap: active
                    ? null
                    : () => MotmVoteAdminPanel.openLaunchSheetFor(
                          context,
                          liveData,
                        ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      active ? 'VOTE EN COURS' : 'LANCER L’HOMME DU MATCH',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: active ? pal.muted : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaireLesStatsTile extends StatelessWidget {
  final Map<String, dynamic> liveData;

  const _FaireLesStatsTile({required this.liveData});

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final mid = (liveData['matchId'] as String? ?? '').trim();
          if (mid.isNotEmpty) {
            await MatchStatsSheetService.instance.setLiveStatsDisplay(
              mid,
              enabled: true,
            );
          }
          if (!context.mounted) return;
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProfileLiveStatsScreen(),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pal.surface,
            border: Border.all(color: pal.accent.withAlpha(90), width: 1),
            borderRadius: BorderRadius.circular(pal.controlRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: pal.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAIRE LES STATS',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: pal.text,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Tirs, corners, possession — même saisie que l’admin.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: pal.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: pal.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsOnlyPilotageCard extends StatelessWidget {
  final bool showHeader;
  final String team1;
  final String team2;
  final String logo1;
  final String logo2;
  final int scoreHome;
  final int scoreAway;
  final Map<String, dynamic> liveData;
  final bool canEditLiveStats;

  const _StatsOnlyPilotageCard({
    required this.showHeader,
    required this.team1,
    required this.team2,
    this.logo1 = '',
    this.logo2 = '',
    required this.scoreHome,
    required this.scoreAway,
    required this.liveData,
    required this.canEditLiveStats,
  });

  @override
  Widget build(BuildContext context) {
    final pal = LivePilotageTheme.of(context);
    return _PilotPlate(
      pal: pal,
      onAir: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            _PilotKickerRow(
              icon: Icons.bar_chart_rounded,
              kicker: 'STATS LIVE',
              trailing: 'SAISIE',
              iconColor: pal.accent,
              trailingColor: pal.accent,
            ),
            const _PilotHairline(),
          ],
          Row(
            children: [
              _PilotCrest(url: logo1, label: team1, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: pal.muted,
                  ),
                ),
              ),
              Text(
                '$scoreHome — $scoreAway',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: pal.text,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: pal.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PilotCrest(url: logo2, label: team2, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saisie des stats — pas le cockpit score.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: pal.muted,
            ),
          ),
          if (canEditLiveStats) ...[
            const SizedBox(height: 12),
            _FaireLesStatsTile(liveData: liveData),
          ],
        ],
      ),
    );
  }
}

class _ProfileWaitLiveColumn extends StatelessWidget {
  final bool showRadio;
  final bool showStats;

  const _ProfileWaitLiveColumn({
    required this.showRadio,
    required this.showStats,
  });

  @override
  Widget build(BuildContext context) {
    if (!showRadio && !showStats) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRadio)
          const _ProfileWaitLiveHint(
            title: 'RADIO',
            body:
                'Pas de live. Ton micro s’affiche ici dès que le CM démarre le match.',
          ),
        if (showRadio && showStats) const SizedBox(height: 10),
        if (showStats)
          const _ProfileWaitLiveHint(
            title: 'STATS LIVE',
            body: 'Pas de live en cours. La saisie s’ouvre pendant le direct.',
          ),
      ],
    );
  }
}

class _ProfileWaitLiveHint extends StatelessWidget {
  final String title;
  final String body;

  const _ProfileWaitLiveHint({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return LivePilotageTheme(
      data: LivePilotageThemeData.app,
      child: _PilotPlate(
        pal: LivePilotageThemeData.app,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PilotKickerRow(
              icon: title == 'RADIO'
                  ? Icons.mic_rounded
                  : Icons.bar_chart_rounded,
              kicker: title,
              trailing: 'EN ATTENTE',
              iconColor: homeGreenBright,
              trailingColor: homeMutedText,
            ),
            const _PilotHairline(),
            Text(
              body,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: homeMutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
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
      return LiveEntryError.uiLabel;
    case 'goal_disallowed':
      return 'But refusé';
    default:
      return 'But';
  }
}
