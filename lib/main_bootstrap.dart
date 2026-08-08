part of 'main.dart';

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
      builder: (context, child) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification ||
                notification is ScrollUpdateNotification) {
              AppHourlyPresenceService.instance.onScrollActivity();
            }
            return false;
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// ── Point d'entrée : actus invité → inscription (option) → tutoriel → app ─────
// Flux :
//   1. Pas connecté  → MainNavigation mode invité (actus), compte optionnel
//   2. Connecté      → TutorialScreen si pas encore fait, sinon MainNavigation
enum _Phase { loading, register, guest, tutorial, app }

class _AppEntry extends ConsumerStatefulWidget {
  final Future<void> bootstrap;

  const _AppEntry({required this.bootstrap});
  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  StreamSubscription<AuthSession?>? _authSub;
  StreamSubscription<Map<String, dynamic>>? _versionPolicySub;
  AuthSession? _currentSession;
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
    final authRepo = ref.read(authRepositoryProvider);
    _currentSession = authRepo.currentSession;
    _authSub = authRepo.watchSession().listen((session) {
      if (!mounted) {
        return;
      }
      _currentSession = session;
      if (session != null) {
        _guestBrowsing = false;
        unawaited(FcmTokenService.syncToken());
        unawaited(AppHourlyPresenceService.instance.ping());
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
      LiveScorePresenceService.instance.setAppResumed(true);
      unawaited(LiveMatchActivityService.syncNow(hardRefresh: true));
      unawaited(AppHourlyPresenceService.instance.ping());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      LiveScorePresenceService.instance.setAppResumed(false);
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
    _currentSession = ref.read(authRepositoryProvider).currentSession;
    final ticket = ++_resolveVersion;
    final session = _currentSession;
    var tutorialDone = false;
    try {
      tutorialDone = await isTutorialDone()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (e, st) {
      debugPrint('DVCR: isTutorialDone error: $e\n$st');
    }
    final next = session == null
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
            _currentSession = ref.read(authRepositoryProvider).currentSession;
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

enum _MainNavSemantic { home, live, matches, articles, chat, prono }

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


