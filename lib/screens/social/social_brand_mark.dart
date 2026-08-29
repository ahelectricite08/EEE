import 'package:flutter/material.dart';

import '../../utils/remote_image_url.dart';
import 'social_links_catalog.dart';

/// Pastille sobre — logo officiel (réseau / site) ou marque peinte.
class SocialBrandMark extends StatelessWidget {
  final SocialBrand brand;
  final double size;

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
    final cacheW =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 256);

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
          border: brand == SocialBrand.youtube
              ? Border.all(color: const Color(0xFFE6E0D1), width: 1)
              : null,
        ),
        child: CustomPaint(painter: _BrandPainter(brand)),
      ),
    );
  }

  static Color _well(SocialBrand brand) {
    switch (brand) {
      case SocialBrand.youtube:
        return const Color(0xFFFFFFFF);
      case SocialBrand.instagram:
        return const Color(0xFF1A1A1A);
      case SocialBrand.tiktok:
        return const Color(0xFF121212);
      case SocialBrand.facebook:
        return const Color(0xFF1877F2);
      case SocialBrand.twitch:
        return const Color(0xFF9146FF);
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
  final Widget fallback;

  const _NetworkLogo({
    required this.url,
    required this.size,
    required this.cacheWidth,
    required this.fit,
    required this.well,
    required this.fallback,
    this.padding = 0,
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
      child: ClipRRect(borderRadius: radius, child: child),
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
      case SocialBrand.twitch:
        _twitch(canvas, size);
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

  /// Glyph TikTok officiel (note « d ») + décalage cyan / magenta.
  void _tiktok(Canvas canvas, Size size) {
    final path = _tiktokPath;
    final ox = size.width * 0.045;
    final oy = size.height * 0.028;
    _fillSvg(canvas, size, path, const Color(0xFFFE2C55),
        pad: 0.12, shift: Offset(ox, -oy));
    _fillSvg(canvas, size, path, const Color(0xFF25F4EE),
        pad: 0.12, shift: Offset(-ox, oy));
    _fillSvg(canvas, size, path, Colors.white, pad: 0.12);
  }

  /// « f » Facebook (glyphe Simple Icons, viewBox 24).
  void _facebook(Canvas canvas, Size size) {
    _fillSvg(canvas, size, _facebookPath, Colors.white, pad: 0.10);
  }

  /// Glitch Twitch (glyphe Simple Icons, viewBox 24).
  void _twitch(Canvas canvas, Size size) {
    _fillSvg(canvas, size, _twitchPath, Colors.white, pad: 0.12);
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

  /// X (ex-Twitter) — glyphe officiel, pas un « × » de croix.
  void _x(Canvas canvas, Size size) {
    _fillSvg(canvas, size, _xPath, Colors.white, pad: 0.20);
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

  void _fillSvg(
    Canvas canvas,
    Size size,
    Path path,
    Color color, {
    required double pad,
    Offset shift = Offset.zero,
    double viewBox = 24,
  }) {
    final inset = size.shortestSide * pad;
    final s = (size.shortestSide - inset * 2) / viewBox;
    canvas.save();
    canvas.translate(inset + shift.dx, inset + shift.dy);
    canvas.scale(s);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true);
    canvas.restore();
  }
}

/// Simple Icons — glyphes 24×24 (identifiants de marque, pas un redessin).
const _kTikTokMark =
    'M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z';

const _kFacebookMark =
    'M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325a8.623 8.623 0 0 0-.653-.036c-.285 0-.733.042-1.125.15-.39.107-.666.242-.84.438-.175.197-.263.385-.263.67v2.713h3.56l-.532 3.667h-3.028v7.98H9.101z';

const _kTwitchMark =
    'M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z';

const _kXMark =
    'M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z';

final _svgToken = RegExp(
  r'([MmLlHhVvCcSsQqTtAaZz])|([+-]?(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?)',
);

final _tiktokPath = _parseSvgPath(_kTikTokMark);
final _facebookPath = _parseSvgPath(_kFacebookMark);
final _twitchPath = _parseSvgPath(_kTwitchMark);
final _xPath = _parseSvgPath(_kXMark);

Path _parseSvgPath(String d) {
  final path = Path();
  final tokens = <String>[];
  for (final m in _svgToken.allMatches(d)) {
    tokens.add(m.group(0)!);
  }

  var i = 0;
  var cx = 0.0;
  var cy = 0.0;
  var sx = 0.0;
  var sy = 0.0;
  var lastC2x = 0.0;
  var lastC2y = 0.0;
  var prev = '';

  double num() => double.parse(tokens[i++]);

  bool isCmd(String t) => t.length == 1 && RegExp(r'[A-Za-z]').hasMatch(t);

  while (i < tokens.length) {
    var cmd = tokens[i];
    if (isCmd(cmd)) {
      i++;
    } else {
      cmd = prev == 'M'
          ? 'L'
          : prev == 'm'
              ? 'l'
              : prev;
    }
    prev = cmd;

    switch (cmd) {
      case 'M':
        cx = num();
        cy = num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
      case 'm':
        cx += num();
        cy += num();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
      case 'L':
        cx = num();
        cy = num();
        path.lineTo(cx, cy);
      case 'l':
        cx += num();
        cy += num();
        path.lineTo(cx, cy);
      case 'H':
        cx = num();
        path.lineTo(cx, cy);
      case 'h':
        cx += num();
        path.lineTo(cx, cy);
      case 'V':
        cy = num();
        path.lineTo(cx, cy);
      case 'v':
        cy += num();
        path.lineTo(cx, cy);
      case 'C':
        final x1 = num();
        final y1 = num();
        lastC2x = num();
        lastC2y = num();
        cx = num();
        cy = num();
        path.cubicTo(x1, y1, lastC2x, lastC2y, cx, cy);
      case 'c':
        final x1 = cx + num();
        final y1 = cy + num();
        lastC2x = cx + num();
        lastC2y = cy + num();
        cx += num();
        cy += num();
        path.cubicTo(x1, y1, lastC2x, lastC2y, cx, cy);
      case 'S':
        final x1 = 2 * cx - lastC2x;
        final y1 = 2 * cy - lastC2y;
        lastC2x = num();
        lastC2y = num();
        cx = num();
        cy = num();
        path.cubicTo(x1, y1, lastC2x, lastC2y, cx, cy);
      case 's':
        final x1 = 2 * cx - lastC2x;
        final y1 = 2 * cy - lastC2y;
        lastC2x = cx + num();
        lastC2y = cy + num();
        cx += num();
        cy += num();
        path.cubicTo(x1, y1, lastC2x, lastC2y, cx, cy);
      case 'A':
      case 'a':
        // Arcs Facebook : rayon >> déplacement — un segment suffit à 44 px.
        final relative = cmd == 'a';
        num();
        num();
        num();
        num();
        num();
        final x = num();
        final y = num();
        if (relative) {
          cx += x;
          cy += y;
        } else {
          cx = x;
          cy = y;
        }
        path.lineTo(cx, cy);
        lastC2x = cx;
        lastC2y = cy;
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
      default:
        throw FormatException('SVG command inconnue: $cmd');
    }

    if (cmd != 'C' && cmd != 'c' && cmd != 'S' && cmd != 's') {
      lastC2x = cx;
      lastC2y = cy;
    }
  }

  path.fillType = PathFillType.evenOdd;
  return path;
}
