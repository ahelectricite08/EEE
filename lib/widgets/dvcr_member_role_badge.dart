import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';

/// Clé du document Firestore `config/role_badges` (identique au panneau admin).
String roleBadgeConfigKey(UserRole r) {
  switch (r) {
    case UserRole.supporter:
      return 'supporter';
    case UserRole.donateur:
      return 'donateur';
    case UserRole.partenaire:
      return 'partenaire';
    case UserRole.teamDvcr:
      return 'team_dvcr';
    case UserRole.editor:
      return 'editor';
    case UserRole.communityManager:
      return 'community_manager';
    case UserRole.statisticien:
      return 'statisticien';
    case UserRole.admin:
      return 'admin';
  }
}

/// URL du badge image à afficher sur l’avatar (médaillon) : d’abord staff si URL
/// configurée, sinon premier palier tribu avec URL (ex. admin + Membre DVCR →
/// image `admin` si présente, sinon `team_dvcr`).
String? resolvedRoleBadgeImageUrl(
  Set<UserRole> roles,
  Map<String, String> badges,
) {
  String? pick(String key) {
    final u = badges[key]?.trim() ?? '';
    return u.isEmpty ? null : u;
  }

  const staffOrder = [
    UserRole.admin,
    UserRole.communityManager,
    UserRole.editor,
    UserRole.statisticien,
  ];
  for (final r in staffOrder) {
    if (roles.contains(r)) {
      final u = pick(roleBadgeConfigKey(r));
      if (u != null) return u;
    }
  }

  const tierOrder = [
    UserRole.teamDvcr,
    UserRole.partenaire,
    UserRole.donateur,
    UserRole.supporter,
  ];
  for (final r in tierOrder) {
    if (roles.contains(r)) {
      final u = pick(roleBadgeConfigKey(r));
      if (u != null) return u;
    }
  }
  return null;
}

/// Médaille circulaire (avatar + chat) : bordure type « premium ».
class DvcrRoleBadgeMedallion extends StatelessWidget {
  final String imageUrl;
  final double diameter;

