import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/home_motion.dart';
import 'matches_feed_tab.dart';
import 'matches_helpers.dart';
import 'matches_palette.dart';
import 'matches_ranking_tab.dart';

const double _kHeroBottomRadius = 24;

class MatchesScreen extends StatefulWidget {
  /// Onglet interne initial (0 = à venir, 1 = résultats, 2 = classement).
  final int initialTabIndex;

  const MatchesScreen({super.key, this.initialTabIndex = 0});

  @override
  MatchesScreenState createState() => MatchesScreenState();
}

class MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final VoidCallback _onTabChanged;
  DateTime _focusMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _shiftMonth(int delta) {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + delta, 1);
    });
  }

  /// Sélectionne un onglet du calendrier (depuis la navigation principale).
  void selectTab(int index) {
    if (!mounted) return;
    final i = index.clamp(0, 2);
    if (_tabController.index == i) return;
    _tabController.animateTo(i);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _onTabChanged = () => setState(() {});
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMonthBar = _tabController.index < 2;

    return Scaffold(
      backgroundColor: kMatchesSheet,
      body: NestedScrollView(
        clipBehavior: Clip.hardEdge,
        headerSliverBuilder: (context, _) => [
          _MatchesHeroSliver(
            tabController: _tabController,
            focusMonth: _focusMonth,
            onPrevMonth: () => _shiftMonth(-1),
            onNextMonth: () => _shiftMonth(1),
            showMonthBar: showMonthBar,
          ),
        ],
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(18),
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              MatchesFeedTab(
                mode: MatchesViewMode.upcoming,
                focusMonth: _focusMonth,
              ),
              MatchesFeedTab(
                mode: MatchesViewMode.results,
                focusMonth: _focusMonth,
              ),
              const MatchesRankingTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab avec icône + label ────────────────────────────────────────────────────
class _MatchTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MatchTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

// ── Bouton flèche mois ────────────────────────────────────────────────────────
class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(50)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _MatchesHeroSliver extends StatefulWidget {
  final TabController tabController;
  final DateTime focusMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final bool showMonthBar;

  const _MatchesHeroSliver({
    required this.tabController,
    required this.focusMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.showMonthBar,
  });

  @override
  State<_MatchesHeroSliver> createState() => _MatchesHeroSliverState();
}

class _MatchesHeroSliverState extends State<_MatchesHeroSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  static const _heroNetwork =
      'https://static.wixstatic.com/media/4ebc61_12bf15e736a344ba8bd86f482cc37aac~mv2.jpg';

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  Widget _heroImage() {
    return Image.network(
      _heroNetwork,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.05),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/IMG_0842.JPG',
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.28),
        errorBuilder: (_, _, _) =>
            const ColoredBox(color: kMatchesHeaderBgDeep),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final focusMonth = widget.focusMonth;
    final showMonthBar = widget.showMonthBar;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 228 + topInset.toDouble(),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(_kHeroBottomRadius),
        ),
      ),
      automaticallyImplyLeading: false,
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      backgroundColor: kMatchesHeaderBgDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_kHeroBottomRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _heroImage()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(115),
                      Colors.black.withAlpha(50),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),
            FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _heroImage()),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            kMatchesGreenDeep.withAlpha(238),
                            kMatchesGreen.withAlpha(115),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.36, 0.8],
                        ),
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
                            begin: Alignment(-0.9 + v * 0.45, -0.15),
                            end: Alignment(0.85 - v * 0.35, 1),
                            colors: [
                              kMatchesGold.withAlpha(14 + (v * 22).round()),
                              Colors.transparent,
                              kMatchesGold
                                  .withAlpha(8 + ((1 - v) * 16).round()),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Text(
                      'À venir · Résultats · Classement',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(235),
                        height: 1.25,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(showMonthBar ? 114 : 68),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(_kHeroBottomRadius),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kMatchesHeaderBg, kMatchesHeaderBgDeep],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, showMonthBar ? 14 : 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Tab bar ──────────────────────────────────────────────
                  HomeReveal(
                    delay: Duration.zero,
                    slideBegin: const Offset(0, 0.05),
                    duration: const Duration(milliseconds: 360),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withAlpha(40),
                          width: 1,
                        ),
                      ),
                      child: TabBar(
                        controller: widget.tabController,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(28),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: kMatchesGreenDeep,
                        unselectedLabelColor: Colors.white.withAlpha(215),
                        isScrollable: false,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        unselectedLabelStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        labelPadding: EdgeInsets.zero,
                        tabs: const [
                          _MatchTab(
                            icon: Icons.calendar_today_rounded,
                            label: 'À venir',
                          ),
                          _MatchTab(
                            icon: Icons.emoji_events_rounded,
                            label: 'Résultats',
                          ),
                          _MatchTab(
                            icon: Icons.leaderboard_rounded,
                            label: 'Classement',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Barre mois / sous-titre ───────────────────────────────
                  if (showMonthBar) ...[
                    const SizedBox(height: 10),
                    HomeReveal(
                      delay: const Duration(milliseconds: 40),
                      slideBegin: const Offset(0, 0.04),
                      duration: const Duration(milliseconds: 320),
                      child: Row(
                        children: [
                          _MonthArrow(
                            icon: Icons.chevron_left_rounded,
                            onTap: widget.onPrevMonth,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _months[focusMonth.month - 1].toUpperCase(),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                    height: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${focusMonth.year}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kMatchesGold,
                                    letterSpacing: 1,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          _MonthArrow(
                            icon: Icons.chevron_right_rounded,
                            onTap: widget.onNextMonth,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    HomeReveal(
                      delay: const Duration(milliseconds: 40),
                      slideBegin: const Offset(0, 0.04),
                      duration: const Duration(milliseconds: 320),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle,
                              size: 5, color: kMatchesGold.withAlpha(180)),
                          const SizedBox(width: 6),
                          Text(
                            'Saison en cours',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(180),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.circle,
                              size: 5, color: kMatchesGold.withAlpha(180)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
