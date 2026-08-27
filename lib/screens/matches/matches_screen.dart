import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../calendar/calendar_controls.dart';
import '../calendar/calendar_header.dart';
import '../calendar/theme/calendar_theme.dart';
import '../calendar/theme/calendar_type.dart';
import '../calendar/widgets/calendar_hero_sliver.dart';
import 'matches_feed_tab.dart';
import 'matches_helpers.dart';
import 'matches_ranking_tab.dart';

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

  String get _heroTitle {
    switch (_tabController.index) {
      case 1:
        return 'Résultats';
      case 2:
        return 'Classement';
      default:
        return 'À venir';
    }
  }

  String get _heroSubtitle {
    if (_tabController.index == 2) {
      return 'Le tableau de la saison';
    }
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${months[_focusMonth.month - 1]} ${_focusMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final showMonthBar = _tabController.index < 2;
    final stripHeight = showMonthBar ? 148.0 : 52.0;

    return Scaffold(
      backgroundColor: CalendarTheme.scaffold,
      body: NestedScrollView(
        clipBehavior: Clip.hardEdge,
        headerSliverBuilder: (context, _) => [
          StreamBuilder<HubHeroBannersSettings>(
            stream: AppSettingsService.hubHeroBannersStream(),
            initialData: AppSettingsService.lastKnownHubHeroBanners,
            builder: (context, snap) {
              final banners =
                  snap.data ?? AppSettingsService.lastKnownHubHeroBanners;
              return CalendarHeroSliver.sliverAppBar(
                context,
                title: _heroTitle,
                subtitle: _heroSubtitle,
                heroImageUrl: banners.urlForSlot(HubHeroSlot.calendar),
                revisionMillis: banners.revisionMillis,
                bottom: CalendarPaperStrip(
                  height: stripHeight,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicator: const UnderlineTabIndicator(
                          borderSide: BorderSide(
                            color: CalendarTheme.ink,
                            width: 3,
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: CalendarTheme.text,
                        unselectedLabelColor: CalendarTheme.textMuted,
                        labelStyle: CalendarType.kicker.copyWith(
                          letterSpacing: 1.2,
                          color: CalendarTheme.text,
                        ),
                        unselectedLabelStyle: CalendarType.kicker.copyWith(
                          letterSpacing: 1.2,
                          color: CalendarTheme.textMuted,
                        ),
                        overlayColor: WidgetStateProperty.all(
                          CalendarTheme.accent.withValues(alpha: 0.06),
                        ),
                        tabs: const [
                          Tab(text: 'À VENIR', height: 46),
                          Tab(text: 'RÉSULTATS', height: 46),
                          Tab(text: 'CLASSEMENT', height: 46),
                        ],
                      ),
                      if (showMonthBar)
                        Expanded(
                          child: MonthBar(
                            focus: _focusMonth,
                            onPrev: () => _shiftMonth(-1),
                            onNext: () => _shiftMonth(1),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        body: ColoredBox(
          color: CalendarTheme.scaffold,
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
