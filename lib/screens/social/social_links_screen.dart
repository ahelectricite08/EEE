import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class _LinkItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final String url;

  const _LinkItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.url,
  });
}

class SocialLinksScreen extends StatelessWidget {
  const SocialLinksScreen({super.key});

  static const _bg = Color(0xFFF5F2E9);
  static const _surface = Color(0xFFFFFCF8);
  static const _surfaceSoft = Color(0xFFEAF5F0);
  static const _border = Color(0xFFD8D2C4);
  static const _text = Color(0xFF1A2522);
  static const _muted = Color(0xFF5C6560);
  static const _gold = Color(0xFFC8A436);
  static const _green = Color(0xFF0A4438);
  static const _greenDeep = Color(0xFF062921);
  static const _facebookBlue = Color(0xFF1877F2);
  static const _youtubeRed = Color(0xFFFF0000);
  static const _soundCloudOrange = Color(0xFFFF6A00);
  static const _applePurple = Color(0xFF9933CC);

  static const _links = <_LinkItem>[
    _LinkItem(
      icon: Icons.language_rounded,
      title: 'Site officiel',
      subtitle: 'Actus, blog et pages DVCR',
      accent: _green,
      url: 'https://www.dvcr.fr',
    ),
    _LinkItem(
      icon: Icons.facebook_rounded,
      title: 'Facebook',
      subtitle: 'Actu, annonces et communauté',
      accent: _facebookBlue,
      url: 'https://www.facebook.com/drapeauvertcartonrouge',
    ),
    _LinkItem(
      icon: Icons.play_circle_rounded,
      title: 'YouTube',
      subtitle: 'Lives, émissions et replays',
      accent: _youtubeRed,
      url: 'https://www.youtube.com/@drapeauvertcartonrouge',
    ),
    _LinkItem(
      icon: Icons.graphic_eq_rounded,
      title: 'SoundCloud',
      subtitle: 'Les émissions en audio',
      accent: _soundCloudOrange,
      url: 'https://soundcloud.com/drapeauvertcartonrouge',
    ),
    _LinkItem(
      icon: Icons.podcasts_rounded,
      title: 'Apple Podcasts',
      subtitle: 'DVCR L\'ÉMISSION sur Apple',
      accent: _applePurple,
      url:
          'https://podcasts.apple.com/fr/podcast/dvcr-lemission/id1770530094',
    ),
    _LinkItem(
      icon: Icons.volunteer_activism_rounded,
      title: 'HelloAsso',
      subtitle: 'Soutenir l\'association DVCR',
      accent: _green,
      url:
          'https://www.helloasso.com/associations/drapeau-vert-carton-rouge',
    ),
  ];

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible d\'ouvrir ce lien pour le moment.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lien copié dans le presse-papiers',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _green,
        title: Text(
          'Nos réseaux',
          style: GoogleFonts.barlowCondensed(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _green,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(18, 4, 18, 24 + bottom),
        children: [
          const _HeroPanel(),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'LIENS OFFICIELS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._links.asMap().entries.map((e) {
            final i = e.key;
            final link = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 320 + i * 45),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: _SocialLinkCard(
                  link: link,
                  onTap: () => _openUrl(context, link.url),
                  onLongPress: () => _copyUrl(context, link.url),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Astuce : appui long sur une carte pour copier le lien.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SocialLinksScreen._greenDeep,
            SocialLinksScreen._green,
            const Color(0xFF1E6B56),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: SocialLinksScreen._green.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -30,
              child: Icon(
                Icons.public_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SocialLinksScreen._gold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'DVCR CONNECTÉ',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tout DVCR,\nau même endroit.',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 0.95,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Site, réseaux, podcasts et soutien : une tape pour ouvrir, un appui long pour copier le lien.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialLinkCard extends StatelessWidget {
  final _LinkItem link;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SocialLinkCard({
    required this.link,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: SocialLinksScreen._surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: link.accent.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: SocialLinksScreen._greenDeep.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(21),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        link.accent,
                        link.accent.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: link.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: link.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(link.icon, color: link.accent, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                link.title,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: SocialLinksScreen._text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                link.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: SocialLinksScreen._muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SocialLinksScreen._surfaceSoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SocialLinksScreen._border.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.north_east_rounded,
                            size: 18,
                            color: SocialLinksScreen._green.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
