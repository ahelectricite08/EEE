import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const _kGold   = Color(0xFFC8A436);
const _kBorder = Color(0xFF2A2A2A);

/// Bannière don réutilisable.
///
/// Paramètres :
/// - [photoAsset]  : chemin asset local (ex: 'assets/images/don.jpg'). Si null → fond stade par défaut.
/// - [photoUrl]    : URL réseau. Prioritaire sur [photoAsset].
/// - [donationUrl] : URL cible du bouton (HelloAsso, Leetchi, etc.)
/// - [title]       : titre affiché (défaut: 'SOUTENEZ LE CLUB')
/// - [subtitle]    : sous-titre (défaut: 'Chaque don compte pour l\'avenir du DVCR')
/// - [compact]     : true → hauteur réduite (pour home/sidebar), false → plein format
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
    this.title    = 'SOUTENEZ DVCR',
    this.subtitle = 'Chaque don nous aide à grandir',
    this.compact  = false,
  });

  Future<void> _launch() async {
    final uri = Uri.parse(donationUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final height = compact ? 145.0 : 160.0;

    return GestureDetector(
      onTap: _launch,
      child: Container(
        margin: EdgeInsets.fromLTRB(14, compact ? 20 : 8, 14, compact ? 0 : 8),
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGold.withAlpha(80), width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photo de fond ──────────────────────────────────────────
            _buildBackground(),

            // ── Dégradé sombre ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withAlpha(20),
                    Colors.black.withAlpha(200),
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
                    Colors.black.withAlpha(160),
                  ],
                ),
              ),
            ),

            // ── Contenu ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: compact ? 10 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge haut
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGold.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _kGold.withAlpha(120)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: _kGold, size: 10),
                        const SizedBox(width: 5),
                        Text('FAIRE UN DON',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _kGold,
                            letterSpacing: 1.5,
                          )),
                      ],
                    ),
                  ),

                  // Texte + bouton
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: GoogleFonts.permanentMarker(
                          fontSize: compact ? 16 : 20,
                          color: Colors.white,
                        )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        style: GoogleFonts.inter(
                          fontSize: compact ? 11 : 12,
                          color: Colors.white60,
                        )),
                      const SizedBox(height: 10),
                      // Bouton
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _kGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('SOUTENIR',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: 0.8,
                              )),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (photoUrl != null) {
      return Image.network(photoUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    if (photoAsset != null) {
      return Image.asset(photoAsset!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(Icons.favorite_rounded,
            color: _kGold.withAlpha(40), size: 48),
      ),
    );
  }
}
