import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Van utilitaire rouge (vue de profil, type Sprinter) qui traverse
/// l’écran en boucle — indicateur de chargement du splash, sans spinner.
class SplashLoadingVan extends StatefulWidget {
  const SplashLoadingVan({super.key});

  @override
  State<SplashLoadingVan> createState() => _SplashLoadingVanState();
}

class _SplashLoadingVanState extends State<SplashLoadingVan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drive;

  @override
  void initState() {
    super.initState();
    _drive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _drive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const vanW = 176.0;
          const vanH = 86.0;
          final travel = constraints.maxWidth + vanW + 32;

          return AnimatedBuilder(
            animation: _drive,
            builder: (context, _) {
              final t = _drive.value;
              final x = -vanW + t * travel;
              final bob = math.sin(t * math.pi * 10) * 1.2;
              final wheelAngle = t * math.pi * 12;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: x,
                    bottom: 4,
                    child: Transform.translate(
                      offset: Offset(0, bob),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(vanW, vanH),
                          painter: _SprinterVanPainter(wheelAngle: wheelAngle),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Illustration custom — silhouette cargo boxy, pas de star Mercedes.
class _SprinterVanPainter extends CustomPainter {
  const _SprinterVanPainter({required this.wheelAngle});

  final double wheelAngle;

  static const _red = AppColors.red;
  static const _redDeep = Color(0xFF8E1830);
  static const _redLit = Color(0xFFD42A48);
  static const _ink = Color(0xFF1A1416);
  static const _glass = Color(0xFF1C2A28);
  static const _glassLit = Color(0xFF3A5852);
  static const _trim = Color(0xFF2A2426);
  static const _ivory = Color(0xFFF4F0E6);
  static const _gold = AppColors.gold;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 176;
    canvas.scale(s, s);

    // Ombre au sol — le van « pose » sur la photo.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(const Rect.fromLTWH(18, 76, 142, 10), shadow);

    _drawBody(canvas);
    _drawWindows(canvas);
    _drawDetails(canvas);
    _wheel(canvas, const Offset(46, 68), 13.5, wheelAngle);
    _wheel(canvas, const Offset(138, 68), 13.5, wheelAngle);
  }

  void _drawBody(Canvas canvas) {
    // Caisse haute + cabine à droite (sens de marche gauche → droite).
    final body = Path()
      ..moveTo(14, 22)
      ..lineTo(118, 22)
      ..lineTo(122, 20)
      ..quadraticBezierTo(128, 18, 134, 26)
      ..lineTo(154, 38)
      ..lineTo(164, 42)
      ..lineTo(166, 50)
      ..lineTo(164, 60)
      ..lineTo(12, 60)
      ..lineTo(8, 52)
      ..lineTo(10, 28)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_redLit, _red, _redDeep],
          stops: [0.0, 0.45, 1.0],
        ).createShader(const Rect.fromLTWH(8, 18, 160, 44)),
    );

    // Filet d’ombre sous le toit.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _redDeep.withValues(alpha: 0.7),
    );

    // Pare-chocs avant / arrière.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(158, 48, 10, 13),
        const Radius.circular(2),
      ),
      Paint()..color = _trim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 48, 8, 13),
        const Radius.circular(2),
      ),
      Paint()..color = _trim,
    );
  }

  void _drawWindows(Canvas canvas) {
    // Pare-brise (légèrement incliné).
    final windshield = Path()
      ..moveTo(128, 28)
      ..lineTo(152, 40)
      ..lineTo(152, 50)
      ..lineTo(126, 50)
      ..lineTo(124, 32)
      ..close();
    canvas.drawPath(windshield, Paint()..color = _glass);
    canvas.drawPath(
      windshield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _ink,
    );
    // Reflet.
    canvas.drawPath(
      Path()
        ..moveTo(130, 31)
        ..lineTo(146, 40)
        ..lineTo(146, 43)
        ..lineTo(130, 34)
        ..close(),
      Paint()..color = _glassLit.withValues(alpha: 0.55),
    );

    // Vitre de porte.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(108, 30, 14, 20),
        const Radius.circular(2),
      ),
      Paint()..color = _glass,
    );

    // Petite vitre arrière (utilitaire).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 28, 10, 14),
        const Radius.circular(1.5),
      ),
      Paint()..color = _glass.withValues(alpha: 0.85),
    );
  }

  void _drawDetails(Canvas canvas) {
    // Ligne d’or club (ceinture de caisse), pas un logo constructeur.
    canvas.drawLine(
      const Offset(18, 54),
      const Offset(156, 54),
      Paint()
        ..color = _gold.withValues(alpha: 0.85)
        ..strokeWidth = 1.4,
    );

    // Joint de porte coulissante.
    canvas.drawLine(
      const Offset(72, 24),
      const Offset(72, 58),
      Paint()
        ..color = _ink.withValues(alpha: 0.35)
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      const Offset(104, 26),
      const Offset(104, 58),
      Paint()
        ..color = _ink.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );

    // Poignée.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(92, 44, 8, 3.5),
        const Radius.circular(1),
      ),
      Paint()..color = _ink.withValues(alpha: 0.55),
    );

    // Rétroviseur.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(150, 34, 8, 6),
        const Radius.circular(1.5),
      ),
      Paint()..color = _ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(151.5, 35.2, 5, 3.5),
        const Radius.circular(0.8),
      ),
      Paint()..color = _glassLit,
    );

    // Phare avant (ivoire, pas d’étoile).
    canvas.drawOval(
      const Rect.fromLTWH(160, 43, 7, 5),
      Paint()..color = _ivory,
    );
    canvas.drawOval(
      const Rect.fromLTWH(161, 44, 3.5, 2.5),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Feu arrière.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 40, 5, 8),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFF6A1020),
    );

    // Grille avant simple (barres horizontales).
    final grille = Paint()
      ..color = _ink.withValues(alpha: 0.55)
      ..strokeWidth = 0.9;
    canvas.drawLine(const Offset(163, 46), const Offset(165, 46), grille);
    canvas.drawLine(const Offset(163, 48), const Offset(165, 48), grille);

    // Toit : rails discrets.
    canvas.drawLine(
      const Offset(22, 21),
      const Offset(116, 21),
      Paint()
        ..color = _trim.withValues(alpha: 0.8)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _wheel(Canvas canvas, Offset c, double r, double angle) {
    canvas.drawCircle(c, r + 1.6, Paint()..color = _ink);
    canvas.drawCircle(c, r * 0.58, Paint()..color = const Color(0xFFD8D2C4));
    canvas.drawCircle(c, r * 0.22, Paint()..color = _trim);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final spoke = Paint()
      ..color = const Color(0xFF6E6A62)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawLine(
        Offset(math.cos(a) * r * 0.16, math.sin(a) * r * 0.16),
        Offset(math.cos(a) * r * 0.5, math.sin(a) * r * 0.5),
        spoke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SprinterVanPainter old) =>
      old.wheelAngle != wheelAngle;
}
