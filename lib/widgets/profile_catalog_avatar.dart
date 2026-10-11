import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/profile/profile_palette.dart';
import '../services/profile_avatars_service.dart';
import 'dvcr_network_image.dart';

/// Face catalogue (cercle ivoire) — pas un [CircleAvatar] Material.
class ProfileCatalogAvatar extends StatelessWidget {
  final String? url;
  final String initials;
  final double size;
  final bool selected;
  final bool showRing;
  final Color fill;
  final Color fg;

  const ProfileCatalogAvatar({
    super.key,
    this.url,
    this.initials = '?',
    this.size = 80,
    this.selected = false,
    this.showRing = true,
    this.fill = profileSurface,
    this.fg = profileGreen,
  });

  @override
  Widget build(BuildContext context) {
    final letters = initials.trim().isEmpty ? '?' : initials.trim();
    final src = (url ?? '').trim();
    final ring = selected ? profileGold : profileHairline;
    final ringW = selected ? 3.0 : 1.0;

    final initialsFace = ColoredBox(
      color: fill,
      child: Center(
        child: Text(
          letters,
          style: GoogleFonts.barlowCondensed(
            fontSize: letters.length > 1 ? size * 0.32 : size * 0.42,
            fontWeight: FontWeight.w900,
            color: fg,
          ),
        ),
      ),
    );

    final face = src.isEmpty
        ? initialsFace
        : DvcrNetworkImage(
            src,
            fit: BoxFit.cover,
            width: size,
            height: size,
            cacheWidth: dvcrCrestCacheWidth(context, size),
            errorBuilder: (_, __, ___) => initialsFace,
          );

    final clipped = ClipOval(
      child: SizedBox(width: size, height: size, child: face),
    );
    if (!showRing) return clipped;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: ringW),
      ),
      child: clipped,
    );
  }
}

/// Disque ami / duel : stream `user_avatars/{uid}` puis initiales.
class PublicUserCatalogFace extends StatelessWidget {
  final String? uid;
  final String? avatarUrl;
  final Widget Function(BuildContext context, String? url) builder;

  const PublicUserCatalogFace({
    super.key,
    required this.builder,
    this.uid,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final direct = (avatarUrl ?? '').trim();
    if (direct.isNotEmpty) return builder(context, direct);
    final id = (uid ?? '').trim();
    if (id.isEmpty) return builder(context, null);
    return StreamBuilder<String?>(
      stream: ProfileAvatarsService.instance.watchPublicAvatarUrl(id),
      builder: (context, snap) => builder(context, snap.data),
    );
  }
}
