import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/match_model.dart';
import '../../services/match_controller.dart';
import '../../services/match_weather_service.dart';
import 'match_detail_theme.dart';

/// Prochain match CSSA : picto + °C au coup d’envoi + phrase club.
class MatchKickoffWeatherLine extends StatefulWidget {
  final MatchModel match;

  const MatchKickoffWeatherLine({super.key, required this.match});

  @override
  State<MatchKickoffWeatherLine> createState() =>
      _MatchKickoffWeatherLineState();
}

class _MatchKickoffWeatherLineState extends State<MatchKickoffWeatherLine> {
  @override
  void initState() {
    super.initState();
    MatchController.instance.addListener(_onCatalog);
    _ensure();
  }

  @override
  void didUpdateWidget(covariant MatchKickoffWeatherLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id ||
        oldWidget.match.date != widget.match.date) {
      _ensure();
    }
  }

  @override
  void dispose() {
    MatchController.instance.removeListener(_onCatalog);
    super.dispose();
  }

  void _onCatalog() => _ensure();

  void _ensure() {
    if (!MatchWeatherService.isMatchDayWindow(widget.match)) return;
    unawaited(MatchWeatherService.instance.ensureForMatch(widget.match));
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
        final wx = MatchWeatherService.instance;
        if (!wx.readingFor(widget.match)) return const SizedBox.shrink();
        final icon = pictogramFor(wx.mode);
        final temp = wx.temperatureC;
        if (icon == null || temp == null) return const SizedBox.shrink();
        final line = MatchWeatherService.clubLineFor(wx.mode, temp);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: 1, color: MatchDetailTheme.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: MatchDetailTheme.green),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$temp°',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MatchDetailTheme.text,
                            ),
                          ),
                          if (line != null)
                            TextSpan(
                              text: '  ·  $line',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: MatchDetailTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
IconData? pictogramFor(MatchWeatherMode mode) {
  switch (mode) {
    case MatchWeatherMode.none:
      return null;
    case MatchWeatherMode.clear:
      return Icons.wb_sunny_outlined;
    case MatchWeatherMode.sunClouds:
      return Icons.wb_cloudy_outlined;
    case MatchWeatherMode.clouds:
    case MatchWeatherMode.fog:
      return Icons.cloud_outlined;
    case MatchWeatherMode.rain:
      return Icons.water_drop_outlined;
    case MatchWeatherMode.storm:
      return Icons.thunderstorm_outlined;
    case MatchWeatherMode.snow:
      return Icons.ac_unit;
  }
}
