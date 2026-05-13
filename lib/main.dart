import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'theme/dvcr_theme.dart';
import 'theme/app_colors.dart';
import 'services/app_cache_service.dart';
import 'services/podcast_controller.dart';
import 'services/match_controller.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/world_cup_tab.dart';
import 'features/prono/prono_public.dart';
import 'screens/global_search_screen.dart';
import 'screens/admin_web_screen.dart';
import 'screens/register_screen.dart';
import 'screens/tutorial_screen.dart';
import 'app/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/network_banner.dart';
import 'services/notification_service.dart';
import 'services/notification_prefs_service.dart';
import 'services/share_templates_cache.dart';
import 'services/feature_flags_service.dart';
import 'navigation/prono_championship_rollout.dart';
import 'navigation/world_cup_tab_rollout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

StreamSubscription<String>? _fcmTokenRefreshSub;
Future<void>? _appBootstrap;

void main() async {
  FlutterError.onError = (details) {
    debugPrint('DVCR FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('DVCR FLUTTER ERROR stack: ${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('DVCR PLATFORM ERROR: $error');
    debugPrint('DVCR PLATFORM ERROR stack: $stack');
    return false;
  };
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColorsLight.scaffold,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColorsLight.scaffold,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  debugPrint('DVCR: start init');
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('DVCR: date format error: $e');
  }
  debugPrint('DVCR: date ok');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('DVCR: firebase error: $e');
  }
  debugPrint('DVCR: firebase ok');
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('DVCR: firestore cache ok');
  } catch (e) {
    debugPrint('DVCR: firestore cache error: $e');
  }
  final bootstrap = _appBootstrap ??= _bootstrapCriticalServices();
  runApp(DVCRApp(bootstrap: bootstrap));
  unawaited(_initDeferredServices(bootstrap));
}

Future<void> _bootstrapCriticalServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 700));
  await _runBootstrapStep('app cache', AppCacheService.init);
  await _runBootstrapStep('podcast', PodcastController.instance.init);
  await _runBootstrapStep('match controller', MatchController.instance.init);
  await _runBootstrapStep('local notifications', NotificationService.init);
}

Future<void> _initDeferredServices(Future<void> bootstrap) async {
  await bootstrap;
  FeatureFlagsService.ensureListener();
  ShareTemplatesCache.start();
  // FCM wakes Google Play Services; delaying it avoids a startup memory spike
  // on small Android emulators while keeping notifications enabled normally.
  await Future<void>.delayed(const Duration(seconds: 2));
  await _initMessaging();
}

Future<void> _runBootstrapStep(
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
    debugPrint('DVCR: $label ok');
  } catch (e) {
    debugPrint('DVCR: $label error: $e');
  }
}

Future<void> _initMessaging() async {
  try {
    NotificationService.setNotificationTapHandler(handleDvcrNotificationPayload);
    await FirebaseMessaging.instance.requestPermission().timeout(
      const Duration(seconds: 5),
    );
    debugPrint('DVCR: messaging ok');
    await _syncCurrentFcmToken();
    await _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      unawaited(_persistFcmToken(token));
    });
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(NotificationService.showRemoteMessage(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(
        pushScreenForNotificationData(
          Map<String, dynamic>.from(message.data),
        ),
      );
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(
        pushScreenForNotificationData(
          Map<String, dynamic>.from(initialMessage.data),
        ),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await NotificationPrefsService.pullFromFirestoreAndCacheLocal(uid);
      } catch (e) {
        debugPrint('DVCR: notification prefs pull: $e');
      }
    }
    bool readNotifBool(String k, String legacy) =>
        prefs.getBool(k) ?? prefs.getBool(legacy) ?? true;
    final notifEnabled = readNotifBool('notif_live', 'profile_notif_live');
    final alertsEnabled = readNotifBool('notif_alerts', 'profile_notif_alerts');
    final actusEnabled = readNotifBool('notif_actus', 'profile_notif_actus');
    final liveEventsEnabled =
        readNotifBool('notif_live_events', 'profile_notif_live_events');
    final matchRemindEnabled =
        readNotifBool('notif_match_remind', 'profile_notif_match_remind');
    if (notifEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_live');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live');
    }
    if (alertsEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_alerts');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_alerts');
    }
    if (actusEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_articles');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_articles');
    }
    if (liveEventsEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_live_events');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live_events');
    }
    if (matchRemindEnabled) {
      FirebaseMessaging.instance.subscribeToTopic('dvcr_notifications');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_notifications');
    }
  } catch (e) {
    debugPrint('DVCR: messaging/prefs error: $e');
  }
}

