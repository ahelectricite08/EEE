import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kGold   = Color(0xFFC8A436);
const _kBorder = Color(0xFF2A2A2A);
const _kGrey   = Color(0xFF666666);

class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final Widget? leading;
  final VoidCallback? onSeeAll;

  const SectionHeaderWidget(
    this.title, {
    super.key,
    this.leading,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barre or
          Container(
            width: 3, height: 22,
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (leading != null) ...[leading!, const SizedBox(width: 7)],
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'VOIR TOUT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kGold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
