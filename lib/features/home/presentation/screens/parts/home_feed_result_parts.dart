part of '../home_screen.dart';

class _ResultStadiumImage extends StatelessWidget {
  final MatchModel match;
  const _ResultStadiumImage({required this.match});

  @override
  Widget build(BuildContext context) {
    // 1. Image explicite sur le match
    final cacheW = _homeHeroCacheWidth(context);
    if (match.stadiumImageUrl != null && match.stadiumImageUrl!.isNotEmpty) {
      return DvcrNetworkImage(
        match.stadiumImageUrl!,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const _SedanStadiumFallback(),
      );
    }
    return StreamBuilder<String?>(
      stream: _watchHomeStadiumHero(match.team1),
      builder: (context, snap) {
        final url = snap.data;
        if (url != null && url.isNotEmpty) {
          return DvcrNetworkImage(
            url,
            fit: BoxFit.cover,
            cacheWidth: cacheW,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) => const _SedanStadiumFallback(),
          );
        }
        return const _SedanStadiumFallback();
      },
    );
  }
}

/// Image par défaut : stade Louis-Dugauguez de Sedan.
class _SedanStadiumFallback extends StatelessWidget {
  const _SedanStadiumFallback();
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/terrain.jpg',
      fit: BoxFit.cover,
    );
  }
}

class _HomeClubSide extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool alignEnd;

  const _HomeClubSide({
    required this.name,
    required this.logoUrl,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(55),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: logoUrl != null && logoUrl!.isNotEmpty
                ? DvcrNetworkImage(
                    logoUrl!,
                    fit: BoxFit.contain,
                    cacheWidth: dvcrCrestCacheWidth(context, 46),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF173C31),
                      size: 20,
                    ),
                  )
                : const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF173C31),
                    size: 20,
                  ),
          ),
        ),
        const SizedBox(height: 7),
        // Nom
        Text(
          name.toUpperCase(),
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _HomeMatchPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;

  const _HomeMatchPill({
    required this.label,
    required this.color,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(150)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
