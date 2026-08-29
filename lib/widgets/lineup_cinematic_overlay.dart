import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lineup_cinematic_plan.dart';
import '../models/sedan_squad.dart';
import '../navigation/lineup_cinematic_presence.dart';
import '../navigation/lineup_cinematic_rollout.dart';
import '../screens/home/home_palette.dart';
import '../screens/matches/matches_helpers.dart';
import '../services/feature_flags_service.dart';
import '../services/lineup_cinematic_service.dart';
import '../services/sedan_squad_service.dart';
import 'dvcr_network_image.dart';

/// Host mobile : XI réel si flag ON (direct + compo annoncée, 1× / appareil).
/// TEST admin sans flag ni live.
/// Monté dans MaterialApp.builder — Stack plein écran au-dessus du Navigator.
class LineupCinematicHost extends StatefulWidget {
  const LineupCinematicHost({super.key});

  @override
  State<LineupCinematicHost> createState() => _LineupCinematicHostState();
}

class _LineupCinematicHostState extends State<LineupCinematicHost>
    with WidgetsBindingObserver {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _matchSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _testSub;
  String? _watchingMatchId;
  String? _playingKey;
  LineupCinematicShow? _show;
  SedanSquad _squad = SedanSquad.empty;
  Map<String, dynamic>? _liveData;
  Map<String, dynamic>? _matchData;
  Map<String, dynamic>? _testData;
  bool _liveExists = false;
  bool _liveSnapSeen = false;
  bool _testSnapSeen = false;
  int _evalGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FeatureFlagsService.notifier.addListener(_onFlags);
    unawaited(_boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FeatureFlagsService.notifier.removeListener(_onFlags);
    unawaited(_liveSub?.cancel());
    unawaited(_matchSub?.cancel());
    unawaited(_testSub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_evaluate());
    }
  }

  void _onFlags() {
    if (!LineupCinematicRollout.isEnabled &&
        !(_playingKey?.startsWith('test_') ?? false)) {
      _dismiss();
      return;
    }
    unawaited(_evaluate());
  }

  Future<void> _boot() async {
    _testSub =
        LineupCinematicService.instance.testRef.snapshots().listen((snap) {
      _testSnapSeen = true;
      _testData = snap.data();
      unawaited(_evaluate());
    });
    _liveSub = FirebaseFirestore.instance
        .collection('live')
        .doc('current')
        .snapshots()
        .listen((snap) {
      _liveSnapSeen = true;
      _liveExists = snap.exists;
      _liveData = snap.data();
      final matchId = (_liveData?['matchId'] as String? ?? '').trim();
      _syncMatchWatch(matchId);
      unawaited(_evaluate());
    });
    try {
      _squad = await SedanSquadService.get();
    } catch (_) {}
    unawaited(_evaluate());
  }

  void _syncMatchWatch(String matchId) {
    if (matchId == _watchingMatchId) return;
    unawaited(_matchSub?.cancel());
    _watchingMatchId = matchId;
    _matchData = null;
    if (matchId.isEmpty || matchId.startsWith('live_')) return;
    _matchSub = FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .listen((snap) {
      _matchData = snap.data();
      unawaited(_evaluate());
    });
  }

  void _present(LineupCinematicShow show, String key) {
    if (!mounted || _playingKey != null) return;
    LineupCinematicPresence.instance.setOccupancy(
      LineupCinematicOccupancy.playing,
    );
    setState(() {
      _playingKey = key;
      _show = show;
    });
  }

  Future<void> _evaluate() async {
    if (!mounted) return;
    final gen = ++_evalGen;
    try {
      final playingTest = _playingKey?.startsWith('test_') ?? false;
      if (!playingTest && _playingKey != null && !_liveExists) {
        _dismiss();
      }

      if (_playingKey != null) return;

      final testNonce = LineupCinematicService.testNonce(_testData);
      if (testNonce != null && LineupCinematicService.isForceTest(_testData)) {
        final testPlayed =
            await LineupCinematicService.instance.hasPlayedTest(testNonce);
        if (!mounted || _playingKey != null) return;
        if (!testPlayed) {
          final show = await LineupCinematicService.instance.loadLatestForTest();
          if (!mounted || _playingKey != null) return;
          await LineupCinematicService.instance.markTestPlayed(testNonce);
          if (!mounted || _playingKey != null) return;
          _present(show, 'test_$testNonce');
          return;
        }
      }

      if (!LineupCinematicRollout.isEnabled) return;
      if (!_liveExists) return;

      final live = _liveData;
      final matchId = (live?['matchId'] as String? ?? '').trim();
      final id = matchId.isEmpty ? 'live' : matchId;
      final team1 = (live?['team1'] ?? _matchData?['team1'] ?? '').toString();
      final team2 = (live?['team2'] ?? _matchData?['team2'] ?? '').toString();
      var show = LineupCinematicService.instance.showFromLiveOrMatch(
        live: live,
        matchDoc: _matchData,
        matchId: id,
        team1: team1,
        team2: team2,
        squad: _squad,
      );
      if (show == null || show.savedAt == null) return;
      show = await LineupCinematicService.instance.resolveCrests(
        show,
        live: live,
        matchDoc: _matchData,
      );
      if (!mounted || _playingKey != null) return;
      final played = await LineupCinematicService.instance
          .hasPlayed(show.matchId, show.savedAt!);
      if (!mounted) return;
      if (!LineupCinematicService.instance.shouldAutoPlay(
        show: show,
        alreadyPlayed: played,
        liveRunning: _liveExists,
      )) {
        return;
      }
      await LineupCinematicService.instance.markPlayed(show.matchId, show.savedAt!);
      if (!mounted) return;
      if (!_liveExists) return;
      _present(
        show,
        LineupCinematicWindow.playKey(show.matchId, show.savedAt!),
      );
    } finally {
      if (!mounted || gen != _evalGen) return;
      LineupCinematicPresence.instance.setOccupancy(
        LineupCinematicSplashHold.afterEvaluate(
          overlayPlaying: _playingKey != null,
          launchInputsReady: _liveSnapSeen && _testSnapSeen,
        ),
      );
    }
  }

  void _dismiss() {
    if (_show == null && _playingKey == null) return;
    setState(() {
      _show = null;
      _playingKey = null;
    });
    LineupCinematicPresence.instance.setOccupancy(
      LineupCinematicOccupancy.idle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final show = _show;
    if (show == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: LineupCinematicOverlay(show: show, onDismiss: _dismiss),
    );
  }
}

