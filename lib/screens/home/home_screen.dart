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
import '../../models/match_stats_schema.dart';
import '../../models/article_model.dart';
import '../../models/video_model.dart';
import '../../services/user_service.dart';
import '../../widgets/dvcr_skeleton.dart';
import '../../widgets/empty_state_panel.dart';
import '../../services/article_service.dart';
import '../../services/home_sections_service.dart';
import '../../services/live_state_service.dart';
import '../../widgets/match_card.dart';
import '../../widgets/live_stats_sheet.dart';
import '../../widgets/emission_poll_home_card.dart';
import '../../widgets/live_interaction_home_slot.dart';
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
import '../../utils/youtube_parser.dart';
import '../matches/matches_helpers.dart';
import '../../services/home_banner_service.dart';

part 'home_feed_sections.dart';
part 'home_media_sections.dart';
part 'home_live_widgets.dart';
part 'home_secondary_sections.dart';

// â"€â"€ Palette identique à live_screen â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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
  bool _matchStreamBroadcast = true;
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
  String _liveMatchId = '';
  bool _liveLineupOnCard = false;
  bool _isHalftime = false;
  bool _isExtraHalftime = false;
  bool _isFulltime = false;
  bool _isExtraFulltime = false;
  bool _isExtraTimePlaying = false;
  int _chronoBaseSeconds = 0;
  int _chronoStartedAtMs = 0;
  bool _chronoRunning = false;
  Timer? _chronoDisplayTimer;
  int _chronoDisplaySeconds = 0;
  List<Map<String, dynamic>> _liveTimelineEvents = [];
  StreamSubscription<LiveHubState>? _liveHubSub;
  HomeLayoutHints _layoutHints = HomeLayoutHints.defaults;
  StreamSubscription<HomeLayoutHints>? _layoutHintsSub;

  // Photo bannière home (null = asset par défaut)
  String? _homeBannerUrl;
  StreamSubscription<String?>? _bannerSub;

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
        _matchStreamBroadcast = hub.matchStreamBroadcast;
        _emissionUrl = hub.emissionStreamUrl;
        _emissionTitle = hub.emissionTitle;
        _emissionViewers = hub.emissionViewers;
        _scoreHome = hub.scoreHome;
        _scoreAway = hub.scoreAway;
        _liveTeam1 = hub.matchTeam1;
        _liveTeam2 = hub.matchTeam2;
        _liveLogo1 = hub.matchLogo1;
        _liveLogo2 = hub.matchLogo2;
        _liveStatsEnabled = hub.liveStatsToggleOn;
        _yellowHome = hub.yellowHome;
        _yellowAway = hub.yellowAway;
        _redHome = hub.redHome;
        _redAway = hub.redAway;
        _liveMinute = hub.minute;
        _liveMatchId = hub.liveMatchId;
        _liveLineupOnCard = hub.liveLineupOnCard;
        _isHalftime = hub.isHalftime;
        _isExtraHalftime = hub.isExtraHalftime;
        _isFulltime = hub.isFulltime;
        _isExtraFulltime = hub.isExtraFulltime;
        _isExtraTimePlaying = hub.isExtraTimePlaying;
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
    _bannerSub = HomeBannerService.photoUrlStream().listen((url) {
      if (!mounted) return;
      setState(() => _homeBannerUrl = url);
    });
  }

  @override
  void dispose() {
    _liveHubSub?.cancel();
    _layoutHintsSub?.cancel();
    _bannerSub?.cancel();
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

  void _showLiveStats(BuildContext context) => showLiveStatsBottomSheet(context);

  Future<void> _loadRole() async {
    final roles = await UserService.getCurrentRoles();
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _userRole = UserService.primaryRole(roles);
    });
  }

  static bool _teamsMatchName(String a, String b) {
    final x = a.trim().toUpperCase();
    final y = b.trim().toUpperCase();
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    const minPrefix = 6;
    if (x.length >= minPrefix &&
        y.length >= minPrefix &&
        x.substring(0, minPrefix) == y.substring(0, minPrefix)) {
      return true;
    }
    return x.startsWith(y) || y.startsWith(x);
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
    if (teamIndex is num) return teamIndex.toInt() == 0;

    final rawTeam = (event['team'] ?? event['teamName'] ?? '').toString();
    if (rawTeam.isNotEmpty) {
      if (_teamsMatchName(rawTeam, _liveTeam1)) return true;
      if (_teamsMatchName(rawTeam, _liveTeam2)) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _heroPreviewEvents() {
    final events = _liveTimelineEvents
        .where((event) {
          final type = (event['type'] as String? ?? '').trim().toLowerCase();
          return type == 'goal' ||
              type == 'yellow' ||
              type == 'red' ||
              type == 'substitution';
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

    // Max 2 événements par équipe (on garde les plus récents)
    final homeEvents = events.where((e) => e['isHomeSide'] == true).take(2).toList();
    final awayEvents = events.where((e) => e['isHomeSide'] != true).take(2).toList();
    return [...homeEvents, ...awayEvents];
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
            // â"€â"€ AppBar + Hero intégrés (photo du tout haut) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            _buildAppBarWithHero(),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // â"€â"€ Coupe du Monde 2026 (masquable par flag admin) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

            // â"€â"€ Prochain match â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 28),
                child: const LiveInteractionHomeSlot(),
              ),
            ),
            SliverToBoxAdapter(
              child: HomeReveal(
                delay: const Duration(milliseconds: 36),
                child: const EmissionPollHomeSlot(),
              ),
            ),
            if (!_isLive) ...[
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
            ],

            // â"€â"€ Podcast DVCR â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

            // â"€â"€ DVCR TV â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

            // â"€â"€ Bannière don â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
            if (!(_layoutHints.hideDonationBannerWhenAnyLive &&
                (_isLive || _isEmissionLive)))
              SliverToBoxAdapter(
                child: HomeReveal(
                  delay: const Duration(milliseconds: 220),
                  child: DonationBanner(
                    photoAsset:
                        'assets/images/d38967e3-9ba5-47f3-91d9-0602cef538e0.jpg',
                    badgeLabel: 'DVCR',
                    title: 'SOUTENEZ DVCR',
                    subtitle: 'Chaque don nous aide à grandir',
                  ),
                ),
              ),

            // â"€â"€ Dernières actus â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

            // â"€â"€ Derniers résultats â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

            // â"€â"€ Mini-classement pronos â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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

  // â"€â"€ AppBar + Hero intégrés â€" photo depuis le tout haut de l'écran â"€â"€â"€â"€â"€â"€â"€â"€
  String _formatPodcastRendezVous(DateTime date) {
    return 'Prochain rendez-vous le ${DateFormat("d MMM yyyy · HH'h'mm", 'fr_FR').format(date)}';
  }

  /// Ouvre la fiche match du live courant sur l'onglet Compositions.
  /// Cherche d'abord par ID, puis par noms d'équipes, puis Firestore si nécessaire.
  Future<void> _openCompoCard(BuildContext ctx) async {
    final allMatches = [
      ...MatchController.instance.upcoming,
      ...MatchController.instance.results,
    ];

    MatchModel? match = allMatches
        .where((m) => m.id == _liveMatchId)
        .firstOrNull;

    if (match == null && _liveTeam1.isNotEmpty && _liveTeam2.isNotEmpty) {
      match = allMatches.where((m) {
        final t1 = m.team1.trim().toUpperCase();
        final t2 = m.team2.trim().toUpperCase();
        final l1 = _liveTeam1.trim().toUpperCase();
        final l2 = _liveTeam2.trim().toUpperCase();
        return (t1.contains(l1.split(' ').first) ||
                l1.contains(t1.split(' ').first)) &&
            (t2.contains(l2.split(' ').first) ||
                l2.contains(t2.split(' ').first));
      }).firstOrNull;
    }

    // Dernier recours : fetch Firestore par matchId si c'est un vrai ID
    if (match == null &&
        _liveMatchId.isNotEmpty &&
        !(_liveMatchId.startsWith('live_') &&
            RegExp(r'^live_\d+$').hasMatch(_liveMatchId))) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('matches')
            .doc(_liveMatchId)
            .get();
        if (snap.exists) {
          match = MatchModel.fromFirestore(snap);
        }
      } catch (_) {}
    }

    if (!ctx.mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Fiche match introuvable.')),
      );
      return;
    }
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(match: match!, initialTab: 1),
      ),
    );
  }

  Future<void> _openPodcastRendezVousEditor(DateTime? initialDate) async {
    final firstDate = DateTime.now().subtract(const Duration(days: 1));
    final lastDate = DateTime.now().add(const Duration(days: 730));
    final sourceDate = initialDate ?? DateTime.now().add(const Duration(days: 7));
    // Clamp pour éviter un initialDate hors plage (ex: date passée ancienne)
    final clampedDate = sourceDate.isBefore(firstDate)
        ? firstDate
        : sourceDate.isAfter(lastDate)
            ? lastDate
            : sourceDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: clampedDate,
      firstDate: firstDate,
      lastDate: lastDate,
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
      // â"€â"€ Titre compact visible quand la photo est scrollée â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
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
      // â"€â"€ Photo pleine largeur depuis le haut â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo toujours visible (même quand collapsé)
          _homeBannerUrl != null && _homeBannerUrl!.isNotEmpty
              ? Image.network(
                  _homeBannerUrl!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/IMG_0842.JPG',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.3),
                  ),
                )
              : Image.asset(
                  'assets/images/IMG_0842.JPG',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                ),
          FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: GestureDetector(
              onTap: () async {
                if (_isLive && !_matchStreamBroadcast) return;
                final url = _isLive
                    ? _liveUrl
                    : (_isEmissionLive ? _emissionUrl : null);
                if (url != null && url.isNotEmpty) {
                  final clean = YoutubeParser.sanitizeShareUrl(url);
                  await launchUrl(
                    Uri.parse(clean),
                    mode: LaunchMode.externalApplication,
                  );
                } else if (!_isLive && !_isEmissionLive) {
                  _switchMain(1);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo de fond â€" stade du club recevant en live
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
                    (_homeBannerUrl != null && _homeBannerUrl!.isNotEmpty && !_isEmissionLive)
                        ? Image.network(
                            _homeBannerUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(-1.0, 0.6),
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/IMG_0842.JPG',
                              fit: BoxFit.cover,
                              alignment: const Alignment(-1.0, 0.6),
                            ),
                          )
                        : Image.asset(
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
                  // ── Gradient haut (toolbar lisible) ─────────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withAlpha(170),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Gradient bas (lisibilité contenu) ───────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(_isLive ? 200 : 180),
                            Colors.black.withAlpha(_isLive ? 80 : 40),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.75],
                        ),
                      ),
                    ),
                  ),
                  // ── Filigrane DVCR — watermark discret en permanence ────
                  if (!_isLive && !_isEmissionLive) ...[
                    Positioned(
                      top: -8,
                      right: -24,
                      child: Text(
                        'DVCR',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha(12),
                          letterSpacing: -4,
                          height: 0.85,
                        ),
                      ),
                    ),
                  ],
                  // ── Contenu dynamique en bas ─────────────────────────────
                  Positioned(
                    bottom: 18,
                    left: 16,
                    right: 16,
                    child: _isLive
                        ? _buildLiveHeroContent(heroEvents)
                        : _isEmissionLive
                        ? _buildEmissionHeroContent()
                        : _buildDefaultHeroContent(),
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

  // ── Contenu hero : état par défaut ──────────────────────────────────────────
  Widget _buildDefaultHeroContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branding DVCR — DV vert / CR rouge
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Ombre vert derrière
            Positioned(
              left: 2,
              top: 3,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'DV',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 76,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF0A4438).withAlpha(180),
                        letterSpacing: -1,
                        height: 0.85,
                      ),
                    ),
                    TextSpan(
                      text: 'CR',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 76,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: _kRed.withAlpha(160),
                        letterSpacing: -1,
                        height: 0.85,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Texte principal DV blanc / CR blanc
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'DV',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 0.85,
                    ),
                  ),
                  TextSpan(
                    text: 'CR',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 0.85,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'LE MÉDIA 800% CSSA',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Contenu hero : émission en direct ───────────────────────────────────────
  Widget _buildEmissionHeroContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withAlpha((60 + (_pulse.value * 120).round())),
                      blurRadius: 4 + _pulse.value * 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'ÉMISSION EN DIRECT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _emissionTitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
            height: 1.0,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (_emissionViewers > 0) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white.withAlpha(160)),
              const SizedBox(width: 5),
              Text(
                '$_emissionViewers spectateurs',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(160),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final url = _emissionUrl;
            if (url != null && url.isNotEmpty) {
              final clean = YoutubeParser.sanitizeShareUrl(url);
              await launchUrl(Uri.parse(clean), mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(color: _kGold.withAlpha(60), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.live_tv_rounded, color: Colors.black, size: 15),
                const SizedBox(width: 7),
                Text(
                  "REGARDER L'ÉMISSION",
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
        ),
      ],
    );
  }

  // ── Contenu hero : match en direct ──────────────────────────────────────────
  Widget _buildLiveHeroContent(List<Map<String, dynamic>> heroEvents) {
    if (_liveTeam1.isEmpty || _liveTeam2.isEmpty) return const SizedBox.shrink();

    final leftEvents = heroEvents.where((e) => e['isHomeSide'] == true).toList();
    final rightEvents = heroEvents.where((e) => e['isHomeSide'] != true).toList();

    final String minuteLabel;
    if (_isFulltime) {
      minuteLabel = 'FIN';
    } else if (_isExtraFulltime) {
      minuteLabel = 'FIN PROLONG.';
    } else if (_isHalftime) {
      minuteLabel = 'MI-TEMPS';
    } else if (_isExtraHalftime) {
      minuteLabel = 'MT PROLONG.';
    } else if (_isExtraTimePlaying) {
      minuteLabel = 'PROLONG.';
    } else if (_chronoRunning) {
      minuteLabel = _chronoDisplay;
    } else if (_liveMinute > 0) {
      minuteLabel = "$_liveMinute'";
    } else {
      minuteLabel = 'DIRECT';
    }

    Widget logoWidget(String? url) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(55), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: (url != null && url.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.sports_soccer_rounded, size: 22, color: Color(0xFF0A4438)),
                ),
              )
            : const Icon(Icons.sports_soccer_rounded, size: 22, color: Color(0xFF0A4438)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── [STATS] [minute/statut] [COMPO] – centré ─────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton STATS (conditionnel)
            if (_liveStatsEnabled) ...[
              GestureDetector(
                onTap: () => _showLiveStats(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGreen.withAlpha(180),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 12, color: Colors.white.withAlpha(220)),
                      const SizedBox(width: 5),
                      Text('STATS', style: GoogleFonts.barlowCondensed(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Minute / statut (toujours affiché au centre)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Text(
                minuteLabel,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            // Bouton COMPO (uniquement si toggle admin activé)
            if (_liveLineupOnCard) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openCompoCard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_rounded, size: 12, color: Colors.white.withAlpha(220)),
                    const SizedBox(width: 5),
                    Text(
                      'COMPO',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ], // end if _liveLineupOnCard
          ],
        ),
        const SizedBox(height: 10),
        // ── Logos + Score ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logoWidget(_liveLogo1),
                  const SizedBox(height: 5),
                  Text(
                    _liveTeam1.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(200),
                      height: 1.1,
                    ),
                  ),
                  _HeroSideCards(yellow: _yellowHome, red: _redHome, alignEnd: false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_scoreHome – $_scoreAway',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logoWidget(_liveLogo2),
                  const SizedBox(height: 5),
                  Text(
                    _liveTeam2.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(200),
                      height: 1.1,
                    ),
                  ),
                  _HeroSideCards(yellow: _yellowAway, red: _redAway, alignEnd: false),
                ],
              ),
            ),
          ],
        ),
        // ── Événements ──────────────────────────────────────────────────
        if (heroEvents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.white.withAlpha(20)),
          const SizedBox(height: 5),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _HeroLiveEventsColumn(events: leftEvents, homeSide: true)),
                if (leftEvents.isNotEmpty && rightEvents.isNotEmpty)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: Colors.white.withAlpha(20),
                  ),
                Expanded(child: _HeroLiveEventsColumn(events: rightEvents, homeSide: false)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        // ── CTA ──────────────────────────────────────────────────────────
        Center(
          child: _matchStreamBroadcast
              ? GestureDetector(
                  onTap: () async {
                    final url = _liveUrl;
                    if (url != null && url.isNotEmpty) {
                      final clean = YoutubeParser.sanitizeShareUrl(url);
                      await launchUrl(Uri.parse(clean), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kGold,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: _kGold.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'REGARDER EN DIRECT',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_soccer_rounded, size: 13, color: Colors.white.withAlpha(200)),
                      const SizedBox(width: 7),
                      Text(
                        'MATCH EN DIRECT · PAS DE VIDÉO',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── Filtres catégories – angulaires style sport ─────────────────────────────
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = _categoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _categoryIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kGreen : _kCard,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? _kGreen : _kBorder,
                ),
              ),
              child: Text(
                _categories[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: sel ? Colors.white : _kText,
                ),
              ),
            ),
          );
        },
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
