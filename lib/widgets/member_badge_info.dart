import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_role.dart';

/// Bulle d’info App Store : badges membre = statut gratuit, sans achat in-app.
abstract final class MemberBadgeInfo {
  static bool roleQualifies(UserRole role) {
    switch (role) {
      case UserRole.supporter:
      case UserRole.teamDvcr:
      case UserRole.donateur:
      case UserRole.partenaire:
        return true;
      default:
        return false;
    }
  }

  static bool labelQualifies(String? label) {
    final n = label?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return false;
    return n.contains('supporter') ||
        n.contains('membre') ||
        n.contains('inscrit');
  }

  static bool xpLevelLabelQualifies(String label) {
    final n = label.trim().toLowerCase();
    return n.contains('supporter') || n == 'membre';
  }

  static Future<void> show(
    BuildContext context, {
    String? badgeLabel,
  }) {
    final custom = badgeLabel?.trim();
    final title = custom != null && custom.isNotEmpty
        ? custom.toUpperCase()
        : 'MEMBRE';

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFFF5F2E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6560).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A4438).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF0A4438),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Statut gratuit',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0A4438),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Le badge « $title » est un statut communautaire '
                  'purement décoratif, obtenu gratuitement à l’inscription.\n\n'
                  'Aucun achat in-app, aucun paiement et aucun avantage payant '
                  'n’est associé à ce badge.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.55,
                    color: const Color(0xFF5C6560),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4438),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Compris',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Enveloppe un badge / pastille membre : tap → bulle « statut gratuit ».
class MemberBadgeInfoTrigger extends StatelessWidget {
  const MemberBadgeInfoTrigger({
    super.key,
    required this.child,
    required this.enabled,
    this.badgeLabel,
  });

  final Widget child;
  final bool enabled;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Semantics(
      button: true,
      label: 'Badge membre — statut gratuit. Appuyer pour plus d’informations.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => MemberBadgeInfo.show(context, badgeLabel: badgeLabel),
          borderRadius: BorderRadius.circular(999),
          child: child,
        ),
      ),
    );
  }
}

/// Petite icône (i) à côté d’un libellé « Supporter » / « Membre ».
class MemberBadgeInfoIconButton extends StatelessWidget {
  const MemberBadgeInfoIconButton({
    super.key,
    this.badgeLabel,
    this.iconSize = 16,
    this.color = const Color(0xFF0A4438),
  });

  final String? badgeLabel;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Informations sur le statut membre gratuit',
      child: InkWell(
        onTap: () => MemberBadgeInfo.show(context, badgeLabel: badgeLabel),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.info_outline_rounded,
            size: iconSize,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
