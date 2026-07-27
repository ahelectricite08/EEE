import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_module_colors.dart';
import 'admin_palette.dart';

/// Bandeau densifié Users — compteurs régie, sans carte crème / pills décoratives.
class AdminUsersHeroCard extends StatelessWidget {
  /// Total réel (`users.count()`), aligné sur le pilotage.
  final int total;
  /// Nombre de fiches chargées dans la liste.
  final int displayed;
  final int admins;
  final int teamDvcr;
  final int supporters;

  const AdminUsersHeroCard({
    super.key,
    required this.total,
    required this.displayed,
    required this.admins,
    required this.teamDvcr,
    required this.supporters,
  });

  static const _accent = AdminModuleColors.administration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rôles, badges et accès — tire vers le bas pour recharger.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: adminGrey,
              height: 1.35,
            ),
          ),
          if (displayed < total) ...[
            const SizedBox(height: 6),
            Text(
              '$displayed / $total comptes chargés',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _accent,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: adminSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: adminBorder),
            ),
            child: Row(
              children: [
                _StatCell(label: 'TOTAL', value: '$total'),
                _divider(),
                _StatCell(label: 'ADMINS', value: '$admins', color: adminRed),
                _divider(),
                _StatCell(
                  label: 'TEAM',
                  value: '$teamDvcr',
                  color: _accent,
                ),
                _divider(),
                _StatCell(label: 'SUPPORT', value: '$supporters'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: adminBorder,
      );
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCell({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color ?? adminGreyLight,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
