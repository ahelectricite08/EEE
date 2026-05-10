import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/podcast_controller.dart';
import '../../services/match_controller.dart';
import '../../services/youtube_playlist_service.dart';
import '../native_video_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/match_model.dart';
import '../../models/article_model.dart';
import '../../models/video_model.dart';
import '../../services/user_service.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/empty_state_panel.dart';
import '../../services/article_service.dart';
import '../../services/home_sections_service.dart';
import '../../services/live_state_service.dart';
import '../../widgets/match_card.dart';
import '../../widgets/emission_poll_home_card.dart';
import '../../widgets/motm_vote_home_card.dart';
import '../../widgets/donation_banner.dart';
import '../chat_screen.dart' show AuthLockScreen;
import '../profile_screen.dart';
import '../video_web_screen.dart';
import '../articles_screen.dart';
import '../match_detail_screen.dart';
import '../global_search_screen.dart';
import '../social_links_screen.dart';
import 'home_palette.dart';
import 'home_motion.dart';
import 'home_shell_widgets.dart';
import '../../services/tournament_service.dart';
import '../../utils/open_prono_for_match.dart';
import '../../navigation/prono_championship_rollout.dart';
import '../../navigation/world_cup_tab_rollout.dart';
import '../../services/feature_flags_service.dart';
import '../../models/season_lifecycle_config.dart';
import '../../services/season_lifecycle_service.dart';

part 'home_feed_sections.dart';
part 'home_media_sections.dart';
part 'home_live_widgets.dart';
part 'home_secondary_sections.dart';

// â”€â”€ Palette identique à live_screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kRed = homeRed;
const _kGreen = homeGreen;
const _kGold = homeGold;
const _kBg = homeBg;
const _kCard = homeSurface;
const _kBorder = homeBorder;
const _kGrey = homeMutedText;
const _kText = homeText;
const _kTextSub = homeMutedText;
const _publicPronoFeaturesEnabled = false;

/// Navigation vers un onglet principal. [matchesSubTab] : 0 à venir, 1 résultats, 2 classement.
typedef HomeMainTabSwitch =
    void Function(int tabIndex, {int? matchesSubTab});

class HomeScreen extends StatefulWidget {
  final HomeMainTabSwitch? onSwitchTab;
  final VoidCallback? onOpenGlobalSearch;

  const HomeScreen({super.key, this.onSwitchTab, this.onOpenGlobalSearch});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  UserRole? _userRole;
  Set<UserRole> _roles = const <UserRole>{};
  int _categoryIndex = 0;

  // Live data (subscrit dans initState pour éviter StreamBuilder dans slivers)
  bool _isLive = false;
  String? _liveUrl;
  int _scoreHome = 0;
  int _scoreAway = 0;
  String _liveTeam1 = '';
  String _liveTeam2 = '';
  String _liveLogo1 = '';
  String _liveLogo2 = '';
  bool _liveStatsEnabled = false;
  int _yellowHome = 0;
  int _yellowAway = 0;
  int _redHome = 0;
  int _redAway = 0;
  int _liveMinute = 0;
  bool _isHalftime = false;
  bool _isFulltime = false;
  int _chronoBaseSeconds = 0;
  int _chronoStartedAtMs = 0;
  bool _chronoRunning = false;
  Timer? _chronoDisplayTimer;
  int _chronoDisplaySeconds = 0;
  List<Map<String, dynamic>> _liveTimelineEvents = [];
  StreamSubscription<LiveHubState>? _liveHubSub;
  HomeLayoutHints _layoutHints = HomeLayoutHints.defaults;
  StreamSubscription<HomeLayoutHints>? _layoutHintsSub;

  // Émission DVCR live (rempli via [LiveStateService])
  bool _isEmissionLive = false;
  String? _emissionUrl;
  String _emissionTitle = '';
  int _emissionViewers = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _categories = [
    'TOUT',
    'RÉSULTATS',
    'AVANT-MATCH',
    'CHRONIQUES SEDANAISES',
    'COULISSES',
    'ANALYSE',
  ];