Future<void> _syncCurrentFcmToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _persistFcmToken(token);
  } catch (e) {
    debugPrint('DVCR: FCM token sync skipped: $e');
  }
}

Future<void> _persistFcmToken(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'fcmToken': token,
    'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    'fcmPlatform': defaultTargetPlatform.name,
  }, SetOptions(merge: true));
}

class DVCRApp extends StatelessWidget {
  final Future<void> bootstrap;

  const DVCRApp({super.key, required this.bootstrap});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: dvcrNavigatorKey,
      title: 'DVCR',
      debugShowCheckedModeBanner: false,
      theme: DVCRTheme.lightTheme,
      home: kIsWeb ? const AdminWebScreen() : _AppEntry(bootstrap: bootstrap),
      routes: buildDvcrAppRoutes(),
    );
  }
}

// ── Point d'entrée : inscription → tutoriel (1×) → app ────────────────────────
// Flux :
//   1. Pas connecté  → RegisterScreen (forcé)
//   2. Connecté      → TutorialScreen si pas encore fait, sinon MainNavigation
enum _Phase { loading, register, tutorial, app }

class _AppEntry extends StatefulWidget {
  final Future<void> bootstrap;

  const _AppEntry({required this.bootstrap});
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  _Phase _phase = _Phase.loading;
  StreamSubscription<User?>? _authSub;
  User? _currentUser;
  bool _bootstrapReady = false;
  int _resolveVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) {
        return;
      }
      _currentUser = user;
      if (user != null) {
        unawaited(_syncCurrentFcmToken());
      }
      if (_bootstrapReady) {
        unawaited(_resolveForCurrentUser());
      }
        // Pendant le splash, laisser _resolve() gérer la transition après le délai minimum
    });
    unawaited(_startBootstrap());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _startBootstrap() async {
    await Future.wait<void>([
      widget.bootstrap,
      Future<void>.delayed(const Duration(milliseconds: 2500)),
    ]);
    if (!mounted) {
      return;
    }
    _bootstrapReady = true;
    await _resolveForCurrentUser();
  }

  Future<void> _resolveForCurrentUser() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    final ticket = ++_resolveVersion;
    final user = _currentUser;
    var tutorialDone = false;
    try {
      tutorialDone = await isTutorialDone()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (e, st) {
      debugPrint('DVCR: isTutorialDone error: $e\n$st');
    }
    final next = user == null
        ? _Phase.register
        : (tutorialDone ? _Phase.app : _Phase.tutorial);
    if (!mounted || ticket != _resolveVersion) {
      return;
    }
    if (_phase != next) {
      setState(() => _phase = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget phaseChild;
    switch (_phase) {
      case _Phase.loading:
        phaseChild = const _SplashScreen();
        break;
      case _Phase.register:
        phaseChild = RegisterScreen(
          onRegistered: () {
            if (!mounted) return;
            _currentUser = FirebaseAuth.instance.currentUser;
            unawaited(_resolveForCurrentUser());
          },
        );
        break;
      case _Phase.tutorial:
        phaseChild = TutorialScreen(
          onDone: () {
            if (mounted) setState(() => _phase = _Phase.app);
          },
        );
        break;
      case _Phase.app:
        phaseChild = const MainNavigation();
        break;
    }

    final base = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: base,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: <Widget>[
              ColoredBox(color: base),
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.024),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<_Phase>(_phase),
          child: phaseChild,
        ),
      ),
    );
  }
}

