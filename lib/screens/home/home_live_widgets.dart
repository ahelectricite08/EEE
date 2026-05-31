part of 'home_screen.dart';

class _PodcastQuickEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PodcastQuickEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: homeGreen.withAlpha(14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: homeGreen.withAlpha(55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_calendar_rounded,
                size: 14,
                color: homeGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'EDITER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: homeGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  final String label;

  const _HeroMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isFulltime =
        label == 'FIN DE MATCH' || label == 'FIN PROLONG.';
    final isHalftime =
        label == 'MI-TEMPS' || label == 'MT PROLONG.';
    final isStats = label == 'Voir les stats';
    final isDirect = label == 'DIRECT';
    final chipColor = isFulltime
        ? Colors.red
        : isHalftime
        ? const Color(0xFFFF9800)
        : Colors.white;

    IconData? icon;
    if (isFulltime) {
      icon = Icons.sports_score_rounded;
    } else if (isHalftime) {
      icon = Icons.coffee_rounded;
    } else if (isStats) {
      icon = Icons.bar_chart_rounded;
    } else if (isDirect) {
      icon = Icons.circle;
    } else {
      icon = Icons.timer_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: chipColor.withAlpha(isFulltime || isHalftime ? 100 : 70),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isDirect ? 6 : 11,
            color: isDirect ? Colors.greenAccent : chipColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartons sous le nom d’équipe (gauche = domicile, droite = extérieur).
class _HeroSideCards extends StatelessWidget {
  final int yellow;
  final int red;
  final bool alignEnd;

  const _HeroSideCards({
    required this.yellow,
    required this.red,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (yellow == 0 && red == 0) return const SizedBox.shrink();

    final chips = <Widget>[
      if (yellow > 0)
        Text(
          '🟨 $yellow',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(220),
          ),
        ),
      if (yellow > 0 && red > 0) const SizedBox(width: 6),
      if (red > 0)
        Text(
          '🟥 $red',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(220),
          ),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: chips,
    );
  }
}

/// Faits de jeu alignés côté domicile (gauche) ou extérieur (droite).
class _HeroLiveEventsColumn extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final bool homeSide;

  const _HeroLiveEventsColumn({
    required this.events,
    required this.homeSide,
  });

  static IconData _icon(String type) {
    switch (type) {
      case 'yellow':
        return Icons.square_rounded;
      case 'red':
        return Icons.square_rounded;
      case 'substitution':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.sports_soccer_rounded;
    }
  }

  static Color _iconColor(String type) {
    switch (type) {
      case 'yellow':
        return const Color(0xFFE8C82A);
      case 'red':
        return const Color(0xFFBA203C);
      case 'substitution':
        return const Color(0xFF5C6BC0);
      default:
        return Colors.white;
    }
  }

  static String _label(Map<String, dynamic> event) {
    final type = (event['type'] as String? ?? '').trim().toLowerCase();
    final minute =
        (event['minuteValue'] as int?) ?? (event['minute'] as int?) ?? 0;
    final minStr = minute > 0 ? " $minute'" : '';

    switch (type) {
      case 'substitution':
        final line = MatchStatsSchema.eventPlayerLine(event);
        final short = line.isEmpty ? 'Rempl.' : line;
        return '$short$minStr';
      case 'yellow':
      case 'red':
        final p = (event['player'] as String? ?? '').trim();
        return '${p.isEmpty ? '?' : p}$minStr';
      case 'goal':
      default:
        final p = (event['player'] as String? ?? '').trim();
        return '${p.isEmpty ? '?' : p}$minStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final align = homeSide ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = homeSide ? TextAlign.left : TextAlign.right;
    final rowMain = homeSide ? MainAxisAlignment.start : MainAxisAlignment.end;

    return Column(
      crossAxisAlignment: align,
      children: events.take(4).map((event) {
        final type = (event['type'] as String? ?? '').trim().toLowerCase();
        final color = _iconColor(type);
        final label = Text(
          _label(event),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(228),
          ),
        );
        final icon = Icon(_icon(type), size: 12, color: color);

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: rowMain,
            children: homeSide
                ? [icon, const SizedBox(width: 4), Flexible(child: label)]
                : [Flexible(child: label), const SizedBox(width: 4), icon],
          ),
        );
      }).toList(),
    );
  }
}

class _PulsingLiveBadge extends StatelessWidget {
  final double pulse;
  const _PulsingLiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(55)),
        boxShadow: [
          BoxShadow(
            color: _kRed.withAlpha((50 + (pulse * 100).round())),
            blurRadius: 6 + pulse * 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _kRed,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return HomeToolbarButton(
      icon: icon,
      onTap: onTap,
      iconColor: color ?? Colors.white,
    );
  }
}

class _PodcastSection extends StatefulWidget {
  const _PodcastSection();

  @override
  State<_PodcastSection> createState() => _PodcastSectionState();
}

class _PodcastSectionState extends State<_PodcastSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playingEdge;

  @override
  void initState() {
    super.initState();
    _playingEdge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    PodcastController.instance.addListener(_syncPlayingEdge);
    _syncPlayingEdge();
  }

  void _syncPlayingEdge() {
    final c = PodcastController.instance;
    if (c.isPlaying) {
      if (!_playingEdge.isAnimating) {
        _playingEdge.repeat(reverse: true);
      }
    } else {
      _playingEdge.stop();
      _playingEdge.value = 0;
    }
  }

  @override
  void dispose() {
    PodcastController.instance.removeListener(_syncPlayingEdge);
    _playingEdge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        if (ctrl.isLoading) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: homeGreen,
                ),
              ),
            ),
          );
        }
        if (ctrl.episodes.isEmpty) return const SizedBox();

        return SizedBox(
          height: 152,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 4, 14, 8),
            physics: const BouncingScrollPhysics(),
            itemCount: ctrl.episodes.length,
            itemBuilder: (context, i) {
              final ep = ctrl.episodes[i];
              final isActive = ctrl.currentIndex == i;
              final playingHere = isActive && ctrl.isPlaying;

              Widget playIconBox() => Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: homeGreen.withAlpha(isActive ? 28 : 14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: homeGreen.withAlpha(isActive ? 70 : 40),
                      ),
                    ),
                    child: Icon(
                      playingHere
                          ? Icons.pause_rounded
                          : Icons.graphic_eq_rounded,
                      color: homeGreen,
                      size: 22,
                    ),
                  );

              final iconLeading = playingHere
                  ? AnimatedBuilder(
                      animation: _playingEdge,
                      builder: (context, _) => Transform.scale(
                        scale: 1 + 0.045 * _playingEdge.value,
                        child: playIconBox(),
                      ),
                    )
                  : playIconBox();

              return HomeScaleOnPress(
                minScale: 0.982,
                child: GestureDetector(
                  onTap: () => ctrl.togglePlay(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: 242,
                    margin: const EdgeInsets.only(right: 12, bottom: 2),
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
                    decoration: BoxDecoration(
                      color: isActive ? homeSurfaceMuted : _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? homeGreen : _kBorder,
                        width: isActive ? 1.22 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isActive ? 10 : 6),
                          blurRadius: isActive ? 14 : 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            iconLeading,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _relDate(ep.pubDate),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? _kText : _kGrey,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ep.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                            height: 1.05,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: isActive ? homeGreen : _kGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ep.duration,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive ? homeGreen : _kGrey,
                                letterSpacing: 0.2,
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
          ),
        );
      },
    );
  }
}
