import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';

/// Carte réutilisable pour sections réglages / staff.
class SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: adminPaper(),
          child: child,
        ),
      ],
    );
  }
}
