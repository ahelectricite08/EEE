import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/prono/presentation/theme/prono_tokens.dart';
import '../services/app_settings_service.dart';
import 'powered_by_partner_image.dart';

/// Où afficher l’encart (couleurs + textes).
enum PoweredByEncartSlot {
  prono,
  worldCup,
}

/// Encart « propulsé par » — alimenté par [AppSettingsService.poweredByPartnerStream].
class PoweredByPartnerEncart extends StatelessWidget {
  final PoweredByEncartSlot slot;

  const PoweredByPartnerEncart({super.key, required this.slot});

  static const Color _wcGreen = Color(0xFF0A4438);
  static const Color _wcGold = Color(0xFFC8A436);
  static const Color _wcTextMuted = Color(0xFF5C6560);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PoweredByPartnerSettings>(
      stream: AppSettingsService.poweredByPartnerStream(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData) {
          return _PoweredByPartnerEncartSkeleton(slot: slot);
        }
        final raw = snap.data!;
        final cfg = slot == PoweredByEncartSlot.worldCup
            ? raw.copyForWorldCupEncart()
            : raw;

        final isWc = slot == PoweredByEncartSlot.worldCup;
        final badgeBg = isWc ? _wcGold : PronoTokens.accentGold;
        final badgeFg = isWc ? Colors.black : PronoTokens.accentDeep;
        final badgeBorder = isWc
            ? _wcGreen.withAlpha(90)
            : PronoTokens.accentDeep.withAlpha(90);
        final titleLarge = isWc ? _wcGreen : PronoTokens.accent;
        final muted = isWc ? _wcTextMuted : PronoTokens.textMuted;
        final deepShadow = isWc ? _wcGreen : PronoTokens.accentDeep;
        final goldBorder = isWc ? _wcGold : PronoTokens.accentGold;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: deepShadow.withAlpha(35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  cfg.badgeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: badgeFg,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              cfg.sectionLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: muted,
                letterSpacing: 2.2,
                height: 1,
              ),
            ),
            Text(
              cfg.poweredByTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: titleLarge,
                letterSpacing: 0.9,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cfg.tagline,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: muted,
                height: 1.28,
              ),
            ),
            if (slot == PoweredByEncartSlot.prono &&
                raw.pronoPrizeHint.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                raw.pronoPrizeHint.trim(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isWc ? _wcGreen : PronoTokens.accentDeep,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: deepShadow.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: goldBorder.withAlpha(110),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.5),
                      child: PoweredByPartnerAspectBanner(settings: cfg),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Placeholder neutre : évite d’afficher [PoweredByPartnerSettings.defaults] (texte + image
/// « par défaut ») une fraction de seconde avant la vraie config Firestore.
class _PoweredByPartnerEncartSkeleton extends StatelessWidget {
  final PoweredByEncartSlot slot;

  const _PoweredByPartnerEncartSkeleton({required this.slot});

  static const Color _wcGreen = Color(0xFF0A4438);

  @override
  Widget build(BuildContext context) {
    final isWc = slot == PoweredByEncartSlot.worldCup;
    final bar = isWc
        ? Colors.white.withValues(alpha: 0.22)
        : PronoTokens.border.withValues(alpha: 0.55);
    final block = isWc
        ? Colors.white.withValues(alpha: 0.14)
        : PronoTokens.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 108,
            height: 14,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 160,
            height: 10,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 220,
            height: 18,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 200,
            height: 10,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isWc
                    ? _wcGreen.withValues(alpha: 0.2)
                    : PronoTokens.accentGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: isWc
                      ? Colors.white.withValues(alpha: 0.65)
                      : PronoTokens.accent.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
