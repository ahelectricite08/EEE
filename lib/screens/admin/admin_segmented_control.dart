import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

/// Option pour [AdminSegmentedControl].
class AdminSegmentOption {
  final String value;
  final String label;
  final IconData? icon;

  const AdminSegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Filtre segmenté (À venir / Résultats / Tous…).
class AdminSegmentedControl extends StatelessWidget {
  final List<AdminSegmentOption> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color accent;

  const AdminSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.accent = adminGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _AdminSegmentTile(
                option: options[i],
                selected: selected == options[i].value,
                accent: accent,
                onTap: () => onChanged(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminSegmentTile extends StatelessWidget {
  final AdminSegmentOption option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _AdminSegmentTile({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(22) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? accent.withAlpha(90) : Colors.transparent,
            ),
          ),
          child: Text(
            option.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? accent : adminGrey,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
