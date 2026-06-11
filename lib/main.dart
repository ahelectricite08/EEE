import 'dart:async';
import 'dart:ui' show ImageFilter;

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
import 'services/fff_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/articles/articles_list_widgets.dart';
import 'screens/chat_screen.dart';
import 'features/prono/prono_public.dart';
import 'screens/global_search_screen.dart';
import 'screens/admin_web_screen.dart';
import 'screens/register_screen.dart';
import 'screens/tutorial_screen.dart';
import 'app/app_router.dart';
import 'navigation/app_shell_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/network_banner.dart';
import 'services/notification_service.dart';
import 'services/live_match_activity_service.dart';
import 'services/live_activity_push_sync.dart';
import 'services/fcm_token_service.dart';
import 'services/notification_prefs_service.dart';
import 'services/share_templates_cache.dart';
import 'services/feature_flags_service.dart';
import 'services/app_version_policy_service.dart';
import 'widgets/app_update_optional_banner.dart';
import 'screens/force_update_screen.dart';
import 'navigation/community_chat_rollout.dart';
import 'navigation/prono_championship_rollout.dart';
import 'navigation/esti_dvcr_rollout.dart';
import 'screens/esti_dvcr/esti_dvcr_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

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
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundLiveSync);
    }
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
  if (!kIsWeb) {
    await _runBootstrapStep(
      'live lock screen score',
      LiveMatchActivityService.start,
    );
  }
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
    await FcmTokenService.requestPermission().timeout(
      const Duration(seconds: 10),
    );
    debugPrint('DVCR: messaging ok');
    await FcmTokenService.syncToken();
    await FcmTokenService.startListening();
    FirebaseMessaging.onMessage.listen((message) async {
      final data = message.data;
      if (data['endLive'] == '1' || data['type'] == 'live_end') {
        unawaited(LiveMatchActivityService.dismissNow());
        return;
      }
      unawaited(LiveActivityPushSync.handleRemoteMessage(message));
      if (data['syncLiveActivity'] == '1') {
        final eventType = (data['type'] ?? '').toString();
        if (_isNotifiableEventType(eventType) &&
            !await LiveActivityPushSync.hasActiveLiveActivity()) {
          final title = (data['alertTitle'] ?? '').toString().trim();
          if (title.isNotEmpty) {
            final short = (data['alertShortBody'] ?? '').toString().trim();
            final body = short.isNotEmpty
                ? short
                : (data['alertBody'] ?? data['lastEventLine'] ?? '')
                    .toString()
                    .trim();
            unawaited(NotificationService.showLiveEvent(
              title: title,
              body: body.isEmpty ? title : body,
              type: eventType,
            ));
          }
        }
        return;
      }
      if (data['notifyVisible'] == '1') {
        if (await LiveActivityPushSync.hasActiveLiveActivity()) return;
        unawaited(NotificationService.showRemoteMessage(message));
        return;
      }
      if (!NotificationService.shouldDisplayBanner(message)) return;
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
    // Topic admin (rappels match Sedan, etc.) — pas de toggle utilisateur.
    await FirebaseMessaging.instance.subscribeToTopic('dvcr_notifications');
  } catch (e) {
    debugPrint('DVCR: messaging/prefs error: $e');
  }
}

const _kNotifiableTypes = {
  'goal', 'yellow', 'yellow_card', 'red', 'red_card',
  'substitution', 'halftime', 'fulltime', 'extra_fulltime',
};

bool _isNotifiableEventType(String type) => _kNotifiableTypes.contains(type);

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

// ── Point d'entrée : actus invité → inscription (option) → tutoriel → app ─────
// Flux :
//   1. Pas connecté  → MainNavigation mode invité (actus), compte optionnel
//   2. Connecté      → TutorialScreen si pas encore fait, sinon MainNavigation
enum _Phase { loading, register, guest, tutorial, app }

class _AppEntry extends StatefulWidget {
  final Future<void> bootstrap;