Future<void> showLineupCinematicOverlay(
  BuildContext context,
  LineupCinematicShow show,
) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      barrierDismissible: true,
      barrierLabel: 'Fermer la composition',
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, __) {
        return LineupCinematicOverlay(
          show: show,
          onDismiss: () => Navigator.of(ctx, rootNavigator: true).maybePop(),
        );
      },
    ),
  );
}

/// Hold lecture par poste. Avant : 2200 ms unique (trop court).
abstract final class LineupCinematicCadence {
  static const open = Duration(milliseconds: 720);
  static const lineSwitch = Duration(milliseconds: 560);
  static const skipLock = Duration(milliseconds: 3000);

  static bool skipAllowed(Duration elapsed) => elapsed >= skipLock;

  static Duration holdFor(LineupCinematicStep step) {
    if (step.isTeamIntro) return const Duration(milliseconds: 3200);
    if (step.isSubstitutes) {
      final extra = step.players.length > 6 ? 500 : 0;
      return Duration(milliseconds: 4200 + extra);
    }
    final extra = ((step.players.length - 1) * 200).clamp(0, 600);
    return Duration(milliseconds: 3200 + extra);
  }
}

/// Feuille de match ivoire — en-tête vert, filets 1 px, Barlow Condensed.
class LineupCinematicOverlay extends StatefulWidget {
  final LineupCinematicShow show;
  final VoidCallback onDismiss;

  const LineupCinematicOverlay({
    super.key,
    required this.show,
    required this.onDismiss,
  });

  @override
  State<LineupCinematicOverlay> createState() => _LineupCinematicOverlayState();
}

