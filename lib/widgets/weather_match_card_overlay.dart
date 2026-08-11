import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/match_weather_service.dart';

/// Couche météo animée — style Apple Weather (doux, atmosphérique, cinématique).
/// À placer **entre** l’image stade et le contenu UI.
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
          painter: _AppleWeatherPainter(
            mode: mode,
            seconds: _seconds.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

// ── Particle models ──────────────────────────────────────────────────────────

class _RainStreak {
  final double xNorm;
  final double phase;
  final double speed;
  final double len;
  final double thickness;
  final double alpha;
  final double slantJitter;

  const _RainStreak({
    required this.xNorm,
    required this.phase,
    required this.speed,
    required this.len,
    required this.thickness,
    required this.alpha,
    required this.slantJitter,
  });
}

class _Snowflake {
  final double xNorm;
  final double phase;
  final double speed;
  final double size;
  final double sway;
  final double swaySpeed;
  final double alpha;

  const _Snowflake({
    required this.xNorm,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
    required this.swaySpeed,
    required this.alpha,
  });
}

class _CloudBlob {
  final double yNorm;
  final double baseX;
  final double speed;
  final double width;
  final double height;
  final double alpha;
  final double soft;

  const _CloudBlob({
    required this.yNorm,
    required this.baseX,
    required this.speed,
    required this.width,
    required this.height,
    required this.alpha,
    required this.soft,
  });
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _AppleWeatherPainter extends CustomPainter {
  final MatchWeatherMode mode;
  final double seconds;

  // Dense multi-depth rain (Apple Weather sheets)
  static final List<_RainStreak> _rainFar = _buildRain(
    n: 95,
    seed: 11,
    speedMin: 0.55,
    speedMax: 0.85,
    lenMin: 10,
    lenMax: 18,
    thickMin: 0.55,
    thickMax: 0.9,
    alphaMin: 0.04,
    alphaMax: 0.09,
  );
  static final List<_RainStreak> _rainMid = _buildRain(
    n: 70,
    seed: 27,
    speedMin: 0.9,
    speedMax: 1.25,
    lenMin: 14,
    lenMax: 26,
    thickMin: 0.85,
    thickMax: 1.25,
    alphaMin: 0.08,
    alphaMax: 0.16,
  );
  static final List<_RainStreak> _rainNear = _buildRain(
    n: 45,
    seed: 53,
    speedMin: 1.3,
    speedMax: 1.75,
    lenMin: 20,
    lenMax: 36,
    thickMin: 1.2,
    thickMax: 1.85,
    alphaMin: 0.14,
    alphaMax: 0.26,
  );

  static final List<_RainStreak> _stormFar = _buildRain(
    n: 110,
    seed: 71,
    speedMin: 0.7,
    speedMax: 1.05,
    lenMin: 12,
    lenMax: 22,
    thickMin: 0.6,
    thickMax: 1.0,
    alphaMin: 0.05,
    alphaMax: 0.11,
  );
  static final List<_RainStreak> _stormMid = _buildRain(
    n: 85,
    seed: 89,
    speedMin: 1.1,
    speedMax: 1.5,
    lenMin: 16,
    lenMax: 30,
    thickMin: 0.95,
    thickMax: 1.4,
    alphaMin: 0.10,
    alphaMax: 0.20,
  );
  static final List<_RainStreak> _stormNear = _buildRain(
    n: 55,
    seed: 101,
    speedMin: 1.55,
    speedMax: 2.1,
    lenMin: 24,
    lenMax: 42,
    thickMin: 1.3,
    thickMax: 2.0,
    alphaMin: 0.16,
    alphaMax: 0.30,
  );

  static final List<_Snowflake> _snowFar = _buildSnow(40, 201, far: true);
  static final List<_Snowflake> _snowNear = _buildSnow(28, 233, far: false);

  static final List<_CloudBlob> _cloudsSoft = _buildClouds(seed: 41, dark: false);
  static final List<_CloudBlob> _cloudsStorm = _buildClouds(seed: 67, dark: true);

  _AppleWeatherPainter({required this.mode, required this.seconds});

  static List<_RainStreak> _buildRain({
    required int n,
    required int seed,
    required double speedMin,
    required double speedMax,
    required double lenMin,
    required double lenMax,
    required double thickMin,
    required double thickMax,
    required double alphaMin,
    required double alphaMax,
  }) {
    final rnd = math.Random(seed);
    return List.generate(n, (_) {
      return _RainStreak(
        xNorm: rnd.nextDouble() * 1.15 - 0.08,
        phase: rnd.nextDouble(),
        speed: speedMin + rnd.nextDouble() * (speedMax - speedMin),
        len: lenMin + rnd.nextDouble() * (lenMax - lenMin),
        thickness: thickMin + rnd.nextDouble() * (thickMax - thickMin),
        alpha: alphaMin + rnd.nextDouble() * (alphaMax - alphaMin),
        slantJitter: rnd.nextDouble() * 0.6 - 0.3,
      );
    });
  }

  static List<_Snowflake> _buildSnow(int n, int seed, {required bool far}) {
    final rnd = math.Random(seed);
    return List.generate(n, (_) {
      return _Snowflake(
        xNorm: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: far
            ? 0.08 + rnd.nextDouble() * 0.12
            : 0.16 + rnd.nextDouble() * 0.22,
        size: far
            ? 1.0 + rnd.nextDouble() * 1.6
            : 2.0 + rnd.nextDouble() * 3.2,
        sway: far ? 4 + rnd.nextDouble() * 8 : 8 + rnd.nextDouble() * 16,
        swaySpeed: 0.6 + rnd.nextDouble() * 1.1,
        alpha: far
            ? 0.10 + rnd.nextDouble() * 0.12
            : 0.18 + rnd.nextDouble() * 0.22,
      );
    });
  }

  static List<_CloudBlob> _buildClouds({required int seed, required bool dark}) {
    final rnd = math.Random(seed);
    return List.generate(dark ? 7 : 6, (i) {
      return _CloudBlob(
        yNorm: 0.08 + rnd.nextDouble() * 0.55,
        baseX: rnd.nextDouble(),
        speed: 6 + rnd.nextDouble() * (dark ? 10 : 14),
        width: 140 + rnd.nextDouble() * 180,
        height: 42 + rnd.nextDouble() * 55,
        alpha: dark
            ? 0.10 + rnd.nextDouble() * 0.12
            : 0.07 + rnd.nextDouble() * 0.10,
        soft: 18 + rnd.nextDouble() * 22,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (mode) {
      case MatchWeatherMode.clear:
        _paintSun(canvas, size);
      case MatchWeatherMode.clouds:
        _paintAtmosphereVeil(canvas, size, cool: false, strength: 0.04);
        _paintCloudLayer(canvas, size, _cloudsSoft, tint: Colors.white);
      case MatchWeatherMode.rain:
        _paintAtmosphereVeil(canvas, size, cool: true, strength: 0.06);
        _paintCloudLayer(canvas, size, _cloudsSoft, tint: const Color(0xFFD8E0EA));
        _paintRainSheets(canvas, size, [_rainFar, _rainMid, _rainNear], slant: 2.4);
      case MatchWeatherMode.storm:
        _paintAtmosphereVeil(canvas, size, cool: true, strength: 0.12, storm: true);
        _paintCloudLayer(canvas, size, _cloudsStorm, tint: const Color(0xFF2A3344));
        _paintRainSheets(
          canvas,
          size,
          [_stormFar, _stormMid, _stormNear],
          slant: 3.4,
        );
        _paintLightningPulse(canvas, size);
      case MatchWeatherMode.snow:
        _paintAtmosphereVeil(canvas, size, cool: true, strength: 0.05);
        _paintSnowLayer(canvas, size, _snowFar);
        _paintSnowLayer(canvas, size, _snowNear);
      case MatchWeatherMode.fog:
        _paintFog(canvas, size);
      case MatchWeatherMode.none:
        break;
    }
  }

  /// Léger voile atmosphérique — lisibilité du texte préservée.
  void _paintAtmosphereVeil(
    Canvas canvas,
    Size size, {
    required bool cool,
    required double strength,
    bool storm = false,
  }) {
    final top = storm
        ? const Color(0xFF1A2233)
        : cool
            ? const Color(0xFF2A3548)
            : const Color(0xFF3A3228);
    final pulse = storm
        ? 0.85 + 0.15 * math.sin(seconds * 0.35)
        : 1.0;
    final a = strength * pulse;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            top.withValues(alpha: a * 1.15),
            top.withValues(alpha: a * 0.35),
            top.withValues(alpha: a * 0.55),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintSun(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.06, size.height * 0.04);
    final breath = 0.5 + 0.5 * math.sin(seconds * 0.55);
    final r = size.shortestSide;

    // Soft warm bloom (multi-stop radial — Apple-like)
    canvas.drawCircle(
      origin,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE4A8).withValues(alpha: 0.22 + 0.06 * breath),
            const Color(0xFFFFC857).withValues(alpha: 0.10 + 0.04 * breath),
            const Color(0xFFFFB347).withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.22, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: r * 1.15)),
    );

    // Very soft god-rays — wide cones, low alpha, gentle sweep
    final nRays = 6;
    for (var i = 0; i < nRays; i++) {
      final base = -0.08 + (i / (nRays - 1)) * 0.95;
      final sway = math.sin(seconds * 0.22 + i * 0.55) * 0.025;
      final a = base + sway;
      final spread = 0.055 + 0.012 * math.sin(seconds * 0.4 + i * 0.8);
      final reach = size.longestSide * (1.05 + 0.06 * math.sin(seconds * 0.3 + i));
      final alpha = 0.028 + 0.022 * (0.5 + 0.5 * math.sin(seconds * 0.45 + i * 0.9));

      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + math.cos(a - spread) * reach,
          origin.dy + math.sin(a - spread) * reach,
        )
        ..lineTo(
          origin.dx + math.cos(a + spread) * reach,
          origin.dy + math.sin(a + spread) * reach,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            origin,
            origin + Offset(math.cos(a) * reach, math.sin(a) * reach),
            [
              const Color(0xFFFFE8B0).withValues(alpha: alpha * 1.4),
              const Color(0xFFFFD27A).withValues(alpha: alpha * 0.35),
              Colors.transparent,
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }

    // Bottom warm kiss on the pitch
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            const Color(0xFFFFC857).withValues(alpha: 0.015 + 0.01 * breath),
            const Color(0xFFFFB347).withValues(alpha: 0.04 + 0.015 * breath),
          ],
          stops: const [0.35, 0.7, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintCloudLayer(
    Canvas canvas,
    Size size,
    List<_CloudBlob> blobs, {
    required Color tint,
  }) {
    final period = size.width + 220.0;
    for (final b in blobs) {
      final x =
          ((b.baseX * period) + seconds * b.speed) % period - 110.0;
      final y = b.yNorm * size.height;
      final center = Offset(x, y);
      final rect = Rect.fromCenter(
        center: center,
        width: b.width,
        height: b.height,
      );

      // Soft volumetric blob via blurred oval + satellite lobes
      final paint = Paint()
        ..color = tint.withValues(alpha: b.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.soft);

      canvas.drawOval(rect, paint);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(b.width * 0.28, b.height * 0.08),
          width: b.width * 0.62,
          height: b.height * 0.78,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(-b.width * 0.22, b.height * 0.12),
          width: b.width * 0.55,
          height: b.height * 0.7,
        ),
        paint,
      );
    }
  }

  void _paintRainSheets(
    Canvas canvas,
    Size size,
    List<List<_RainStreak>> layers, {
    required double slant,
  }) {
    // Soft rain curtain gradient (depth cue)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.transparent,
            Colors.white.withValues(alpha: 0.02),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final layer in layers) {
      for (final d in layer) {
        final cycle = ((seconds * d.speed) + d.phase) % 1.0;
        final travel = size.height + d.len + 40;
        final y = cycle * travel - 20;
        final x = d.xNorm * size.width + cycle * slant * 10;
        final s = slant + d.slantJitter;
        paint
          ..color = Colors.white.withValues(alpha: d.alpha)
          ..strokeWidth = d.thickness;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - s * (d.len / 10), y + d.len),
          paint,
        );
      }
    }
  }

  void _paintLightningPulse(Canvas canvas, Size size) {
    // Soft glow pulses — not neon strobe. Rare, brief, cool-white.
    double pulse(double freq, double phase, double sharpness) {
      final wave = (0.5 + 0.5 * math.sin(seconds * freq + phase)).clamp(0.0, 1.0);
      return math.pow(wave, sharpness).toDouble();
    }

    final p1 = pulse(0.55, 0.0, 22);
    final p2 = pulse(0.72, 2.4, 30);
    final p3 = pulse(0.41, 5.1, 40); // rarer secondary flicker
    final a = (p1 * 0.14 + p2 * 0.10 + p3 * 0.08).clamp(0.0, 0.22);
    if (a < 0.008) return;

    // Full-card cool wash
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFDCE8FF).withValues(alpha: a * 0.55),
    );

    // Localized bloom (horizon / sky)
    final bloomCenter = Offset(
      size.width * (0.55 + 0.2 * math.sin(seconds * 0.3)),
      size.height * 0.18,
    );
    canvas.drawCircle(
      bloomCenter,
      size.shortestSide * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE8F0FF).withValues(alpha: a),
            const Color(0xFFB8C8E8).withValues(alpha: a * 0.35),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(
          Rect.fromCircle(center: bloomCenter, radius: size.shortestSide * 0.7),
        ),
    );
  }

  void _paintSnowLayer(Canvas canvas, Size size, List<_Snowflake> flakes) {
    for (final f in flakes) {
      final cycle = ((seconds * f.speed) + f.phase) % 1.0;
      final y = cycle * (size.height + 24) - 12;
      final x = f.xNorm * size.width +
          math.sin(seconds * f.swaySpeed + f.phase * math.pi * 2) * f.sway;
      canvas.drawCircle(
        Offset(x, y),
        f.size,
        Paint()
          ..color = Colors.white.withValues(alpha: f.alpha)
          ..maskFilter = f.size > 2.5
              ? const MaskFilter.blur(BlurStyle.normal, 1.2)
              : null,
      );
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    final breath = 0.5 + 0.5 * math.sin(seconds * 0.35);
    final drift = (seconds * 9) % (size.width * 1.5);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.2 + drift / size.width, -0.2),
          end: Alignment(0.8 + drift / size.width, 0.4),
          colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.07 + 0.03 * breath),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.06 + 0.02 * breath),
            Colors.white.withValues(alpha: 0.015),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Soft drifting bands
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.25 + i * 0.22);
      final dx = ((seconds * (5 + i * 2.5)) + i * 80) % (size.width + 160) - 80;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, y),
          width: size.width * 0.7,
          height: 36 + i * 8.0,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.04 + 0.015 * breath)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AppleWeatherPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.seconds != seconds;
}
