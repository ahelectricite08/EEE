import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kGold = Color(0xFFC8A436);

class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  const SectionHeaderWidget(
    this.title, {
    super.key,
    this.subtitle,
    this.leading,
    this.onSeeAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: subtitle == null ? 30 : 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE1C15A), _kGold],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _kGold.withAlpha(18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kGold.withAlpha(70)),
                        ),
                        child: Center(child: leading),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.3,
                          height: 0.95,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null || onSeeAll != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailing != null) ...[trailing!],
                if (trailing != null && onSeeAll != null)
                  const SizedBox(height: 8),
                if (onSeeAll != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeeAll,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _kGold.withAlpha(18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _kGold.withAlpha(75)),
                        ),
                        child: Text(
                          'VOIR TOUT',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
