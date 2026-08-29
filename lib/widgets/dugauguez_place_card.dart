import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/home/presentation/widgets/home_palette.dart';
import '../models/dugauguez_place.dart';
import '../models/match_fan_poll_window.dart';
import '../models/match_model.dart';
import '../screens/chat_screen.dart' show AuthLockScreen;
import '../services/dugauguez_place_service.dart';
import '../services/live_state_service.dart';
import '../services/match_controller.dart';

/// Accueil : sticker domicile CSSA, H-30 → KO+20. Compteurs invisibles.
class DugauguezPlaceHomeSlot extends StatefulWidget {
  const DugauguezPlaceHomeSlot({super.key});

  @override
  State<DugauguezPlaceHomeSlot> createState() => _DugauguezPlaceHomeSlotState();
}

class _DugauguezPlaceHomeSlotState extends State<DugauguezPlaceHomeSlot> {
  Timer? _ticker;
  Timer? _edgeTimer;
  DateTime _now = DateTime.now();
  Map<String, dynamic>? _testData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _testSub;
  DateTime? _armedEdge;

  MatchModel? _catalogSedanHomeInWindow() {
    final pool = [
      ...MatchController.instance.upcoming,
      ...MatchController.instance.results,
    ];
    final hits = pool.where((m) {
      if (m.status == MatchStatus.finished) return false;
      if (!DugauguezPlaceGate.isSedanHome(m.team1)) return false;
      return DugauguezPlaceWindow.isOpen(kickoff: m.date, now: _now);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return hits.isEmpty ? null : hits.first;
  }

  void _armEdgeTimer() {
    DateTime? next;
    final inWindow = _catalogSedanHomeInWindow();
    if (inWindow != null) {
      next = MatchFanPollWindow.closesAt(inWindow.date);
    } else {
      final pool = [
        ...MatchController.instance.upcoming,
        ...MatchController.instance.results,
      ];
      final upcoming = pool.where((m) {
        if (m.status == MatchStatus.finished) return false;
        if (!DugauguezPlaceGate.isSedanHome(m.team1)) return false;
        return _now.isBefore(MatchFanPollWindow.opensAt(m.date));
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (upcoming.isNotEmpty) {
        next = MatchFanPollWindow.opensAt(upcoming.first.date);
      }
    }
    if (next == _armedEdge) return;
    _armedEdge = next;
    _edgeTimer?.cancel();
    if (next == null) return;
    final until = next.difference(DateTime.now());
    if (until.isNegative) return;
    _edgeTimer = Timer(until, () {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void initState() {
    super.initState();
    MatchController.instance.addListener(_onCatalog);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _testSub = DugauguezPlaceService.instance.testRef.snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => _testData = snap.data());
    });
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    MatchController.instance.removeListener(_onCatalog);
    _ticker?.cancel();
    _edgeTimer?.cancel();
    unawaited(_testSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final force = DugauguezPlaceService.isForceTest(_testData);
    _armEdgeTimer();
    final catalog = _catalogSedanHomeInWindow();
    if (catalog != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: DugauguezPlaceSticker(
          matchId: catalog.id,
          team1: catalog.team1,
          team2: catalog.team2,
        ),
      );
    }
    if (force) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: DugauguezPlaceSticker(
          matchId: DugauguezPlaceService.testMatchId,
          team1: 'CSSA',
          team2: 'TEST',
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveStateService.watchCurrentSnapshots(),
      builder: (context, liveSnap) {
        final live = liveSnap.data?.data();
        final liveRunning = liveSnap.data?.exists == true && live != null;
        final team1 = (live?['team1'] ?? '').toString();
        final team2 = (live?['team2'] ?? '').toString();
        final matchId = (live?['matchId'] as String? ?? '').trim();

        if (!liveRunning ||
            !DugauguezPlaceGate.isSedanHome(team1) ||
            matchId.isEmpty ||
            matchId.startsWith('live_')) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .snapshots(),
          builder: (context, matchSnap) {
            final kickoff = DugauguezPlaceService.parseDate(
              matchSnap.data?.data()?['date'],
            );
            final show = DugauguezPlaceGate.shouldShow(
              team1: team1,
              kickoff: kickoff,
              now: _now,
            );
            if (!show) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: DugauguezPlaceSticker(
                matchId: matchId,
                team1: team1,
                team2: team2,
              ),
            );
          },
        );
      },
    );
  }
}

/// Fiche match — même sticker, domicile CSSA, disparaît hors fenêtre.
class DugauguezPlaceFicheSlot extends StatefulWidget {
  final MatchModel match;

  const DugauguezPlaceFicheSlot({super.key, required this.match});

  @override
  State<DugauguezPlaceFicheSlot> createState() => _DugauguezPlaceFicheSlotState();
}

class _DugauguezPlaceFicheSlotState extends State<DugauguezPlaceFicheSlot> {
  Timer? _edgeTimer;

  void _armEdgeTimer() {
    _edgeTimer?.cancel();
    final now = DateTime.now();
    final opens = MatchFanPollWindow.opensAt(widget.match.date);
    final closes = MatchFanPollWindow.closesAt(widget.match.date);
    DateTime? next;
    if (now.isBefore(opens)) {
      next = opens;
    } else if (now.isBefore(closes)) {
      next = closes;
    }
    if (next == null) return;
    final until = next.difference(now);
    if (until.isNegative) return;
    _edgeTimer = Timer(until, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _armEdgeTimer();
  }

  @override
  void didUpdateWidget(covariant DugauguezPlaceFicheSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.date != widget.match.date) _armEdgeTimer();
  }

  @override
  void dispose() {
    _edgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = DugauguezPlaceGate.shouldShow(
      team1: widget.match.team1,
      kickoff: widget.match.date,
      now: DateTime.now(),
    );
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: DugauguezPlaceSticker(
        matchId: widget.match.id,
        team1: widget.match.team1,
        team2: widget.match.team2,
      ),
    );
  }
}

/// Pass jour de match — 2×2 tampons. Compteurs : admin / preview seulement.
class DugauguezPlaceSticker extends StatelessWidget {
  final String matchId;
  final String team1;
  final String team2;
  final bool preview;

