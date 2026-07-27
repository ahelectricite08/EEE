part of '../home_screen.dart';

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
      children: events.take(2).map((event) {
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

/// Raccourci navigation dark-glass dans le hero par défaut.
class _DefaultNavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DefaultNavPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(130),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white.withAlpha(200)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ],
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
