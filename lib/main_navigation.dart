part of 'main.dart';

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

