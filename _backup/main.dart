import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

import 'theme/dvcr_theme.dart';
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
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await initializeDateFormatting('fr_FR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  final prefs = await SharedPreferences.getInstance();
  final notifEnabled = prefs.getBool('notif_live') ?? true;
  if (notifEnabled) {
    await FirebaseMessaging.instance.subscribeToTopic('dvcr_live');
  } else {
    await FirebaseMessaging.instance.unsubscribeFromTopic('dvcr_live');
  }
  // Abonnement aux notifs articles (toujours actif)
  await FirebaseMessaging.instance.subscribeToTopic('dvcr_articles');
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

  List<Widget> get _screens => [
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
      body: _screens[_index],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF1C1C1C), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(_tabs.length, _buildTab),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int i) {
    final selected = _index == i;
    const red = Color(0xFFBA203C);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? _tabs[i].activeIcon : _tabs[i].icon,
              size: 22,
              color: selected ? red : const Color(0xFF666666),
            ),
            const SizedBox(height: 3),
            Text(
              _tabs[i].label,
              style: GoogleFonts.barlow(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
                color: selected ? red : const Color(0xFF555555),
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
