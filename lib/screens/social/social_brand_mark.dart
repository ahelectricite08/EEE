import 'package:flutter/material.dart';

import '../../utils/remote_image_url.dart';
import 'social_links_catalog.dart';

/// Pastille sobre — logo officiel (réseau / site) ou marque peinte.
class SocialBrandMark extends StatelessWidget {
  final SocialBrand brand;
  final double size;

  /// Icône Facebook 2021 (Wikimedia, PNG — pas Canva).
  static const facebookLogoUrl =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/2021_Facebook_icon.svg/240px-2021_Facebook_icon.svg.png';

  /// Logo DVCR (Wix, URL stable fournie).
  static const siteLogoUrl =
      'https://static.wixstatic.com/media/e91e00_c106d50ee9b1452a9725b8aebf0fc90d~mv2.png';

  const SocialBrandMark({
    super.key,
    required this.brand,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final cacheW = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(64, 256);

    if (brand == SocialBrand.facebook) {
      return _NetworkLogo(
        url: facebookLogoUrl,
        size: size,
        cacheWidth: cacheW,
        fit: BoxFit.contain,
        well: const Color(0xFF1877F2),
        clip: false,
        fallback: CustomPaint(painter: _BrandPainter(SocialBrand.facebook)),
      );
    }
    if (brand == SocialBrand.site) {
      return _NetworkLogo(
        url: siteLogoUrl,
        size: size,
        cacheWidth: cacheW,
        fit: BoxFit.contain,
        well: const Color(0xFFF4F0E6),
        padding: size * 0.08,
        fallback: CustomPaint(painter: _BrandPainter(SocialBrand.site)),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _well(brand),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: CustomPaint(painter: _BrandPainter(brand)),
      ),
    );
  }

  static Color _well(SocialBrand brand) {
    switch (brand) {
      case SocialBrand.youtube:
        return const Color(0xFF111111);
      case SocialBrand.instagram:
        return const Color(0xFF1A1A1A);
      case SocialBrand.tiktok:
        return const Color(0xFF121212);
      case SocialBrand.facebook:
        return const Color(0xFF1877F2);
      case SocialBrand.site:
        return const Color(0xFFF4F0E6);
      case SocialBrand.x:
        return const Color(0xFF111111);
      case SocialBrand.discord:
        return const Color(0xFF5865F2);
      case SocialBrand.soundcloud:
        return const Color(0xFFFF5500);
      case SocialBrand.applePodcasts:
        return const Color(0xFF7C3AED);
    }
  }
}

class _NetworkLogo extends StatelessWidget {
  final String url;
  final double size;
  final int cacheWidth;
  final BoxFit fit;
  final Color well;
  final double padding;
  final bool clip;
  final Widget fallback;