  const DvcrRoleBadgeMedallion({
    super.key,
    required this.imageUrl,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    final ring = diameter * 0.14;
    return Container(
      width: diameter + ring * 2,
      height: diameter + ring * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(55),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFC8A436).withAlpha(90),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(ring * 0.45),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            startAngle: -0.85,
            endAngle: 2.4,
            colors: [
              const Color(0xFFFFF8E1),
              const Color(0xFFC8A436),
              const Color(0xFF5D4A1A),
              const Color(0xFFC8A436),
              const Color(0xFFFFF8E1),
            ],
            stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0D1210),
          ),
          padding: const EdgeInsets.all(1.6),
          child: ClipOval(
            child: Image.network(
              imageUrl,
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A1A),
                alignment: Alignment.center,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: diameter * 0.48,
                  color: const Color(0xFFC8A436),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rôle « tribu » affiché sur l’avatar (hors staff : admin, CM, éditeur, stats).
UserRole dvcrMemberTierRole(Set<UserRole> roles) {
  const order = [
    UserRole.teamDvcr,
    UserRole.partenaire,
    UserRole.donateur,
    UserRole.supporter,
  ];
  for (final r in order) {
    if (roles.contains(r)) return r;
  }
  return UserRole.supporter;
}

class _TierStyle {
  final List<Color> outerSweep;
  final List<Color> innerRing;
  final Color gutter;
  final List<BoxShadow> glow;
  final IconData icon;
  final String shortLabel;

  const _TierStyle({
    required this.outerSweep,
    required this.innerRing,
    required this.gutter,
    required this.glow,
    required this.icon,
    required this.shortLabel,
  });

  static _TierStyle forRole(UserRole r) {
    switch (r) {
      case UserRole.teamDvcr:
        return _TierStyle(
          outerSweep: const [
            Color(0xFFFFE082),
            Color(0xFFC8A436),
            Color(0xFF8A7228),
            Color(0xFFC8A436),
            Color(0xFFFFE082),
          ],
          innerRing: const [Color(0xFFFFF3D6), Color(0xFFE8C86A)],
          gutter: const Color(0xFF1A1408),
          glow: [
            BoxShadow(
              color: const Color(0xFFC8A436).withAlpha(110),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          icon: Icons.bolt_rounded,
          shortLabel: 'MEMBRE DVCR',
        );
      case UserRole.partenaire:
        return _TierStyle(
          outerSweep: const [
            Color(0xFFFFE0B2),
            Color(0xFFFF9100),
            Color(0xFFE65100),
            Color(0xFFFF9100),
            Color(0xFFFFE0B2),
          ],
          innerRing: const [Color(0xFFFFECB3), Color(0xFFFFB74D)],
          gutter: const Color(0xFF1A0E00),
          glow: [
            BoxShadow(
              color: const Color(0xFFFF9100).withAlpha(100),
              blurRadius: 18,
              spreadRadius: -3,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
          icon: Icons.handshake_rounded,
          shortLabel: 'PARTENAIRE',
        );
      case UserRole.donateur:
        return _TierStyle(
          outerSweep: const [
            Color(0xFFC8E6C9),
            Color(0xFF43A047),
            Color(0xFF1B5E20),
            Color(0xFF43A047),
            Color(0xFFC8E6C9),
          ],
          innerRing: const [Color(0xFFE8F5E9), Color(0xFF66BB6A)],
          gutter: const Color(0xFF051208),
          glow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withAlpha(95),
              blurRadius: 18,
              spreadRadius: -3,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
          icon: Icons.volunteer_activism_rounded,
          shortLabel: 'DONATEUR',
        );
      case UserRole.supporter:
        return _supporterTier();
      default:
        return _supporterTier();
    }
  }

  /// Palier « tribu » par défaut : supporter (foot), libellé **SUPPORTER** sur la pastille.
  static _TierStyle _supporterTier() {
    return _TierStyle(
      outerSweep: const [
        Color(0xFFE8EAED),
        Color(0xFF90A4AE),
        Color(0xFF546E7A),
        Color(0xFF90A4AE),
        Color(0xFFE8EAED),
      ],
      innerRing: const [Color(0xFFF5F5F5), Color(0xFFB0BEC5)],
      gutter: const Color(0xFF0D1215),
      glow: [
        BoxShadow(
          color: const Color(0xFF607D8B).withAlpha(85),
          blurRadius: 16,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withAlpha(38),
          blurRadius: 11,
          offset: const Offset(0, 5),
        ),
      ],
      icon: Icons.favorite_rounded,
      shortLabel: 'SUPPORTER',
    );
  }
}

/// Double contour circulaire autour de l’avatar (profil + chat).
class DvcrAvatarRoleFrame extends StatelessWidget {
  final Widget child;
  final Set<UserRole> roles;
  final double innerDiameter;
  final double frameThickness;
  /// Image `config/role_badges` (médaillon bas-droite, hors photo profil).
  final String? badgeImageUrl;

  const DvcrAvatarRoleFrame({
    super.key,
    required this.child,
    required this.roles,
    required this.innerDiameter,
    this.frameThickness = 7,
    this.badgeImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final tier = dvcrMemberTierRole(roles);
    final v = _TierStyle.forRole(tier);
    final t = frameThickness;

    final frame = Container(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: v.glow),
      child: Container(
        padding: EdgeInsets.all(t * 0.42),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            startAngle: -0.9,
            endAngle: 2.35,
            colors: v.outerSweep,
            stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(t * 0.26),
          decoration: BoxDecoration(shape: BoxShape.circle, color: v.gutter),
          child: Container(
            padding: EdgeInsets.all(t * 0.26),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: v.innerRing,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: innerDiameter,
                height: innerDiameter,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    final url = badgeImageUrl?.trim() ?? '';
    if (url.isEmpty) return frame;

    final medallionD = innerDiameter * 0.42;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        frame,
        Positioned(
          right: -medallionD * 0.08,
          bottom: -medallionD * 0.08,
          child: DvcrRoleBadgeMedallion(
            imageUrl: url,
            diameter: medallionD,
          ),
        ),
      ],
    );
  }
}

bool dvcrRoleUsesTierBadge(UserRole r) {
  switch (r) {
    case UserRole.supporter:
    case UserRole.donateur:
    case UserRole.partenaire:
    case UserRole.teamDvcr:
      return true;
    default:
      return false;
  }
}

/// Pastille compacte à côté du pseudo (chat, listes).
class DvcrChatRoleCapsule extends StatelessWidget {
  final UserRole role;
  final bool small;
  /// URL `config/role_badges` pour ce rôle (aperçu à côté du libellé).
  final String? badgeImageUrl;

  const DvcrChatRoleCapsule({
    super.key,
    required this.role,
    this.small = false,
    this.badgeImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final v = _TierStyle.forRole(role);
    final h = small ? 19.0 : 22.0;
    final iconS = small ? 11.0 : 12.0;
    final padH = small ? 6.0 : 7.0;
    final imgUrl = badgeImageUrl?.trim() ?? '';
    final imgD = small ? 13.0 : 15.0;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            v.innerRing.first,
            v.innerRing.last.withAlpha(230),
          ],
        ),
        border: Border.all(color: v.gutter.withAlpha(180), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: v.innerRing.last.withAlpha(55),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imgUrl.isNotEmpty)
            Container(
              width: imgD,
              height: imgD,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: v.gutter.withAlpha(200),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(28),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    v.icon,
                    size: iconS * 0.95,
                    color: v.gutter.withAlpha(245),
                  ),
                ),
              ),
            )
          else
            Icon(v.icon, size: iconS, color: v.gutter.withAlpha(245)),
          SizedBox(width: imgUrl.isNotEmpty ? (small ? 4 : 5) : (small ? 3 : 4)),
          Text(
            v.shortLabel,
            style: GoogleFonts.inter(
              fontSize: small
                  ? (v.shortLabel.length > 14 ? 6.6 : 8.2)
                  : (v.shortLabel.length > 14 ? 7.4 : 9),
              fontWeight: FontWeight.w900,
              color: v.gutter.withAlpha(250),
              letterSpacing: v.shortLabel.length > 14 ? 0.15 : 0.35,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