class _LineupCinematicOverlayState extends State<LineupCinematicOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  Timer? _skipLock;
  bool _skipUnlocked = false;
  late final AnimationController _open;

  List<LineupCinematicStep> get _steps => widget.show.steps;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: LineupCinematicCadence.open,
    );
    _open.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(HapticFeedback.heavyImpact());
        _arm();
      }
    });
    _open.forward();
    _skipLock = Timer(LineupCinematicCadence.skipLock, () {
      if (!mounted) return;
      setState(() => _skipUnlocked = true);
    });
    unawaited(HapticFeedback.mediumImpact());
    unawaited(DvcrNetworkImage.warm(widget.show.sedanLogoUrl));
    unawaited(DvcrNetworkImage.warm(widget.show.opponentLogoUrl));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _skipLock?.cancel();
    _open.dispose();
    super.dispose();
  }

  void _requestDismiss() {
    if (!_skipUnlocked) return;
    widget.onDismiss();
  }

  void _arm() {
    if (!mounted || _steps.isEmpty) return;
    _timer?.cancel();
    final step = _steps[_index.clamp(0, _steps.length - 1)];
    _timer = Timer(LineupCinematicCadence.holdFor(step), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index >= _steps.length - 1) {
      widget.onDismiss();
      return;
    }
    setState(() => _index++);
    _arm();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = steps[_index.clamp(0, steps.length - 1)];
    final media = MediaQuery.of(context);
    final show = widget.show;
    return Material(
      color: homeGreen,
      child: AnimatedBuilder(
        animation: _open,
        builder: (context, _) {
          final t = _open.value.clamp(0.0, 1.0);
          final slam = Curves.easeOutBack.transform(t);
          final flash = t < 0.55
              ? 0.0
              : (1 - ((t - 0.55) / 0.45).clamp(0.0, 1.0)) * 0.18;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _requestDismiss,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: homeGreen),
                Padding(
                  padding: EdgeInsets.only(
                    top: media.padding.top,
                    bottom: media.padding.bottom,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, (1 - slam) * -(media.size.height * 0.72)),
                    child: _MatchSheet(
                      show: show,
                      step: step,
                      index: _index,
                      total: steps.length,
                      onSkip: _requestDismiss,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Opacity(
                    opacity: flash.clamp(0.0, 0.18),
                    child: const ColoredBox(color: homeGold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatchSheet extends StatelessWidget {
  final LineupCinematicShow show;
  final LineupCinematicStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;

  const _MatchSheet({
    required this.show,
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: homeBg,
        border: Border.all(color: homeGold, width: 1),
      ),
      child: CustomPaint(
        painter: const _PressCropMarksPainter(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetMasthead(show: show, onSkip: onSkip),
            Container(height: 1, color: homeGold),
            _ClubBanner(show: show, step: step),
            Container(height: 1, color: homeHairline),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: AnimatedSwitcher(
                  duration: LineupCinematicCadence.lineSwitch,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey('$index-${step.lineLabel}'),
                    child: _StepBody(show: show, step: step),
                  ),
                ),
              ),
            ),
            _SheetProgress(index: index, total: total),
          ],
        ),
      ),
    );
  }
}

class _SheetMasthead extends StatelessWidget {
  final LineupCinematicShow show;
  final VoidCallback onSkip;

  const _SheetMasthead({required this.show, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: homeGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            _SheetCrest(
              url: show.sedanLogoUrl,
              teamName: show.sedan.teamName,
              size: 36,
              isSedan: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLUB SPORTIF SEDAN ARDENNES',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: homeGold,
                    ),
                  ),
                  Text(
                    'FEUILLE DE MATCH',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: 0.6,
                      color: homeBg,
                    ),
                  ),
                ],
              ),
            ),
            if (show.opponent != null) ...[
              _SheetCrest(
                url: show.opponentLogoUrl,
                teamName: show.opponent!.teamName,
                size: 32,
                isSedan: false,
              ),
              const SizedBox(width: 4),
            ],
            TextButton(
              onPressed: onSkip,
              child: Text(
                'PASSER',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: homeBg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubBanner extends StatelessWidget {
  final LineupCinematicShow show;
  final LineupCinematicStep step;

  const _ClubBanner({required this.show, required this.step});

  @override
  Widget build(BuildContext context) {
    final url = LineupCinematicCrests.forTeam(show, isSedan: step.isSedan);
    return ColoredBox(
      color: homeSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            _SheetCrest(
              url: url,
              teamName: step.teamName,
              size: 44,
              isSedan: step.isSedan,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.isSedan ? 'ÉQUIPE' : 'ADVERSAIRE',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: homeGold,
                    ),
                  ),
                  Text(
                    step.teamName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: 0.4,
                      color: step.isSedan ? homeGreen : homeInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetCrest extends StatelessWidget {
  final String url;
  final String teamName;
  final double size;
  final bool isSedan;

  const _SheetCrest({
    required this.url,
    required this.teamName,
    required this.size,
    required this.isSedan,
  });

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isSedan ? homeGreen : homeBorder,
          width: 1,
        ),
      ),
      child: u.isEmpty
          ? _fallback()
          : DvcrNetworkImage(
              u,
              fit: BoxFit.contain,
              cacheWidth: dvcrCrestCacheWidth(context, size),
              errorBuilder: (_, __, ___) => _fallback(),
            ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        teamInitials(teamName),
        style: GoogleFonts.barlowCondensed(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
          color: isSedan ? homeGreen : homeMutedText,
        ),
      ),
    );
  }
}

class _SheetProgress extends StatelessWidget {
  final int index;
  final int total;

  const _SheetProgress({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 1,
                    color: i <= index ? homeGold : homeHairline,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Toucher n’importe où pour fermer',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: homeMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  final LineupCinematicShow show;
  final LineupCinematicStep step;

  const _StepBody({required this.show, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _Hairline()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                step.lineLabel,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: homeGold,
                ),
              ),
            ),
            const Expanded(child: _Hairline()),
          ],
        ),
        if (step.isTeamIntro) ...[
          const Spacer(),
          _IntroBlock(show: show, step: step),
          const Spacer(),
        ] else ...[
          const SizedBox(height: 10),
          _GridHeader(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: step.players.length,
              itemBuilder: (context, i) {
                return _PlayerRow(
                  player: step.players[i],
                  isSedan: step.isSedan,
                  striped: i.isOdd,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _IntroBlock extends StatelessWidget {
  final LineupCinematicShow show;
  final LineupCinematicStep step;

  const _IntroBlock({required this.show, required this.step});

  @override
  Widget build(BuildContext context) {
    final url = LineupCinematicCrests.forTeam(show, isSedan: step.isSedan);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        border: Border.all(color: homeGold, width: 1),
      ),
      child: Column(
        children: [
          _SheetCrest(
            url: url,
            teamName: step.teamName,
            size: 72,
            isSedan: step.isSedan,
          ),
          const SizedBox(height: 12),
          Text(
            step.teamName.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: 0.8,
              color: step.isSedan ? homeGreen : homeInk,
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 48, height: 1, color: homeGold),
          const SizedBox(height: 8),
          Text(
            'COMPOSITION  ·  N° ET NOMS',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: homeMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: homeInk, width: 1),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              'N°',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: homeMutedText,
              ),
            ),
          ),
          Container(width: 1, height: 12, color: homeHairline),
          const SizedBox(width: 12),
          Text(
            'NOM',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: homeMutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: homeHairline);
  }
}

class _PlayerRow extends StatelessWidget {
  final LineupCinematicPlayer player;
  final bool isSedan;
  final bool striped;

  const _PlayerRow({
    required this.player,
    required this.isSedan,
    required this.striped,
  });

  @override
  Widget build(BuildContext context) {
    final number = player.displayNumber.isEmpty ? '—' : player.displayNumber;
    return ColoredBox(
      color: striped ? homeSurface : Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: homeHairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                number,
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSedan ? homeGreen : homeInk,
                ),
              ),
            ),
            Container(width: 1, height: 28, color: homeHairline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.name.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: 0.3,
                  color: homeInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressCropMarksPainter extends CustomPainter {
  const _PressCropMarksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = homeGold
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const inset = 5.0;
    const arm = 11.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * arm, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * arm), paint);
    }

    corner(inset, inset, 1, 1);
    corner(size.width - inset, inset, -1, 1);
    corner(inset, size.height - inset, 1, -1);
    corner(size.width - inset, size.height - inset, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
