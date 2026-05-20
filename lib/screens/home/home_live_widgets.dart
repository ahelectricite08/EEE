part of 'home_screen.dart';

class _PodcastQuickEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PodcastQuickEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: homeGreen.withAlpha(14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: homeGreen.withAlpha(55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_calendar_rounded,
                size: 14,
                color: homeGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'EDITER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: homeGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  final String label;

  const _HeroMetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isFulltime = label == 'FIN DE MATCH';
    final isHalftime = label == 'MI-TEMPS';
    final isStats = label == 'STATS';
    final isDirect = label == 'DIRECT';
    final chipColor = isFulltime
        ? Colors.red
        : isHalftime
        ? const Color(0xFFFF9800)
        : Colors.white;

    IconData? icon;
    if (isFulltime) {
      icon = Icons.sports_score_rounded;
    } else if (isHalftime) {
      icon = Icons.coffee_rounded;
    } else if (isStats) {
      icon = Icons.bar_chart_rounded;
    } else if (isDirect) {
      icon = Icons.circle;
    } else {
      icon = Icons.timer_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: chipColor.withAlpha(isFulltime || isHalftime ? 100 : 70),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isDirect ? 6 : 11,
            color: isDirect ? Colors.greenAccent : chipColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLiveEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final String homeTeam;
  final String awayTeam;
  final bool alignRight;

  const _HeroLiveEventRow({
    required this.event,
    required this.homeTeam,
    required this.awayTeam,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = (event['type'] as String? ?? '').trim().toLowerCase();
    final minute =
        (event['minuteValue'] as int?) ?? (event['minute'] as int?) ?? 0;
    final player = (event['player'] as String? ?? '').trim();

    Color accent;
    IconData icon;
    switch (type) {
      case 'yellow':
        accent = const Color(0xFFE8C82A);
        icon = Icons.crop_portrait_rounded;
        break;
      case 'red':
        accent = const Color(0xFFBA203C);
        icon = Icons.crop_portrait_rounded;
        break;
      default:
        accent = const Color(0xFFC8A436);
        icon = Icons.sports_soccer_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (alignRight)
            Text(
              minute > 0 ? "$minute'" : '',
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          if (alignRight) const SizedBox(width: 8),
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              player,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(230),
                height: 1.05,
              ),
            ),
          ),
          if (!alignRight) const SizedBox(width: 8),
          if (!alignRight)
            Text(
              minute > 0 ? "$minute'" : '',
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingLiveBadge extends StatelessWidget {
  final double pulse;
  const _PulsingLiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(55)),
        boxShadow: [
          BoxShadow(
            color: _kRed.withAlpha((50 + (pulse * 100).round())),
            blurRadius: 6 + pulse * 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _kRed,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return HomeToolbarButton(
      icon: icon,
      onTap: onTap,
      iconColor: color ?? Colors.white,
    );
  }
}

class _PodcastSection extends StatefulWidget {
  const _PodcastSection();

  @override
  State<_PodcastSection> createState() => _PodcastSectionState();
}

class _PodcastSectionState extends State<_PodcastSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playingEdge;

  @override
  void initState() {
    super.initState();
    _playingEdge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    PodcastController.instance.addListener(_syncPlayingEdge);
    _syncPlayingEdge();
  }

  void _syncPlayingEdge() {
    final c = PodcastController.instance;
    if (c.isPlaying) {
      if (!_playingEdge.isAnimating) {
        _playingEdge.repeat(reverse: true);
      }
    } else {
      _playingEdge.stop();
      _playingEdge.value = 0;
    }
  }

  @override
  void dispose() {
    PodcastController.instance.removeListener(_syncPlayingEdge);
    _playingEdge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        if (ctrl.isLoading) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: homeGreen,
                ),
              ),
            ),
          );
        }
        if (ctrl.episodes.isEmpty) return const SizedBox();

        return SizedBox(
          height: 152,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 4, 14, 8),
            physics: const BouncingScrollPhysics(),
            itemCount: ctrl.episodes.length,
            itemBuilder: (context, i) {
              final ep = ctrl.episodes[i];
              final isActive = ctrl.currentIndex == i;
              final playingHere = isActive && ctrl.isPlaying;

              Widget playIconBox() => Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: homeGreen.withAlpha(isActive ? 28 : 14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: homeGreen.withAlpha(isActive ? 70 : 40),
                      ),
                    ),
                    child: Icon(
                      playingHere
                          ? Icons.pause_rounded
                          : Icons.graphic_eq_rounded,
                      color: homeGreen,
                      size: 22,
                    ),
                  );

              final iconLeading = playingHere
                  ? AnimatedBuilder(
                      animation: _playingEdge,
                      builder: (context, _) => Transform.scale(
                        scale: 1 + 0.045 * _playingEdge.value,
                        child: playIconBox(),
                      ),
                    )
                  : playIconBox();

              return HomeScaleOnPress(
                minScale: 0.982,
                child: GestureDetector(
                  onTap: () => ctrl.togglePlay(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: 242,
                    margin: const EdgeInsets.only(right: 12, bottom: 2),
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
                    decoration: BoxDecoration(
                      color: isActive ? homeSurfaceMuted : _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? homeGreen : _kBorder,
                        width: isActive ? 1.22 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isActive ? 10 : 6),
                          blurRadius: isActive ? 14 : 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            iconLeading,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _relDate(ep.pubDate),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? _kText : _kGrey,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ep.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                            height: 1.05,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: isActive ? homeGreen : _kGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ep.duration,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive ? homeGreen : _kGrey,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LiveStatsSheet extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String team1, team2;
  final String logo1, logo2;
  final int yellowHome, yellowAway, redHome, redAway, scoreHome, scoreAway;
  final List<Map<String, dynamic>> events;
  const _LiveStatsSheet({
    required this.stats,
    required this.team1,
    required this.team2,
    this.logo1 = '',
    this.logo2 = '',
    this.yellowHome = 0,
    this.yellowAway = 0,
    this.redHome = 0,
    this.redAway = 0,
    this.scoreHome = 0,
    this.scoreAway = 0,
    this.events = const [],
  });

  static const _gold = Color(0xFFC8A436);
  static const _grey = Color(0xFF888888);
  static const _yellow = Color(0xFFE8C82A);
  static const _red = Color(0xFFBA203C);

  int _i(dynamic v) => (v is num) ? v.toInt() : 0;

  bool _isHomeSide(Map<String, dynamic> event, String team1, String team2) {
    final rawBool = event['isHome'];
    if (rawBool is bool) return rawBool;

    final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (side == 'home' || side == 'left' || side == 'team1') return true;
    if (side == 'away' || side == 'right' || side == 'team2') return false;

    final teamIndex = event['teamIndex'];
    if (teamIndex is num) return teamIndex.toInt() == 0;

    final teamRaw = (event['team'] ?? event['teamName'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final t1 = team1.trim().toUpperCase();
    final t2 = team2.trim().toUpperCase();

    if (teamRaw.isNotEmpty) {
      if (teamRaw == t1) return true;
      if (teamRaw == t2) return false;
      if (t1.isNotEmpty && teamRaw.contains(t1.split(' ').first)) return true;
      if (t2.isNotEmpty && teamRaw.contains(t2.split(' ').first)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _typedEvents(
    String type,
    bool isHome,
    String team1,
    String team2,
  ) {
    return events
        .whereType<Map<String, dynamic>>()
        .where((e) => (e['type'] as String? ?? '').trim().toLowerCase() == type)
        .where((e) => _isHomeSide(e, team1, team2) == isHome)
        .toList()
      ..sort(
        (a, b) => ((a['minute'] as num?)?.toInt() ?? 0).compareTo(
          (b['minute'] as num?)?.toInt() ?? 0,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final t1 = team1.isNotEmpty ? team1 : 'DOM';
    final t2 = team2.isNotEmpty ? team2 : 'EXT';

    final goals1 = _typedEvents('goal', true, t1, t2);
    final goals2 = _typedEvents('goal', false, t1, t2);
    final yellows1 = _typedEvents('yellow', true, t1, t2);
    final yellows2 = _typedEvents('yellow', false, t1, t2);
    final reds1 = _typedEvents('red', true, t1, t2);
    final reds2 = _typedEvents('red', false, t1, t2);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 16, color: _gold),
                const SizedBox(width: 8),
                Text(
                  'STATISTIQUES',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (logo1.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.network(
                            logo1,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          t1.length > 9 ? '${t1.substring(0, 9)}.' : t1,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$scoreHome  –  $scoreAway',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          t2.length > 9 ? '${t2.substring(0, 9)}.' : t2,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (logo2.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Image.network(
                            logo2,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (goals1.isNotEmpty || goals2.isNotEmpty) ...[
                  _sectionLabel(
                    'BUTS',
                    icon: Icons.sports_soccer_rounded,
                    color: const Color(0xFFC8A436),
                  ),
                  _eventsRow(goals1, goals2, 'âš½'),
                  const SizedBox(height: 12),
                ],
                if (yellows1.isNotEmpty ||
                    yellows2.isNotEmpty ||
                    reds1.isNotEmpty ||
                    reds2.isNotEmpty ||
                    yellowHome + yellowAway + redHome + redAway > 0) ...[
                  _sectionLabel(
                    'CARTONS',
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFFE8C82A),
                  ),
                  if (yellows1.isNotEmpty || yellows2.isNotEmpty)
                    _eventsRow(yellows1, yellows2, '🟨'),
                  if (reds1.isNotEmpty || reds2.isNotEmpty)
                    _eventsRow(reds1, reds2, '🟥'),
                  if (yellowHome + yellowAway > 0)
                    _row('JAUNES', yellowHome, yellowAway, barColor: _yellow),
                  if (redHome + redAway > 0)
                    _row('ROUGES', redHome, redAway, barColor: _red),
                  const SizedBox(height: 4),
                ],
                _sectionLabel(
                  'POSSESSION',
                  icon: Icons.timer_rounded,
                  color: const Color(0xFFC8A436),
                ),
                _row(
                  'POSSESSION',
                  _i(s['possession1']),
                  _i(s['possession2']),
                  sfx: '%',
                  barColor: const Color(0xFFC8A436),
                ),
                _sectionLabel(
                  'TIRS',
                  icon: Icons.sports_soccer_rounded,
                  color: const Color(0xFF4CAF50),
                ),
                _row(
                  'TOTAL',
                  _i(s['tirs1']),
                  _i(s['tirs2']),
                  barColor: const Color(0xFF4CAF50),
                ),
                _row(
                  'CADRÉS',
                  _i(s['tirsCadres1']),
                  _i(s['tirsCadres2']),
                  barColor: const Color(0xFF4CAF50),
                ),
                _row(
                  'POTEAUX',
                  _i(s['poteau1']),
                  _i(s['poteau2']),
                  barColor: const Color(0xFFD4A017),
                ),
                _row(
                  'CONTRÉES',
                  _i(s['blocked1']),
                  _i(s['blocked2']),
                  barColor: Colors.white38,
                ),
                _sectionLabel(
                  'PASSES',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF42A5F5),
                ),
                _row(
                  'RÉUSSIES',
                  _i(s['passes1']),
                  _i(s['passes2']),
                  barColor: const Color(0xFF42A5F5),
                ),
                _row(
                  'RATÉES',
                  _i(s['passInacc1']),
                  _i(s['passInacc2']),
                  barColor: const Color(0xFF42A5F5),
                ),
                _sectionLabel(
                  'CENTRES',
                  icon: Icons.open_with_rounded,
                  color: Colors.orange,
                ),
                _row(
                  'RÉUSSIS',
                  _i(s['crossAcc1']),
                  _i(s['crossAcc2']),
                  barColor: Colors.orange,
                ),
                _row(
                  'RATÉS',
                  _i(s['crossInacc1']),
                  _i(s['crossInacc2']),
                  barColor: Colors.orange,
                ),
                _sectionLabel(
                  'DUELS',
                  icon: Icons.sports_mma_rounded,
                  color: const Color(0xFF7B68EE),
                ),
                _row(
                  'GAGNÉS',
                  _i(s['duelWon1']),
                  _i(s['duelWon2']),
                  barColor: const Color(0xFF7B68EE),
                ),
                _sectionLabel(
                  'ÉVÉNEMENTS',
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFEF5350),
                ),
                _row(
                  'CORNERS',
                  _i(s['corners1']),
                  _i(s['corners2']),
                  barColor: const Color(0xFFEF5350),
                ),
                _row(
                  'HORS-JEU',
                  _i(s['horsJeu1']),
                  _i(s['horsJeu2']),
                  barColor: const Color(0xFFEF5350),
                ),
                _row(
                  'FAUTES',
                  _i(s['fautes1']),
                  _i(s['fautes2']),
                  barColor: const Color(0xFFEF5350),
                ),
                _row(
                  'ARRÊTS',
                  _i(s['arretsGardien1']),
                  _i(s['arretsGardien2']),
                  barColor: const Color(0xFFEF5350),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, {IconData? icon, Color? color}) {
    final col = color ?? _grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: col),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: col,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: col.withAlpha(50))),
        ],
      ),
    );
  }

  Widget _eventsRow(List events1, List events2, String icon) {
    Widget side(List evs, bool right) => Expanded(
      child: Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: evs.map((e) {
          final player = (e['player'] as String? ?? '').trim();
          final min = ((e['minute'] as num?)?.toInt() ?? 0);
          final text = player.isEmpty
              ? (min > 0 ? "$min'" : '')
              : min > 0
              ? "$player $min'"
              : player;
          return Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
            textAlign: right ? TextAlign.right : TextAlign.left,
          );
        }).toList(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          side(events1, false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(icon, style: const TextStyle(fontSize: 14)),
          ),
          side(events2, true),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    int v1,
    int v2, {
    String sfx = '',
    Color? barColor,
  }) {
    final total = v1 + v2;
    final frac = total == 0 ? 0.5 : v1 / total;
    final bar1 = (frac * 100).round().clamp(1, 99);
    final bColor = barColor ?? _gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  '$v1$sfx',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '$v2$sfx',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: bar1,
                    child: Container(color: bColor),
                  ),
                  Expanded(
                    flex: 100 - bar1,
                    child: Container(color: const Color(0xFF2A2A2A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
