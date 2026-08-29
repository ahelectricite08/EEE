import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/quiz_raffle.dart';
import '../screens/live/theme/tv_theme.dart';
import '../screens/live/theme/tv_type.dart';

const _kRowH = 44.0;
const _kViewportH = 132.0;

/// Tombola papier — défilement des bons votants, stop sur le gagnant Firestore.
/// Surface principale : DVCR TV / Live (fans). Aussi utilisé en Direct admin.
class QuizRaffleTombolaReveal extends StatelessWidget {
  final String winnerUid;
  final String winnerName;
  final List<String> eligibleNames;

  const QuizRaffleTombolaReveal({
    super.key,
    required this.winnerUid,
    required this.winnerName,
    required this.eligibleNames,
  });

  @override
  Widget build(BuildContext context) {
    final hasWinner = winnerUid.trim().isNotEmpty;
    if (!hasWinner) {
      return Text(
        'Personne n’a trouvé — pas de gagnant.',
        style: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: TvTheme.textMuted,
          height: 1.1,
        ),
      );
    }

    if (!QuizRaffleLogic.shouldRollTombola(
      winnerUid: winnerUid,
      eligibleNames: eligibleNames,
    )) {
      return _WinnerLine(name: winnerName);
    }

    return _TombolaRoll(
      eligibleNames: eligibleNames,
      winnerName: winnerName,
    );
  }
}

class _WinnerLine extends StatelessWidget {
  final String name;

  const _WinnerLine({required this.name});

  @override
  Widget build(BuildContext context) {
    final n = name.trim().isEmpty ? 'Membre' : name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GAGNANT', style: TvType.kicker),
        const SizedBox(height: 6),
        Text(
          n,
          style: GoogleFonts.barlowCondensed(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: TvTheme.green,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _TombolaRoll extends StatefulWidget {
  final List<String> eligibleNames;
  final String winnerName;

  const _TombolaRoll({
    required this.eligibleNames,
    required this.winnerName,
  });

  @override
  State<_TombolaRoll> createState() => _TombolaRollState();
}

class _TombolaRollState extends State<_TombolaRoll> {
  final _controller = ScrollController();
  late final List<String> _reel;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _reel = QuizRaffleLogic.buildTombolaReel(
      eligibleNames: widget.eligibleNames,
      winnerName: widget.winnerName,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _targetOffset {
    final last = _reel.length - 1;
    final raw = last * _kRowH - (_kViewportH - _kRowH) / 2;
    return raw < 0 ? 0 : raw;
  }

  Future<void> _run() async {
    if (!mounted || !_controller.hasClients) return;
    await _controller.animateTo(
      _targetOffset,
      duration: const Duration(milliseconds: 3200),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_settled ? 'GAGNANT' : 'TIRAGE', style: TvType.kicker),
        const SizedBox(height: 8),
        AbsorbPointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TvTheme.surface,
              borderRadius: BorderRadius.circular(TvTheme.paperRadius),
              border: Border.all(color: TvTheme.hairline, width: 1),
            ),
            child: SizedBox(
              height: _kViewportH,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    itemExtent: _kRowH,
                    itemCount: _reel.length,
                    itemBuilder: (context, i) {
                      final last = i == _reel.length - 1;
                      final highlight = _settled && last;
                      return ColoredBox(
                        color: highlight
                            ? TvTheme.surfaceMuted
                            : Colors.transparent,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              _reel[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.barlowCondensed(
                                fontSize: highlight ? 26 : 20,
                                fontWeight: FontWeight.w800,
                                color: highlight
                                    ? TvTheme.green
                                    : TvTheme.text,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const IgnorePointer(
                    child: Align(
                      alignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: TvTheme.border, width: 1),
                            bottom: BorderSide(color: TvTheme.border, width: 1),
                          ),
                        ),
                        child: SizedBox(height: _kRowH, width: double.infinity),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _settled
              ? 'Gagnant : ${widget.winnerName.trim().isEmpty ? 'Membre' : widget.winnerName.trim()}'
              : 'Les noms défilent…',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: TvTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
