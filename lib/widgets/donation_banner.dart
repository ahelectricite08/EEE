import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

const _kGold = Color(0xFFC8A436);

/// Bannière visuelle : badge or [badgeLabel] + [title] en bas (sans lien externe).
class DonationBanner extends StatelessWidget {
  final String? photoAsset;
  final String? photoUrl;
  /// Texte dans le badge or (ex. « DVCR »).
  final String badgeLabel;
  /// Ligne principale sous le badge (ex. « Association »).
  final String title;
  final String subtitle;
  final bool compact;

  const DonationBanner({
    super.key,
    this.photoAsset,
    this.photoUrl,
    this.badgeLabel = 'DVCR',
    this.title = 'Association',
    this.subtitle = '',
    this.compact = false,
  });

  bool get _imageOnly =>
      badgeLabel.trim().isEmpty &&
      title.trim().isEmpty &&
      subtitle.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 145.0 : 160.0;

    return Container(
      margin: EdgeInsets.fromLTRB(
        14,
        compact ? 20 : 8,
        14,
        compact ? 0 : 8,
      ),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColorsLight.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGold.withAlpha(100), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (!_imageOnly) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColorsLight.scaffold.withAlpha(40),
                    AppColors.green.withAlpha(200),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColorsLight.textPrimary.withAlpha(140),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: compact ? 10 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (badgeLabel.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _kGold.withAlpha(120)),
                      ),
                      child: Text(
                        badgeLabel.trim().toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: _kGold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.trim().isNotEmpty)
                        Text(
                          title.trim(),
                          style: GoogleFonts.permanentMarker(
                            fontSize: compact ? 16 : 20,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black45,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle.trim(),
                          style: GoogleFonts.inter(
                            fontSize: compact ? 11 : 12,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final url = photoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _assetBackground(),
      );
    }
    return _assetBackground();
  }

  Widget _assetBackground() {
    final asset = photoAsset?.trim() ?? '';
    if (asset.isNotEmpty) {
      return Image.asset(asset, fit: BoxFit.cover);
    }
    return Container(color: AppColors.green);
  }
}
