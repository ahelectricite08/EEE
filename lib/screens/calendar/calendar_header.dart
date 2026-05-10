import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/cssa_favorite_ranking_share_button.dart';
import '../home/home_motion.dart';
import '../matches/matches_helpers.dart';
import 'calendar_helpers.dart';
import 'calendar_palette.dart';

class SedanResultsHeader extends StatefulWidget {
  final DateTime focus;
  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onModeChanged;
  /// Pour partager le classement Firestore de l’équipe favorite (coin du bandeau).
  final String? favoriteTeam;
  /// Saison du doc `ranking` (alignée sur l’onglet Classement matchs).
  final String rankingSeason;

  const SedanResultsHeader({
    super.key,
    required this.focus,
    required this.mode,
    required this.onModeChanged,
    this.favoriteTeam,
    this.rankingSeason = '2025-2026',
  });

  @override
  State<SedanResultsHeader> createState() => _SedanResultsHeaderState();
}

class _SedanResultsHeaderState extends State<SedanResultsHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focus;
    final seasonLabel = focus.month >= 7
        ? '${focus.year}/${(focus.year + 1).toString().substring(2)}'
        : '${focus.year - 1}/${focus.year.toString().substring(2)}';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeReveal(
            delay: Duration.zero,
            slideBegin: const Offset(0, -0.045),
            duration: const Duration(milliseconds: 440),
            child: _heroStrip(),
          ),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kSedanGreen, kSedanGreenDeep],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeReveal(
                  delay: Duration.zero,
                  slideBegin: const Offset(0, 0.04),
                  duration: const Duration(milliseconds: 400),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedAccentBar(controller: _ambient),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: kSedanGold.withAlpha(45),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withAlpha(85),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kSedanGold.withAlpha(35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'CALENDRIER CSSA',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'FIERS. FORTS. FÉROCES.',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                                height: 0.98,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(70),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Calendrier et résultats du club',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(220),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      HomeReveal(
                        delay: const Duration(milliseconds: 24),
                        slideBegin: const Offset(0.06, 0),
                        duration: const Duration(milliseconds: 360),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CssaFavoriteRankingShareButton(
                              season: widget.rankingSeason,
                              favoriteTeam: widget.favoriteTeam,
                              leagueLabel: rankingLeagueLabel(widget.rankingSeason),
                              style: CssaRankingShareStyle.calendarGreen,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(32),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withAlpha(55),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(40),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                HomeReveal(
                  delay: const Duration(milliseconds: 55),
                  slideBegin: const Offset(0, 0.05),
                  duration: const Duration(milliseconds: 420),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopModeTab(
                          label: 'À venir',
                          subtitle: 'Saison $seasonLabel',
                          active: widget.mode == CalendarViewMode.upcoming,
                          onTap: () => widget.onModeChanged(
                            CalendarViewMode.upcoming,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopModeTab(
                          label: 'Résultats',
                          subtitle: 'Matchs terminés',
                          active: widget.mode == CalendarViewMode.results,
                          onTap: () => widget.onModeChanged(
                            CalendarViewMode.results,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStrip() {
    return SizedBox(
      height: 118,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/IMG_0842.JPG',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.32),
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: kSedanGreenDeep,
              child: Icon(
                Icons.sports_soccer_rounded,
                size: 48,
                color: Colors.white.withAlpha(40),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(55),
                  Colors.black.withAlpha(120),
                  kSedanGreen.withAlpha(230),
                  kSedanGreen,
                ],
                stops: const [0.0, 0.35, 0.78, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, child) {
              final v = _ambient.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.85 + v * 0.35, -1),
                    end: Alignment(0.85 - v * 0.35, 0.9),
                    colors: [
                      kSedanGold.withAlpha(18 + (v * 22).round()),
                      Colors.transparent,
                      kSedanGold.withAlpha(12 + ((1 - v) * 18).round()),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedAccentBar extends StatelessWidget {
  const _AnimatedAccentBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final h = 44.0 + controller.value * 10;
        return Container(
          width: 4,
          height: h,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kSedanGold,
                Color.lerp(
                  kSedanGold,
                  Colors.white,
                  0.35 + controller.value * 0.25,
                )!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: kSedanGold.withAlpha(50 + (controller.value * 40).round()),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopModeTab extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _TopModeTab({
    required this.label,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScaleOnPress(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: active ? kSedanGold : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? kSedanGold
                    : Colors.white.withAlpha(110),
                width: active ? 2 : 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(55),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.black : Colors.white,
                    letterSpacing: 0.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? kSedanText.withAlpha(200)
                        : Colors.white.withAlpha(200),
                    height: 1.2,
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
