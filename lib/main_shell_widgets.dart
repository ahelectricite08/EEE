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
            child: HubHeroPhoto(
              slot: HubHeroSlot.guest,
              fallbackAsset: 'assets/images/1ba3d6e9-9678-42b2-8ec5-9e8899f16194.jpg',
              fallback: ColoredBox(
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

          // Van rouge CSSA — bande basse / milieu, sur la photo de fond.
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.sizeOf(context).height * 0.22,
            height: 96,
            child: FadeTransition(
              opacity: _logoFade,
              child: const SplashLoadingVan(),
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

const _kPodIvory = Color(0xFFF4F0E6);
const _kPodPaper = Color(0xFFFFFDF8);
const _kPodHair = Color(0xFFE6E0D1);
const _kPodInk = Color(0xFF0A1C18);
const _kPodGreen = Color(0xFF0A4438);
const _kPodMuted = Color(0xFF5E6662);

void _openPodcastNowPlaying(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: _kPodIvory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
    ),
    builder: (_) => const _PodcastNowPlayingSheet(),
  );
}

class _PodcastMiniPlayer extends StatelessWidget {
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
          child: Material(
            color: _kPodPaper,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: _kPodHair, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openPodcastNowPlaying(context),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              color: _kPodGreen,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openPodcastNowPlaying(context),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            ep.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kPodInk,
                            ),
                          ),
                        ),
                      ),
                      _MiniPlayerBtn(
                        icon: Icons.replay_10_rounded,
                        onTap: () =>
                            ctrl.skipBy(const Duration(seconds: -15)),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ctrl.isPlaying ? ctrl.pause() : ctrl.resume(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _kPodInk,
                            borderRadius: BorderRadius.circular(2),
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
                        onTap: () =>
                            ctrl.skipBy(const Duration(seconds: 15)),
                      ),
                      _MiniPlayerBtn(
                        icon: Icons.close_rounded,
                        onTap: () => ctrl.dismiss(),
                        size: 16,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        ctrl.positionLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: _kPodMuted,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: _kPodGreen,
                            inactiveTrackColor: _kPodHair,
                            thumbColor: _kPodInk,
                            overlayColor: _kPodGreen.withAlpha(40),
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: ctrl.effectiveDuration > Duration.zero
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
                          color: _kPodMuted,
                        ),
                      ),
                    ],
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

class _PodcastNowPlayingSheet extends StatelessWidget {
  const _PodcastNowPlayingSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        final ep = ctrl.currentEpisode;
        if (ep == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox(height: 120);
        }
        final progress = ctrl.progress.clamp(0.0, 1.0);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    color: _kPodHair,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'PODCAST DVCR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: _kPodMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ep.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    color: _kPodInk,
                  ),
                ),
                const SizedBox(height: 18),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: _kPodGreen,
                    inactiveTrackColor: _kPodHair,
                    thumbColor: _kPodInk,
                    overlayColor: _kPodGreen.withAlpha(40),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: ctrl.effectiveDuration > Duration.zero
                        ? ctrl.seekToFraction
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      ctrl.positionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kPodMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ctrl.durationLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kPodMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniPlayerBtn(
                      icon: Icons.replay_10_rounded,
                      onTap: () =>
                          ctrl.skipBy(const Duration(seconds: -15)),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () =>
                          ctrl.isPlaying ? ctrl.pause() : ctrl.resume(),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _kPodInk,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Icon(
                          ctrl.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _MiniPlayerBtn(
                      icon: Icons.forward_10_rounded,
                      onTap: () =>
                          ctrl.skipBy(const Duration(seconds: 15)),
                    ),
                  ],
                ),
                if (ctrl.episodes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const ColoredBox(
                    color: _kPodHair,
                    child: SizedBox(height: 1, width: double.infinity),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ÉPISODES',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: _kPodMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: ctrl.episodes.length,
                      itemBuilder: (context, i) {
                        final item = ctrl.episodes[i];
                        final active = ctrl.currentIndex == i;
                        return GestureDetector(
                          onTap: () => ctrl.togglePlay(i),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Icon(
                                  active && ctrl.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18,
                                  color: active ? _kPodGreen : _kPodMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active ? _kPodInk : _kPodMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.duration,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _kPodMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
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

