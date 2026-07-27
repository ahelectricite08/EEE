import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dvcr/features/auth/auth.dart';
import 'package:dvcr/features/home/data/adapters/home_articles_feed_adapter.dart';
import 'package:dvcr/features/home/data/adapters/home_live_hub_adapter.dart';
import 'package:dvcr/features/home/data/adapters/home_match_catalog_adapter.dart';
import 'package:dvcr/features/home/data/datasources/home_prediction_datasource.dart';
import 'package:dvcr/features/home/data/datasources/home_prono_leaderboard_datasource.dart';
import 'package:dvcr/features/home/data/datasources/home_stadium_datasource.dart';
import 'package:dvcr/features/home/domain/entities/home_layout_hints.dart';
import 'package:dvcr/features/home/domain/entities/home_sections_config.dart';
import 'package:dvcr/features/home/presentation/home_providers.dart';
import 'package:dvcr/models/article_model.dart';
import 'package:dvcr/models/match_model.dart';
import 'package:dvcr/models/match_stats_schema.dart';
import 'package:dvcr/models/season_lifecycle_config.dart';
import 'package:dvcr/models/video_model.dart';
import 'package:dvcr/navigation/prono_championship_rollout.dart';
import 'package:dvcr/screens/articles_screen.dart';
import 'package:dvcr/screens/chat_screen.dart' show AuthLockScreen;
import 'package:dvcr/screens/global_search_screen.dart';
import 'package:dvcr/screens/match_detail_screen.dart';
import 'package:dvcr/screens/matches/matches_helpers.dart';
import 'package:dvcr/screens/native_video_screen.dart';
import 'package:dvcr/screens/profile_screen.dart';
import 'package:dvcr/screens/social_links_screen.dart';
import 'package:dvcr/screens/video_web_screen.dart';
import 'package:dvcr/services/app_settings_service.dart';
import 'package:dvcr/services/feature_flags_service.dart';
import 'package:dvcr/services/live_state_service.dart';
import 'package:dvcr/services/podcast_controller.dart';
import 'package:dvcr/services/season_lifecycle_service.dart';
import 'package:dvcr/services/user_service.dart';
import 'package:dvcr/services/youtube_playlist_service.dart';
import 'package:dvcr/utils/open_prono_for_match.dart';
import 'package:dvcr/utils/youtube_parser.dart';
import 'package:dvcr/widgets/donation_banner.dart';
import 'package:dvcr/widgets/dvcr_skeleton.dart';
import 'package:dvcr/widgets/emission_poll_home_card.dart';
import 'package:dvcr/widgets/empty_state_panel.dart';
import 'package:dvcr/widgets/live_interaction_home_slot.dart';
import 'package:dvcr/widgets/live_stats_sheet.dart';
import 'package:dvcr/widgets/match_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/home_motion.dart';
import '../widgets/home_palette.dart';
import '../widgets/home_shell_widgets.dart';

part 'parts/home_screen_live_helpers.dart';
part 'parts/home_screen_body.dart';
part 'parts/home_screen_actions.dart';
part 'parts/home_screen_hero_app_bar.dart';
part 'parts/home_screen_hero_contents.dart';
part 'parts/home_screen_hero_live.dart';
part 'parts/home_screen_date_helpers.dart';
part 'parts/home_feed_match_logic.dart';
part 'parts/home_feed_featured_header.dart';
part 'parts/home_feed_prono_widgets.dart';
part 'parts/home_feed_next_match_card.dart';
part 'parts/home_feed_articles.dart';
part 'parts/home_feed_results.dart';
part 'parts/home_feed_result_card.dart';
part 'parts/home_feed_result_parts.dart';
part 'parts/home_hero_chips.dart';
part 'parts/home_hero_toolbar.dart';
part 'parts/home_podcast_widgets.dart';
part 'parts/home_media_sections.dart';
part 'parts/home_media_tv_card.dart';
part 'parts/home_secondary_prono.dart';

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

const _categories = [
  'TOUT',
  'RÉSULTATS',
  'AVANT-MATCH',
  'CHRONIQUES SEDANAISES',
  'COULISSES',
  'ANALYSE',
];

/// Navigation vers un onglet principal. [matchesSubTab] : 0 à venir, 1 résultats, 2 classement.
typedef HomeMainTabSwitch =
    void Function(int tabIndex, {int? matchesSubTab});

class HomeScreen extends ConsumerStatefulWidget {
  final HomeMainTabSwitch? onSwitchTab;
  final VoidCallback? onOpenGlobalSearch;

  const HomeScreen({super.key, this.onSwitchTab, this.onOpenGlobalSearch});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Accueil state fields — mixins attach behavior (avoids recursive self-mixin).
abstract class _HomeScreenController extends ConsumerState<HomeScreen>
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

  // Photo bannière home (null = asset par défaut) — via homeBannerPhotoUrlProvider
  String? _homeBannerUrl;

  // Émission DVCR live (rempli via [LiveStateService])
  bool _isEmissionLive = false;
  String? _emissionUrl;
  String _emissionTitle = '';
  int _emissionViewers = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // Cross-mixin API (sibling mixins cannot see each other without these).
  void _switchMain(int tab, {int? matchesSubTab}) {
    widget.onSwitchTab?.call(tab, matchesSubTab: matchesSubTab);
  }

  int _computeChronoSeconds();
  void _updateChronoTimer();
  String get _chronoDisplay;
  void _showLiveStats(BuildContext context);
  Future<void> _loadRole();
  List<Map<String, dynamic>> _heroPreviewEvents();
  String _formatPodcastRendezVous(DateTime date);
  Future<void> _openCompoCard(BuildContext ctx);
  Future<void> _openPodcastRendezVousEditor(DateTime? initialDate);
  SliverAppBar _buildAppBarWithHero();
  Widget _buildDefaultHeroContent();
  Widget _buildEmissionHeroContent();
  Widget _buildLiveHeroContent(List<Map<String, dynamic>> heroEvents);
  Widget _buildCategoryFilter();
}

class _HomeScreenState extends _HomeScreenController
    with
        _HomeScreenLiveHelpersMixin,
        _HomeScreenBodyMixin,
        _HomeScreenActionsMixin,
        _HomeScreenHeroAppBarMixin,
        _HomeScreenHeroContentsMixin,
        _HomeScreenHeroLiveMixin {
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _loadRole();
    _liveHubSub = ref.read(homeLiveHubAdapterProvider).watch().listen((hub) {
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
  }

  @override
  void dispose() {
    _liveHubSub?.cancel();
    _chronoDisplayTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }
}
