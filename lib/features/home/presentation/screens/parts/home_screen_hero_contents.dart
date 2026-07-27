part of '../home_screen.dart';

mixin _HomeScreenHeroContentsMixin on _HomeScreenController {
  Widget _buildDefaultHeroContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branding DVCR — DV vert / CR rouge
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Ombre vert derrière
            Positioned(
              left: 2,
              top: 3,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'DV',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 76,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF0A4438).withAlpha(180),
                        letterSpacing: -1,
                        height: 0.85,
                      ),
                    ),
                    TextSpan(
                      text: 'CR',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 76,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: _kRed.withAlpha(160),
                        letterSpacing: -1,
                        height: 0.85,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Texte principal DV blanc / CR blanc
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'DV',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 0.85,
                    ),
                  ),
                  TextSpan(
                    text: 'CR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 0.85,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'LE MÉDIA 800% CSSA',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Contenu hero : émission en direct ───────────────────────────────────────
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
                  color: _kGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withAlpha((60 + (_pulse.value * 120).round())),
                      blurRadius: 4 + _pulse.value * 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'ÉMISSION EN DIRECT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
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
              Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white.withAlpha(160)),
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
              await launchUrl(Uri.parse(clean), mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(color: _kGold.withAlpha(60), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.live_tv_rounded, color: Colors.black, size: 15),
                const SizedBox(width: 7),
                Text(
                  "REGARDER L'ÉMISSION",
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
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

  // ── Contenu hero : match en direct ──────────────────────────────────────────
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = _categoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _categoryIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kGreen : _kCard,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? _kGreen : _kBorder,
                ),
              ),
              child: Text(
                _categories[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: sel ? Colors.white : _kText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
