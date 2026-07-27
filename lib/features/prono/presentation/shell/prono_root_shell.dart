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
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';

/// Racine onglet Pronos — remplace l’ancienne arène + hub monolithique.
class PronoRootShell extends StatefulWidget {
  const PronoRootShell({super.key});

  @override
  State<PronoRootShell> createState() => _PronoRootShellState();
}

class _PronoRootShellState extends State<PronoRootShell> {
  final ValueNotifier<int> _index = ValueNotifier<int>(0);
  String _displayName = 'Membre';
  bool _loading = true;
  final _repo = FirestorePronoRepository();
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

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
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
    try {
      await PronoSocialService.ensureSearchablePronoProfile(
        uid: u.uid,
        displayName: resolved,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _displayName = resolved;
      _loading = false;
    });
  }

  void _selectTab(int i) {
    if (_index.value == i) {
      _pronoNestedNavKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _index.value = i;
    _pronoNestedNavKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_loading) {
      return PronoThemeScope(
        child: DecoratedBox(
          decoration: PronoTokens.scaffoldDecoration(),
          child: const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(
                color: PronoTokens.textMuted,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (user == null) {
      return PronoThemeScope(
        child: DecoratedBox(
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
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: PronoTokens.textMuted,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Connecte-toi pour accéder aux pronos',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: PronoTokens.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Suis tes scores, tes duels et ton classement.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: PronoTokens.textMuted,
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
                        style: PronoTheme.primaryCtaStyle(),
                        child: Text(
                          'Se connecter',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
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
        ),
      );
    }

    final uid = user.uid;

    void openGlobalRanking() {
      _pronoNestedNavKey.currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PronoThemeScope(
            pageAccent: PronoPageAccent.social,
            child: DecoratedBox(
              decoration: PronoTokens.scaffoldDecoration(),
              child: PronoLeaderboardPage(currentUid: uid),
            ),
          ),
        ),
      );
    }

    // Main shell uses extendBody:true + floating pill. Flutter's Scaffold
    // _BodyBuilder already injects the full main-nav height into
    // MediaQuery.padding.bottom — use that alone (no extra constant).
    // Read from this context: the nested Scaffold strips bottom padding on
    // its bottomNavigationBar slot.
    final mainNavClearance = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<int>(
      valueListenable: _index,
      builder: (context, index, _) {
        final pageAccent = PronoPageAccent.forTabIndex(index);
        return PronoThemeScope(
          pageAccent: pageAccent,
          child: DecoratedBox(
            decoration: PronoTokens.scaffoldDecoration(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Navigator(
                key: _pronoNestedNavKey,
                onGenerateRoute: (RouteSettings settings) {
                  if (settings.name == '/' ||
                      settings.name == Navigator.defaultRouteName) {
                    return MaterialPageRoute<void>(
                      settings: settings,
                      builder: (context) => ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (context, tabIndex, _) {
                          switch (tabIndex) {
                            case 1:
                              return PronoMatchesFeedPage(
                                uid: uid,
                                repo: _repo,
                              );
                            case 2:
                              return PronoProgressPage(
                                uid: uid,
                                repo: _repo,
                                onOpenMatches: () => _selectTab(1),
                                // Social / multijoueur vit désormais sur Accueil.
                                onOpenSocial: () => _selectTab(0),
                                onOpenGlobalRanking: openGlobalRanking,
                              );
                            case 0:
                            default:
                              return PronoHomePage(
                                uid: uid,
                                displayName: _displayName,
                                repo: _repo,
                                onOpenMatches: () => _selectTab(1),
                              );
                          }
                        },
                      ),
                    );
                  }
                  return null;
                },
              ),
              bottomNavigationBar: Padding(
                padding: EdgeInsets.only(bottom: mainNavClearance),
                child: _PronoInnerTabBar(
                  index: index,
                  onChanged: _selectTab,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InnerTabSpec {
  final IconData icon;
  final IconData iconSel;
  final String label;
  final PronoPageAccent accent;

  const _InnerTabSpec(this.icon, this.iconSel, this.label, this.accent);
}

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
      PronoPageAccent.accueil,
    ),
    _InnerTabSpec(
      Icons.sports_soccer_outlined,
      Icons.sports_soccer_rounded,
      'Matchs',
      PronoPageAccent.matchs,
    ),
    _InnerTabSpec(
      Icons.insights_outlined,
      Icons.insights_rounded,
      'Progression',
      PronoPageAccent.progression,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: PronoTokens.surfaceMuted,
      child: Container(
        decoration: BoxDecoration(
          color: PronoTokens.surfaceMuted,
          border: Border(
            top: BorderSide(color: PronoTokens.border),
          ),
        ),
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_items.length, (i) {
              final it = _items[i];
              final sel = index == i;
              return Expanded(
                child: _PronoTabItem(
                  selected: sel,
                  pageAccent: it.accent,
                  icon: sel ? it.iconSel : it.icon,
                  label: it.label,
                  onTap: () => onChanged(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PronoTabItem extends StatefulWidget {
  final bool selected;
  final PronoPageAccent pageAccent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PronoTabItem({
    required this.selected,
    required this.pageAccent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PronoTabItem> createState() => _PronoTabItemState();
}

class _PronoTabItemState extends State<_PronoTabItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final accent = widget.pageAccent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: PronoTokens.animFast,
        curve: PronoTokens.animCurve,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 22,
              color: sel ? accent.color : PronoTokens.textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                height: 1.1,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                color: sel ? PronoTokens.text : PronoTokens.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: PronoTokens.animNormal,
              curve: PronoTokens.animCurve,
              width: sel ? 4 : 0,
              height: 4,
              decoration: sel
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.color,
                    )
                  : const BoxDecoration(),
            ),
          ],
        ),
      ),
    );
  }
}