  const _AppEntry({required this.bootstrap});
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<Map<String, dynamic>>? _versionPolicySub;
  User? _currentUser;
  bool _bootstrapReady = false;
  bool _guestBrowsing = false;
  int _resolveVersion = 0;
  AppVersionEvaluation _versionEval = AppVersionEvaluation.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _versionPolicySub = AppVersionPolicyService.configStream().listen((_) {
      unawaited(_refreshVersionGate());
    });
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) {
        return;
      }
      _currentUser = user;
      if (user != null) {
        _guestBrowsing = false;
        unawaited(FcmTokenService.syncToken());
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _versionPolicySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(LiveMatchActivityService.syncNow(hardRefresh: true));
    }
  }

  Future<void> _refreshVersionGate() async {
    final eval = await AppVersionPolicyService.evaluateCurrent();
    if (!mounted) return;
    setState(() => _versionEval = eval);
  }

  Future<void> _startBootstrap() async {
    await Future.wait<void>([
      widget.bootstrap,
      Future<void>.delayed(const Duration(milliseconds: 2500)),
    ]);
    if (!mounted) {
      return;
    }
    await _refreshVersionGate();
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
        ? (_guestBrowsing ? _Phase.register : _Phase.guest)
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
    if (_versionEval.mustBlock && _versionEval.required != null) {
      return ForceUpdateScreen(
        update: _versionEval.required!,
        onRetry: () => _refreshVersionGate(),
      );
    }

    final Widget phaseChild;
    switch (_phase) {
      case _Phase.loading:
        phaseChild = const _SplashScreen();
        break;
      case _Phase.register:
        phaseChild = RegisterScreen(
          onRegistered: () {
            if (!mounted) return;
            _guestBrowsing = false;
            _currentUser = FirebaseAuth.instance.currentUser;
            unawaited(_resolveForCurrentUser());
          },
          onBrowseArticlesAsGuest: () {
            if (!mounted) return;
            setState(() {
              _guestBrowsing = false;
              _phase = _Phase.guest;
            });
          },
          onBackToGuest: () {
            if (!mounted) return;
            setState(() {
              _guestBrowsing = false;
              _phase = _Phase.guest;
            });
          },
        );
        break;
      case _Phase.guest:
        phaseChild = MainNavigation(
          guestMode: true,
          onRequestSignIn: () {
            if (!mounted) return;
            setState(() {
              _guestBrowsing = true;
              _phase = _Phase.register;
            });
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
    final optional = _versionEval.optional;
    Widget body = ColoredBox(
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

    if (optional != null) {
      body = Stack(
        fit: StackFit.expand,
        children: [
          body,
          Align(
            alignment: Alignment.topCenter,
            child: AppUpdateOptionalBanner(
              prompt: optional,
              onDismissed: _refreshVersionGate,
            ),
          ),
        ],
      );
    }

    return body;
  }
}

enum _MainNavSemantic { home, live, matches, articles, chat, prono, estiDvcr }

class _NavEntry {
  final _MainNavSemantic semantic;
  final Widget child;
  final _Tab tab;
  final bool guestLocked;

  const _NavEntry({
    required this.semantic,
    required this.child,
    required this.tab,
    this.guestLocked = false,
  });
}

class MainNavigation extends StatefulWidget {
  /// Lecture des actus sans compte (conformité App Store).
  final bool guestMode;
  final VoidCallback? onRequestSignIn;

  const MainNavigation({
    super.key,
    this.guestMode = false,
    this.onRequestSignIn,
  });

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

  bool _lastChatVisible = false;
  bool _lastPronoVisible = false;
  bool _lastEstiDvcrVisible = false;
  int _estiDvcrToken = 0;

  // Scroll-aware nav — ValueNotifier : seul le widget nav se repaint
  final _navScaleNotifier = ValueNotifier<double>(1.0);
  Timer? _navScaleResetTimer;
  double _navScrollAccum = 0;

  // Position du lecteur podcast flottant (initialisée au premier build)
  Offset? _playerPos;
  Timer? _guestActusSignupTimer;
  bool _guestSignupPromptShown = false;

  Widget _guestLockedTabChild() => const _GuestLockedTabPane();

  List<_NavEntry> _navEntries() {
    final guest = widget.guestMode;

    final entries = <_NavEntry>[
      _NavEntry(
        semantic: _MainNavSemantic.home,
        child: guest ? _guestLockedTabChild() : _homeNavigatorChild(),
        guestLocked: guest,
        tab: const _Tab(
          icon: Icons.home_rounded,
          activeIcon: Icons.home_rounded,
          label: 'ACCUEIL',
        ),
      ),
      _NavEntry(
        semantic: _MainNavSemantic.live,
        child: guest ? _guestLockedTabChild() : const LiveScreen(),
        guestLocked: guest,
        tab: const _Tab(
          icon: Icons.live_tv_outlined,
          activeIcon: Icons.live_tv_rounded,
          label: 'DVCR TV',
        ),
      ),
      _NavEntry(
        semantic: _MainNavSemantic.matches,
        child: guest ? _guestLockedTabChild() : _matchesScreenChild(),
        guestLocked: guest,
        tab: const _Tab(
          icon: Icons.emoji_events_outlined,
          activeIcon: Icons.emoji_events_rounded,
          label: 'CALENDRIER',
        ),
      ),
      _NavEntry(
        semantic: _MainNavSemantic.articles,
        child: guest
            ? ArticlesScreen(
                guestMode: true,
                onRequestSignIn: widget.onRequestSignIn,
              )
            : const ArticlesScreen(),
        tab: const _Tab(
          icon: Icons.article_outlined,
          activeIcon: Icons.article_rounded,
          label: 'ACTUS',
        ),
      ),
    ];

    final showChat = guest ||
        (!guest &&
            FirebaseAuth.instance.currentUser != null &&
            CommunityChatRollout.isVisible);
    if (showChat) {
      entries.add(
        _NavEntry(
          semantic: _MainNavSemantic.chat,
          child: guest ? _guestLockedTabChild() : const ChatScreen(),
          guestLocked: guest,
          tab: const _Tab(
            icon: Icons.people_outline,
            activeIcon: Icons.people_rounded,
            label: 'COMMUNAUTÉ',
            shortLabel: 'CHAT',
          ),
        ),
      );
    }

    final showProno = guest ||
        (!guest &&
            FirebaseAuth.instance.currentUser != null &&
            PronoChampionshipRollout.isHubVisible);
    if (showProno) {
      entries.add(
        _NavEntry(
          semantic: _MainNavSemantic.prono,
          child: guest ? _guestLockedTabChild() : const PronoRootShell(),
          guestLocked: guest,
          tab: const _Tab(
            icon: Icons.stadium_outlined,
            activeIcon: Icons.stadium_rounded,
            label: 'PRONOS',
          ),
        ),
      );
    }

    final showEstiDvcr = !widget.guestMode &&
        FirebaseAuth.instance.currentUser != null &&
        EstiDvcrRollout.isTabVisible;
    if (showEstiDvcr) {
      entries.add(
        _NavEntry(
          semantic: _MainNavSemantic.estiDvcr,
          child: EstiDvcrTab(partnerEncartResetToken: _estiDvcrToken),
          guestLocked: false,
          tab: const _Tab(
            icon: Icons.sports_soccer_outlined,
            activeIcon: Icons.sports_soccer_rounded,
            label: "ESTI'DVCR",
          ),
        ),
      );
    }

    return entries;
  }

  _MainNavSemantic? _semanticAt(int i) {
    final entries = _navEntries();
    if (i < 0 || i >= entries.length) return null;
    return entries[i].semantic;
  }

  int _indexForSemantic(_MainNavSemantic semantic) {
    final i = _navEntries().indexWhere((e) => e.semantic == semantic);
    return i >= 0 ? i : 0;
  }

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
    if (widget.guestMode) {
      _index = _indexForSemantic(_MainNavSemantic.articles);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleGuestActusSignupPrompt();
      });
    }
    _lastChatVisible =
        !widget.guestMode && CommunityChatRollout.isVisible;
    _lastPronoVisible =
        !widget.guestMode && PronoChampionshipRollout.isHubVisible;
    _lastEstiDvcrVisible =
        !widget.guestMode && EstiDvcrRollout.isTabVisible;
    AppShellNavigation.register(
      onRequest: _handleShellNavigationRequest,
      homeNavigatorKey: _homeTabNavigatorKey,
    );
    if (!widget.guestMode) {
      FeatureFlagsService.notifier.addListener(_onNavRolloutFlagsChanged);
    }
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
    _cancelGuestActusSignupPrompt();
    AppShellNavigation.unregister();
    if (!widget.guestMode) {
      FeatureFlagsService.notifier.removeListener(_onNavRolloutFlagsChanged);
    }
    _tabSwitchAnim.dispose();
    _navScaleResetTimer?.cancel();
    _navScaleNotifier.dispose();
    super.dispose();
  }

  void _cancelGuestActusSignupPrompt() {
    _guestActusSignupTimer?.cancel();
    _guestActusSignupTimer = null;
  }

  void _scheduleGuestActusSignupPrompt() {
    _cancelGuestActusSignupPrompt();
    if (!widget.guestMode || _guestSignupPromptShown) return;
    if (_semanticAt(_index) != _MainNavSemantic.articles) return;
    _guestActusSignupTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      unawaited(_presentGuestSignupPrompt());
    });
  }

  Future<void> _presentGuestSignupPrompt() async {
    if (!mounted || !widget.guestMode || _guestSignupPromptShown) return;
    if (_semanticAt(_index) != _MainNavSemantic.articles) return;
    _guestSignupPromptShown = true;
    _cancelGuestActusSignupPrompt();
    await showGuestSignupPromptDialog(
      context,
      onRegister: () => widget.onRequestSignIn?.call(),
    );
  }

  _MainNavSemantic _semanticForShellTab(AppShellTab tab) {
    switch (tab) {
      case AppShellTab.home:
        return _MainNavSemantic.home;
      case AppShellTab.live:
        return _MainNavSemantic.live;
      case AppShellTab.matches:
        return _MainNavSemantic.matches;
      case AppShellTab.articles:
        return _MainNavSemantic.articles;
      case AppShellTab.chat:
        return _MainNavSemantic.chat;
      case AppShellTab.prono:
        return _MainNavSemantic.prono;
    }
  }

  void _handleShellNavigationRequest(AppShellNavigationRequest request) {
    if (request.popRootOverlays) {
      dvcrNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    final semantic = _semanticForShellTab(request.tab);
    _setMainTab(
      _indexForSemantic(semantic),
      matchesSubTab: request.matchesSubTab,
    );
    final after = request.afterSelected;
    if (after != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await after();
      });
    }
  }

  void _onNavRolloutFlagsChanged() {
    if (!mounted || widget.guestMode) return;
    final chat = CommunityChatRollout.isVisible;
    final prono = PronoChampionshipRollout.isHubVisible;
    final estiDvcr = EstiDvcrRollout.isTabVisible;
    if (chat == _lastChatVisible &&
        prono == _lastPronoVisible &&
        estiDvcr == _lastEstiDvcrVisible) return;

    setState(() {
      final sem = _semanticAt(_index) ?? _MainNavSemantic.home;
      var adjusted = sem;
      if ((sem == _MainNavSemantic.chat && !chat) ||
          (sem == _MainNavSemantic.prono && !prono) ||
          (sem == _MainNavSemantic.estiDvcr && !estiDvcr)) {
        adjusted = _MainNavSemantic.home;
      }
      _index = _indexForSemantic(adjusted);
      _lastChatVisible = chat;
      _lastPronoVisible = prono;
      _lastEstiDvcrVisible = estiDvcr;
    });
  }

  List<Widget> _indexedStackChildren() =>
      _navEntries().map((e) => e.child).toList(growable: false);

  List<_Tab> _bottomTabs() => _navEntries().map((e) => e.tab).toList(growable: false);

  void _setMainTab(int i, {int? matchesSubTab}) {
    final tabs = _bottomTabs();
    final maxIdx = tabs.length - 1;
    final iSafe = i.clamp(0, maxIdx);

    final changed = _index != iSafe;
    if (changed) {
      HapticFeedback.selectionClick();
      if (_semanticAt(iSafe) == _MainNavSemantic.estiDvcr &&
          _semanticAt(_index) != _MainNavSemantic.estiDvcr) {
        _estiDvcrToken++;
      }
      setState(() => _index = iSafe);
      _tabSwitchAnim.forward(from: 0);
    }
if (_semanticAt(iSafe) == _MainNavSemantic.matches) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(FffSyncService.instance.refreshOnCalendarOpen());
      });
    }
    if (_semanticAt(iSafe) == _MainNavSemantic.matches &&
        matchesSubTab != null) {
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
    if (widget.guestMode) {
      if (_semanticAt(iSafe) == _MainNavSemantic.articles) {
        _scheduleGuestActusSignupPrompt();
      } else {
        _cancelGuestActusSignupPrompt();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notif) {
          if (notif is ScrollUpdateNotification) {
            final delta = notif.scrollDelta ?? 0;
            if (delta < 0) {
              _navScrollAccum = 0;
              if (_navScaleNotifier.value != 1.0) _navScaleNotifier.value = 1.0;
            } else {
              _navScrollAccum += delta;
              if (_navScrollAccum > 40 && _navScaleNotifier.value != 0.82) {
                _navScaleNotifier.value = 0.82;
              }
            }
          } else if (notif is ScrollEndNotification) {
            _navScrollAccum = 0;
          }
          return false;
        },
        child: Stack(
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
            // ── Lecteur podcast flottant & déplaçable
            if (!widget.guestMode)
              _DraggablePodcastPlayer(
                initialPos: _playerPos,
                onPositionChanged: (p) => _playerPos = p,
              ),
            if (_globalSearchOpen)
              Positioned.fill(
                child: GlobalSearchScreen(
                  onDismiss: () => setState(() => _globalSearchOpen = false),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final tabs = _bottomTabs();
    final navHeight = tabs.length >= 6 ? 60.0 : 54.0;
    const radius = 36.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: ValueListenableBuilder<double>(
          valueListenable: _navScaleNotifier,
          builder: (context, scale, child) => AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
          child: Container(
          height: navHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              // Ombre profonde — effet "suspendu"
              BoxShadow(
                color: Colors.black.withAlpha(32),
                blurRadius: 36,
                spreadRadius: -2,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                // ── Layers décoratifs : IgnorePointer pour ne jamais absorber les taps
                // 1. Blur fort
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                // 2. Fill verre chaud translucide
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xFFF8F6F2).withAlpha(172),
                    ),
                  ),
                ),
                // 3. Reflet spéculaire
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: navHeight * 0.52,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(150),
                            Colors.white.withAlpha(30),
                            Colors.white.withAlpha(0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── 4. Contenu des onglets (seul layer qui répond aux taps)
                SizedBox(
                  height: navHeight,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.15,
                    child: Row(
                      children: List.generate(tabs.length, _buildTab),
                    ),
                  ),
                ),
                // 5. Bordure prismatique irisée
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LiquidGlassBorderPainter(radius: radius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ), // ValueListenableBuilder
      ),
    );
  }

  void _onBottomTabTap(int i) {
    final entries = _navEntries();
    if (i < 0 || i >= entries.length) return;
    if (widget.guestMode && entries[i].guestLocked) {
      HapticFeedback.lightImpact();
      widget.onRequestSignIn?.call();
      return;
    }
    _setMainTab(i);
  }

  Widget _navTabIcon(_Tab tab, {required bool selected, required bool locked}) {
    Widget icon = Icon(
      selected ? tab.activeIcon : tab.icon,
      size: 22,
      color: locked
          ? AppColorsLight.textMuted.withValues(alpha: 0.42)
          : (selected ? AppColors.green : AppColorsLight.textMuted),
    );
    if (locked) {
      icon = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 2.6, sigmaY: 2.6),
        child: Opacity(opacity: 0.72, child: icon),
      );
    }
    return icon;
  }

  Widget _buildTab(int i) {
    final entries = _navEntries();
    final tab = entries[i].tab;
    final locked = widget.guestMode && entries[i].guestLocked;
    final selected = _index == i;

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 62;
          final label = compact && tab.shortLabel != null
              ? tab.shortLabel!
              : tab.label;

          return GestureDetector(
            onTap: () => _onBottomTabTap(i),
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
                    color: selected && !locked
                        ? AppColors.green.withAlpha(26)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selected && !locked
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
                    scale: selected && !locked ? 1.045 : 1.0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: _navTabIcon(tab, selected: selected, locked: locked),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 8 : 9,
                    fontWeight: selected && !locked
                        ? FontWeight.w800
                        : FontWeight.w500,
                    letterSpacing: selected ? 0.4 : 0.35,
                    color: locked
                        ? AppColorsLight.textMuted.withValues(alpha: 0.38)
                        : (selected
                            ? AppColors.green
                            : AppColorsLight.textMuted),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bordure prismatique / irisée pour l'effet liquid glass.
/// Dessine un trait arrondi avec un dégradé qui simule la réfraction de la
/// lumière sur les bords d'un verre (blanc → bleu glace → blanc → rose → mint).
class _LiquidGlassBorderPainter extends CustomPainter {
  final double radius;
  const _LiquidGlassBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.7));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withAlpha(240),                    // blanc vif (top-left)
          const Color(0xFFADD8FF).withAlpha(160),         // bleu glace
          Colors.white.withAlpha(210),
          const Color(0xFFFFB3CC).withAlpha(130),         // rose poudré
          Colors.white.withAlpha(195),
          const Color(0xFFADFFD8).withAlpha(120),         // mint
          Colors.white.withAlpha(230),                    // blanc (bottom-right)
        ],
        stops: const [0.0, 0.16, 0.33, 0.50, 0.67, 0.83, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassBorderPainter old) =>
      old.radius != radius;
}