  const _NetworkLogo({
    required this.url,
    required this.size,
    required this.cacheWidth,
    required this.fit,
    required this.well,
    required this.fallback,
    this.padding = 0,
    this.clip = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    Widget child;
    if (shouldSkipNetworkImageUrl(url)) {
      child = fallback;
    } else {
      child = Image.network(
        url,
        width: size,
        height: size,
        fit: fit,
        alignment: Alignment.center,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheWidth,
        headers: kDvcrImageHttpHeaders,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (padding > 0) {
      child = Padding(padding: EdgeInsets.all(padding), child: child);
    }
    final box = DecoratedBox(
      decoration: BoxDecoration(color: well, borderRadius: radius),
      child: clip ? ClipRRect(borderRadius: radius, child: child) : child,
    );
    return SizedBox(width: size, height: size, child: box);
  }
}

class _BrandPainter extends CustomPainter {
  final SocialBrand brand;
  const _BrandPainter(this.brand);

  @override
  void paint(Canvas canvas, Size size) {
    switch (brand) {
      case SocialBrand.youtube:
        _youtube(canvas, size);
      case SocialBrand.instagram:
        _instagram(canvas, size);
      case SocialBrand.tiktok:
        _tiktok(canvas, size);
      case SocialBrand.facebook:
        _facebook(canvas, size);
      case SocialBrand.site:
        _site(canvas, size);
      case SocialBrand.x:
        _x(canvas, size);
      case SocialBrand.discord:
        _discord(canvas, size);
      case SocialBrand.soundcloud:
        _soundcloud(canvas, size);
      case SocialBrand.applePodcasts:
        _apple(canvas, size);
    }
  }

  void _youtube(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.62,
        height: size.height * 0.40,
      ),
      Radius.circular(size.width * 0.10),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFF0000));
    final p = Path()
      ..moveTo(size.width * 0.42, size.height * 0.38)
      ..lineTo(size.width * 0.64, size.height * 0.50)
      ..lineTo(size.width * 0.42, size.height * 0.62)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  void _instagram(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c,
          width: size.width * 0.52,
          height: size.height * 0.52,
        ),
        Radius.circular(size.width * 0.14),
      ),
      stroke,
    );
    canvas.drawCircle(c, size.width * 0.13, stroke);
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.32),
      size.width * 0.035,
      Paint()..color = Colors.white,
    );
  }

  void _tiktok(Canvas canvas, Size size) {
    final note = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.38),
      size.width * 0.10,
      note,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        size.width * 0.64,
        size.height * 0.28,
        size.width * 0.70,
        size.height * 0.62,
        Radius.circular(size.width * 0.03),
      ),
      note,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.64),
        width: size.width * 0.22,
        height: size.height * 0.16,
      ),
      note,
    );
  }

  /// « f » géométrique, reculé du bord pour ne pas être coupé par le rayon.
  void _facebook(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.16;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    canvas.save();
    canvas.translate(inset, inset);
    final f = Path()
      ..moveTo(w * 0.58, h * 0.14)
      ..lineTo(w * 0.58, h * 0.38)
      ..lineTo(w * 0.72, h * 0.38)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.58, h * 0.86)
      ..lineTo(w * 0.40, h * 0.86)
      ..lineTo(w * 0.40, h * 0.52)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.30, h * 0.38)
      ..lineTo(w * 0.40, h * 0.38)
      ..lineTo(w * 0.40, h * 0.28)
      ..cubicTo(w * 0.40, h * 0.12, w * 0.48, h * 0.08, w * 0.58, h * 0.14)
      ..close();
    canvas.drawPath(f, Paint()..color = Colors.white);
    canvas.restore();
  }

  void _site(Canvas canvas, Size size) {
    final flag = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.54,
        height: size.height * 0.36,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.save();
    canvas.clipRRect(flag);
    final w = size.width * 0.54;
    final left = size.width * 0.23;
    final top = size.height * 0.32;
    final h = size.height * 0.36;
    canvas.drawRect(
      Rect.fromLTWH(left, top, w / 3, h),
      Paint()..color = const Color(0xFF0A4438),
    );
    canvas.drawRect(
      Rect.fromLTWH(left + w / 3, top, w / 3, h),
      Paint()..color = const Color(0xFFF4F0E6),
    );
    canvas.drawRect(
      Rect.fromLTWH(left + 2 * w / 3, top, w / 3, h),
      Paint()..color = const Color(0xFFBA203C),
    );
    canvas.restore();
  }

  void _x(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.30),
      Offset(size.width * 0.70, size.height * 0.70),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.70, size.height * 0.30),
      Offset(size.width * 0.30, size.height * 0.70),
      p,
    );
  }

  void _discord(Canvas canvas, Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.56,
            height: size.height * 0.40,
          ),
          Radius.circular(size.width * 0.18),
        ),
      );
    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(size.width * 0.40, size.height * 0.48),
      size.width * 0.055,
      Paint()..color = const Color(0xFF5865F2),
    );
    canvas.drawCircle(
      Offset(size.width * 0.60, size.height * 0.48),
      size.width * 0.055,
      Paint()..color = const Color(0xFF5865F2),
    );
  }

  void _soundcloud(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const heights = [0.22, 0.38, 0.52, 0.44, 0.30, 0.18];
    for (var i = 0; i < heights.length; i++) {
      final h = size.height * heights[i];
      final x = size.width * (0.26 + i * 0.09);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          size.height / 2 - h / 2,
          x + size.width * 0.055,
          size.height / 2 + h / 2,
          Radius.circular(size.width * 0.03),
        ),
        paint,
      );
    }
  }

  void _apple(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055;
    canvas.drawCircle(c, size.width * 0.28, stroke);
    canvas.drawCircle(c, size.width * 0.17, stroke);
    canvas.drawCircle(c, size.width * 0.07, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.brand != brand;
}
