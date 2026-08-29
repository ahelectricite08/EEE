import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/club_branding.dart';
import '../social/social_brand_mark.dart';
import '../social/social_links_catalog.dart';
import '../social/social_links_settings.dart';
import 'match_detail_theme.dart';
import 'match_tv_broadcast.dart';

/// Bloc « C’est à la télé » — petits logos club, liens globaux.
class MatchTvBlock extends StatelessWidget {
  final bool streamBroadcast;

  const MatchTvBlock({super.key, required this.streamBroadcast});

  @override
  Widget build(BuildContext context) {
    if (!streamBroadcast) {
      return const _TvShell(
        onAir: false,
        child: SizedBox.shrink(),
      );
    }

    return StreamBuilder<List<SocialNetworkSpec>>(
      stream: SocialLinksSettings.watchAll(),
      initialData: MatchTvBroadcast.row(kSocialCatalogDefaults),
      builder: (context, snap) {
        final channels = MatchTvBroadcast.row(
          snap.data ?? const <SocialNetworkSpec>[],
        );
        if (channels.isEmpty) return const SizedBox.shrink();
        return _TvShell(
          onAir: true,
          child: _ChannelStrip(channels: channels),
        );
      },
    );
  }
}

class _TvShell extends StatelessWidget {
  final Widget child;
  final bool onAir;
  const _TvShell({required this.child, this.onAir = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: MatchDetailTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              SizedBox(
                width: 36,
                height: 10,
                child: CustomPaint(painter: _AntennaPainter()),
              ),
              const SizedBox(height: 4),
              Text(
                onAir ? 'C’EST À LA TÉLÉ !' : 'PAS À LA TÉLÉ',
                textAlign: TextAlign.center,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 1.2,
                  color: MatchDetailTheme.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                onAir ? ClubBranding.liveActivityBrand : 'Écoute la radio DVCR',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MatchDetailTheme.textMuted,
                ),
              ),
              if (onAir) ...[
                const SizedBox(height: 12),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelStrip extends StatelessWidget {
  final List<SocialNetworkSpec> channels;
  const _ChannelStrip({required this.channels});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MatchDetailTheme.scaffold,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MatchDetailTheme.green, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < channels.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _TinyBrandButton(spec: channels[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TinyBrandButton extends StatelessWidget {
  final SocialNetworkSpec spec;
  const _TinyBrandButton({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: spec.isOpenable,
      enabled: spec.isOpenable,
      label: spec.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: spec.isOpenable
              ? () {
                  HapticFeedback.selectionClick();
                  SocialLinksActions.open(context, spec.url);
                }
              : null,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32 * 0.28 + 8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SocialBrandMark(brand: spec.brand, size: 32),
          ),
        ),
      ),
    );
  }
}

class _AntennaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = MatchDetailTheme.green
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final base = Offset(size.width / 2, size.height);
    canvas.drawLine(base, Offset(size.width * 0.18, 1), line);
    canvas.drawLine(base, Offset(size.width * 0.82, 1), line);
    canvas.drawCircle(
      Offset(size.width * 0.18, 1.5),
      1.6,
      Paint()..color = MatchDetailTheme.red,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, 1.5),
      1.6,
      Paint()..color = MatchDetailTheme.greenBright,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
