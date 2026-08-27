import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../models/best_scorer_challenge_config.dart';
import '../../../../screens/login_screen.dart';
import '../../../../screens/prono/prono_screen.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/best_scorer_challenge_service.dart';
import '../../../../services/prono_social_service.dart';
import '../../../../services/user_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../data/firestore_prono_repository.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../home/best_scorer_challenge_welcome.dart';
import '../home/prono_home_page.dart';
import '../matches/prono_matches_feed_page.dart';
import '../progress/prono_progress_page.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';
import '../widgets/prono_ui.dart';

/// Racine onglet Pronos — remplace l’ancienne arène + hub monolithique.
class PronoRootShell extends StatefulWidget {
  const PronoRootShell({super.key});

  static void Function(int index)? _selectTabHandler;
  static int? _pendingTab;

  /// 0 accueil · 1 prochains matchs · 2 palmarès — deep link FCM.
  static void selectTab(int index) {
    if (_selectTabHandler != null) {
      _selectTabHandler!(index);
    } else {
      _pendingTab = index;
    }
  }

  static GlobalKey<NavigatorState>? _activeNestedNav;

  /// Retour système Android : dépile une page Pronos (ligue, duel…) si ouverte.
  static bool maybePopNested() {
    final nav = _activeNestedNav?.currentState;
    if (nav == null || !nav.canPop()) return false;
    nav.pop();
    return true;
  }

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
  StreamSubscription<PronoBannersSettings>? _bannerWarmSub;
  StreamSubscription<List<PronoMatchListItem>>? _logoWarmSub;

  @override
  void initState() {
    super.initState();
    PronoRootShell._activeNestedNav = _pronoNestedNavKey;
    PronoRootShell._selectTabHandler = _selectTab;
    final pending = PronoRootShell._pendingTab;
    if (pending != null) {
      PronoRootShell._pendingTab = null;
      _selectTab(pending);
    }
    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) _loadUser();
    });
    _loadUser();
    _bannerWarmSub = AppSettingsService.pronoBannersStream().listen((banners) {
      for (final slot in PronoBannerSlot.values) {
        final raw = banners.urlForSlot(slot).trim();
        if (raw.isEmpty) continue;
        unawaited(
          DvcrNetworkImage.warm(
            cacheBustedImageUrl(raw, banners.revisionMillis),
          ),
        );
      }
    });
    _logoWarmSub = _repo.watchUpcomingMatches().listen((rows) {
      for (final m in rows) {
        unawaited(DvcrNetworkImage.warm(m.logo1 ?? ''));
        unawaited(DvcrNetworkImage.warm(m.logo2 ?? ''));
      }
    });
  }

  @override
  void dispose() {
    if (identical(PronoRootShell._activeNestedNav, _pronoNestedNavKey)) {
      PronoRootShell._activeNestedNav = null;
    }
    if (PronoRootShell._selectTabHandler == _selectTab) {
      PronoRootShell._selectTabHandler = null;
    }
    _bannerWarmSub?.cancel();
    _logoWarmSub?.cancel();
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
      return const _PronoShellCanvas(child: _PronoShellLoading());
    }

    if (user == null) {
      return _PronoShellCanvas(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ACCÈS PRONOS', style: PronoType.kicker),
                  const SizedBox(height: 14),
                  Text(
                    'Connecte-toi pour accéder aux pronos',
                    style: PronoType.headline,
                  ),
                  const SizedBox(height: 16),
                  PronoArenaTheme.goldRule(width: 44),
                  const SizedBox(height: 16),
                  Text(
                    'Suis tes scores, tes duels et ton classement.',
                    style: PronoType.caption,
                  ),
                  const SizedBox(height: 26),
                  PronoInkCta(
                    label: 'Se connecter',
                    icon: Icons.login_rounded,
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    // Portail défi : tant que pas picked|ignored, aucun contenu Prono.
    return StreamBuilder<BestScorerChallengeConfig>(
      stream: BestScorerChallengeService.watchConfig(),
      builder: (context, cfgSnap) {
        // permission-denied / stream cassé : ne pas bloquer tout l’onglet.
        if (cfgSnap.hasError) {
          return _buildPronoShell(uid: uid);
        }
        if (!cfgSnap.hasData &&
            cfgSnap.connectionState == ConnectionState.waiting) {
          return const _PronoShellCanvas(child: _PronoShellLoading());
        }
        final config = cfgSnap.data ?? BestScorerChallengeConfig.defaults;
        return StreamBuilder<BestScorerPick?>(
          stream: BestScorerChallengeService.watchPick(uid),
          builder: (context, pickSnap) {
            if (pickSnap.hasError) {
              return _buildPronoShell(uid: uid);
            }
            if (config.isGateActive &&
                !pickSnap.hasData &&
                pickSnap.connectionState == ConnectionState.waiting) {
              return const _PronoShellCanvas(child: _PronoShellLoading());
            }
            final gated = BestScorerChallengeService.mustGateAccess(
              config: config,
              pick: pickSnap.data,
            );
            if (gated) {
              return BestScorerChallengeGatePage(uid: uid, config: config);
            }
            return _buildPronoShell(uid: uid);
          },
        );
      },
    );
  }

  Widget _buildPronoShell({required String uid}) {
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
                          return IndexedStack(
                            index: tabIndex.clamp(0, 2),
                            sizing: StackFit.expand,
                            children: [
                              PronoHomePage(
                                key: const ValueKey('prono-tab-home'),
                                uid: uid,
                                displayName: _displayName,
                                repo: _repo,
                                onOpenMatches: () => _selectTab(1),
                              ),
                              PronoMatchesFeedPage(
                                key: const ValueKey('prono-tab-matches'),
                                uid: uid,
                                repo: _repo,
                              ),
                              PronoProgressPage(
                                key: const ValueKey('prono-tab-progress'),
                                uid: uid,
                                repo: _repo,
                                onOpenMatches: () => _selectTab(1),
                                onOpenSocial: () => _selectTab(0),
                                onOpenGlobalRanking: openGlobalRanking,
                              ),
                            ],
                          );
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

/// Canvas ivoire des états hors contenu (chargement, portail, déconnecté).
class _PronoShellCanvas extends StatelessWidget {
  final Widget child;

  const _PronoShellCanvas({required this.child});

  @override
  Widget build(BuildContext context) {
    return PronoThemeScope(
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: child,
        ),
      ),
    );
  }
}

/// Attente calme — un filet qui tourne, pas un spinner de framework.
class _PronoShellLoading extends StatelessWidget {
  const _PronoShellLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: PronoArenaTheme.textSoft,
          strokeWidth: 2,
        ),
      ),
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
    // Rail de tableau d’affichage : papier, filet haut, onglet actif marqué
    // par une barre d’accent posée sur l’arête supérieure.
    return Material(
      elevation: 0,
      color: PronoArenaTheme.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PronoArenaTheme.surface,
          border: Border(
            top: BorderSide(color: PronoArenaTheme.hairline),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: PronoArenaTheme.animFast,
            curve: PronoArenaTheme.animCurve,
            height: 3,
            color: sel ? accent.color : Colors.transparent,
          ),
          Expanded(
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1,
              duration: PronoArenaTheme.animFast,
              curve: PronoArenaTheme.animCurve,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 21,
                    color: sel ? accent.color : PronoArenaTheme.textSoft,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PronoType.kicker.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.3,
                      color: sel
                          ? PronoArenaTheme.text
                          : PronoArenaTheme.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
