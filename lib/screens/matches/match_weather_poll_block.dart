import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/match_fan_poll_window.dart';
import '../../models/match_model.dart';
import '../../models/match_weather_poll.dart';
import '../../services/match_controller.dart';
import '../../services/match_weather_poll_service.dart';
import '../../services/match_weather_service.dart';
import 'match_detail_theme.dart';

/// Sous la ligne météo, prochain CSSA seulement.
class MatchWeatherPollBlock extends StatefulWidget {
  final MatchModel match;

  const MatchWeatherPollBlock({super.key, required this.match});

  @override
  State<MatchWeatherPollBlock> createState() => _MatchWeatherPollBlockState();
}

class _MatchWeatherPollBlockState extends State<MatchWeatherPollBlock> {
  late Stream<MatchWeatherPollSnapshot> _votes;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _votes = MatchWeatherPollService.instance.watch(widget.match.id);
    _armWindowTimers();
  }

  @override
  void didUpdateWidget(covariant MatchWeatherPollBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) {
      _votes = MatchWeatherPollService.instance.watch(widget.match.id);
    }
    if (oldWidget.match.date != widget.match.date) {
      _armWindowTimers();
    }
  }

  void _armWindowTimers() {
    _closeTimer?.cancel();
    final now = DateTime.now();
    final closes = MatchFanPollWindow.closesAt(widget.match.date);
    if (now.isBefore(closes)) {
      _closeTimer = Timer(closes.difference(now), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MatchWeatherService.instance,
        MatchController.instance,
      ]),
      builder: (context, _) {
        if (!MatchWeatherService.isMatchDayWindow(widget.match)) {
          return const SizedBox.shrink();
        }
        if (!MatchWeatherPoll.isOpen(widget.match.date)) {
          return const SizedBox.shrink();
        }
        final wx = MatchWeatherService.instance;
        final prompt = MatchWeatherPoll.promptFor(wx.mode, wx.temperatureC);
        final options = MatchWeatherPoll.optionsFor(wx.mode, wx.temperatureC);
        return StreamBuilder<MatchWeatherPollSnapshot>(
          stream: _votes,
          builder: (context, snap) {
            final data = snap.data ?? const MatchWeatherPollSnapshot();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, color: MatchDetailTheme.hairline),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: _PollBody(
                    match: widget.match,
                    prompt: prompt,
                    options: options,
                    weatherMode: wx.mode,
                    temperatureC: wx.temperatureC,
                    snapshot: data,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PollBody extends StatefulWidget {
  final MatchModel match;
  final String prompt;
  final List<MatchWeatherPollOption> options;
  final MatchWeatherMode weatherMode;
  final int? temperatureC;
  final MatchWeatherPollSnapshot snapshot;

  const _PollBody({
    required this.match,
    required this.prompt,
    required this.options,
    required this.weatherMode,
    required this.temperatureC,
    required this.snapshot,
  });

  @override
  State<_PollBody> createState() => _PollBodyState();
}

class _PollBodyState extends State<_PollBody> {
  bool _saving = false;
  String? _pendingId;

  Future<void> _cast(MatchWeatherPollOption option) async {
    if (_saving) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _toast('Connecte-toi pour voter.');
      return;
    }
    if (widget.snapshot.myOptionId == option.id) return;
    setState(() {
      _saving = true;
      _pendingId = option.id;
    });
    try {
      await MatchWeatherPollService.instance.vote(
        matchId: widget.match.id,
        optionId: option.id,
        kickoff: widget.match.date,
        mode: widget.weatherMode,
        tempC: widget.temperatureC,
      );
    } catch (e) {
      if (mounted) {
        _toast(MatchWeatherPollService.userFacingWriteError(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pendingId = null;
        });
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: MatchDetailTheme.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = _pendingId ?? widget.snapshot.myOptionId;
    final options = widget.options;
    final tally = MatchWeatherPoll.tallyLine(
      widget.snapshot.counts,
      visible: options,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.prompt.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            height: 1.2,
            color: MatchDetailTheme.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _OptionRow(
            option: options[i],
            selected: mine == options[i].id,
            onTap: () => _cast(options[i]),
          ),
        ],
        if (tally.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            tally,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: MatchDetailTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final MatchWeatherPollOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? MatchDetailTheme.sedanPaper
                : MatchDetailTheme.surface,
            border: Border.all(
              color: selected
                  ? MatchDetailTheme.green
                  : MatchDetailTheme.hairline,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  size: 16,
                  color: selected
                      ? MatchDetailTheme.green
                      : MatchDetailTheme.textSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? MatchDetailTheme.green
                          : MatchDetailTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