/// Placeholder sous-jacent aux onglets verrouillés en mode invité.
class _GuestLockedTabPane extends StatelessWidget {
  const _GuestLockedTabPane();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColorsLight.scaffold);
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? shortLabel;
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.shortLabel,
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

/// Widget flottant draggable qui enveloppe [_PodcastMiniPlayer].
/// Se positionne en bas-centre par défaut ; mémorise la position via [onPositionChanged].
class _DraggablePodcastPlayer extends StatefulWidget {
  final Offset? initialPos;
  final ValueChanged<Offset> onPositionChanged;

  const _DraggablePodcastPlayer({
    required this.initialPos,
    required this.onPositionChanged,
  });

  @override
  State<_DraggablePodcastPlayer> createState() =>
      _DraggablePodcastPlayerState();
}

class _DraggablePodcastPlayerState extends State<_DraggablePodcastPlayer> {
  static const _playerWidth = 340.0;
  Offset? _pos;

  Offset _defaultPos(Size screen) => Offset(
        (screen.width - _playerWidth) / 2,
        screen.height - 160,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PodcastController.instance,
      builder: (context, _) {
        if (PodcastController.instance.currentEpisode == null) {
          return const SizedBox.shrink();
        }

        final screen = MediaQuery.of(context).size;
        _pos ??= widget.initialPos ?? _defaultPos(screen);

        return Positioned(
          left: _pos!.dx,
          top: _pos!.dy,
          width: _playerWidth,
          child: GestureDetector(
            // Drag pour déplacer
            onPanUpdate: (d) {
              final next = Offset(
                (_pos!.dx + d.delta.dx)
                    .clamp(0.0, screen.width - _playerWidth),
                (_pos!.dy + d.delta.dy)
                    .clamp(0.0, screen.height - 100),
              );
              setState(() => _pos = next);
              widget.onPositionChanged(next);
            },
            child: _PodcastMiniPlayer(),
          ),
        );
      },
    );
  }
}

