import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lineup_cinematic_plan.dart';
import '../navigation/app_store_safe_mode.dart';
import '../navigation/lineup_cinematic_presence.dart';
import '../services/helloasso_adhesion_service.dart';
import '../utils/remote_image_url.dart';
import 'dvcr_network_image.dart';

const _kIvory = Color(0xFFF4F0E6);
const _kInk = Color(0xFF0A1C18);
const _kGreenDeep = Color(0xFF062921);
const _kGold = Color(0xFFC8A436);

/// Overlay plein écran adhésion — à brancher sur l’entrée app (guest / app).
///
/// Affiché si campagne ouverte + `splashEnabled` + URL d’adhésion, une fois
/// par process jusqu’à « Plus tard ». Masqué si adhérent actif, campagne close,
/// ou si la cinématique XI est en cours / sur le point de jouer.
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

    return ValueListenableBuilder<LineupCinematicOccupancy>(
      valueListenable: LineupCinematicPresence.instance.occupancy,
      builder: (context, occupancy, _) {
        if (LineupCinematicSplashHold.blocksAdhesionSplash(occupancy)) {
          return const SizedBox.shrink();
        }
        if (!AdhesionSplashSession.instance.shouldOffer) {
          return const SizedBox.shrink();
        }

        return AppStoreMonetizationGate(
          child: StreamBuilder<HelloAssoAdhesionConfig>(
          stream: HelloAssoAdhesionService.instance.configStream(),
          initialData: HelloAssoAdhesionService.instance.lastKnownConfig,
          builder: (context, snap) {
            final config = snap.data ??
                HelloAssoAdhesionService.instance.lastKnownConfig;
            if (!config.shouldShowSplash()) return const SizedBox.shrink();
            if (!AdhesionSplashSession.instance.shouldOffer) {
              return const SizedBox.shrink();
            }
            return StreamBuilder<bool>(
              stream: HelloAssoAdhesionService.instance
                  .watchCurrentUserIsAdherentActive(),
              builder: (context, adherentSnap) {
                // Hide for active members; also hide until we know (avoid flash).
                if (adherentSnap.data != false) return const SizedBox.shrink();
                return _AdhesionSplashBody(
                  config: config,
                  onCta: () => _openAdhesion(config),
                  onLater: _later,
                  showLater: true,
                );
              },
            );
          },
        ),
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
    final title = config.splashTitle.trim();
    final subtitle = config.splashSubtitle.trim();
    final cta = config.splashCtaLabel.trim().isEmpty
        ? 'Adhérer'
        : config.splashCtaLabel.trim();

    return Material(
      color: _kGreenDeep,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SplashBackground(config: config),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x730A1C18),
                  Color(0x330A1C18),
                  Color(0x99062921),
                  Color(0xF2062921),
                ],
                stops: [0.0, 0.28, 0.58, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                top > 0 ? 8 : 16,
                16,
                12 + (bottom > 0 ? 0 : 8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'SOUTENEZ',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                              color: _kGold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      if (showLater)
                        IconButton(
                          onPressed: onLater,
                          tooltip: 'Plus tard',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            foregroundColor: _kIvory,
                            backgroundColor: const Color(0x660A1C18),
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  Text(
                    'DVCR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      height: 0.86,
                      letterSpacing: 1.4,
                      color: _kGold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'LE MÉDIA 800% CSSA',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: _kIvory,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(
                      color: _kGold,
                      child: SizedBox(height: 3, width: 56),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ADHÉSION',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: _kIvory.withValues(alpha: 0.78),
                    ),
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 0.98,
                        letterSpacing: -0.2,
                        color: _kIvory,
                      ),
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: _kIvory.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                  if (config.memberCount > 0) ...[
                    const SizedBox(height: 16),
                    _MemberCountOnPhoto(
                      count: config.memberCount,
                      label: config.memberCountLabel,
                      formatter: _countFmt,
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: onCta,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGold,
                      foregroundColor: _kInk,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      cta.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (showLater) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: onLater,
                      style: TextButton.styleFrom(
                        foregroundColor: _kIvory.withValues(alpha: 0.88),
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
                  Text(
                    'Via HelloAsso',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _kIvory.withValues(alpha: 0.62),
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
        ],
      ),
    );
  }
}

class _MemberCountOnPhoto extends StatelessWidget {
  final int count;
  final String label;
  final NumberFormat formatter;

  const _MemberCountOnPhoto({
    required this.count,
    required this.label,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ColoredBox(
          color: _kGold,
          child: SizedBox(width: 3, height: 36),
        ),
        const SizedBox(width: 12),
        Text(
          formatter.format(count),
          style: GoogleFonts.barlowCondensed(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _kGold,
            height: 1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label.trim().isEmpty ? 'personnes ont rejoint' : label.trim(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kIvory,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashBackground extends StatelessWidget {
  final HelloAssoAdhesionConfig config;

  const _SplashBackground({required this.config});

  @override
  Widget build(BuildContext context) {
    final cacheW = dvcrStadiumCacheWidth(context);
    final splash = config.splashImageUrl.trim();
    if (splash.isNotEmpty && !shouldSkipNetworkImageUrl(splash)) {
      return DvcrNetworkImage(
        cacheBustedImageUrl(splash, 0),
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    final banner = config.backgroundUrl.trim();
    if (config.useCustomBackground &&
        banner.isNotEmpty &&
        !shouldSkipNetworkImageUrl(banner)) {
      return DvcrNetworkImage(
        cacheBustedImageUrl(banner, 0),
        fit: BoxFit.cover,
        cacheWidth: cacheW,
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
      errorBuilder: (_, __, ___) => const ColoredBox(color: _kGreenDeep),
    );
  }
}
