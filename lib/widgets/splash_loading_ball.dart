import 'package:flutter/material.dart';

/// Ballon de match photoréaliste — roule de gauche à droite en boucle
/// (indicateur de chargement du splash, sans spinner).
class SplashLoadingBall extends StatefulWidget {
  const SplashLoadingBall({super.key});

  @override
  State<SplashLoadingBall> createState() => _SplashLoadingBallState();
}

class _SplashLoadingBallState extends State<SplashLoadingBall>
    with SingleTickerProviderStateMixin {
  static const _asset = 'assets/images/splash_football.png';
  static const _size = 72.0;

  late final AnimationController _roll;

  @override
  void initState() {
    super.initState();
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const ball = _size;
          final travel = constraints.maxWidth + ball + 24;
          final radius = ball / 2;

          return AnimatedBuilder(
            animation: _roll,
            builder: (context, child) {
              final t = _roll.value;
              final x = -ball + t * travel;
              final angle = t * travel / radius;

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: x,
                    bottom: 4,
                    width: ball,
                    height: ball,
                    child: Transform.rotate(
                      angle: angle,
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: const RepaintBoundary(
              child: ClipOval(
                child: Image(
                  image: AssetImage(_asset),
                  width: ball,
                  height: ball,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
