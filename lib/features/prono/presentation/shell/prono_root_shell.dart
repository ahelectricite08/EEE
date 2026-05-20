import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../screens/login_screen.dart';
import '../../../../screens/prono/prono_screen.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/user_service.dart';
import '../../data/firestore_prono_repository.dart';
import '../home/prono_home_page.dart';
import '../matches/prono_matches_feed_page.dart';
import '../progress/prono_progress_page.dart';
import '../social/prono_social_hub_page.dart';
import '../theme/prono_tokens.dart';

/// Racine onglet Pronos — remplace l’ancienne arène + hub monolithique.
class PronoRootShell extends StatefulWidget {
  const PronoRootShell({super.key});

  @override
  State<PronoRootShell> createState() => _PronoRootShellState();
}

class _PronoRootShellState extends State<PronoRootShell> {
  int _index = 0;
  String _displayName = 'Membre';
  bool _loading = true;
  final _repo = FirestorePronoRepository();
  /// Pile de routes locale à l’onglet Pronos (ligues, duels, classements…).
  /// Sans lui, les `push` depuis le hub social peuvent finir sur un écran vide (IndexedStack / overlay).
  final GlobalKey<NavigatorState> _pronoNestedNavKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) _loadUser();
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = await UserService.getUserDataByUid(u.uid);
    final resolved = PronoSocialService.resolveDisplayName(
      data: data,
      email: u.email,
    );
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
      if ((data?['email'] ?? '').toString().trim().isEmpty &&
          (u.email ?? '').isNotEmpty)
        'email': u.email,
      if ((data?['displayName'] ?? '').toString().trim().isEmpty)
        'displayName': resolved,
      'pronoProfile': {
        'displayName': resolved,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() {
      _displayName = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_loading) {
      return DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(
              color: PronoTokens.accent,
              strokeWidth: 2.2,
            ),
          ),
        ),
      );
    }

    if (user == null) {
      return DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PronoTokens.surface,
                        shape: BoxShape.circle,
                        boxShadow: PronoTokens.cardShadow(context),
                        border: Border.all(color: PronoTokens.accentGold.withAlpha(90)),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 40,
                        color: PronoTokens.accent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Connecte-toi pour accéder aux pronos',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: PronoTokens.text,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Suis tes scores, tes duels et ton classement.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: PronoTokens.textMuted,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: PronoTokens.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Se connecter',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    void openGlobalRanking() {
      _pronoNestedNavKey.currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PronoLeaderboardPage(currentUid: uid),
        ),
      );
    }

    // Un seul écran monté à la fois : évite les crashs de paint du viewport
    // (ScrollView + Clip.none) quand plusieurs CustomScrollView coexistent dans un IndexedStack.
    Widget bodyForIndex() {
      switch (_index) {
        case 1:
          return PronoMatchesFeedPage(uid: uid, repo: _repo);
        case 2:
          return PronoProgressPage(
            uid: uid,
            repo: _repo,
            onOpenMatches: () => setState(() => _index = 1),
            onOpenSocial: () => setState(() => _index = 3),
            onOpenGlobalRanking: openGlobalRanking,
          );
        case 3:
          return PronoSocialHubPage(uid: uid, displayName: _displayName);
        case 0:
        default:
          return PronoHomePage(
            uid: uid,
            displayName: _displayName,
            repo: _repo,
            onOpenMatches: () => setState(() => _index = 1),
            onOpenSeason: () => setState(() => _index = 2),
            onOpenSocial: () => setState(() => _index = 3),
            onOpenGlobalRanking: openGlobalRanking,
          );
      }
    }

    return DecoratedBox(
      decoration: PronoTokens.scaffoldDecoration(),
      child: Navigator(
        key: _pronoNestedNavKey,
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/' || settings.name == Navigator.defaultRouteName) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => Scaffold(
                backgroundColor: Colors.transparent,
                body: bodyForIndex(),
                bottomNavigationBar: _PronoInnerTabBar(
                  index: _index,
                  onChanged: (i) => setState(() => _index = i),
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

class _InnerTabSpec {
  final IconData icon;
  final IconData iconSel;
  final String label;
  final PronoIconAccent tabAccent;

  const _InnerTabSpec(
    this.icon,
    this.iconSel,
    this.label,
    this.tabAccent,
  );
}

/// Barre interne Pronos : pastille verte sur l’onglet actif (comme l’aperçu mobile).
class _PronoInnerTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _PronoInnerTabBar({
    required this.index,
    required this.onChanged,
  });

  static const _items = <_InnerTabSpec>[
    _InnerTabSpec(
      Icons.home_outlined,
      Icons.home_rounded,
      'Accueil',
      PronoIconAccent.primary,
    ),
    _InnerTabSpec(
      Icons.sports_soccer_outlined,
      Icons.sports_soccer_rounded,
      'Matchs',
      PronoIconAccent.matches,
    ),
    _InnerTabSpec(
      Icons.insights_outlined,
      Icons.insights_rounded,
      'Progression',
      PronoIconAccent.progress,
    ),
    _InnerTabSpec(
      Icons.groups_outlined,
      Icons.groups_rounded,
      'Social',
      PronoIconAccent.social,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      shadowColor: const Color(0xFF1A2522).withAlpha(28),
      surfaceTintColor: Colors.transparent,
      color: PronoTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PronoTokens.surface,
                PronoTokens.surfaceMuted.withAlpha(140),
              ],
            ),
            border: Border(
              top: BorderSide(color: PronoTokens.border.withAlpha(160)),
            ),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final it = _items[i];
              final sel = index == i;
              final tabHue =
                  PronoTokens.iconAccentColors(it.tabAccent).$3;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? tabHue : Colors.transparent,
                            border: Border.all(
                              color: sel
                                  ? tabHue.withAlpha(55)
                                  : PronoTokens.border.withAlpha(140),
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: tabHue.withAlpha(95),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            sel ? it.iconSel : it.icon,
                            size: 22,
                            color: sel
                                ? Colors.white
                                : tabHue.withAlpha(175),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          it.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                            color: sel
                                ? tabHue
                                : tabHue.withAlpha(175),
                            letterSpacing: sel ? 0.15 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