enum _MainNavSemantic { home, live, matches, articles, chat, prono, wc }

_MainNavSemantic? _mainNavSemanticForIndex(
  int i,
  bool pronoHub,
  bool wcTab,
) {
  if (i >= 0 && i < 5) {
    return [
      _MainNavSemantic.home,
      _MainNavSemantic.live,
      _MainNavSemantic.matches,
      _MainNavSemantic.articles,
      _MainNavSemantic.chat,
    ][i];
  }
  if (pronoHub && i == 5) return _MainNavSemantic.prono;
  final wcIdx = wcTab ? (5 + (pronoHub ? 1 : 0)) : -1;
  if (wcTab && wcIdx >= 0 && i == wcIdx) return _MainNavSemantic.wc;
  return null;
}

int _mainNavIndexForSemantic(
  _MainNavSemantic semantic,
  bool pronoHub,
  bool wcTab,
) {
  switch (semantic) {
    case _MainNavSemantic.home:
      return 0;
    case _MainNavSemantic.live:
      return 1;
    case _MainNavSemantic.matches:
      return 2;
    case _MainNavSemantic.articles:
      return 3;
    case _MainNavSemantic.chat:
      return 4;
    case _MainNavSemantic.prono:
      return pronoHub ? 5 : 0;
    case _MainNavSemantic.wc:
      if (!wcTab) return 0;
      return pronoHub ? 6 : 5;
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _globalSearchOpen = false;
  late final AnimationController _tabSwitchAnim;
  late final Animation<double> _tabSwitchFade;
  late final Animation<Offset> _tabSwitchSlide;

  final GlobalKey<NavigatorState> _homeTabNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<MatchesScreenState> _matchesScreenKey =
      GlobalKey<MatchesScreenState>();

  /// Pas `late final` + [initState] seul : après un **hot reload**, [initState] ne
  /// repasse pas et les `late` restent non initialisés.
  Widget? _homeNavigatorCache;
  Widget? _matchesScreenCache;

  bool _lastPronoHub = false;
  bool _lastWorldCupTab = false;

  /// Incrémenté à chaque **sélection** de l’onglet CdM (même re-tap) : remet l’encart
  /// partenaire visible **sans** recréer l’onglet (évite le flash image / `initialData`
  /// du [StreamBuilder] partenaire).
  int _wcPartnerEncartVisitToken = 0;

  Widget _homeNavigatorChild() {
    return _homeNavigatorCache ??= Navigator(
      key: _homeTabNavigatorKey,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => HomeScreen(
            onSwitchTab: _setMainTab,
            onOpenGlobalSearch: () =>
                setState(() => _globalSearchOpen = true),
          ),
        );
      },
    );
  }

  Widget _matchesScreenChild() {
    return _matchesScreenCache ??= MatchesScreen(key: _matchesScreenKey);
  }

  @override
  void initState() {
    super.initState();
    _lastPronoHub = PronoChampionshipRollout.isHubVisible;
    _lastWorldCupTab = WorldCupTabRollout.isTabVisible;
    FeatureFlagsService.notifier.addListener(_onNavRolloutFlagsChanged);
    _tabSwitchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 1.0;
    final curve = CurvedAnimation(
      parent: _tabSwitchAnim,
      curve: Curves.easeOutCubic,
    );
    _tabSwitchFade = Tween<double>(begin: 0.93, end: 1.0).animate(curve);
    _tabSwitchSlide = Tween<Offset>(
      begin: const Offset(0, 0.014),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    FeatureFlagsService.notifier.removeListener(_onNavRolloutFlagsChanged);
    _tabSwitchAnim.dispose();
    super.dispose();
  }

  void _onNavRolloutFlagsChanged() {
    if (!mounted) return;
    final p = PronoChampionshipRollout.isHubVisible;
    final w = WorldCupTabRollout.isTabVisible;
    if (p == _lastPronoHub && w == _lastWorldCupTab) return;

    setState(() {
      final sem = _mainNavSemanticForIndex(_index, _lastPronoHub, _lastWorldCupTab) ??
          _MainNavSemantic.home;
      var adjusted = sem;
      if (sem == _MainNavSemantic.prono && !p) {
        adjusted = _MainNavSemantic.home;
      }
      if (sem == _MainNavSemantic.wc && !w) {
        adjusted = _MainNavSemantic.home;
      }
      _index = _mainNavIndexForSemantic(adjusted, p, w);
      _lastPronoHub = p;
      _lastWorldCupTab = w;
    });
  }

  List<Widget> _indexedStackChildren() {
    final prono = PronoChampionshipRollout.isHubVisible;
    final wc = WorldCupTabRollout.isTabVisible;
    return [
      _homeNavigatorChild(),
      const LiveScreen(),
      _matchesScreenChild(),
      const ArticlesScreen(),
      const ChatScreen(),
      if (prono) const PronoRootShell(),
      if (wc) WorldCupTab(partnerEncartResetToken: _wcPartnerEncartVisitToken),
    ];
  }

  List<_Tab> _bottomTabs() {
    final prono = PronoChampionshipRollout.isHubVisible;
    final wc = WorldCupTabRollout.isTabVisible;
    return [
      const _Tab(
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
        label: 'ACCUEIL',
      ),
      const _Tab(
        icon: Icons.live_tv_outlined,
        activeIcon: Icons.live_tv_rounded,
        label: 'DVCR TV',
      ),
      const _Tab(
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events_rounded,
        label: 'CALENDRIER',
      ),
      const _Tab(
        icon: Icons.article_outlined,
        activeIcon: Icons.article_rounded,
        label: 'ACTUS',
      ),
      const _Tab(
        icon: Icons.people_outline,
        activeIcon: Icons.people_rounded,
        label: 'COMMUNAUTÉ',
      ),
      if (prono)
        const _Tab(
          icon: Icons.stadium_outlined,
          activeIcon: Icons.stadium_rounded,
          label: 'PRONOS',
        ),
      if (wc)
        const _Tab(
          icon: Icons.public_outlined,
          activeIcon: Icons.public_rounded,
          label: 'CdM 2026',
        ),
    ];
  }

  void _setMainTab(int i, {int? matchesSubTab}) {
    final tabs = _bottomTabs();
    final maxIdx = tabs.length - 1;
    final iSafe = i.clamp(0, maxIdx);
    final wcOn = WorldCupTabRollout.isTabVisible;
    final pronoOn = PronoChampionshipRollout.isHubVisible;
    final wcIdx = wcOn ? (pronoOn ? 6 : 5) : null;
    final tappedWorldCup = wcIdx != null && iSafe == wcIdx;

    final changed = _index != iSafe;
    if (changed) {
      HapticFeedback.selectionClick();
      setState(() {
        _index = iSafe;
        if (tappedWorldCup) {
          _wcPartnerEncartVisitToken++;
        }
      });
      _tabSwitchAnim.forward(from: 0);
    } else if (tappedWorldCup) {
      setState(() => _wcPartnerEncartVisitToken++);
    }
    if (iSafe == 2 && matchesSubTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _matchesScreenKey.currentState?.selectTab(matchesSubTab);
      });
    }
    // Re-tap sur Accueil (ou retour sur cet onglet) : dépile profil / autres
    // écrans poussés sur le Navigator interne de l’onglet Home.
    if (iSafe == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeTabNavigatorKey.currentState
            ?.popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _tabSwitchFade,
            child: SlideTransition(
              position: _tabSwitchSlide,
              child: IndexedStack(
                index: _index.clamp(0, _bottomTabs().length - 1),
                children: _indexedStackChildren(),
              ),
            ),
          ),
          const NetworkBanner(),
          if (_globalSearchOpen)
            Positioned.fill(
              child: GlobalSearchScreen(
                onDismiss: () => setState(() => _globalSearchOpen = false),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_PodcastMiniPlayer(), _buildBottomNav()],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColorsLight.card,
        border: const Border(
          top: BorderSide(color: AppColorsLight.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(28),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: List.generate(_bottomTabs().length, _buildTab)),
        ),
      ),
    );
  }

  Widget _buildTab(int i) {
    final tabs = _bottomTabs();
    final tab = tabs[i];
    final selected = _index == i;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setMainTab(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 11 : 10,
                vertical: selected ? 5 : 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.green.withAlpha(26)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.green.withAlpha(36),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedScale(
                scale: selected ? 1.045 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? tab.activeIcon : tab.icon,
                  size: 22,
                  color: selected
                      ? AppColors.green
                      : AppColorsLight.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: selected ? 0.4 : 0.35,
                color: selected
                    ? AppColors.green
                    : AppColorsLight.textMuted,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ── Splash screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween<double>(begin: 1.08, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fond ≠ noir pur : sur simulateur VM / rendu logiciel le décodage JPEG peut
    // prendre du temps — sans couche dessous on dirait un écran « mort ».
    return Scaffold(
      backgroundColor: AppColors.green,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.green),
          // Photo avec légère animation de zoom
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.scale(
              scale: _scale.value,
              child: child,
            ),
            child: Image.asset(
              'assets/images/1ba3d6e9-9678-42b2-8ec5-9e8899f16194.jpg',
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSync) {
                if (wasSync || frame != null) return child;
                return Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold.withValues(alpha: 0.85),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => ColoredBox(
                color: AppColorsLight.scaffold,
                child: Center(
                  child: Icon(Icons.local_shipping_rounded,
                      size: 72, color: AppColorsLight.textMuted.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),

          // Gradient overlay — sombre en haut et en bas
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(120),
                  Colors.black.withAlpha(20),
                  Colors.black.withAlpha(20),
                  Colors.black.withAlpha(200),
                ],
                stops: const [0.0, 0.25, 0.65, 1.0],
              ),
            ),
          ),

          // Spinner discret en bas
          Positioned(
            bottom: 52,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _logoFade,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFC8A436),
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastMiniPlayer extends StatelessWidget {
  static const _gold = Color(0xFFC8A436);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        final ctrl = PodcastController.instance;
        final ep = ctrl.currentEpisode;
        if (ep == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: AppColorsLight.cardMuted,
            border: Border(
              top: BorderSide(color: AppColors.green.withAlpha(50), width: 1),
              bottom: const BorderSide(
                color: AppColorsLight.border,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.headphones_rounded, size: 16, color: _gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ep.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColorsLight.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${ctrl.positionLabel} / ${ctrl.durationLabel}',
                          style: const TextStyle(
                            color: AppColorsLight.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => ctrl.skipBy(const Duration(seconds: -15)),
                    icon: const Icon(
                      Icons.replay_10_rounded,
                      size: 22,
                      color: AppColorsLight.textMuted,
                    ),
                    splashRadius: 18,
                  ),
                  GestureDetector(
                    onTap: () => ctrl.isPlaying ? ctrl.pause() : ctrl.resume(),
                    child: Icon(
                      ctrl.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 36,
                      color: _gold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => ctrl.skipBy(const Duration(seconds: 15)),
                    icon: const Icon(
                      Icons.forward_10_rounded,
                      size: 22,
                      color: AppColorsLight.textMuted,
                    ),
                    splashRadius: 18,
                  ),
                  GestureDetector(
                    onTap: () => ctrl.dismiss(),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColorsLight.textMuted,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: _gold,
                  inactiveTrackColor: AppColorsLight.border,
                  thumbColor: _gold,
                  overlayColor: const Color(0x33C8A436),
                ),
                child: Slider(
                  value: ctrl.progress.clamp(0.0, 1.0),
                  onChanged: ctrl.effectiveDuration > Duration.zero
                      ? ctrl.seekToFraction
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
