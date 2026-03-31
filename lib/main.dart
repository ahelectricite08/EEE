import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'theme/dvcr_theme.dart';
import 'services/podcast_controller.dart';
import 'services/match_controller.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/replay_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_web_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  debugPrint('DVCR: start init');
  try { await initializeDateFormatting('fr_FR', null); } catch (e) { debugPrint('DVCR: date format error: $e'); }
  debugPrint('DVCR: date ok');
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { debugPrint('DVCR: firebase error: $e'); }
  debugPrint('DVCR: firebase ok');
  try {
    await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 5));
    debugPrint('DVCR: messaging ok');
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled   = prefs.getBool('notif_live')   ?? true;
    final alertsEnabled  = prefs.getBool('notif_alerts') ?? true;
    final actusEnabled   = prefs.getBool('notif_actus')  ?? true;
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
  } catch (e) { debugPrint('DVCR: messaging/prefs error: $e'); }
  await PodcastController.instance.init();
  await MatchController.instance.init();
  debugPrint('DVCR: launching app');
  runApp(const DVCRApp());
}

class DVCRApp extends StatelessWidget {
  const DVCRApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DVCR',
      debugShowCheckedModeBanner: false,
      theme: DVCRTheme.theme,
      home: const MainNavigation(),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/login':    (_) => const LoginScreen(),
        '/calendar': (_) => const CalendarScreen(),
        '/admin':    (_) => const AdminWebScreen(),
      },
    );
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
  ];

  static const _tabs = [
    _Tab(icon: Icons.home_rounded,         activeIcon: Icons.home_rounded,        label: 'ACCUEIL'),
    _Tab(icon: Icons.live_tv_outlined,     activeIcon: Icons.live_tv_rounded,     label: 'DVCR TV'),
    _Tab(icon: Icons.emoji_events_outlined,activeIcon: Icons.emoji_events_rounded,label: 'RÉSULTATS'),
    _Tab(icon: Icons.article_outlined,     activeIcon: Icons.article_rounded,     label: 'ACTUS'),
    _Tab(icon: Icons.people_outline,       activeIcon: Icons.people_rounded,      label: 'COMMUNAUTÉ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PodcastMiniPlayer(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black, blurRadius: 16, offset: Offset(0, -2))],
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
  const _Tab({required this.icon, required this.activeIcon, required this.label});
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
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
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ep.duration,
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ctrl.isPlaying ? ctrl.pause() : ctrl.resume(),
                child: Icon(
                  ctrl.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 36,
                  color: _gold,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ctrl.dismiss(),
                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF666666)),
              ),
            ],
          ),
        );
      },
    );
  }
}
