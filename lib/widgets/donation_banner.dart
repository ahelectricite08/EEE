import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_settings_service.dart';
import '../theme/app_colors.dart';

const _kGold = Color(0xFFC8A436);

/// Bannière don réutilisable.
///
/// Paramètres :
/// - [photoAsset] : chemin asset local. Si null, fond par défaut.
/// - [photoUrl] : URL réseau prioritaire sur [photoAsset].
/// - [donationUrl] : URL cible du bouton.
/// - [title] : titre affiché.
/// - [subtitle] : sous-titre.
/// - [compact] : true pour une version plus petite.
class DonationBanner extends StatelessWidget {
  final String? photoAsset;
  final String? photoUrl;
  final String donationUrl;
  final String title;
  final String subtitle;
  final bool compact;

  const DonationBanner({
    super.key,
    this.photoAsset,
    this.photoUrl,
    required this.donationUrl,
    this.title = 'SOUTENEZ DVCR',
    this.subtitle = 'Chaque don nous aide à grandir',
    this.compact = false,
  });

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = compact ? 145.0 : 160.0;

    return StreamBuilder<SupportSettings>(
      stream: AppSettingsService.supportStream(),
      builder: (context, snap) {
        final configuredUrl = snap.data?.supportUrl.trim() ?? '';
        final effectiveUrl = configuredUrl.isNotEmpty
            ? configuredUrl
            : donationUrl;

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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: _kGold,
                            size: 10,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'FAIRE UN DON',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _kGold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
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
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: compact ? 11 : 12,
                            color: Colors.white.withAlpha(220),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _launch(effectiveUrl),
                            borderRadius: BorderRadius.circular(6),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _kGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SOUTENIR',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.black,
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    if (photoUrl != null) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    if (photoAsset != null) {
      return Image.asset(
        photoAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: AppColorsLight.cardMuted,
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: _kGold.withAlpha(40),
          size: 48,
        ),
      ),
    );
  }
}