  void _switchMain(int tab, {int? matchesSubTab}) {
    widget.onSwitchTab?.call(tab, matchesSubTab: matchesSubTab);
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _loadRole();
    _liveHubSub = LiveStateService.watch().listen((hub) {
      if (!mounted) return;
      setState(() {
        _isLive = hub.isMatchLive;
        _isEmissionLive = hub.isEmissionLive;
        _liveUrl = hub.matchStreamUrl;
        _emissionUrl = hub.emissionStreamUrl;
        _emissionTitle = hub.emissionTitle;
        _emissionViewers = hub.emissionViewers;
        _scoreHome = hub.scoreHome;
        _scoreAway = hub.scoreAway;
        _liveTeam1 = hub.matchTeam1;
        _liveTeam2 = hub.matchTeam2;
        _liveLogo1 = hub.matchLogo1;
        _liveLogo2 = hub.matchLogo2;
        _liveStatsEnabled = hub.statsEnabled;
        _yellowHome = hub.yellowHome;
        _yellowAway = hub.yellowAway;
        _redHome = hub.redHome;
        _redAway = hub.redAway;
        _liveMinute = hub.minute;
        _isHalftime = hub.isHalftime;
        _isFulltime = hub.isFulltime;
        _chronoBaseSeconds = hub.chronoBaseSeconds;
        _chronoStartedAtMs = hub.chronoStartedAtMs;
        _chronoRunning = hub.chronoRunning;
        _chronoDisplaySeconds = _computeChronoSeconds();
        _updateChronoTimer();
        _liveTimelineEvents = hub.timelineEvents;
      });
    });
    _layoutHintsSub = HomeSectionsService.layoutHintsStream().listen((h) {
      if (!mounted) return;
      setState(() => _layoutHints = h);
    });
  }

