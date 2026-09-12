part of '../home_screen.dart';

class _NextMatchSectionHeader extends StatelessWidget {
  final VoidCallback? onSeeAll;

  const _NextMatchSectionHeader({this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeasonLifecycleConfig>(
      stream: SeasonLifecycleService.stream(),
      builder: (context, lifeSnap) {
        final life =
            lifeSnap.data ?? SeasonLifecycleConfig.defaults;
        if (life.betweenSeasons) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              HomeTheme.gutter,
              16,
              HomeTheme.gutter,
              HomeTheme.headerToBody,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 3, height: 18, color: HomeTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(life.homeHeadline, style: HomeType.section),
                      const SizedBox(height: 4),
                      Text(life.homeSubline, style: HomeType.caption),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                      child: Text(
                        'TOUT VOIR',
                        style: HomeType.kicker.copyWith(
                          color: HomeTheme.greenDeep,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return StreamBuilder<LiveHubState>(
          stream: const HomeLiveHubAdapter().watch(),
          initialData: const HomeLiveHubAdapter().latest,
          builder: (context, hubSnap) {
            final hub = hubSnap.data ?? LiveHubState.empty;
            return ListenableBuilder(
              listenable: const HomeMatchCatalogAdapter().listenable,
              builder: (context, _) {
                final ctrl = const HomeMatchCatalogAdapter();
                if (!_showHomeFeaturedMatchSection(ctrl, hub, life)) {
                  return const SizedBox.shrink();
                }
                final picked = _pickHomeFeaturedMatch(ctrl, hub);
                if (picked == null) {
                  return const SizedBox.shrink();
                }
                final match = _buildHomeDisplayMatch(picked, hub);
                final subtitle = _buildContextLabel(match, hub);
                final title = _homeFeaturedSectionTitle(match, hub);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HomeTheme.gutter,
                    16,
                    HomeTheme.gutter,
                    HomeTheme.headerToBody,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 3, height: 18, color: HomeTheme.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              key: ValueKey<String>(title),
                              style: HomeType.section,
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: Text(
                                subtitle,
                                key: ValueKey<String>(subtitle),
                                style: HomeType.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onSeeAll != null)
                        GestureDetector(
                          onTap: onSeeAll,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                            child: Text(
                              'TOUT VOIR',
                              style: HomeType.kicker.copyWith(
                                color: HomeTheme.greenDeep,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _buildContextLabel(MatchModel match, LiveHubState hub) {
    if (match.status == MatchStatus.live) {
      if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
        final minBit = LiveBannerFormat.minuteLabel(hub);
        return 'En direct · $minBit · ${match.competition}';
      }
      return '${match.competition}';
    }
    final now = DateTime.now();
    final dayDiff = calendarDaysFromToday(match.date);
    if (dayDiff < 0) {
      final elapsed = now.difference(match.date);
      if (elapsed <= _homeMatchHoldAfterKickoff) {
        return 'Depuis ${_timeLabel(match.date)} · ${match.competition}';
      }
      return 'Terminé · ${_dateLabel(match.date)}';
    }
    if (dayDiff == 0) {
      return 'Aujourd\'hui à ${_timeLabel(match.date)} · ${match.competition}';
    }
    if (dayDiff == 1) {
      return 'Demain à ${_timeLabel(match.date)} · ${match.competition}';
    }
    if (dayDiff < 7) {
      return 'Dans $dayDiff jours · ${_dateLabel(match.date)}';
    }
    if (dayDiff < 14) {
      return 'La semaine prochaine · ${_dateLabel(match.date)}';
    }
    final weeks = (dayDiff / 7).floor();
    if (weeks >= 2) {
      return 'Dans $weeks semaines · ${_dateLabel(match.date)}';
    }
    return _dateLabel(match.date);
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${hour}h$minute';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return 'Le ${date.day} ${months[date.month - 1]} à ${_timeLabel(date)}';
  }
}
