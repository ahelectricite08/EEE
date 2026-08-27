import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/remote_image_url.dart';

/// Logo partenaire — filet 1 px, pas de pastille ronde.
///
/// [lockSquare] (souvenir) : cadre carré + [BoxFit.cover].
/// Sinon (note du match / homme du match) : le cadre suit le ratio réel
/// du fichier, contenu dans [maxWidth] × [maxHeight] — pas d’étirement.
class SquarePartnerLogo extends StatelessWidget {
  final String? url;
  final int revisionMillis;
  final double size;
  final Color background;
  final Color borderColor;
  final bool showEmptyPlaceholder;
  final String emptyLabel;
  final bool lockSquare;
  final double? maxWidth;
  final double? maxHeight;

  const SquarePartnerLogo({
    super.key,
    this.url,
    this.revisionMillis = 0,
    this.size = 48,
    this.background = const Color(0xFFF5F2E9),
    this.borderColor = const Color(0xFFE6E0D2),
    this.showEmptyPlaceholder = false,
    this.emptyLabel = '',
    this.lockSquare = true,
    this.maxWidth,
    this.maxHeight,
  });

  double get _maxH => maxHeight ?? size;
  double get _maxW => maxWidth ?? (lockSquare ? size : size * 2.25);

  @override
  Widget build(BuildContext context) {
    final src = (url ?? '').trim();
    if (src.isEmpty && !showEmptyPlaceholder) {
      return const SizedBox.shrink();
    }

    if (src.isEmpty) {
      return _framed(
        width: size,
        height: size,
        child: _emptyChild(size),
      );
    }

    if (lockSquare) {
      return _framed(
        width: size,
        height: size,
        child: _networkImage(
          src,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return _AspectPartnerLogo(
      url: src,
      revisionMillis: revisionMillis,
      maxWidth: _maxW,
      maxHeight: _maxH,
      background: background,
      borderColor: borderColor,
    );
  }

  Widget _framed({
    required double width,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _emptyChild(double box) {
    return ColoredBox(
      color: background,
      child: emptyLabel.isEmpty
          ? Icon(
              Icons.handshake_outlined,
              size: box * 0.38,
              color: AppColorsLight.textSecondary.withAlpha(140),
            )
          : Center(
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColorsLight.textSecondary,
                ),
              ),
            ),
    );
  }

  Widget _networkImage(
    String src, {
    required double width,
    required double height,
    required BoxFit fit,
  }) {
    if (shouldSkipNetworkImageUrl(src)) {
      return _broken(width);
    }
    return Image.network(
      cacheBustedImageUrl(src, revisionMillis),
      fit: fit,
      width: width,
      height: height,
      filterQuality: FilterQuality.high,
      headers: kDvcrImageHttpHeaders,
      errorBuilder: (_, __, ___) => _broken(width),
    );
  }

  Widget _broken(double box) {
    return ColoredBox(
      color: background,
      child: Icon(
        Icons.broken_image_outlined,
        size: box * 0.36,
        color: AppColorsLight.textSecondary.withAlpha(160),
      ),
    );
  }
}

class _AspectPartnerLogo extends StatefulWidget {
  final String url;
  final int revisionMillis;
  final double maxWidth;
  final double maxHeight;
  final Color background;
  final Color borderColor;

  const _AspectPartnerLogo({
    required this.url,
    required this.revisionMillis,
    required this.maxWidth,
    required this.maxHeight,
    required this.background,
    required this.borderColor,
  });

  @override
  State<_AspectPartnerLogo> createState() => _AspectPartnerLogoState();
}

class _AspectPartnerLogoState extends State<_AspectPartnerLogo> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _intrinsic;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AspectPartnerLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.revisionMillis != widget.revisionMillis) {
      _intrinsic = null;
      _failed = false;
      _resolve();
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

  void _resolve() {
    _detach();
    if (shouldSkipNetworkImageUrl(widget.url)) {
      _failed = true;
      return;
    }
    final url = cacheBustedImageUrl(widget.url, widget.revisionMillis);
    final provider = NetworkImage(url, headers: kDvcrImageHttpHeaders);
    final stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w <= 0 || h <= 0) return;
        setState(() {
          _intrinsic = Size(w, h);
          _failed = false;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    _stream = stream;
    stream.addListener(_listener!);
  }

  Size _fitted() {
    final src = _intrinsic!;
    final scale = min(
      widget.maxWidth / src.width,
      widget.maxHeight / src.height,
    );
    return Size(src.width * scale, src.height * scale);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      final box = min(widget.maxWidth, widget.maxHeight);
      return _box(
        width: box,
        height: box,
        child: Icon(
          Icons.broken_image_outlined,
          size: box * 0.36,
          color: AppColorsLight.textSecondary.withAlpha(160),
        ),
      );
    }

    if (_intrinsic == null) {
      final h = widget.maxHeight;
      return _box(
        width: h,
        height: h,
        child: Center(
          child: SizedBox(
            width: h * 0.28,
            height: h * 0.28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColorsLight.textSecondary.withAlpha(140),
            ),
          ),
        ),
      );
    }

    final fitted = _fitted();
    return _box(
      width: fitted.width,
      height: fitted.height,
      child: Image.network(
        cacheBustedImageUrl(widget.url, widget.revisionMillis),
        fit: BoxFit.contain,
        width: fitted.width,
        height: fitted.height,
        filterQuality: FilterQuality.high,
        headers: kDvcrImageHttpHeaders,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.broken_image_outlined,
          size: min(fitted.width, fitted.height) * 0.36,
          color: AppColorsLight.textSecondary.withAlpha(160),
        ),
      ),
    );
  }

  Widget _box({
    required double width,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: widget.background,
        border: Border.all(color: widget.borderColor, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
