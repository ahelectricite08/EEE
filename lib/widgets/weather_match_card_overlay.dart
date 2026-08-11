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
        _paintSun(canvas, size, intensity: 1.0);
      case MatchWeatherMode.sunClouds:
        _paintSun(canvas, size, intensity: 0.85);
        _paintCloudLayer(canvas, size, _cloudsSoft, tint: Colors.white);
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

  /// Soleil cinématique (Apple Weather) — disque soft + bloom + haze + shafts.
  /// Stadium + texte restent lisibles (pas de wash orange opaque).
  /// Softness via multi-stop gradients (évite MaskFilter massif = GC).
  void _paintSun(Canvas canvas, Size size, {double intensity = 1.0}) {
    final i = intensity.clamp(0.0, 1.2);
    final origin = Offset(size.width * 0.04, size.height * -0.02);
    final breath = 0.5 + 0.5 * math.sin(seconds * 0.38);
    final breathSlow = 0.5 + 0.5 * math.sin(seconds * 0.21 + 1.1);
    final r = size.shortestSide;
    final fanRotate = seconds * 0.016; // très lent

    // ── 1. Atmospheric warm haze (layered radial — not a flat orange sheet)
    canvas.drawCircle(
      origin,
      r * 1.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3D8).withValues(alpha: (0.16 + 0.045 * breath) * i),
            const Color(0xFFFFDFA8).withValues(alpha: (0.08 + 0.028 * breathSlow) * i),
            const Color(0xFFFFC888).withValues(alpha: 0.032 * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.26, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: r * 1.65)),
    );

    // Soft drifting haze lobes (same blur craft language as clouds — few only)
    for (var h = 0; h < 2; h++) {
      final ang = 0.42 + h * 0.55 + fanRotate * 0.4;
      final dist = r * (0.42 + h * 0.22);
      final pulse = 0.5 + 0.5 * math.sin(seconds * (0.26 + h * 0.08) + h);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            origin.dx + math.cos(ang) * dist,
            origin.dy + math.sin(ang) * dist,
          ),
          width: r * (0.62 + h * 0.14),
          height: r * (0.3 + h * 0.08),
        ),
        Paint()
          ..color = const Color(0xFFFFE8C0)
              .withValues(alpha: (0.04 + 0.022 * pulse) * i)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 + h * 10.0),
      );
    }

    // ── 2. God-rays — nested soft wedges (outer wash + mid + bright core)
    final nRays = 8;
    for (var j = 0; j < nRays; j++) {
      final t = j / (nRays - 1);
      final base = -0.02 + t * 1.12 + fanRotate;
      final sway = math.sin(seconds * 0.17 + j * 0.68) * 0.02;
      final a = base + sway;
      final spread =
          0.055 + 0.018 * math.sin(seconds * 0.3 + j * 0.85) + (j.isEven ? 0.012 : 0);
      final reach = size.longestSide *
          (1.02 + 0.07 * math.sin(seconds * 0.24 + j * 0.5));
      final pulse = 0.5 + 0.5 * math.sin(seconds * 0.34 + j * 0.8);
      final alpha = (0.034 + 0.038 * pulse) *
          i *
          (0.72 + 0.28 * (1 - (t - 0.45).abs() * 1.4).clamp(0.0, 1.0));

      final tip = Offset(
        origin.dx + math.cos(a) * reach,
        origin.dy + math.sin(a) * reach,
      );

      Path wedge(double s, [double lenScale = 1.0]) {
        final len = reach * lenScale;
        return Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(
            origin.dx + math.cos(a - s) * len,
            origin.dy + math.sin(a - s) * len,
          )
          ..lineTo(
            origin.dx + math.cos(a + s) * len,
            origin.dy + math.sin(a + s) * len,
          )
          ..close();
      }

      // Wide soft wash
      canvas.drawPath(
        wedge(spread * 1.55),
        Paint()
          ..shader = ui.Gradient.linear(
            origin,
            tip,
            [
              const Color(0xFFFFF4D8).withValues(alpha: alpha * 0.45),
              const Color(0xFFFFE0A8).withValues(alpha: alpha * 0.16),
              Colors.transparent,
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
      // Mid shaft
      canvas.drawPath(
        wedge(spread),
        Paint()
          ..shader = ui.Gradient.linear(
            origin,
            tip,
            [
              const Color(0xFFFFF8E8).withValues(alpha: alpha * 0.85),
              const Color(0xFFFFE8B8).withValues(alpha: alpha * 0.32),
              Colors.transparent,
            ],
            const [0.0, 0.36, 1.0],
          ),
      );
      // Bright core filament
      canvas.drawPath(
        wedge(spread * 0.32, 0.94),
        Paint()
          ..shader = ui.Gradient.linear(
            origin,
            tip,
            [
              const Color(0xFFFFFFF4).withValues(alpha: alpha * 1.05),
              const Color(0xFFFFF0C8).withValues(alpha: alpha * 0.22),
              Colors.transparent,
            ],
            const [0.0, 0.28, 1.0],
          ),
      );
    }

    // ── 3. Outer corona bloom
    canvas.drawCircle(
      origin,
      r * 0.98,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFEAB8).withValues(alpha: (0.26 + 0.07 * breath) * i),
            const Color(0xFFFFD480).withValues(alpha: (0.11 + 0.035 * breathSlow) * i),
            const Color(0xFFFFB868).withValues(alpha: 0.038 * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: r * 0.98)),
    );

    // ── 4. Soft realistic sun disk (hot core → cream limb → soft edge)
    final diskR = r * 0.145;
    canvas.drawCircle(
      origin,
      diskR * 1.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFF6).withValues(alpha: (0.7 + 0.1 * breath) * i),
            const Color(0xFFFFF4D0).withValues(alpha: (0.4 + 0.08 * breath) * i),
            const Color(0xFFFFD98A).withValues(alpha: (0.14 + 0.04 * breathSlow) * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.32, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: diskR * 1.7)),
    );
    canvas.drawCircle(
      origin,
      diskR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFF8).withValues(alpha: (0.9 + 0.06 * breath) * i),
            const Color(0xFFFFF7DC).withValues(alpha: (0.58 + 0.08 * breath) * i),
            const Color(0xFFFFE4A0).withValues(alpha: (0.2 + 0.05 * breath) * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 0.76, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: diskR)),
    );
    // Specular hot spot (soft radial, no MaskFilter)
    canvas.drawCircle(
      origin.translate(diskR * 0.14, diskR * 0.1),
      diskR * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: (0.42 + 0.12 * breath) * i),
            Colors.white.withValues(alpha: 0.08 * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(
          Rect.fromCircle(
            center: origin.translate(diskR * 0.14, diskR * 0.1),
            radius: diskR * 0.42,
          ),
        ),
    );

    // ── 5. Subtle lens / anamorphic flare (quiet, not gamer-neon)
    final flareDir = Offset(size.width * 0.72, size.height * 0.62);
    final flareLen = (flareDir - origin).distance;
    final flareUnit = Offset(
      (flareDir.dx - origin.dx) / flareLen,
      (flareDir.dy - origin.dy) / flareLen,
    );
    final flarePulse = 0.55 + 0.45 * math.sin(seconds * 0.31);

    // Soft anamorphic streak aligned to the light axis
    final streakMid = origin + flareUnit * (r * 0.08);
    final streakRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.95,
      height: r * 0.032,
    );
    canvas.save();
    canvas.translate(streakMid.dx, streakMid.dy);
    canvas.rotate(math.atan2(flareUnit.dy, flareUnit.dx));
    canvas.drawOval(
      streakRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFCF5).withValues(alpha: 0.11 * flarePulse * i),
            const Color(0xFFFFF0D0).withValues(alpha: 0.035 * flarePulse * i),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(streakRect),
    );
    canvas.restore();

    // Ghost orbs along the light axis (very faint)
    const ghosts = <(double, double, Color)>[
      (0.28, 0.016, Color(0xFFFFE8C8)),
      (0.46, 0.024, Color(0xFFFFD8A8)),
      (0.63, 0.012, Color(0xFFFFF0D8)),
      (0.79, 0.02, Color(0xFFFFE0B0)),
    ];
    for (final g in ghosts) {
      final ga = g.$2 * flarePulse * i;
      final gr = r * (0.038 + g.$2 * 2.0);
      final c = Offset(
        origin.dx + flareUnit.dx * flareLen * g.$1,
        origin.dy + flareUnit.dy * flareLen * g.$1,
      );
      canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              g.$3.withValues(alpha: ga),
              g.$3.withValues(alpha: ga * 0.22),
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: gr)),
      );
    }

    // ── 6. Bottom warm kiss on the pitch (subtle — photo stays visible)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            const Color(0xFFFFD9A0).withValues(alpha: (0.018 + 0.01 * breath) * i),
            const Color(0xFFFFC078).withValues(alpha: (0.04 + 0.016 * breathSlow) * i),
          ],
          stops: const [0.38, 0.74, 1.0],
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
