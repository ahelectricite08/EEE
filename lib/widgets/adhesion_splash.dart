import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/helloasso_adhesion_service.dart';
import '../theme/app_colors.dart';
import '../utils/remote_image_url.dart';

const _kGold = Color(0xFFC8A436);

/// Overlay plein écran adhésion — à brancher sur l’entrée app (guest / app).
///
/// Affiché si `splashEnabled` + URL HelloAsso, une fois par process jusqu’à
/// « Plus tard » (pas de « Ne plus afficher »).
class AdhesionSplashOverlay extends StatefulWidget {
  /// Aperçu admin : ignore le gate session et Firestore.
  final HelloAssoAdhesionConfig? preview;

  /// Si false, n’affiche rien (ex. phase loading / tutorial).
  final bool active;

  const AdhesionSplashOverlay({
    super.key,
    this.preview,
    this.active = true,
  });

  @override
  State<AdhesionSplashOverlay> createState() => _AdhesionSplashOverlayState();
}

class _AdhesionSplashOverlayState extends State<AdhesionSplashOverlay> {
  Future<void> _openAdhesion(HelloAssoAdhesionConfig config) async {
    final url = config.buildTrackedUrl(mediumOverride: 'splash');
    if (url.isEmpty) return;
    await HelloAssoAdhesionService.instance.logBannerClick(slot: 'splash');
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _later() {
    AdhesionSplashSession.instance.dismiss();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    if (widget.preview != null) {
      return _AdhesionSplashBody(
        config: widget.preview!,
        onCta: () => _openAdhesion(widget.preview!),
        onLater: _later,
        showLater: false,
      );
    }

    if (!AdhesionSplashSession.instance.shouldOffer) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<HelloAssoAdhesionConfig>(
      stream: HelloAssoAdhesionService.instance.configStream(),
      builder: (context, snap) {
        final config = snap.data ?? HelloAssoAdhesionConfig.defaults;
        if (!config.shouldShowSplash) return const SizedBox.shrink();
        if (!AdhesionSplashSession.instance.shouldOffer) {
          return const SizedBox.shrink();
        }
        return _AdhesionSplashBody(
          config: config,
          onCta: () => _openAdhesion(config),
          onLater: _later,
          showLater: true,
        );
      },
    );
  }
}

class _AdhesionSplashBody extends StatelessWidget {
  final HelloAssoAdhesionConfig config;
  final VoidCallback onCta;
  final VoidCallback onLater;
  final bool showLater;

  const _AdhesionSplashBody({
    required this.config,
    required this.onCta,
    required this.onLater,
    required this.showLater,
  });

  static final _countFmt = NumberFormat.decimalPattern('fr_FR');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SplashBackground(config: config),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.15),
                  AppColors.green.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, top > 0 ? 8 : 24, 24, 16 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kGold.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        'ADHÉSION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kGold,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (config.splashTitle.trim().isNotEmpty)
                    Text(
                      config.splashTitle.trim(),
                      textAlign: TextAlign.left,
                      style: GoogleFonts.permanentMarker(
                        fontSize: 34,
                        height: 1.15,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black54,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  if (config.splashSubtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      config.splashSubtitle.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  if (config.memberCount > 0) ...[
                    const SizedBox(height: 22),
                    _MemberCountBlock(
                      count: config.memberCount,
                      label: config.memberCountLabel,
                      formatter: _countFmt,
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onCta,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      (config.splashCtaLabel.trim().isEmpty
                              ? 'Adhérer'
                              : config.splashCtaLabel.trim())
                          .toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (showLater) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onLater,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Plus tard',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCountBlock extends StatelessWidget {
  final int count;
  final String label;
  final NumberFormat formatter;

  const _MemberCountBlock({
    required this.count,
    required this.label,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Text(
            formatter.format(count),
            style: GoogleFonts.barlowCondensed(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _kGold,
              height: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.trim().isEmpty ? 'personnes ont rejoint' : label.trim(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  final HelloAssoAdhesionConfig config;

  const _SplashBackground({required this.config});

  @override
  Widget build(BuildContext context) {
    final splash = config.splashImageUrl.trim();
    if (splash.isNotEmpty) {
      return Image.network(
        cacheBustedImageUrl(splash, 0),
        fit: BoxFit.cover,
        headers: kDvcrImageHttpHeaders,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    final banner = config.backgroundUrl.trim();
    if (config.useCustomBackground && banner.isNotEmpty) {
      return Image.network(
        cacheBustedImageUrl(banner, 0),
        fit: BoxFit.cover,
        headers: kDvcrImageHttpHeaders,
        errorBuilder: (_, __, ___) => _asset(),
      );
    }
    return _asset();
  }

  Widget _fallback() => _asset();

  Widget _asset() {
    return Image.asset(
      HelloAssoAdhesionConfig.defaultBackgroundAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppColors.green),
    );
  }
}
