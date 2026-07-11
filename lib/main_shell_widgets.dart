part of 'main.dart';

class _LiquidGlassBorderPainter extends CustomPainter {
  final double radius;
  const _LiquidGlassBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.7));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(240),                    // blanc vif (top-left)
          const Color(0xFFADD8FF).withAlpha(160),         // bleu glace
          Colors.white.withAlpha(210),
          const Color(0xFFFFB3CC).withAlpha(130),         // rose poudré
          Colors.white.withAlpha(195),
          const Color(0xFFADFFD8).withAlpha(120),         // mint
          Colors.white.withAlpha(230),                    // blanc (bottom-right)
        ],
        stops: const [0.0, 0.16, 0.33, 0.50, 0.67, 0.83, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassBorderPainter old) =>
      old.radius != radius;
}

/// Placeholder sous-jacent aux onglets verrouillés en mode invité.
class _GuestLockedTabPane extends StatelessWidget {
  const _GuestLockedTabPane();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColorsLight.scaffold);
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? shortLabel;
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.shortLabel,
  });
}

// ── Splash screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 1.08, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fond ≠ noir pur : sur simulateur VM / rendu logiciel le décodage JPEG peut
    // prendre du temps — sans couche dessous on dirait un écran « mort ».
    return Scaffold(
      backgroundColor: AppColors.green,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.green),
          // Photo avec légère animation de zoom
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: Image.asset(
              'assets/images/1ba3d6e9-9678-42b2-8ec5-9e8899f16194.jpg',
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSync) {
                if (wasSync || frame != null) return child;
                return Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold.withValues(alpha: 0.85),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => ColoredBox(
                color: AppColorsLight.scaffold,
                child: Center(
                  child: Icon(Icons.local_shipping_rounded,
                      size: 72, color: AppColorsLight.textMuted.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),

          // Gradient overlay — sombre en haut et en bas
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(120),
                  Colors.black.withAlpha(20),
                  Colors.black.withAlpha(20),
                  Colors.black.withAlpha(200),
                ],
                stops: const [0.0, 0.25, 0.65, 1.0],
              ),
            ),
          ),

          // Spinner discret en bas
          Positioned(
            bottom: 52,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _logoFade,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFC8A436),
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget flottant draggable qui enveloppe [_PodcastMiniPlayer].
/// Se positionne en bas-centre par défaut ; mémorise la position via [onPositionChanged].
class _DraggablePodcastPlayer extends StatefulWidget {
  final Offset? initialPos;
  final ValueChanged<Offset> onPositionChanged;

  const _DraggablePodcastPlayer({
    required this.initialPos,
    required this.onPositionChanged,
  });

  @override
  State<_DraggablePodcastPlayer> createState() =>
      _DraggablePodcastPlayerState();
}

class _DraggablePodcastPlayerState extends State<_DraggablePodcastPlayer> {
  static const _playerWidth = 340.0;
  Offset? _pos;

  Offset _defaultPos(Size screen) => Offset(
        (screen.width - _playerWidth) / 2,
        screen.height - 160,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        if (PodcastController.instance.currentEpisode == null) {
          return const SizedBox.shrink();
        }

        final screen = MediaQuery.of(context).size;
        _pos ??= widget.initialPos ?? _defaultPos(screen);

        return Positioned(
          left: _pos!.dx,
          top: _pos!.dy,
          width: _playerWidth,
          child: GestureDetector(
            // Drag pour déplacer
            onPanUpdate: (d) {
              final next = Offset(
                (_pos!.dx + d.delta.dx)
                    .clamp(0.0, screen.width - _playerWidth),
                (_pos!.dy + d.delta.dy)
                    .clamp(0.0, screen.height - 100),
              );
              setState(() => _pos = next);
              widget.onPositionChanged(next);
            },
            child: _PodcastMiniPlayer(),
          ),
        );
      },
    );
  }
}

void _seekFromLocal(PodcastController ctrl, double localX, BuildContext context) {
  // La largeur du player est fixée à 340px dans _DraggablePodcastPlayer
  const playerWidth = 340.0;
  const hPad = 14.0;
  final fraction = ((localX - hPad) / (playerWidth - hPad * 2)).clamp(0.0, 1.0);
  if (ctrl.effectiveDuration > Duration.zero) ctrl.seekToFraction(fraction);
}

class _PodcastMiniPlayer extends StatelessWidget {
  static const _gold = Color(0xFFC8A436);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        final ep = ctrl.currentEpisode;
        if (ep == null) return const SizedBox.shrink();

        final progress = ctrl.progress.clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(28),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // ── Glass background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0xFFF8F6F2).withAlpha(210),
                      ),
                    ),
                  ),
                  // ── Contenu principal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rangée : icône + titre + contrôles
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _gold.withAlpha(22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _gold.withAlpha(60)),
                              ),
                              child: const Icon(Icons.headphones_rounded,
                                  size: 16, color: _gold),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ep.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColorsLight.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _MiniPlayerBtn(
                              icon: Icons.replay_10_rounded,
                              onTap: () => ctrl.skipBy(const Duration(seconds: -15)),
                            ),
                            GestureDetector(
                              onTap: () => ctrl.isPlaying
                                  ? ctrl.pause()
                                  : ctrl.resume(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _gold.withAlpha(80),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  ctrl.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _MiniPlayerBtn(
                              icon: Icons.forward_10_rounded,
                              onTap: () => ctrl.skipBy(const Duration(seconds: 15)),
                            ),
                            _MiniPlayerBtn(
                              icon: Icons.close_rounded,
                              onTap: () => ctrl.dismiss(),
                              size: 16,
                            ),
                          ],
                        ),
                        // ── Slider seek + temps
                        Row(
                          children: [
                            Text(
                              ctrl.positionLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: AppColorsLight.textMuted,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14),
                                  activeTrackColor: _gold,
                                  inactiveTrackColor:
                                      Colors.black.withAlpha(20),
                                  thumbColor: _gold,
                                  overlayColor: _gold.withAlpha(40),
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: ctrl.effectiveDuration >
                                          Duration.zero
                                      ? ctrl.seekToFraction
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              ctrl.durationLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: AppColorsLight.textMuted,
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
          ),
        );
      },
    );
  }
}

class _MiniPlayerBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _MiniPlayerBtn({
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: AppColorsLight.textMuted),
      ),
    );
  }
}

