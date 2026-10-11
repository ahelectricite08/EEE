import 'dart:async';

import 'package:flutter/material.dart';

import '../models/lineup_prediction.dart';

/// Compte à rebours live jusqu’au verrou du XI probable.
class LineupLockCountdown extends StatefulWidget {
  final DateTime kickoff;
  final TextStyle? style;
  final bool locked;

  const LineupLockCountdown({
    super.key,
    required this.kickoff,
    this.style,
    this.locked = false,
  });

  @override
  State<LineupLockCountdown> createState() => _LineupLockCountdownState();
}

class _LineupLockCountdownState extends State<LineupLockCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant LineupLockCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kickoff != widget.kickoff ||
        oldWidget.locked != widget.locked) {
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (widget.locked) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.locked
        ? 'La composition est verrouillée.'
        : LineupPrediction.lockCountdownLabel(widget.kickoff);
    return Text(text, style: widget.style);
  }
}