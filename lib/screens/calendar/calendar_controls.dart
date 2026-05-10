import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'calendar_helpers.dart';
import 'calendar_palette.dart';

class MonthBar extends StatelessWidget {
  final DateTime focus;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const MonthBar({
    super.key,
    required this.focus,
    required this.onPrev,
    required this.onNext,
  });

  static const _months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Row(
        children: [
          _NavCircle(icon: Icons.chevron_left_rounded, onTap: onPrev),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _months[focus.month - 1],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: kSedanGreenDeep,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                ),
                Text(
                  focus.year.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kSedanGold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 56,
                  decoration: BoxDecoration(
                    color: kSedanGold,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: kSedanGold.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _NavCircle(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class CompetitionBar extends StatelessWidget {
  final List<String> competitions;
  final String selected;
  final ValueChanged<String> onSelected;

  const CompetitionBar({
    super.key,
    required this.competitions,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: kSedanIvory,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSedanGold.withAlpha(90)),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final competition = competitions[index];
            final active = competition == selected;
            return Center(
              child: GestureDetector(
                onTap: () => onSelected(competition),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? kSedanGreenDeep : kSedanCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? kSedanGold : kSedanBorder,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: kSedanGold.withAlpha(70),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    competition == 'TOUT' ? 'Tout' : competition,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : kSedanText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          itemCount: competitions.length,
        ),
      ),
    );
  }
}

class FavoriteTeamBar extends StatelessWidget {
  final String favoriteTeam;
  final bool favoriteOnly;
  final ValueChanged<bool> onChanged;

  const FavoriteTeamBar({
    super.key,
    required this.favoriteTeam,
    required this.favoriteOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        scrollDirection: Axis.horizontal,
        children: [
          _FavoriteModeChip(
            label: 'Mon équipe',
            subtitle: favoriteTeam,
            active: favoriteOnly,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 10),
          _FavoriteModeChip(
            label: 'Tout voir',
            subtitle: 'Toutes les affiches',
            active: !favoriteOnly,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class DaySelectorBar extends StatelessWidget {
  final List<DateTime> days;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelected;

  const DaySelectorBar({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = selectedDay != null && isSameDay(selectedDay!, day);
          return GestureDetector(
            onTap: () => onSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 62,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: active ? kSedanGold : kSedanCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? kSedanGreenDeep : kSedanBorder,
                  width: active ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (active ? kSedanGold : Colors.black)
                        .withAlpha(active ? 90 : 12),
                    blurRadius: active ? 14 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayShort(day),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: active
                          ? kSedanGreenDeep.withAlpha(220)
                          : kSedanMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: active ? kSedanGreenDeep : kSedanText,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kSedanCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kSedanGold.withAlpha(100)),
            boxShadow: [
              BoxShadow(
                color: kSedanGreenDeep.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: kSedanGreenDeep, size: 24),
        ),
      ),
    );
  }
}

class _FavoriteModeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _FavoriteModeChip({
    required this.label,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? kSedanGreen : kSedanCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? kSedanGreen : kSedanBorder,
              width: active ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(active ? 12 : 5),
                blurRadius: active ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.star_rounded : Icons.tune_rounded,
                size: 18,
                color: active ? kSedanGold : kSedanGreen,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : kSedanText,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors.white.withAlpha(210)
                            : kSedanMuted,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