void _seekFromLocal(PodcastController ctrl, double localX, BuildContext context) {
  // La largeur du player est fixée à 340px dans _DraggablePodcastPlayer
  const playerWidth = 340.0;
  const hPad = 14.0;
  final fraction = ((localX - hPad) / (playerWidth - hPad * 2)).clamp(0.0, 1.0);
  if (ctrl.effectiveDuration > Duration.zero) ctrl.seekToFraction(fraction);
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

        final progress = ctrl.progress.clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(28),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // ── Glass background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0xFFF8F6F2).withAlpha(210),
                      ),
                    ),
                  ),
                  // ── Contenu principal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rangée : icône + titre + contrôles
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _gold.withAlpha(22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _gold.withAlpha(60)),
                              ),
                              child: const Icon(Icons.headphones_rounded,
                                  size: 16, color: _gold),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                ep.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColorsLight.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _MiniPlayerBtn(
                              icon: Icons.replay_10_rounded,
                              onTap: () => ctrl.skipBy(const Duration(seconds: -15)),
                            ),
                            GestureDetector(
                              onTap: () => ctrl.isPlaying
                                  ? ctrl.pause()
                                  : ctrl.resume(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _gold.withAlpha(80),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  ctrl.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _MiniPlayerBtn(
                              icon: Icons.forward_10_rounded,
                              onTap: () => ctrl.skipBy(const Duration(seconds: 15)),
                            ),
                            _MiniPlayerBtn(
                              icon: Icons.close_rounded,
                              onTap: () => ctrl.dismiss(),
                              size: 16,
                            ),
                          ],
                        ),
                        // ── Slider seek + temps
                        Row(
                          children: [
                            Text(
                              ctrl.positionLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: AppColorsLight.textMuted,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14),
                                  activeTrackColor: _gold,
                                  inactiveTrackColor:
                                      Colors.black.withAlpha(20),
                                  thumbColor: _gold,
                                  overlayColor: _gold.withAlpha(40),
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: ctrl.effectiveDuration >
                                          Duration.zero
                                      ? ctrl.seekToFraction
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              ctrl.durationLabel,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: AppColorsLight.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlayerBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _MiniPlayerBtn({
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: AppColorsLight.textMuted),
      ),
    );
  }
}
