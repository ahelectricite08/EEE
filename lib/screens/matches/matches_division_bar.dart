import 'package:flutter/material.dart';

import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';

/// Sélecteur papier R1 | R2 — calendrier (À venir / Résultats) et classement.
enum MatchesFffDivision { r1, r2 }

class MatchesDivisionBar extends StatelessWidget {
  final MatchesFffDivision division;
  final ValueChanged<MatchesFffDivision> onChanged;

  /// Libellé compétition R2 (même champ que le classement).
  final String r2Subtitle;

  const MatchesDivisionBar({
    super.key,
    required this.division,
    required this.onChanged,
    this.r2Subtitle = 'Régional 2',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        4,
        CalendarTheme.gutter,
        8,
      ),
      child: DecoratedBox(
        decoration: CalendarTheme.paperQuiet(radius: CalendarTheme.paperRadius),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: _MatchesDivisionSegment(
                  label: 'R1',
                  subtitle: 'Régional 1',
                  selected: division == MatchesFffDivision.r1,
                  onTap: () => onChanged(MatchesFffDivision.r1),
                ),
              ),
              const ColoredBox(
                color: CalendarTheme.hairline,
                child: SizedBox(width: 1, height: double.infinity),
              ),
              Expanded(
                child: _MatchesDivisionSegment(
                  label: 'R2',
                  subtitle: r2Subtitle,
                  selected: division == MatchesFffDivision.r2,
                  onTap: () => onChanged(MatchesFffDivision.r2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchesDivisionSegment extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MatchesDivisionSegment({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: CalendarTheme.gold.withValues(alpha: 0.08),
          highlightColor: CalendarTheme.gold.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: CalendarTheme.animFast,
            curve: CalendarTheme.animCurve,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? CalendarTheme.gold : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: CalendarType.title.copyWith(
                    fontSize: 20,
                    color: selected
                        ? CalendarTheme.text
                        : CalendarTheme.textMuted,
                  ),
                ),
                Text(
                  subtitle.toUpperCase(),
                  style: CalendarType.kicker.copyWith(
                    fontSize: 8,
                    letterSpacing: 1.1,
                    color: selected
                        ? CalendarTheme.textSoft
                        : CalendarTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
