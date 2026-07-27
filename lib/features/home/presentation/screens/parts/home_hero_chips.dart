part of '../home_screen.dart';

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