  const DugauguezPlaceSticker({
    super.key,
    required this.matchId,
    this.team1 = '',
    this.team2 = '',
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    if (matchId.isEmpty && !preview) return const SizedBox.shrink();
    final session = matchId.isEmpty
        ? DugauguezPlaceService.testMatchId
        : matchId;
    if (!preview) {
      return _VoteShell(
        session: session,
        counts: DugauguezPlaceCounts.empty(),
        showCounts: false,
        hideWhenVoted: true,
        team1: team1,
        team2: team2,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DugauguezPlaceService.instance.summaryRef(session).snapshots(),
      builder: (context, sumSnap) {
        final counts = DugauguezPlaceCounts.fromMap(
          sumSnap.data?.data()?['counts'] as Map<String, dynamic>?,
        );
        return _VoteShell(
          session: session,
          counts: counts,
          showCounts: true,
          hideWhenVoted: false,
          team1: team1,
          team2: team2,
        );
      },
    );
  }
}

class _VoteShell extends StatelessWidget {
  final String session;
  final DugauguezPlaceCounts counts;
  final bool showCounts;
  final bool hideWhenVoted;
  final String team1;
  final String team2;

  const _VoteShell({
    required this.session,
    required this.counts,
    required this.showCounts,
    required this.hideWhenVoted,
    required this.team1,
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _StickerBody(
        counts: counts,
        showCounts: showCounts,
        hideWhenVoted: hideWhenVoted,
        selected: null,
        onPick: (_) => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const AuthLockScreen(),
          ),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DugauguezPlaceService.instance.votesCol(session).doc(uid).snapshots(),
      builder: (context, voteSnap) {
        final voted = voteSnap.data?.exists == true;
        if (hideWhenVoted && voted) return const SizedBox.shrink();
        final selected = DugauguezPlaceChoiceCodec.fromId(
          voteSnap.data?.data()?['choice'] as String?,
        );
        return _StickerBody(
          counts: counts,
          showCounts: showCounts,
          hideWhenVoted: hideWhenVoted,
          selected: selected,
          onPick: (choice) => DugauguezPlaceService.instance.castVote(
            matchId: session,
            choice: choice,
            team1: team1,
            team2: team2,
          ),
        );
      },
    );
  }
}

class _StickerBody extends StatefulWidget {
  final DugauguezPlaceCounts counts;
  final bool showCounts;
  final bool hideWhenVoted;
  final DugauguezPlaceChoice? selected;
  final Future<void> Function(DugauguezPlaceChoice) onPick;

  const _StickerBody({
    required this.counts,
    required this.showCounts,
    required this.hideWhenVoted,
    required this.selected,
    required this.onPick,
  });

  @override
  State<_StickerBody> createState() => _StickerBodyState();
}

class _StickerBodyState extends State<_StickerBody> {
  bool _busy = false;
  bool _gone = false;

  Future<void> _tap(DugauguezPlaceChoice choice) async {
    if (_busy || _gone) return;
    setState(() => _busy = true);
    try {
      await widget.onPick(choice);
      if (mounted && widget.hideWhenVoted) {
        setState(() {
          _gone = true;
          _busy = false;
        });
        return;
      }
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } finally {
      if (mounted && !_gone) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideWhenVoted && (_gone || widget.selected != null)) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: const _TicketNotchPainter(),
      child: Container(
        decoration: BoxDecoration(
          color: homeSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: homeGold.withAlpha(140), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: homeGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              ),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -0.08,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: homeGold,
                        border: Border.all(color: const Color(0xFFE8D48A)),
                      ),
                      child: Text(
                        'J’Y SUIS',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: homeInk,
                          letterSpacing: 1.1,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'OÙ TU REGARDES LE MATCH, TOI ?',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stamp(
                          choice: DugauguezPlaceChoice.home,
                          icon: Icons.weekend_outlined,
                          selected: widget.selected,
                          counts: widget.counts,
                          showCounts: widget.showCounts,
                          onTap: () => _tap(DugauguezPlaceChoice.home),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stamp(
                          choice: DugauguezPlaceChoice.stadium,
                          icon: Icons.stadium_outlined,
                          selected: widget.selected,
                          counts: widget.counts,
                          showCounts: widget.showCounts,
                          onTap: () => _tap(DugauguezPlaceChoice.stadium),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Stamp(
                          choice: DugauguezPlaceChoice.virage,
                          icon: Icons.campaign_outlined,
                          selected: widget.selected,
                          counts: widget.counts,
                          showCounts: widget.showCounts,
                          onTap: () => _tap(DugauguezPlaceChoice.virage),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stamp(
                          choice: DugauguezPlaceChoice.virageExt,
                          icon: Icons.groups_outlined,
                          selected: widget.selected,
                          counts: widget.counts,
                          showCounts: widget.showCounts,
                          onTap: () => _tap(DugauguezPlaceChoice.virageExt),
                        ),
                      ),
                    ],
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

class _Stamp extends StatelessWidget {
  final DugauguezPlaceChoice choice;
  final IconData icon;
  final DugauguezPlaceChoice? selected;
  final DugauguezPlaceCounts counts;
  final bool showCounts;
  final VoidCallback onTap;

  const _Stamp({
    required this.choice,
    required this.icon,
    required this.selected,
    required this.counts,
    required this.showCounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mine = selected == choice;
    final total = counts.total;
    final n = counts.of(choice);
    final pct = counts.percentOf(choice);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: mine ? homeGreen : homeBg,
            border: Border.all(
              color: mine ? homeGold : homeBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                size: 22,
                color: mine ? homeGold : homeGreen,
              ),
              const SizedBox(height: 6),
              Text(
                choice.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: mine ? Colors.white : homeInk,
                  height: 1.05,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                choice.hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: mine
                      ? Colors.white.withAlpha(190)
                      : homeMutedText,
                  height: 1.2,
                ),
              ),
              if (showCounts && total > 0) ...[
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  color: mine
                      ? Colors.white.withAlpha(40)
                      : homeHairline,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: math.max(pct / 100, 0.04),
                    child: ColoredBox(
                      color: mine ? homeGold : homeGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct% · $n',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: mine ? homeGold : homeGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketNotchPainter extends CustomPainter {
  const _TicketNotchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()..color = homeBg;
    const r = 7.0;
    canvas.drawCircle(Offset(0, size.height * 0.38), r, hole);
    canvas.drawCircle(Offset(size.width, size.height * 0.38), r, hole);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Barres admin — ivoire, filet 1 px, pas un dashboard SaaS.
class DugauguezPlaceComparisonBars extends StatelessWidget {
  final DugauguezPlaceCounts counts;
  final String? matchLabel;

  const DugauguezPlaceComparisonBars({
    super.key,
    required this.counts,
    this.matchLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = counts.total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: homeSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: homeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (matchLabel ?? 'COMPARAISON').toUpperCase(),
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: homeGreen,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0
                ? 'Aucun vote pour l’instant.'
                : '$total vote${total > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: homeMutedText,
            ),
          ),
          const SizedBox(height: 12),
          for (final c in DugauguezPlaceChoice.values) ...[
            _AdminBarRow(
              choice: c,
              count: counts.of(c),
              percent: counts.percentOf(c),
              total: total,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AdminBarRow extends StatelessWidget {
  final DugauguezPlaceChoice choice;
  final int count;
  final int percent;
  final int total;

  const _AdminBarRow({
    required this.choice,
    required this.count,
    required this.percent,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final frac = total <= 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                choice.label,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: homeInk,
                ),
              ),
            ),
            Text(
              '$percent%  ·  $count',
              style: GoogleFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: homeGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: homeBg,
            border: Border.all(color: homeHairline, width: 1),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: frac.clamp(0.0, 1.0),
            child: const ColoredBox(color: homeGreen),
          ),
        ),
      ],
    );
  }
}
