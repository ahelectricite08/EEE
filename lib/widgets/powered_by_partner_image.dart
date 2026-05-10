import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../utils/remote_image_url.dart';

/// Visuel carte / logo partenaire (URL remote ou asset par défaut).
class PoweredByPartnerImage extends StatelessWidget {
  final PoweredByPartnerSettings settings;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;

  const PoweredByPartnerImage({
    super.key,
    required this.settings,
    this.fit = BoxFit.fitWidth,
    this.alignment = Alignment.topCenter,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final raw = settings.imageUrl.trim();
    final url = cacheBustedImageUrl(raw, settings.revisionMillis);
    if (raw.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        headers: kDvcrImageHttpHeaders,
        gaplessPlayback: false,
        key: ValueKey<String>(url),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final indicator = Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
          if (width == null && height == null) {
            return SizedBox.expand(child: indicator);
          }
          return SizedBox(
            width: width,
            height: height ?? 120,
            child: indicator,
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _assetImage(fit: fit, width: width, height: height),
      );
    }
    return _assetImage(fit: fit, width: width, height: height);
  }

  Widget _assetImage({
    required BoxFit fit,
    double? width,
    double? height,
  }) {
    return Image.asset(
      PoweredByPartnerSettings.fallbackAssetPath,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Image locale introuvable',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// Bannière partenaire : le cadre prend le **ratio largeur/hauteur réel** du visuel
/// (réseau ou asset) — la bordure or épouse l’image, sans gouttières latérales.
class PoweredByPartnerAspectBanner extends StatefulWidget {
  final PoweredByPartnerSettings settings;
  final double loadingPlaceholderHeight;

  const PoweredByPartnerAspectBanner({
    super.key,
    required this.settings,
    this.loadingPlaceholderHeight = 132,
  });

  @override
  State<PoweredByPartnerAspectBanner> createState() =>
      _PoweredByPartnerAspectBannerState();
}

class _PoweredByPartnerAspectBannerState extends State<PoweredByPartnerAspectBanner> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;

  /// Évite bannières extrêmes (très portrait / très panoramique) qui cassent le scroll.
  static double _clampAspect(double wOverH) => wOverH.clamp(0.42, 4.2);

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant PoweredByPartnerAspectBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.imageUrl != widget.settings.imageUrl ||
        oldWidget.settings.revisionMillis != widget.settings.revisionMillis) {
      _aspectRatio = null;
      _resolveAspect();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspect() {
    _detach();
    final raw = widget.settings.imageUrl.trim();
    final ImageProvider provider;
    if (raw.isNotEmpty) {
      final url = cacheBustedImageUrl(raw, widget.settings.revisionMillis);
      provider = NetworkImage(url, headers: kDvcrImageHttpHeaders);
    } else {
      provider = AssetImage(PoweredByPartnerSettings.fallbackAssetPath);
    }

    final stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w <= 0 || h <= 0) return;
        setState(() {
          _aspectRatio = _clampAspect(w / h);
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) return;
        // Ratio de secours raisonnable si le réseau échoue (l’[Image] affichera l’asset).
        setState(() => _aspectRatio = _clampAspect(1.85));
      },
    );
    _stream = stream;
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW <= 0) return const SizedBox.shrink();

        if (_aspectRatio == null) {
          return SizedBox(
            width: maxW,
            height: widget.loadingPlaceholderHeight,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final ar = _aspectRatio!;
        final h = maxW / ar;
        return SizedBox(
          width: maxW,
          height: h,
          child: PoweredByPartnerImage(
            settings: widget.settings,
            fit: BoxFit.cover,
            width: maxW,
            height: h,
            alignment: Alignment.center,
          ),
        );
      },
    );
  }
}
