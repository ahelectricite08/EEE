part of '../home_screen.dart';

mixin _HomeScreenHeroContentsMixin on _HomeScreenController {
  Widget _buildDefaultHeroContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 44, height: 2, color: HomeTheme.accent),
        const SizedBox(height: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 2,
              top: 3,
              child: Text(
                'DVCR',
                style: HomeType.masthead.copyWith(
                  color: const Color(0xFF0A4438).withAlpha(90),
                ),
              ),
            ),
            Text('DVCR', style: HomeType.masthead),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'LE MÉDIA 800% CSSA',
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmissionHeroContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: HomeTheme.greenBright,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HomeTheme.greenBright.withAlpha(
                        (60 + (_pulse.value * 120).round()),
                      ),
                      blurRadius: 4 + _pulse.value * 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'ÉMISSION EN DIRECT',
                style: HomeType.kickerOnPhoto,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _emissionTitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
            height: 1.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (_emissionViewers > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_red_eye_rounded,
                size: 12,
                color: Colors.white.withAlpha(160),
              ),
              const SizedBox(width: 5),
              Text(
                '$_emissionViewers spectateurs',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(160),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final url = _emissionUrl;
            if (url != null && url.isNotEmpty) {
              final clean = YoutubeParser.sanitizeShareUrl(url);
              await launchUrl(
                Uri.parse(clean),
                mode: LaunchMode.externalApplication,
              );
            }
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  color: HomeTheme.ink,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  "REGARDER L'ÉMISSION",
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: HomeTheme.ink,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (_, i) {
          final sel = _categoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _categoryIndex = i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _categories[i],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                    color: sel ? HomeTheme.text : HomeTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: sel ? 22 : 0,
                  color: sel ? HomeTheme.accent : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
