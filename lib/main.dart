import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'theme/dvcr_theme.dart';
import 'services/app_cache_service.dart';
import 'services/podcast_controller.dart';
import 'services/match_controller.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/world_cup_tab.dart';
import 'screens/admin_web_screen.dart';
import 'screens/register_screen.dart';
import 'screens/tutorial_screen.dart';
import 'app/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/network_banner.dart';
import 'services/notification_service.dart';
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D0D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
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
      pushScreenForNotificationData(Map<String, dynamic>.from(message.data));
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      pushScreenForNotificationData(
        Map<String, dynamic>.from(initialMessage.data),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled =
        prefs.getBool('notif_live') ??
        prefs.getBool('profile_notif_live') ??
        true;
    final alertsEnabled =
        prefs.getBool('notif_alerts') ??
        prefs.getBool('profile_notif_alerts') ??
        true;
    final actusEnabled =
        prefs.getBool('notif_actus') ??
        prefs.getBool('profile_notif_actus') ??
        true;
    final liveEventsEnabled =
        prefs.getBool('notif_live_events') ??
        prefs.getBool('profile_notif_live_events') ??
        true;
    final matchRemindEnabled =
        prefs.getBool('notif_match_remind') ??
        prefs.getBool('profile_notif_match_remind') ??
        true;
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
      theme: DVCRTheme.theme,
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
    final ticket = ++_resolveVersion;
    final user = _currentUser;
    final next = user == null
        ? _Phase.register
        : (await isTutorialDone() ? _Phase.app : _Phase.tutorial);
    if (!mounted || ticket != _resolveVersion) {
      return;
    }
    if (_phase != next) {
      setState(() => _phase = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const _SplashScreen();

      case _Phase.register:
        // Écoute l'auth — dès que l'user se connecte/inscrit, passe à l'onboarding
        return const RegisterScreen();
              // Connecté → vérifie les étapes suivantes

      case _Phase.tutorial:
        return TutorialScreen(
          onDone: () {
            if (mounted) setState(() => _phase = _Phase.app);
          },
        );

      case _Phase.app:
        return const MainNavigation();
    }
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  late final List<Widget> _screens = [
    HomeScreen(onSwitchTab: (i) => setState(() => _index = i)),
    const LiveScreen(),
    const MatchesScreen(),
    const ArticlesScreen(),
    const ChatScreen(),
    const WorldCupTab(),
  ];

  static const _tabs = [
    _Tab(
      icon: Icons.home_rounded,
      activeIcon: Icons.home_rounded,
      label: 'ACCUEIL',
    ),
    _Tab(
      icon: Icons.live_tv_outlined,
      activeIcon: Icons.live_tv_rounded,
      label: 'DVCR TV',
    ),
    _Tab(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'CALENDRIER',
    ),
    _Tab(
      icon: Icons.article_outlined,
      activeIcon: Icons.article_rounded,
      label: 'ACTUS',
    ),
    _Tab(
      icon: Icons.people_outline,
      activeIcon: Icons.people_rounded,
      label: 'COMMUNAUTÉ',
    ),
    _Tab(
      icon: Icons.public_outlined,
      activeIcon: Icons.public_rounded,
      label: 'CdM 2026',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          const NetworkBanner(),
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
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black, blurRadius: 16, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(children: List.generate(_tabs.length, _buildTab)),
        ),
      ),
    );
  }

  Widget _buildTab(int i) {
    final selected = _index == i;
    const gold = Color(0xFFC8A436);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? gold.withAlpha(22) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? _tabs[i].activeIcon : _tabs[i].icon,
                size: 22,
                color: selected ? gold : Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _tabs[i].label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: 0.4,
                  color: selected ? gold : Colors.white30,
                ),
                maxLines: 1,
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          decoration: const BoxDecoration(
            color: Color(0xFF111100),
            border: Border(
              top: BorderSide(color: _gold, width: 1),
              bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.headphones_rounded, size: 16, color: _gold),
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
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${ctrl.positionLabel} / ${ctrl.durationLabel}',
                          style: const TextStyle(
                            color: Color(0xFF888888),
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
                      color: Color(0xFF9D9D9D),
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
                      color: Color(0xFF9D9D9D),
                    ),
                    splashRadius: 18,
                  ),
                  GestureDetector(
                    onTap: () => ctrl.dismiss(),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF666666),
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
                  inactiveTrackColor: const Color(0xFF3A3A3A),
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
