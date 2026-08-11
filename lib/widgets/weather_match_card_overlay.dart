import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/match_weather_service.dart';

/// Couche météo animée — à placer **entre** l’image stade et le contenu UI.
/// Lit uniquement le cache [MatchWeatherService] (aucun fetch).
class WeatherMatchCardLayer extends StatefulWidget {
  const WeatherMatchCardLayer({super.key});

  @override
  State<WeatherMatchCardLayer> createState() => _WeatherMatchCardLayerState();
}

class _WeatherMatchCardLayerState extends State<WeatherMatchCardLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  MatchWeatherMode _lastMode = MatchWeatherMode.none;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / 1e6;
    });
    MatchWeatherService.instance.addListener(_onWeatherChanged);
    _syncTicker(MatchWeatherService.instance.mode);
  }

  void _onWeatherChanged() {
    _syncTicker(MatchWeatherService.instance.mode);
  }

  void _syncTicker(MatchWeatherMode mode) {
    final active = mode != MatchWeatherMode.none;
    if (active && !_ticker.isActive) {
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
    _lastMode = mode;
  }

  @override
  void dispose() {
    MatchWeatherService.instance.removeListener(_onWeatherChanged);
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MatchWeatherService.instance,
        _seconds,
      ]),
      builder: (context, _) {
        final mode = MatchWeatherService.instance.mode;
        if (mode != _lastMode) {
          _syncTicker(mode);
        }
        if (mode == MatchWeatherMode.none) {
          return const SizedBox.shrink();
        }
        return CustomPaint(
          painter: _WeatherPainter(
            mode: mode,
            seconds: _seconds.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RainDrop {
  final double xNorm;
  final double phase;
  final double speed;
  final double len;
  final double thickness;
  final double alpha;

  const _RainDrop({
    required this.xNorm,
    required this.phase,
    required this.speed,
    required this.len,
    required this.thickness,
    required this.alpha,
  });
}

class _Snowflake {
  final double xNorm;
  final double phase;
  final double speed;
  final double size;
  final double sway;

  const _Snowflake({
    required this.xNorm,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
  });
}

class _WeatherPainter extends CustomPainter {
  final MatchWeatherMode mode;
  final double seconds;

  static final List<_RainDrop> _rain = _buildRain(36);
  static final List<_RainDrop> _stormRain = _buildRain(52);
  static final List<_Snowflake> _snow = _buildSnow(22);

  _WeatherPainter({required this.mode, required this.seconds});

  static List<_RainDrop> _buildRain(int n) {
    final rnd = math.Random(42);
    return List.generate(n, (_) {
      return _RainDrop(
        xNorm: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.85 + rnd.nextDouble() * 1.15,
        len: 8 + rnd.nextDouble() * 10,
        thickness: 1.0 + rnd.nextDouble() * 0.8,
        alpha: 0.10 + rnd.nextDouble() * 0.14,
      );
    });
  }

  static List<_Snowflake> _buildSnow(int n) {
    final rnd = math.Random(99);
    return List.generate(n, (_) {
      return _Snowflake(
        xNorm: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.18 + rnd.nextDouble() * 0.28,
        size: 1.2 + rnd.nextDouble() * 2.0,
        sway: 5 + rnd.nextDouble() * 10,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case MatchWeatherMode.clear:
        _paintSun(canvas, size);
      case MatchWeatherMode.clouds:
        _paintClouds(canvas, size);
      case MatchWeatherMode.rain:
        _paintRain(canvas, size, _rain, storm: false);
      case MatchWeatherMode.storm:
        _paintStormClouds(canvas, size);
        _paintRain(canvas, size, _stormRain, storm: true);
        _paintLightningFlash(canvas, size);
      case MatchWeatherMode.snow:
        _paintSnow(canvas, size);
      case MatchWeatherMode.fog:
        _paintFog(canvas, size);
      case MatchWeatherMode.none:
        break;
    }
  }

  void _paintSun(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.08, size.height * 0.06);
    final shimmer = 0.5 + 0.5 * math.sin(seconds * 1.4);

    // Halo doux (pas un voile plein-carte)
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withValues(alpha: 0.16 + 0.07 * shimmer),
          const Color(0xFFFFB347).withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: origin, radius: size.shortestSide * 0.85));
    canvas.drawCircle(origin, size.shortestSide * 0.85, halo);

    // Rayons animés (rotation lente + pulsation longueur)
    final rayPaint = Paint()
      ..style = PaintingStyle.fill;
    final nRays = 7;
    for (var i = 0; i < nRays; i++) {
      final base = -0.15 + (i / (nRays - 1)) * 1.05;
      final a = base + math.sin(seconds * 0.35 + i * 0.4) * 0.03;
      final spread = 0.045 + 0.01 * math.sin(seconds * 1.1 + i);
      final reach = size.longestSide * (0.95 + 0.08 * math.sin(seconds * 0.9 + i));
      final alpha = 0.05 + 0.04 * (0.5 + 0.5 * math.sin(seconds * 1.3 + i * 0.7));
      rayPaint.color = const Color(0xFFFFD27A).withValues(alpha: alpha);
      final p1 = origin;
      final p2 = origin + Offset(math.cos(a - spread) * reach, math.sin(a - spread) * reach);
      final p3 = origin + Offset(math.cos(a + spread) * reach, math.sin(a + spread) * reach);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(path, rayPaint);
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    void puff(double x, double y, double s, double a) {
      final paint = Paint()..color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), s, paint);
      canvas.drawCircle(Offset(x + s * 0.75, y + 2), s * 0.78, paint);
      canvas.drawCircle(Offset(x - s * 0.6, y + 3), s * 0.68, paint);
      canvas.drawCircle(Offset(x + s * 0.15, y - s * 0.35), s * 0.55, paint);
    }

    final w = size.width + 140.0;
    final d1 = (seconds * 18) % w;
    final d2 = (seconds * 11 + 60) % w;
    final d3 = (seconds * 8 + 120) % w;

    puff(d1 - 70, size.height * 0.16, 22, 0.09);
    puff(d2 - 70, size.height * 0.34, 18, 0.07);
    puff(d3 - 70, size.height * 0.52, 20, 0.08);
    puff((d1 * 0.6 + 40) % w - 70, size.height * 0.72, 14, 0.05);
  }

  void _paintStormClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1A1F28).withValues(alpha: 0.10);
    final drift = (seconds * 10) % (size.width + 100);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(drift - 40, size.height * 0.12),
        width: 160,
        height: 48,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset((drift * 0.7 + 80) % (size.width + 100) - 40, size.height * 0.28),
        width: 130,
        height: 40,
      ),
      paint,
    );
  }

  void _paintRain(
    Canvas canvas,
    Size size,
    List<_RainDrop> drops, {
    required bool storm,
  }) {
    final slant = storm ? 3.2 : 2.2;
    for (final d in drops) {
      final cycle = ((seconds * d.speed) + d.phase) % 1.0;
      final y = cycle * (size.height + 28) - 14;
      final x = d.xNorm * size.width + cycle * slant * 6;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: storm ? d.alpha * 1.25 : d.alpha)
        ..strokeWidth = d.thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - slant, y + d.len),
        paint,
      );
    }
  }

  void _paintLightningFlash(Canvas canvas, Size size) {
    // Éclairs rares : pics courts via sin^n
    final burst = math.pow(
      (0.5 + 0.5 * math.sin(seconds * 1.7)).clamp(0.0, 1.0),
      28,
    ).toDouble();
    final burst2 = math.pow(
      (0.5 + 0.5 * math.sin(seconds * 2.3 + 1.8)).clamp(0.0, 1.0),
      36,
    ).toDouble();
    final a = (burst * 0.16 + burst2 * 0.10).clamp(0.0, 0.22);
    if (a < 0.01) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8F0FF).withValues(alpha: a),
    );
  }

  void _paintSnow(Canvas canvas, Size size) {
    for (final f in _snow) {
      final cycle = ((seconds * f.speed) + f.phase) % 1.0;
      final y = cycle * (size.height + 16) - 8;
      final x = f.xNorm * size.width +
          math.sin(seconds * 1.4 + f.phase * math.pi * 2) * f.sway;
      canvas.drawCircle(
        Offset(x, y),
        f.size,
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    final a = 0.05 + 0.025 * math.sin(seconds * 0.8);
    final drift = (seconds * 12) % size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + drift / size.width, 0),
          end: Alignment(1 + drift / size.width, 0),
          colors: [
            Colors.white.withValues(alpha: a * 0.2),
            Colors.white.withValues(alpha: a),
            Colors.white.withValues(alpha: a * 0.2),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.seconds != seconds;
}
