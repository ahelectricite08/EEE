import 'package:flutter/material.dart';

import '../theme/calendar_theme.dart';
import '../theme/calendar_type.dart';

/// Filet + kicker — en-tête de section magazine.
class CalendarSectionHeader extends StatelessWidget {
  final String title;
  final String? countLabel;
  final Widget? action;

  const CalendarSectionHeader({
    super.key,
    required this.title,
    this.countLabel,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Container(width: 16, height: 3, color: CalendarTheme.accent),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CalendarType.kicker.copyWith(color: CalendarTheme.text),
            ),
          ),
          if (countLabel != null && countLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(countLabel!, style: CalendarType.meta),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class CalendarRule extends StatelessWidget {
  final double top;
  final double bottom;

  const CalendarRule({super.key, this.top = 0, this.bottom = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: const ColoredBox(
        color: CalendarTheme.hairline,
        child: SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}

/// Segment sportif souligné — jamais une pilule Material.
class CalendarFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CalendarFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: CalendarTheme.animFast,
        curve: CalendarTheme.animCurve,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? CalendarTheme.ink : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? CalendarTheme.ink : CalendarTheme.hairline,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: CalendarType.kicker.copyWith(
            color: selected ? Colors.white : CalendarTheme.textMuted,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Sélecteur papier Mon équipe / Toutes les équipes — filet or sur l’actif,
/// jamais chip Material ni aplat vert.
class CalendarTeamScopeBar extends StatelessWidget {
  final bool favoriteOnly;
  final ValueChanged<bool> onChanged;
  final bool showClubMark;
  final String clubMark;

  const CalendarTeamScopeBar({
    super.key,
    required this.favoriteOnly,
    required this.onChanged,
    this.showClubMark = true,
    this.clubMark = 'CS',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CalendarTheme.gutter,
        6,
        CalendarTheme.gutter,
        4,
      ),
      child: DecoratedBox(
        decoration: CalendarTheme.paperQuiet(radius: CalendarTheme.paperRadius),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: _TeamScopeSegment(
                  label: 'Mon équipe',
                  selected: favoriteOnly,
                  showMark: showClubMark,
                  mark: clubMark,
                  onTap: () => onChanged(true),
                ),
              ),
              const ColoredBox(
                color: CalendarTheme.hairline,
                child: SizedBox(width: 1, height: double.infinity),
              ),
              Expanded(
                child: _TeamScopeSegment(
                  label: 'Toutes les équipes',
                  selected: !favoriteOnly,
                  showMark: false,
                  mark: '',
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamScopeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool showMark;
  final String mark;
  final VoidCallback onTap;

  const _TeamScopeSegment({
    required this.label,
    required this.selected,
    required this.showMark,
    required this.mark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showMark) ...[
                      _ClubMarkDisc(mark: mark, selected: selected),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      style: CalendarType.kicker.copyWith(
                        color: selected
                            ? CalendarTheme.text
                            : CalendarTheme.textMuted,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubMarkDisc extends StatelessWidget {
  final String mark;
  final bool selected;

  const _ClubMarkDisc({required this.mark, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CalendarTheme.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? CalendarTheme.gold : CalendarTheme.hairline,
        ),
      ),
      child: Text(
        mark,
        style: CalendarType.kicker.copyWith(
          fontSize: 8,
          letterSpacing: 0.4,
          color: selected ? CalendarTheme.goldDeep : CalendarTheme.textMuted,
        ),
      ),
    );
  }
}

class CalendarEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const CalendarEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: CalendarTheme.edgeHighlight),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CalendarType.headline.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 12),
          Container(width: 34, height: 3, color: CalendarTheme.accent),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: CalendarType.caption,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 22),
            action!,
          ],
        ],
      ),
    );
  }
}

class CalendarErrorState extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;

  const CalendarErrorState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return CalendarEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      body: body,
      action: action,
    );
  }
}

/// Squelette — contenants papier, pas une réglure.
class CalendarLoadingTape extends StatelessWidget {
  final int rows;
  final double horizontalPadding;

  const CalendarLoadingTape({
    super.key,
    this.rows = 5,
    this.horizontalPadding = CalendarTheme.gutter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (i) {
        final fade = 1.0 - (i * 0.14).clamp(0.0, 0.6);
        return Opacity(
          opacity: fade,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              CalendarTheme.fixtureGap,
            ),
            child: Container(
              height: 148,
              decoration: CalendarTheme.fixturePaper(),
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
              child: Row(
                children: [
                  _disc(38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(72, 8),
                        const SizedBox(height: 12),
                        _bar(150, 12),
                        const SizedBox(height: 9),
                        _bar(104, 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _disc(38),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  static Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        color: CalendarTheme.surfaceMuted,
      );

  static Widget _disc(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CalendarTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: CalendarTheme.hairline),
        ),
      );
}

class CalendarPaperNav extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CalendarPaperNav({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          width: 40,
          height: 40,
          decoration: CalendarTheme.paperQuiet(),
          child: Icon(icon, color: CalendarTheme.text, size: 22),
        ),
      ),
    );
  }
}
