import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';
import '../services/app_settings_service.dart';
import 'dvcr_member_role_badge.dart';
import 'member_badge_info.dart';

/// Galerie **décorative** : médaillons **Membre** et **Membre DVCR** uniquement.
class MemberRoleBadgesPreview extends StatelessWidget {
  final Color mutedColor;
  final double medallionDiameter;

  const MemberRoleBadgesPreview({
    super.key,
    this.mutedColor = const Color(0xFF5C6560),
    this.medallionDiameter = 50,
  });

  static const _previewRoles = <UserRole>[
    UserRole.supporter,
    UserRole.teamDvcr,
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoleBadgeSettings>(
      stream: AppSettingsService.roleBadgesStream(),
      builder: (context, snap) {
        final settings = snap.data ?? const RoleBadgeSettings(badges: {});
        final badges = settings.badges;

        return Semantics(
          container: true,
          label: 'Badges membres, appuyer pour voir le statut gratuit',
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (final role in _previewRoles)
                _RoleMedallionTile(
                  role: role,
                  label: settings.labelForKey(
                    roleBadgeConfigKey(role),
                    role.displayName,
                  ),
                  imageUrl: badges[roleBadgeConfigKey(role)],
                  diameter: medallionDiameter,
                  labelColor: mutedColor,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleMedallionTile extends StatelessWidget {
  final UserRole role;
  final String label;
  final String? imageUrl;
  final double diameter;
  final Color labelColor;

  const _RoleMedallionTile({
    required this.role,
    required this.label,
    required this.imageUrl,
    required this.diameter,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';

    return MemberBadgeInfoTrigger(
      enabled: MemberBadgeInfo.roleQualifies(role) ||
          MemberBadgeInfo.labelQualifies(label),
      badgeLabel: label,
      child: SizedBox(
        width: diameter + 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url.isNotEmpty)
              DvcrRoleBadgeMedallion(imageUrl: url, diameter: diameter)
            else
              _RoleMedallionFallback(role: role, diameter: diameter),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: labelColor.withValues(alpha: 0.88),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleMedallionFallback extends StatelessWidget {
  final UserRole role;
  final double diameter;

  const _RoleMedallionFallback({
    required this.role,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter + 8,
      height: diameter + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: const [
            Color(0xFFFFF8E1),
            Color(0xFFC8A436),
            Color(0xFF5D4A1A),
            Color(0xFFC8A436),
            Color(0xFFFFF8E1),
          ],
          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1A2522),
        ),
        child: Icon(
          role == UserRole.teamDvcr
              ? Icons.bolt_rounded
              : Icons.favorite_rounded,
          size: diameter * 0.42,
          color: const Color(0xFFC8A436),
        ),
      ),
    );
  }
}
