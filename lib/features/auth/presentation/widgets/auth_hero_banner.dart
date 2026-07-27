import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_palette.dart';

/// Shared hero strip for Auth screens (visual parity with legacy).
class AuthHeroBanner extends StatelessWidget {
  const AuthHeroBanner({
    super.key,
    required this.title,
    required this.height,
    this.onBack,
    this.showImageLoadingPlaceholder = false,
  });

  final String title;
  final double height;
  final VoidCallback? onBack;
  final bool showImageLoadingPlaceholder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showImageLoadingPlaceholder)
            const ColoredBox(color: AuthPalette.bg),
          Image.asset(
            'assets/images/0a9898b9-c241-40e2-bcca-05670bfa3d8e.jpg',
            fit: BoxFit.cover,
            frameBuilder: showImageLoadingPlaceholder
                ? (context, child, frame, wasSync) {
                    if (wasSync || frame != null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuthPalette.gold.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  }
                : null,
            errorBuilder: showImageLoadingPlaceholder
                ? (_, __, ___) => ColoredBox(
                      color: AuthPalette.bg,
                      child: Icon(
                        Icons.stadium_rounded,
                        size: 56,
                        color: AuthPalette.muted.withValues(alpha: 0.35),
                      ),
                    )
                : null,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(60),
                  Colors.black.withAlpha(190),
                  AuthPalette.bg.withAlpha(255),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
          if (onBack != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onBack,
              ),
            ),
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: AuthPalette.gold, width: 1.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DVCR',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AuthPalette.gold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