  @override
  void dispose() {
    _liveHubSub?.cancel();
    _layoutHintsSub?.cancel();
    _chronoDisplayTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  int _computeChronoSeconds() {
    if (!_chronoRunning || _chronoStartedAtMs == 0) return _chronoBaseSeconds;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _chronoStartedAtMs;
    return _chronoBaseSeconds + (elapsed ~/ 1000);
  }

  void _updateChronoTimer() {
    _chronoDisplayTimer?.cancel();
    _chronoDisplayTimer = null;
    if (_chronoRunning) {
      _chronoDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _chronoDisplaySeconds = _computeChronoSeconds());
        }
      });
    }
  }

  String get _chronoDisplay {
    final s = _chronoDisplaySeconds;
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$m:$sec";
  }

  void _showLiveStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('live')
            .doc('current')
            .snapshots(),
        builder: (context, snap) {
          final d = snap.data?.data() as Map<String, dynamic>? ?? {};
          final s = d['stats'] as Map<String, dynamic>? ?? {};
          final evRaw = d['events'];
          final evs =
              (evRaw is List ? evRaw : <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .where(
                    (e) => const {'goal', 'yellow', 'red'}.contains(e['type']),
                  )
                  .toList()
                ..sort(
                  (a, b) => (a['minute'] as int? ?? 0).compareTo(
                    b['minute'] as int? ?? 0,
                  ),
                );
          return _LiveStatsSheet(
            stats: s,
            team1: d['team1'] as String? ?? _liveTeam1,
            team2: d['team2'] as String? ?? _liveTeam2,
            logo1: d['logo1'] as String? ?? _liveLogo1,
            logo2: d['logo2'] as String? ?? _liveLogo2,
            yellowHome: (d['yellowHome'] as num?)?.toInt() ?? _yellowHome,
            yellowAway: (d['yellowAway'] as num?)?.toInt() ?? _yellowAway,
            redHome: (d['redHome'] as num?)?.toInt() ?? _redHome,
            redAway: (d['redAway'] as num?)?.toInt() ?? _redAway,
            scoreHome: (d['scoreHome'] as num?)?.toInt() ?? _scoreHome,
            scoreAway: (d['scoreAway'] as num?)?.toInt() ?? _scoreAway,
            events: evs,
          );
        },
      ),
    );
  }

  Future<void> _loadRole() async {
    final roles = await UserService.getCurrentRoles();
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _userRole = UserService.primaryRole(roles);
    });
  }

  bool _isHomeLiveEvent(Map<String, dynamic> event) {
    final direct = event['isHome'];
    if (direct is bool) return direct;

    final side = (event['side'] ?? event['teamSide'] ?? event['teamSlot'])
        .toString()
        .trim()
        .toLowerCase();
    if (side == 'home' || side == 'left' || side == 'dom') return true;
    if (side == 'away' || side == 'right' || side == 'ext') return false;

    final teamIndex = event['teamIndex'];
    if (teamIndex is num) return teamIndex.toInt() == 1;

    final rawTeam = (event['team'] ?? event['teamName'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final home = _liveTeam1.trim().toUpperCase();
    final away = _liveTeam2.trim().toUpperCase();
    if (rawTeam.isNotEmpty) {
      if (rawTeam == home) return true;
      if (rawTeam == away) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _heroPreviewEvents() {
    final events = _liveTimelineEvents
        .where((event) {
          final type = (event['type'] as String? ?? '').trim().toLowerCase();
          return type == 'goal' || type == 'yellow' || type == 'red';
        })
        .map(
          (event) => {
            ...event,
            'isHomeSide': _isHomeLiveEvent(event),
            'minuteValue': (event['minute'] is num)
                ? (event['minute'] as num).toInt()
                : int.tryParse('${event['minute'] ?? 0}') ?? 0,
          },
        )
        .toList();

    events.sort(
      (a, b) => (b['minuteValue'] as int).compareTo(a['minuteValue'] as int),
    );
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kGreen,
        backgroundColor: _kCard,
        onRefresh: () => MatchController.instance.forceRefresh(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // â”€â”€ AppBar + Hero intégrés (photo du tout haut) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildAppBarWithHero(),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // â”€â”€ Coupe du Monde 2026 (masquable par flag admin) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            ListenableBuilder(
              listenable: FeatureFlagsService.notifier,
              builder: (context, _) {
                if (!WorldCupTabRollout.isTabVisible) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: HomeReveal(
                    delay: const Duration(milliseconds: 18),
                    child: _TournamentMiniCard(
                      onOpenTab: () => _switchMain(
                            WorldCupTabRollout.targetMainTabIndexOrHome(),
                          ),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // â”€â”€ Prochain match â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 28),
                child: const MotmVoteHomeSlot(),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 36),
                child: const EmissionPollHomeSlot(),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 44),
                child: _NextMatchSectionHeader(
                  onSeeAll: () => _switchMain(2, matchesSubTab: 0),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 54),
                child: _NextMatchCard(onSwitchMainTab: widget.onSwitchTab),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // â”€â”€ Podcast DVCR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!(_layoutHints.hidePodcastBlockWhenAnyLive &&
                (_isLive || _isEmissionLive))) ...[
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 62),
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: HomeSectionsService.stream(),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? const <String, dynamic>{};
                      final rendezVousAt = data['podcastNextEventAt'] is Timestamp
                          ? (data['podcastNextEventAt'] as Timestamp).toDate()
                          : null;
                      return HomeSectionHeader(
                        title: 'PODCAST DVCR',
                        subtitle: rendezVousAt == null
                            ? 'Chroniques, debats et Dudule Quiz'
                            : _formatPodcastRendezVous(rendezVousAt),
                        icon: Icons.headphones_rounded,
                        trailing: _roles.contains(UserRole.admin)
                            ? _PodcastQuickEditButton(
                                onTap: () =>
                                    _openPodcastRendezVousEditor(rendezVousAt),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 175),
                  child: const _PodcastSection(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // â”€â”€ DVCR TV â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!(_layoutHints.hideDvcrTvBlockWhenAnyLive &&
                (_isLive || _isEmissionLive))) ...[
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 76),
                child: HomeSectionHeader(
                  title: 'DVCR TV',
                  subtitle: 'Les derniers replays et contenus DVCR',
                  icon: Icons.play_circle_outline_rounded,
                  onSeeAll: () => _switchMain(1),
                ),
              ),
            ),
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 82),
                  child: _DVCRTVRow(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 22)),
            ],

            // â”€â”€ Bannière don â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!(_layoutHints.hideDonationBannerWhenAnyLive &&
                (_isLive || _isEmissionLive)))
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 220),
                  child: DonationBanner(
                    donationUrl: 'https://www.helloasso.com',
                    photoAsset:
                        'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                    title: 'SOUTENEZ DVCR',
                    subtitle: 'Chaque don nous aide à grandir',
                  ),
                ),
              ),

            // â”€â”€ Dernières actus â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'ACTUS',
                subtitle: 'Les nouvelles du club, de la commu et du terrain',
                icon: Icons.article_outlined,
                showBadge: false,
                onSeeAll: () => _switchMain(3),
              ),
            ),
            SliverToBoxAdapter(child: _buildCategoryFilter()),
            SliverToBoxAdapter(
              child: _ArticlesFeed(category: _categories[_categoryIndex]),
            ),

            // â”€â”€ Derniers résultats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'RESULTATS',
                subtitle: 'Retrouve les derniers résultats du CSSA',
                icon: Icons.emoji_events_rounded,
                accent: _kGreen,
                showBadge: false,
                onSeeAll: () => _switchMain(2, matchesSubTab: 1),
              ),
            ),
            SliverToBoxAdapter(child: _ResultsFeed()),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // â”€â”€ Mini-classement pronos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (_publicPronoFeaturesEnabled)
              SliverToBoxAdapter(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          HomeSectionHeader(
                            title: 'CLASSEMENT PRONOS',
                            subtitle: 'Les meilleurs pronostiqueurs du moment',
                            icon: Icons.leaderboard_rounded,
                            onSeeAll: null,
                          ),
                          _PronoLeaderboardMiniCard(onSeeAll: null),
                        ],
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            color: Colors.white.withAlpha(140),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: homeBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFD8D2C4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Color(0xFF6E776F),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Bientôt disponible',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6E776F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  // â”€â”€ AppBar + Hero intégrés â€” photo depuis le tout haut de l'écran â”€â”€â”€â”€â”€â”€â”€â”€
  String _formatPodcastRendezVous(DateTime date) {
    return 'Prochain rendez-vous le ${DateFormat("d MMM yyyy · HH'h'mm", 'fr_FR').format(date)}';
  }

  Future<void> _openPodcastRendezVousEditor(DateTime? initialDate) async {
    final sourceDate =
        initialDate ?? DateTime.now().add(const Duration(days: 7));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: sourceDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Prochain rendez-vous podcast',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC8A436),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(sourceDate),
      helpText: 'Heure du rendez-vous',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC8A436),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || pickedTime == null) return;

    final nextDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await HomeSectionsService.setPodcastNextEvent(nextDate);
    if (!mounted) return;
  }

  SliverAppBar _buildAppBarWithHero() {
    final user = FirebaseAuth.instance.currentUser;
    final heroEvents = _heroPreviewEvents();

    return SliverAppBar(
      pinned: true,
      expandedHeight: 312,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 52,
      // â”€â”€ Titre compact visible quand la photo est scrollée â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _IconBtn(
              icon: Icons.public_rounded,
              color: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialLinksScreen()),
              ),
            ),
            if (_isLive || _isEmissionLive) ...[
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _PulsingLiveBadge(pulse: _pulse.value),
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (_userRole != null && _userRole != UserRole.supporter)
              _RolePill(role: _userRole!.displayName),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.search_rounded,
              onTap: () {
                final open = widget.onOpenGlobalSearch;
                if (open != null) {
                  open();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 10),
            _IconBtn(
              icon: user == null
                  ? Icons.person_outline_rounded
                  : Icons.person_rounded,
              color: user != null ? const Color(0xFFC8A436) : null,
              onTap: () async {
                if (user == null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthLockScreen()),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        onSwitchMainTab: widget.onSwitchTab,
                      ),
                    ),
                  );
                }
                _loadRole();
              },
            ),
          ],
        ),
      ),
      // â”€â”€ Photo pleine largeur depuis le haut â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo toujours visible (mÃªme quand collapsé)
          Image.asset(
            'assets/images/IMG_0842.JPG',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(140),
                  Colors.black.withAlpha(200),
                ],
              ),
            ),
          ),
          FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: GestureDetector(
              onTap: () async {
                final url = _isLive
                    ? _liveUrl
                    : (_isEmissionLive ? _emissionUrl : null);
                if (url != null && url.isNotEmpty) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } else if (!_isLive && !_isEmissionLive) {
                  _switchMain(1);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo de fond â€” stade du club recevant en live
                  if (_isLive && _liveTeam1.isNotEmpty)
                    StreamBuilder<String?>(
                      stream: _watchHomeStadiumHero(_liveTeam1),
                      builder: (context, snap) {
                        final stadiumUrl = snap.data;
                        if (stadiumUrl != null && stadiumUrl.isNotEmpty) {
                          return Image.network(
                            stadiumUrl,
                            fit: BoxFit.cover,
                            alignment: const Alignment(-1.0, 0.6),
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(-1.0, 0.6),
                            ),
                          );
                        }
                        return Image.asset(
                          'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(-1.0, 0.6),
                        );
                      },
                    )
                  else
                    Image.asset(
                      _isEmissionLive
                          ? 'assets/images/IMG_0377.JPG'
                          : 'assets/images/IMG_0842.JPG',
                      fit: BoxFit.cover,
                      alignment: const Alignment(-1.0, 0.6),
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF111111),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_soccer_rounded,
                                size: 48,
                                color: _kRed.withAlpha(80),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'DVCR',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white38,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Gradient haut (status bar + toolbar lisibles)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withAlpha(160),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Gradient bas fort
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(230),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  // Badge EN DIRECT : dans la barre (title), à droite du globe — pas ici (évitait le chevauchement).
                  // Titre + sous-titre en bas
                  Positioned(
                    bottom: 16,
                    left: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isLive && !_isEmissionLive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(24),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withAlpha(65),
                              ),
                            ),
                            child: Text(
                              'ACCUEIL DVCR',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'LE CLUB, LE LIVE ET LA COMMU',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Retrouve les matchs, les replays et toute l activite DVCR au meme endroit.',
                            style: GoogleFonts.barlow(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _kGold,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: _kGold.withAlpha(45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'VOIR LES REPLAYS',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_isEmissionLive && !_isLive) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.black.withAlpha(92),
                                    _kGreen.withAlpha(92),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: Colors.white.withAlpha(36),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(42),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(18),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(50),
                                      ),
                                    ),
                                    child: Text(
                                      'EMISSION DVCR',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _emissionTitle.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                      height: 1.0,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _emissionViewers > 0
                                        ? '$_emissionViewers en direct'
                                        : 'Emission en direct',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.barlow(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 190,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kGold,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kGold.withAlpha(55),
                                          blurRadius: 14,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.live_tv_rounded,
                                          color: Colors.black,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "REGARDER L'EMISSION",
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_isLive) ...[
                          const SizedBox(height: 6),
                          if (_liveTeam1.isNotEmpty &&
                              _liveTeam2.isNotEmpty) ...[
                            Builder(
                              builder: (context) {
                                final leftEvents = heroEvents
                                    .where(
                                      (event) => event['isHomeSide'] == true,
                                    )
                                    .take(5)
                                    .toList();
                                final rightEvents = heroEvents
                                    .where(
                                      (event) => event['isHomeSide'] != true,
                                    )
                                    .take(5)
                                    .toList();

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compactHero =
                                        constraints.maxWidth < 360;
                                    return Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        14,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.black.withAlpha(92),
                                            _kGreen.withAlpha(108),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withAlpha(36),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(42),
                                            blurRadius: 18,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Text(
                                                    _liveTeam1.toUpperCase(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.right,
                                                    style:
                                                        GoogleFonts.barlowCondensed(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white70,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: compactHero
                                                      ? 6
                                                      : 10,
                                                ),
                                                child: Container(
                                                  constraints: BoxConstraints(
                                                    minWidth: compactHero
                                                        ? 88
                                                        : 108,
                                                  ),
                                                  alignment: Alignment.center,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: compactHero
                                                        ? 10
                                                        : 14,
                                                    vertical: 7,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.white.withAlpha(
                                                          24,
                                                        ),
                                                        _kGreen.withAlpha(24),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withAlpha(70),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withAlpha(20),
                                                        blurRadius: 16,
                                                        offset: const Offset(
                                                          0,
                                                          6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    '$_scoreHome  -  $_scoreAway',
                                                    textAlign: TextAlign.center,
                                                    style:
                                                        GoogleFonts.barlowCondensed(
                                                          fontSize: compactHero
                                                              ? 18
                                                              : 22,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Colors.white,
                                                          letterSpacing: 0.6,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    _liveTeam2.toUpperCase(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.left,
                                                    style:
                                                        GoogleFonts.barlowCondensed(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white70,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (_isFulltime)
                                                const _HeroMetaChip(
                                                  label: 'FIN DE MATCH',
                                                )
                                              else if (_isHalftime)
                                                const _HeroMetaChip(
                                                  label: 'MI-TEMPS',
                                                )
                                              else
                                                _HeroMetaChip(
                                                  label: _chronoRunning
                                                      ? _chronoDisplay
                                                      : _liveMinute > 0
                                                      ? "$_liveMinute'"
                                                      : "DIRECT",
                                                ),
                                              if (_liveStatsEnabled)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showLiveStats(context),
                                                  child: const _HeroMetaChip(
                                                    label: 'STATS',
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (heroEvents.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            compactHero
                                                ? Column(
                                                    children: [
                                                      if (leftEvents.isNotEmpty)
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: leftEvents
                                                              .map(
                                                                (
                                                                  event,
                                                                ) => _HeroLiveEventRow(
                                                                  event: event,
                                                                  homeTeam:
                                                                      _liveTeam1,
                                                                  awayTeam:
                                                                      _liveTeam2,
                                                                ),
                                                              )
                                                              .toList(),
                                                        ),
                                                      if (leftEvents
                                                              .isNotEmpty &&
                                                          rightEvents
                                                              .isNotEmpty)
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                vertical: 8,
                                                              ),
                                                          child: Divider(
                                                            height: 1,
                                                            color:
                                                                Colors.white10,
                                                          ),
                                                        ),
                                                      if (rightEvents
                                                          .isNotEmpty)
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: rightEvents
                                                              .map(
                                                                (
                                                                  event,
                                                                ) => _HeroLiveEventRow(
                                                                  event: event,
                                                                  homeTeam:
                                                                      _liveTeam1,
                                                                  awayTeam:
                                                                      _liveTeam2,
                                                                  alignRight:
                                                                      true,
                                                                ),
                                                              )
                                                              .toList(),
                                                        ),
                                                    ],
                                                  )
                                                : Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: leftEvents
                                                              .map(
                                                                (
                                                                  event,
                                                                ) => _HeroLiveEventRow(
                                                                  event: event,
                                                                  homeTeam:
                                                                      _liveTeam1,
                                                                  awayTeam:
                                                                      _liveTeam2,
                                                                ),
                                                              )
                                                              .toList(),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height:
                                                            12.0 *
                                                                [
                                                                  leftEvents
                                                                      .length,
                                                                  rightEvents
                                                                      .length,
                                                                  1,
                                                                ].reduce(
                                                                  (a, b) =>
                                                                      a > b
                                                                      ? a
                                                                      : b,
                                                                ) +
                                                            8,
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                            ),
                                                        color: Colors.white10,
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: rightEvents
                                                              .map(
                                                                (
                                                                  event,
                                                                ) => _HeroLiveEventRow(
                                                                  event: event,
                                                                  homeTeam:
                                                                      _liveTeam1,
                                                                  awayTeam:
                                                                      _liveTeam2,
                                                                  alignRight:
                                                                      true,
                                                                ),
                                                              )
                                                              .toList(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ],
                                          const SizedBox(height: 12),
                                          Center(
                                            child: GestureDetector(
                                              onTap: () async {
                                                final url = _liveUrl;
                                                if (url != null &&
                                                    url.isNotEmpty) {
                                                  await launchUrl(
                                                    Uri.parse(url),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                }
                                              },
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  minWidth: compactHero
                                                      ? 150
                                                      : 176,
                                                ),
                                                alignment: Alignment.center,
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: compactHero
                                                      ? 14
                                                      : 18,
                                                  vertical: 9,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _kGold,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _kGold.withAlpha(
                                                        55,
                                                      ),
                                                      blurRadius: 14,
                                                      offset: const Offset(
                                                        0,
                                                        6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.play_arrow_rounded,
                                                      color: Colors.black,
                                                      size: 15,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'REGARDER EN DIRECT',
                                                      style:
                                                          GoogleFonts.barlowCondensed(
                                                            fontSize:
                                                                compactHero
                                                                ? 12
                                                                : 13,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.black,
                                                            letterSpacing: 0.9,
                                                          ),
                                                    ),
                                                  ],
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
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // â”€â”€ Filtres catégories â€” angulaires style sport â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCategoryFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final sel = _categoryIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _categoryIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kGreen : const Color(0xFFF0ECE1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: sel ? _kGreen : _kBorder.withAlpha(140),
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _kGreen.withAlpha(28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _categories[i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: sel ? Colors.white : _kText,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

String _relDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  final months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
