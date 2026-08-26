import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_theme.dart';
import 'home_type.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onSeeAll;
  final Widget? trailing;
  final bool showBadge;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.accent,
    this.onSeeAll,
    this.trailing,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? HomeTheme.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 2, height: 22, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: HomeType.section),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: HomeType.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onSeeAll != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Voir tout',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tone,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const HomeToolbarButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(26),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(70)),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        ),
      ),
    );
  }
}
