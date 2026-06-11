import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBorder = Color(0xFF2A2A2A);
const _kGold = Color(0xFFC8A436);

enum DVCRActionTone { neutral, primary, active }

class DVCRActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final DVCRActionTone tone;
  final bool compact;

  const DVCRActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.label,
    this.tone = DVCRActionTone.neutral,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = switch (tone) {
      DVCRActionTone.neutral => Colors.white,
      DVCRActionTone.primary => _kGold,
      DVCRActionTone.active => _kGold,
    };
    final background = switch (tone) {
      DVCRActionTone.neutral => Colors.black.withAlpha(115),
      DVCRActionTone.primary => _kGold.withAlpha(22),
      DVCRActionTone.active => _kGold.withAlpha(28),
    };
    final border = switch (tone) {
      DVCRActionTone.neutral => _kBorder,
      DVCRActionTone.primary => _kGold.withAlpha(90),
      DVCRActionTone.active => _kGold,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 999 : 12),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 10 : 12,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(compact ? 999 : 12),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: foreground),
              if (label != null) ...[
                const SizedBox(width: 7),
                Text(
                  label!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
