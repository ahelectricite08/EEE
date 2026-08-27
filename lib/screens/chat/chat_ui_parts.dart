part of 'chat_screen.dart';

class _ChatAccessLockedScreen extends StatelessWidget {
  const _ChatAccessLockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSheet,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: ChatDesign.paper,
              borderRadius: BorderRadius.circular(ChatDesign.radiusMd),
              border: Border.all(color: ChatDesign.hairline),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: ChatDesign.fillet,
                  child: ColoredBox(color: ChatDesign.gold),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ACCÈS CHAT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: ChatDesign.goldDeep,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Désactivé pour ton rôle',
                        textAlign: TextAlign.center,
                        style: ChatDesign.title,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le salon n’est pas ouvert pour ton rôle. Un admin peut le débloquer depuis Rôles et permissions.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _kMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: Text(
                          'Retour',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ChatDesign.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Masthead : photo + nameplate + filet + onglets = UN bloc ──────────────────
/// Page club : bandeau photo court, titre dans la photo, filet vert, tablette
/// ivoire collée. Pas trois widgets empilés avec un jour entre eux.
class _ChatMasthead extends StatelessWidget {
  final UserRole? role;
  final Set<UserRole> roles;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  final double topPad;
  final bool compact;
  final String currentSalonId;
  final bool canCreateSalon;
  final void Function(String id, String name) onSwitchSalon;
  final VoidCallback onAddSalon;

  const _ChatMasthead({
    this.role,
    this.roles = const {},
    this.roleBadges = const {},
    this.roleBadgeLabels = const {},
    this.topPad = 0,
    this.compact = false,
    required this.currentSalonId,
    required this.canCreateSalon,
    required this.onSwitchSalon,
    required this.onAddSalon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatHeroBand(
          role: role,
          roles: roles,
          roleBadges: roleBadges,
          roleBadgeLabels: roleBadgeLabels,
          topPad: topPad,
          compact: compact,
        ),
        const ColoredBox(
          color: ChatDesign.accent,
          child: SizedBox(height: ChatDesign.stripe, width: double.infinity),
        ),
        if (!compact)
          ColoredBox(
            color: ChatDesign.chrome,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SalonTabs(
                  currentId: currentSalonId,
                  canCreateSalon: canCreateSalon,
                  onSwitch: onSwitchSalon,
                  onAdd: onAddSalon,
                ),
                const ColoredBox(
                  color: ChatDesign.hairline,
                  child: SizedBox(height: 1, width: double.infinity),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bandeau photo. Nameplate ancré en bas, dans l’image. Pas de fade vert.
class _ChatHeroBand extends StatelessWidget {
  final UserRole? role;
  final Set<UserRole> roles;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  final double topPad;
  final bool compact;

  const _ChatHeroBand({
    this.role,
    this.roles = const {},
    this.roleBadges = const {},
    this.roleBadgeLabels = const {},
    this.topPad = 0,
    this.compact = false,
  });

  static double _photoHeight(double screenH, {required bool compact}) {
    if (compact) return screenH < 400 ? 56 : 64;
    if (screenH < 560) return 108;
    return 128;
  }

  @override
  Widget build(BuildContext context) {
    final UserRole? headerBadgeRole = roles.isEmpty && role != null
        ? _chatHeaderPrimaryBadgeRole(role!, roles)
        : null;
    final photoH = _photoHeight(
      MediaQuery.sizeOf(context).height,
      compact: compact,
    );

    final Widget badge;
    if (roles.isNotEmpty) {
      badge = _RoleBadges(
        roles: _chatHeaderBadgeRoles(roles),
        small: true,
        maxBadges: 1,
        roleBadges: roleBadges,
        roleBadgeLabels: roleBadgeLabels,
      );
    } else if (headerBadgeRole != null) {
      badge = _RoleBadge(
        role: headerBadgeRole,
        small: true,
        imageUrl: roleBadges[roleBadgeConfigKey(headerBadgeRole)]?.trim(),
      );
    } else {
      badge = const SizedBox.shrink();
    }

    return SizedBox(
      height: topPad + photoH,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: ChatDesign.heroUnder),
          const _ChatCommunityPhoto(
            alignment: Alignment(0, -0.22),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x4A000000),
                  Color(0x14000000),
                  Color(0xB3000000),
                ],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kChatMaxContentWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ChatDesign.gutter,
                    10,
                    ChatDesign.gutter,
                    12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: ChatDesign.fillet,
                        height: compact ? 28 : 36,
                        color: ChatDesign.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!compact)
                              Text(
                                'COMMUNAUTÉ',
                                style: ChatDesign.kickerOnPhoto,
                              ),
                            if (!compact) const SizedBox(height: 5),
                            Text(
                              'La commu DVCR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ChatDesign.heroTitle.copyWith(
                                fontSize: compact ? 20 : 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      badge,
                    ],
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

// ── Salon tabs ────────────────────────────────────────────────────────────────
class _SalonTabs extends StatelessWidget {
  final String currentId;

  /// Création d’un salon : réservé aux admins (pas aux CM).
  final bool canCreateSalon;
  final void Function(String id, String name) onSwitch;
  final VoidCallback onAdd;
  const _SalonTabs({
    required this.currentId,
    required this.canCreateSalon,
    required this.onSwitch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .orderBy('order')
          .snapshots(),
      builder: (_, snap) {
        final allDocs = snap.data?.docs ?? [];
        final now = DateTime.now();

        // Salons visibles : non archivés, et si live terminé, chatClosesAt pas encore passé.
        bool isVisible(QueryDocumentSnapshot d) {
          final data = d.data() as Map<String, dynamic>;
          if (data['archived'] == true) return false;
          final closesAt = (data['chatClosesAt'] as Timestamp?)?.toDate();
          if (closesAt != null && now.isAfter(closesAt)) return false;
          // Rétrocompat : anciens salons sans chatClosesAt mais avec liveEndedAt
          if (closesAt == null) {
            final endedAt = (data['liveEndedAt'] as Timestamp?)?.toDate();
            if (endedAt != null &&
                now.difference(endedAt) > const Duration(hours: 1)) {
              return false;
            }
          }
          return true;
        }

        final liveDocs = allDocs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['isLive'] == true &&
                isVisible(d))
            .toList();
        final isLiveMode = liveDocs.isNotEmpty;
        final docs = isLiveMode ? liveDocs : allDocs.where(isVisible).toList();

        // Auto-switch to live salon when live mode activates
        if (isLiveMode && liveDocs.isNotEmpty) {
          final liveId = liveDocs.first.id;
          if (currentId != liveId) {
            final liveName = (liveDocs.first.data()
                    as Map<String, dynamic>)['name'] as String? ??
                'Live';
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onSwitch(liveId, liveName));
          }
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _kChatMaxContentWidth,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                ChatDesign.gutter,
                8,
                ChatDesign.gutter,
                8,
              ),
              child: Row(
                children: [
                if (isLiveMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ChatDesign.paper,
                          borderRadius:
                              BorderRadius.circular(ChatDesign.radius),
                          border: Border.all(color: ChatDesign.red.withAlpha(70)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: _kRed, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text('LIVE',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _kRed,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (docs.isEmpty && !isLiveMode)
                  _SalonTab(
                    id: 'general',
                    name: 'général',
                    isSelected: currentId == 'general',
                    onTap: () => onSwitch('general', 'Général'),
                  ),
                ...docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? d.id;
                  return _SalonTab(
                    id: d.id,
                    name: name,
                    isSelected: currentId == d.id,
                    onTap: () => onSwitch(d.id, name),
                  );
                }),
                if (canCreateSalon && !isLiveMode)
                  Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(ChatDesign.radius),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            color: ChatDesign.paper,
                            borderRadius:
                                BorderRadius.circular(ChatDesign.radius),
                            border: Border.all(color: ChatDesign.hairline),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 17,
                            color: ChatDesign.green,
                          ),
                        ),
                      ),
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

class _SalonTab extends StatelessWidget {
  final String id;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  const _SalonTab({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ChatDesign.radius),
          splashColor: _kGold.withValues(alpha: 0.18),
          highlightColor: _kGreen.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(2, 8, 10, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ChatDesign.tab.copyWith(
                      color: isSelected ? ChatDesign.green : _kMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: ChatDesign.fillet,
                  width: isSelected ? 28 : 0,
                  color: isSelected ? ChatDesign.green : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pinned message bar ────────────────────────────────────────────────────────
/// Message épinglé. Une ligne par défaut, dépliable d'une pression : un
/// épinglé important dépasse souvent la ligne, et le tronquer sans recours
/// revenait à le cacher.
class _PinnedBar extends StatefulWidget {
  final String salonId;
  final bool canUnpin;
  final VoidCallback onUnpin;
  const _PinnedBar({
    required this.salonId,
    required this.canUnpin,
    required this.onUnpin,
  });

  @override
  State<_PinnedBar> createState() => _PinnedBarState();
}

class _PinnedBarState extends State<_PinnedBar> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _PinnedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId && _expanded) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .doc(widget.salonId)
          .snapshots(),
      builder: (_, snap) {
        final pinned = (snap.data?.data() as Map<String, dynamic>?)?['pinned']
            as Map<String, dynamic>?;
        if (pinned == null) return const SizedBox.shrink();
        final text = pinned['text'] as String? ?? '';
        final firstName = pinned['firstName'] as String? ?? '';
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _kChatMaxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(ChatDesign.radius),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ChatDesign.plateGold,
                        borderRadius:
                            BorderRadius.circular(ChatDesign.radius),
                        border: Border.all(color: ChatDesign.hairline),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(ChatDesign.radius),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: ChatDesign.fillet,
                              child: ColoredBox(color: ChatDesign.gold),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.push_pin_rounded,
                                      size: 13,
                                      color: ChatDesign.goldDeep,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ÉPINGLÉ · ${firstName.toUpperCase()}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: ChatDesign.goldDeep,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          text,
                                          maxLines: _expanded ? 8 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                            color: _kText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.canUnpin)
                                    GestureDetector(
                                      onTap: widget.onUnpin,
                                      behavior: HitTestBehavior.opaque,
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(10, 2, 2, 2),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                          color: _kMuted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Apparition d'un message qui vient d'arriver, le mien comme celui d'un autre.
///
/// Les identifiants déjà joués sont mémorisés au niveau de la classe : sans ça,
/// remonter puis redescendre le fil rejouerait l'animation à chaque recyclage
/// de tuile, ce qui donne un fil qui tremble au défilement.
class _MessageEntrance extends StatefulWidget {
  final String docId;
  final Widget child;
  const _MessageEntrance({required this.docId, required this.child});

  /// docId → instant du premier rendu, ou 0 si le message était déjà là.
  static final Map<String, int> _seenAt = <String, int>{};
  static const int _windowMs = 520;

  /// Vrai à la première apparition d'un message frais, puis le temps que
  /// l'animation se termine — un rebuild du flux ne doit pas la couper net.
  static bool shouldPlay(String docId, bool isFresh) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final seen = _seenAt[docId];
    if (seen != null) return seen > 0 && now - seen < _windowMs;
    _seenAt[docId] = isFresh ? now : 0;
    if (_seenAt.length > 400) _seenAt.remove(_seenAt.keys.first);
    return isFresh;
  }

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

/// Pastille « revenir au dernier message », visible dès qu'on remonte le fil.
class _JumpToLatestButton extends StatelessWidget {
  final ValueNotifier<bool> hidden;
  final VoidCallback onTap;
  const _JumpToLatestButton({required this.hidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hidden,
      builder: (context, atBottom, _) {
        return IgnorePointer(
          ignoring: atBottom,
          child: AnimatedSlide(
            offset: atBottom ? const Offset(0, 0.9) : Offset.zero,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: atBottom ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(ChatDesign.radius),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                      decoration: BoxDecoration(
                        color: ChatDesign.paper,
                        borderRadius:
                            BorderRadius.circular(ChatDesign.radius),
                        border: Border.all(color: ChatDesign.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            size: 16,
                            color: ChatDesign.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Derniers messages',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ChatDesign.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Photo tribune (masthead uniquement) ───────────────────────────────────────
/// Photo Communauté du bandeau. Le fil est sur papier, pas sur la photo.
class _ChatCommunityPhoto extends StatelessWidget {
  final Alignment alignment;
  const _ChatCommunityPhoto({
    this.alignment = const Alignment(0, -0.35),
  });

  @override
  Widget build(BuildContext context) {
    final cacheW = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1440);
    return HubHeroPhoto(
      slot: HubHeroSlot.community,
      fallbackNetworkUrl: _kChatHeroBg,
      alignment: alignment,
      cacheWidth: cacheW,
      filterQuality: FilterQuality.medium,
      fallback: const ColoredBox(color: ChatDesign.heroUnder),
    );
  }
}

// ── Séparateur de jour ────────────────────────────────────────────────────────
class _ChatDateSeparator extends StatelessWidget {
  final String label;
  const _ChatDateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Expanded(child: _DaySeparatorRule(fadeLeft: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ChatDesign.muted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: _DaySeparatorRule(fadeLeft: false)),
        ],
      ),
    );
  }
}

class _DaySeparatorRule extends StatelessWidget {
  final bool fadeLeft;
  const _DaySeparatorRule({required this.fadeLeft});

  @override
  Widget build(BuildContext context) {
    final colors = [ChatDesign.hairline.withAlpha(0), ChatDesign.hairline];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeLeft ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

// ── État du fil (vide, hors ligne, erreur) ───────────────────────────────────
/// Une seule carte pour tous les moments où le fil n'a rien à montrer. Le salon
/// vide et la panne réseau partagent la composition : seuls le glyphe et le
/// texte changent, pour qu'aucun de ces écrans n'ait l'air d'un oubli.
class _ChatFeedState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ChatFeedState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              color: ChatDesign.plateOther,
              borderRadius: BorderRadius.circular(ChatDesign.radiusMd),
              border: Border.all(color: ChatDesign.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: ChatDesign.gold,
                ),
                const SizedBox(height: 14),
                Icon(icon, size: 36, color: ChatDesign.green),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────
class _MessageList extends StatefulWidget {
  final ScrollController scroll;
  final String salonId;
  final String currentUid;
  final String currentUserHandle;
  final UserRole? role;
  final Set<UserRole> currentUserRoles;
  final Map<String, dynamic> emojiConfig;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  final void Function(String) onDelete;
  final void Function(String, String, String, String) onReport;
  final void Function(Map<String, dynamic>) onReply;
  final void Function(String, String, String) onPin;
  final void Function(String, String) onBan;
  final void Function(String, String) onWarn;
  final void Function(String, String) onReact;

  const _MessageList({
    required this.scroll,
    required this.salonId,
    required this.currentUid,
    required this.currentUserHandle,
    required this.role,
    required this.currentUserRoles,
    required this.emojiConfig,
    required this.roleBadges,
    this.roleBadgeLabels = const {},
    required this.onDelete,
    required this.onReport,
    required this.onReply,
    required this.onPin,
    required this.onBan,
    required this.onWarn,
    required this.onReact,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  List<QueryDocumentSnapshot>? _cachedDocs;
  String? _docsSignature;

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId) {
      _cachedDocs = null;
      _docsSignature = null;
    }
  }

  static String _messagesSignature(List<QueryDocumentSnapshot> docs) {
    final b = StringBuffer();
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      b
        ..write(d.id)
        ..write('|')
        ..write(m['text'])
        ..write('|')
        ..write(m['reactions'])
        ..write('|')
        ..write(m['firstName']);
    }
    return b.toString();
  }

  static bool _isFresh(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is! Timestamp) return false;
    return DateTime.now().difference(ts.toDate()).inSeconds <= 8;
  }

  /// Le message m'interpelle : soit l'UID est explicitement listé, soit mon
  /// pseudo apparaît dans les mentions textuelles.
  bool _mentionsMe(Map<String, dynamic> data) {
    final uids = data['mentionUids'];
    if (uids is List && uids.contains(widget.currentUid)) return true;
    final handles = data['mentions'];
    if (handles is List && widget.currentUserHandle.isNotEmpty) {
      final me = widget.currentUserHandle.toLowerCase();
      return handles.any((h) => h.toString().toLowerCase() == me);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .doc(widget.salonId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const _ChatFeedState(
            icon: Icons.wifi_off_rounded,
            title: 'Salon injoignable',
            body:
                'La liaison avec le salon est coupée. Les messages reviennent '
                'tout seuls dès que le réseau repart.',
          );
        }
        if (!snap.hasData) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
            );
          }
          return const _ChatFeedState(
            icon: Icons.cloud_off_rounded,
            title: 'Salon indisponible',
            body: 'Impossible de charger les messages pour le moment. '
                'Réessaie dans un instant.',
          );
        }

        final filtered = snap.data!.docs
            .where((d) => (d.data() as Map)['isDeleted'] != true)
            .toList();
        final sig = _messagesSignature(filtered);
        if (sig != _docsSignature) {
          _docsSignature = sig;
          _cachedDocs = filtered;
        }
        final docs = _cachedDocs ?? filtered;

        if (docs.isEmpty) {
          return const _ChatFeedState(
            icon: Icons.edit_note_rounded,
            title: 'À toi de jouer',
            body: 'Le vestiaire est ouvert. Un bonjour, un prono, un souvenir — '
                'écris la première ligne.',
          );
        }

        return RepaintBoundary(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _kChatMaxContentWidth,
              ),
              child: ListView.builder(
                controller: widget.scroll,
                reverse: true,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                cacheExtent: 480,
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;

                  final showDaySeparator = _chatShowDateSeparator(i, docs);
                  final nextData = i < docs.length - 1
                      ? docs[i + 1].data() as Map<String, dynamic>
                      : null;
                  // Un changement de jour rouvre toujours la signature de l'auteur,
                  // même si le message précédent est du même membre.
                  final isGrouped = !showDaySeparator &&
                      nextData != null &&
                      nextData['uid'] == data['uid'] &&
                      _diffMin(nextData['createdAt'], data['createdAt']) < 5;

                  final msgUid = data['uid'] as String? ?? '';
                  final msgName = data['firstName'] as String? ?? 'Membre';
                  final msgText = data['text'] as String? ?? '';
                  final isMine = msgUid == widget.currentUid;

                  Widget tile = _MessageTile(
                    data: data,
                    docId: doc.id,
                    isMine: isMine,
                    isGrouped: isGrouped,
                    isLastOfGroup: i == 0 ||
                        (docs[i - 1].data() as Map<String, dynamic>)['uid'] !=
                            data['uid'],
                    mentionsMe: !isMine && _mentionsMe(data),
                    role: widget.role,
                    currentUid: widget.currentUid,
                    currentUserRoles: widget.currentUserRoles,
                    emojiConfig: widget.emojiConfig,
                    roleBadges: widget.roleBadges,
                    roleBadgeLabels: widget.roleBadgeLabels,
                    onDelete: () => widget.onDelete(doc.id),
                    onReport: () =>
                        widget.onReport(doc.id, msgText, msgUid, msgName),
                    onReply: () => widget.onReply({
                      'id': doc.id,
                      'text': msgText,
                      'firstName': msgName,
                    }),
                    onPin: () => widget.onPin(doc.id, msgText, msgName),
                    onBan: () => widget.onBan(msgUid, msgName),
                    onWarn: () => widget.onWarn(msgUid, msgName),
                    onReact: (emoji) => widget.onReact(doc.id, emoji),
                  );
                  if (_MessageEntrance.shouldPlay(doc.id, _isFresh(data))) {
                    tile = _MessageEntrance(docId: doc.id, child: tile);
                  }
                  if (showDaySeparator) {
                    final dayTs = data['createdAt'];
                    if (dayTs is Timestamp) {
                      tile = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChatDateSeparator(
                            label: _chatDaySeparatorLabel(dayTs.toDate()),
                          ),
                          tile,
                        ],
                      );
                    }
                  }
                  return KeyedSubtree(
                    key: ValueKey(doc.id),
                    child: tile,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  int _diffMin(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return 999;
    return a.toDate().difference(b.toDate()).inMinutes.abs();
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final String currentUid;
  final String salonId;
  const _TypingIndicator({required this.currentUid, required this.salonId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_typing')
          .where('salonId', isEqualTo: salonId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
        final typers = snap.data!.docs
            .where((d) {
              if (d.id == currentUid) return false;
              final ts = d['typingAt'];
              if (ts is! Timestamp) return false;
              return ts.toDate().isAfter(cutoff);
            })
            .map((d) => d['name'] as String? ?? 'Quelqu\'un')
            .toList();

        if (typers.isEmpty) return const SizedBox.shrink();

        final label = typers.length == 1
            ? '${typers[0]} écrit un message…'
            : '${typers.take(2).join(' et ')} écrivent…';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: const BoxDecoration(
            color: ChatDesign.chrome,
            border: Border(top: BorderSide(color: ChatDesign.hairline)),
          ),
          child: Row(
            children: [
              _DotsAnimation(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _kMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (v - i * 0.2).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(
              0.3,
              1.0,
            );
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: _kGreen.withAlpha((opacity * 255).round()),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Avatar chat avec bordure rôle ─────────────────────────────────────────────
class _ChatAvatar extends StatelessWidget {
  final String initials;
  final Set<UserRole> roles;
  final Map<String, String> roleBadges;
  final double size;
  const _ChatAvatar({
    required this.initials,
    required this.roles,
    required this.roleBadges,
    this.size = 34.0,
  });

  double get _s => size;

  @override
  Widget build(BuildContext context) {
    final publicRoles = _publicChatRoles(roles);
    final badgeUrl = resolvedRoleBadgeImageUrl(publicRoles, roleBadges) ?? '';

    final core = Container(
      width: _s,
      height: _s,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ChatDesign.green,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: _s >= 48 ? 15 : 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );

    return DvcrAvatarRoleFrame(
      roles: publicRoles,
      innerDiameter: _s,
      frameThickness: _s >= 48 ? 5.8 : 4.2,
      badgeImageUrl: badgeUrl.isEmpty ? null : badgeUrl,
      child: core,
    );
  }
}

// ── Petits éléments de plaque ─────────────────────────────────────────────────
/// Message cité. Filet or + texte rapporté, pas une carte empilée.
class _QuotedMessage extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  const _QuotedMessage({required this.replyTo});

  @override
  Widget build(BuildContext context) {
    final resolved = _displayNameFromData(replyTo);
    final name = resolved.isNotEmpty
        ? resolved
        : (replyTo['firstName'] as String? ?? 'Membre');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ChatDesign.gold, width: ChatDesign.fillet),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'En réponse à $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ChatDesign.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                replyTo['text'] as String? ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: _kText.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String token;
  final int count;
  final bool mine;
  final Map<String, Map<String, dynamic>> emojiMap;
  final VoidCallback onTap;
  const _ReactionChip({
    required this.token,
    required this.count,
    required this.mine,
    required this.emojiMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ChatDesign.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: mine ? ChatDesign.plateGold : ChatDesign.plateOther,
            borderRadius: BorderRadius.circular(ChatDesign.radius),
            border: Border.all(
              color: mine ? ChatDesign.gold.withAlpha(170) : ChatDesign.hairline,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmojiInline(
                token: token,
                emojiMap: emojiMap,
                size: 15,
                useCustomSticker: false,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: mine ? _kGoldDeep : _kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReactionChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddReactionChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ChatDesign.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: ChatDesign.plateOther,
            borderRadius: BorderRadius.circular(ChatDesign.radius),
            border: Border.all(color: ChatDesign.hairline),
          ),
          child: const Icon(
            Icons.add_reaction_outlined,
            size: 14,
            color: _kMuted,
          ),
        ),
      ),
    );
  }
}

// ── Message tile ──────────────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isMine;
  final bool isGrouped;
  final bool isLastOfGroup;
  final bool mentionsMe;
  final UserRole? role;
  final String currentUid;
  final Set<UserRole> currentUserRoles;
  final Map<String, dynamic> emojiConfig;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  final VoidCallback onReply;
  final VoidCallback onPin;
  final VoidCallback onBan;
  final VoidCallback onWarn;
  final void Function(String emoji) onReact;

  const _MessageTile({
    required this.data,
    required this.docId,
    required this.isMine,
    required this.isGrouped,
    this.isLastOfGroup = true,
    this.mentionsMe = false,
    required this.role,
    required this.currentUid,
    required this.currentUserRoles,
    required this.emojiConfig,
    required this.roleBadges,
    this.roleBadgeLabels = const {},
    required this.onDelete,
    required this.onReport,
    required this.onReply,
    required this.onPin,
    required this.onBan,
    required this.onWarn,
    required this.onReact,
  });

  bool get _isAdmin =>
      currentUserRoles.contains(UserRole.admin) || role == UserRole.admin;
  bool get _isCM =>
      currentUserRoles.contains(UserRole.communityManager) ||
      role == UserRole.communityManager;
  bool get _isTeamDvcr => currentUserRoles.contains(UserRole.teamDvcr);
  bool get _canMod => _isAdmin || _isCM;

  @override
  Widget build(BuildContext context) {
    final firstName = (data['firstName'] ?? 'Membre') as String;
    final lastName = (data['lastName'] ?? '') as String;
    final isModNotice = data['isModerationNotice'] == true;
    final text = (data['text'] ?? '') as String;
    final ts = data['createdAt'] as Timestamp?;
    final replyTo = data['replyTo'] as Map<String, dynamic>?;
    final reactionsRaw = data['reactions'] as Map<String, dynamic>?;
    // Pour ses propres messages : utiliser les rôles live (mis à jour en temps réel)
    final rawMsgRoles = isMine ? currentUserRoles : _rolesFromMsg(data);
    final msgRoles = _publicChatRoles(rawMsgRoles);
    final msgRole = UserService.primaryRole(msgRoles);
    final rd = _roleData(msgRole);
    final nameColor = isModNotice ? _kGoldDeep : _readableChatNameColor(rd.$4);

    final accent = ChatDesign.plateAccent(
      mine: isMine,
      mention: mentionsMe,
      moderation: isModNotice,
    );
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}'
            .toUpperCase();
    final authorLabel =
        isModNotice ? firstName : (isMine ? 'Toi' : _displayNameFromData(data));
    final emojiMap = _emojiValueMap(emojiConfig);

    final reactions = <String, int>{};
    final myReactions = <String>{};
    if (reactionsRaw != null) {
      final normalized = normalizeReactionsMap(
        Map<String, dynamic>.from(reactionsRaw),
      );
      for (final entry in normalized.entries) {
        final uids = reactionUidsFromFirestore(entry.value);
        if (uids.isEmpty) continue;
        reactions[entry.key] = uids.length;
        if (uids.contains(currentUid)) myReactions.add(entry.key);
      }
    }

    final avatar = isGrouped
        ? const SizedBox(width: 32, height: 32)
        : isModNotice
            ? SizedBox(
                width: 32,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ChatDesign.radius),
                    color: ChatDesign.gold.withAlpha(40),
                    border: Border.all(color: ChatDesign.gold.withAlpha(120)),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ChatDesign.gold,
                    size: 16,
                  ),
                ),
              )
            : GestureDetector(
                onTap: _canMod && !isMine
                    ? () => _showUserProfile(
                          context,
                          data,
                          roleBadges,
                          roleBadgeLabels,
                        )
                    : null,
                child: _ChatAvatar(
                  initials: initials,
                  roles: msgRoles,
                  roleBadges: roleBadges,
                  size: 32,
                ),
              );

    final plate = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      decoration: ChatDesign.plateBox(
        mine: isMine,
        mention: mentionsMe,
        moderation: isModNotice,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMine ? 11 : 12,
              8,
              isMine ? 12 : 11,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isGrouped)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                authorLabel.isNotEmpty
                                    ? authorLabel
                                    : firstName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatDesign.byline.copyWith(
                                  color: isModNotice
                                      ? _kGoldDeep
                                      : (isMine ? _kGreen : nameColor),
                                ),
                              ),
                            ),
                            if (ts != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _fmtTs(ts),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _kMuted.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (msgRoles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _RoleBadges(
                              roles: msgRoles,
                              small: true,
                              roleBadges: roleBadges,
                              roleBadgeLabels: roleBadgeLabels,
                              maxBadges: 2,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (ts != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _chatClockLabel(ts.toDate()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: _kMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                if (replyTo != null)
                  _QuotedMessage(
                    replyTo: Map<String, dynamic>.from(replyTo),
                  ),
                _ChatRichText(
                  text: text,
                  emojiMap: emojiMap,
                  textColor: _kText,
                ),
              ],
            ),
          ),
          Positioned(
            left: isMine ? null : 0,
            right: isMine ? 0 : null,
            top: 0,
            bottom: 0,
            width: ChatDesign.fillet,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );

    final reactionRow = reactions.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment:
                  isMine ? WrapAlignment.end : WrapAlignment.start,
              children: [
                ...reactions.entries.map(
                  (e) => _ReactionChip(
                    token: e.key,
                    count: e.value,
                    mine: myReactions.contains(e.key),
                    emojiMap: emojiMap,
                    onTap: () => onReact(e.key),
                  ),
                ),
                _AddReactionChip(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showActions(context);
                  },
                ),
              ],
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showActions(context);
      },
      onDoubleTap: isModNotice ? null : () => onReact(kChatReactionHeart),
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 36 : 10,
          right: isMine ? 10 : 28,
          top: isGrouped ? 3 : 10,
          bottom: isLastOfGroup ? 6 : 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[
              avatar,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  plate,
                  reactionRow,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final msgName = data['firstName'] as String? ?? 'Membre';
    final isNotice = data['isModerationNotice'] == true;
    final emojiMap = _emojiValueMap(emojiConfig);

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ChatDesign.ivory,
            borderRadius: BorderRadius.circular(ChatDesign.radiusMd),
            border: Border.all(color: ChatDesign.hairline),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 10),
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Rappel du message visé : on agit rarement à l'aveugle.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$msgName · ${(data['text'] ?? '').toString()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.35,
                            color: _kMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Réactions rapides
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ChatDesign.paper,
                        borderRadius: BorderRadius.circular(ChatDesign.radius),
                        border: Border.all(color: ChatDesign.hairline),
                      ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: kChatDefaultQuickReactions.map((e) {
                        final active = _myReactionTokens().contains(
                          normalizeChatReactionEmoji(e),
                        );
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              onReact(e);
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: active
                                    ? _kGold.withAlpha(40)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active
                                      ? _kGold.withAlpha(160)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: _EmojiInline(
                                  token: e,
                                  emojiMap: emojiMap,
                                  size: 24,
                                  useCustomSticker: false,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1, color: _kBorder),
                // Répondre
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: _kGreen),
                  title: Text(
                    'Répondre',
                    style: GoogleFonts.inter(color: _kText, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReply();
                  },
                ),
                if (isMine && !isNotice)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF5350),
                    ),
                    title: Text(
                      'Supprimer mon message',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete();
                    },
                  ),
                if (_canMod && !isMine && !isNotice)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF5350),
                    ),
                    title: Text(
                      'Supprimer le message',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete();
                    },
                  ),
                if ((_isCM || _isTeamDvcr) && !isMine && !isNotice)
                  ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: Color(0xFFFFB74D),
                    ),
                    title: Text(
                      'Signaler à l\'admin',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Comportement suspect — sans supprimer le message',
                      style: GoogleFonts.inter(color: _kMuted, fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onReport();
                    },
                  ),
                if (_isTeamDvcr && !isMine && !isNotice)
                  ListTile(
                    leading: const Icon(
                      Icons.visibility_off_outlined,
                      color: Color(0xFFEF5350),
                    ),
                    title: Text(
                      'Masquer ce message',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete();
                    },
                  ),
                if (_canMod && !isMine && !isNotice) ...[
                  ListTile(
                    leading: const Icon(Icons.push_pin_rounded, color: _kGold),
                    title: Text(
                      'Épingler',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onPin();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB74D),
                    ),
                    title: Text(
                      'Avertir $msgName',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onWarn();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: _kRed),
                    title: Text(
                      'Suspendre $msgName 24h',
                      style: GoogleFonts.inter(color: _kText, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onBan();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserProfile(
    BuildContext context,
    Map<String, dynamic> msgData,
    Map<String, String> badges,
    Map<String, String> labels,
  ) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserProfileSheet(
        msgData: msgData,
        roleBadges: badges,
        roleBadgeLabels: labels,
      ),
    );
  }

  /// Réactions déjà posées par moi, en clés canoniques.
  Set<String> _myReactionTokens() {
    final raw = data['reactions'];
    if (raw is! Map) return const {};
    final normalized = normalizeReactionsMap(Map<String, dynamic>.from(raw));
    return {
      for (final entry in normalized.entries)
        if (reactionUidsFromFirestore(entry.value).contains(currentUid))
          entry.key,
    };
  }

  String _fmtTs(Timestamp ts) => _chatMessageTimeLabel(ts.toDate());
}

// ── Barre ban ─────────────────────────────────────────────────────────────────
class _BannedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ChatDesign.chrome,
        border: Border(top: BorderSide(color: ChatDesign.hairline)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: _kRed, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Suite à votre message vous avez été restreint au chat pendant 24h',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _kText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _EmojiInline extends StatelessWidget {
  final String token;
  final Map<String, Map<String, dynamic>> emojiMap;
  final double size;

  /// Stickers DVCR (Wix) : barre de saisie uniquement, pas les réactions.
  final bool useCustomSticker;

  const _EmojiInline({
    required this.token,
    required this.emojiMap,
    this.size = 18,
    this.useCustomSticker = true,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = emojiMap[token];
    final imageUrl =
        useCustomSticker ? (emoji?['imageUrl'] ?? '').toString().trim() : '';
    if (imageUrl.isNotEmpty) {
      return ChatStickerImage(
        imageUrl: imageUrl,
        size: size,
        errorFallback: isChatHeartReaction(token)
            ? Icon(
                Icons.favorite_rounded,
                size: size * 1.08,
                color: const Color(0xFFE53935),
              )
            : Text(token, style: TextStyle(fontSize: size, height: 1.1)),
      );
    }
    if (isChatHeartReaction(token)) {
      return Icon(
        Icons.favorite_rounded,
        size: size * 1.08,
        color: const Color(0xFFE53935),
      );
    }
    return Text(token, style: TextStyle(fontSize: size, height: 1.1));
  }
}

class _ChatRichText extends StatelessWidget {
  final String text;
  final Map<String, Map<String, dynamic>> emojiMap;
  final Color textColor;

  const _ChatRichText({
    required this.text,
    required this.emojiMap,
    required this.textColor,
  });

  /// Permet au [RichText] de revenir à la ligne sur URL / mots sans espace.
  static String _softBreakLongWord(String segment, {int step = 18}) {
    if (segment.length <= step || step < 6) return segment;
    const zwsp = '\u200B';
    final out = StringBuffer();
    for (var j = 0; j < segment.length; j++) {
      if (j > 0 && j % step == 0) out.write(zwsp);
      out.write(segment[j]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final segments = RegExp(
      r'\S+|\s+',
    ).allMatches(text).map((match) => match.group(0) ?? '').toList();

    return RichText(
      textAlign: TextAlign.start,
      softWrap: true,
      text: TextSpan(
        children: segments.map<InlineSpan>((segment) {
          if (segment.trim().isEmpty) {
            return TextSpan(text: segment);
          }
          final forLayout = emojiMap.containsKey(segment)
              ? segment
              : _softBreakLongWord(segment);
          if (segment.startsWith('@')) {
            return TextSpan(
              text: forLayout,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.4,
                color: _kGoldDeep,
                fontWeight: FontWeight.w700,
              ),
            );
          }
          if (emojiMap.containsKey(segment) || isChatHeartReaction(segment)) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _EmojiInline(
                  token: segment,
                  emojiMap: emojiMap,
                  size: 20,
                ),
              ),
            );
          }
          return TextSpan(
            text: forLayout,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.4,
              color: textColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Palette d'émojis de la barre de saisie. Insertion locale dans le champ
/// texte : le message envoyé reste une chaîne, aucun champ nouveau côté base.
const List<String> _kChatEmojiPalette = [
  '😀',
  '😁',
  '😂',
  '🤣',
  '😊',
  '😍',
  '🤩',
  '😎',
  '🤔',
  '😮',
  '😢',
  '😡',
  '🙏',
  '🤝',
  '💪',
  '🫡',
  '👍',
  '👏',
  '🙌',
  '🔥',
  '⚡',
  '⭐',
  '🎉',
  '🥳',
  '❤️',
  '💚',
  '⚽',
  '🥅',
  '🏟️',
  '🏆',
  '📣',
  '🐗',
];

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;
  final Map<String, dynamic>? replyTo;
  final List<Map<String, dynamic>> customEmojis;
  final List<Map<String, dynamic>> mentionSuggestions;
  final void Function(Map<String, dynamic>) onMentionSelected;
  final VoidCallback onClearReply;
  final double bottomPad;

  const _InputBar({
    required this.ctrl,
    required this.onSend,
    this.sending = false,
    required this.replyTo,
    required this.customEmojis,
    required this.mentionSuggestions,
    required this.onMentionSelected,
    required this.onClearReply,
    this.bottomPad = 0,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final FocusNode _focus = FocusNode();
  bool _emojiPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focus.hasFocus && _emojiPanelOpen) {
      setState(() => _emojiPanelOpen = false);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// Insère un jeton au curseur (ou en fin de texte) sans casser la sélection.
  void _insertToken(String token) {
    final ctrl = widget.ctrl;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final at = sel.isValid ? sel.end : text.length;
    final before = text.substring(0, at);
    final after = text.substring(at);
    final needsSpace = before.isNotEmpty && !before.endsWith(' ');
    final insert = '${needsSpace ? ' ' : ''}$token ';
    final next = '$before$insert$after';
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  void _toggleEmojiPanel() {
    HapticFeedback.selectionClick();
    final opening = !_emojiPanelOpen;
    setState(() => _emojiPanelOpen = opening);
    if (opening) _focus.unfocus();
  }

  void _startMention() {
    HapticFeedback.selectionClick();
    final ctrl = widget.ctrl;
    final text = ctrl.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    final next = '$text${needsSpace ? ' ' : ''}@';
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final onSend = widget.onSend;
    final replyTo = widget.replyTo;
    final customEmojis = widget.customEmojis;
    final mentionSuggestions = widget.mentionSuggestions;
    final onMentionSelected = widget.onMentionSelected;
    final onClearReply = widget.onClearReply;
    final focused = _focus.hasFocus;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      decoration: const BoxDecoration(
        color: ChatDesign.chrome,
        border: Border(
          top: BorderSide(color: ChatDesign.hairline, width: 1),
        ),
      ),
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final canSend = ctrl.text.trim().isNotEmpty;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _kChatMaxContentWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mentionSuggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxHeight: isLandscape ? 80 : 160),
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          color: ChatDesign.paper,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: mentionSuggestions.map((user) {
                              final handle = _userHandleFromData(user);
                              final display = _displayNameFromData(user);
                              return GestureDetector(
                                onTap: () => onMentionSelected(user),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ChatDesign.paper,
                                    borderRadius: BorderRadius.circular(
                                      ChatDesign.radius,
                                    ),
                                    border: Border.all(color: ChatDesign.hairline),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: _kGold.withAlpha(20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            display.isNotEmpty
                                                ? display[0].toUpperCase()
                                                : '@',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _kGoldDeep,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              display,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _kText,
                                              ),
                                            ),
                                            Text(
                                              '@$handle',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: _kMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  if (!isLandscape && customEmojis.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: ChatDesign.paper,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: customEmojis.map((emoji) {
                            final value =
                                (emoji['value'] ?? '').toString().trim();
                            final imageUrl =
                                (emoji['imageUrl'] ?? '').toString().trim();
                            final label = (emoji['label'] ?? value).toString();
                            if (value.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: () {
                                final separator = ctrl.text.isEmpty ? '' : ' ';
                                final next = '${ctrl.text}$separator$value ';
                                ctrl.value = TextEditingValue(
                                  text: next,
                                  selection: TextSelection.collapsed(
                                    offset: next.length,
                                  ),
                                );
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.only(right: 8, bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: ChatDesign.paper,
                                  borderRadius: BorderRadius.circular(
                                    ChatDesign.radius,
                                  ),
                                  border: Border.all(color: ChatDesign.hairline),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (imageUrl.isNotEmpty)
                                      ChatStickerImage(
                                        imageUrl: imageUrl,
                                        size: 22,
                                        errorFallback: Text(
                                          value,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      )
                                    else
                                      Text(value,
                                          style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _kMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (replyTo != null)
                    Container(
                      decoration: const BoxDecoration(
                        color: ChatDesign.paper,
                        border: Border(
                          top: BorderSide(color: ChatDesign.hairline),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 2.5,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _kGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  replyTo['firstName'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kGoldDeep,
                                  ),
                                ),
                                Text(
                                  replyTo['text'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _kMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onClearReply,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: _kMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: isLandscape ? 4 : 8,
                      bottom: (isLandscape ? 4 : 8) +
                          (_emojiPanelOpen
                              ? 0.0
                              : (MediaQuery.of(context).viewInsets.bottom > 0
                                  ? 0.0
                                  : widget.bottomPad)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: focused
                                  ? ChatDesign.paper
                                  : ChatDesign.ivory,
                              borderRadius: BorderRadius.circular(
                                ChatDesign.radius,
                              ),
                              border: Border.all(
                                color: focused
                                    ? ChatDesign.green
                                    : ChatDesign.hairline,
                                width: focused ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: _startMention,
                                  tooltip: 'Mentionner',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  icon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 18,
                                    color: focused ? _kGreen : _kMuted,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: ctrl,
                                    focusNode: _focus,
                                    enabled: !widget.sending,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _kText,
                                      height: 1.25,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Ton message…',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: _kMuted.withValues(alpha: 0.75),
                                      ),
                                      border: InputBorder.none,
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) {
                                      if (canSend && !widget.sending) onSend();
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: _toggleEmojiPanel,
                                  tooltip: 'Emoji',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  icon: Icon(
                                    _emojiPanelOpen
                                        ? Icons.keyboard_rounded
                                        : Icons.emoji_emotions_outlined,
                                    size: 20,
                                    color:
                                        _emojiPanelOpen ? _kGreen : _kMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canSend && !widget.sending ? onSend : null,
                            borderRadius:
                                BorderRadius.circular(ChatDesign.radius),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: ChatDesign.green.withValues(
                                  alpha: canSend ? 1.0 : 0.38,
                                ),
                                borderRadius: BorderRadius.circular(
                                  ChatDesign.radius,
                                ),
                              ),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: widget.sending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          Icons.send_rounded,
                                          color: Colors.white.withValues(
                                            alpha: canSend ? 1 : 0.7,
                                          ),
                                          size: 18,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_emojiPanelOpen)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 176),
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          10,
                          0,
                          10,
                          8 + widget.bottomPad,
                        ),
                        itemCount: _kChatEmojiPalette.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemBuilder: (context, i) {
                          final emoji = _kChatEmojiPalette[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _insertToken(emoji),
                              borderRadius: BorderRadius.circular(10),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style:
                                      const TextStyle(fontSize: 22, height: 1),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserProfileSheet extends StatefulWidget {
  final Map<String, dynamic> msgData;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  const _UserProfileSheet({
    required this.msgData,
    required this.roleBadges,
    this.roleBadgeLabels = const {},
  });
  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    final uid = widget.msgData['uid'] as String?;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() {
            _userData = snap.data();
            _loading = false;
          });
        }
      });
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.msgData['firstName'] ?? 'Membre') as String;
    final lastName = (widget.msgData['lastName'] ?? '') as String;
    final roles = _rolesFromMsg(widget.msgData);
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}'
            .toUpperCase();

    String memberSince = '';
    bool isBanned = false;
    int warnings = 0;
    int xp = 0;

    if (_userData != null) {
      final ts = _userData!['createdAt'];
      if (ts is Timestamp) {
        final d = ts.toDate();
        const months = [
          'jan',
          'fév',
          'mar',
          'avr',
          'mai',
          'juin',
          'juil',
          'aoû',
          'sep',
          'oct',
          'nov',
          'déc',
        ];
        memberSince = '${d.day} ${months[d.month - 1]} ${d.year}';
      }
      final bannedUntil = _userData!['chatBannedUntil'];
      if (bannedUntil is Timestamp) {
        isBanned = bannedUntil.toDate().isAfter(DateTime.now());
      }
      warnings = _userData!['chatWarnings'] as int? ?? 0;
      xp = _userData!['xp'] as int? ?? 0;
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: XpService.levelsDocStream(),
      builder: (context, lvlSnap) {
        final levels = XpService.parseLevels(lvlSnap.data?.data());
        final level = XpService.levelFromXp(xp, levels: levels);
        final levelName = XpService.levelLabelFromXp(xp, levels: levels);

        return Container(
          decoration: const BoxDecoration(
            color: ChatDesign.ivory,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ChatDesign.radiusMd),
            ),
            border: Border(top: BorderSide(color: ChatDesign.hairline)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 8, bottom: 12),
                child: _ChatAvatar(
                  initials: initials,
                  roles: roles,
                  roleBadges: widget.roleBadges,
                  size: 64,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$firstName $lastName'.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (isBanned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _kRed.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _kRed.withAlpha(80)),
                            ),
                            child: Text(
                              'SUSPENDU',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kRed,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final list = _publicChatRoles(roles).toList();
                        sortRolesByPriority(list);
                        return Wrap(
                          spacing: 5,
                          children: list
                              .map(
                                (r) => dvcrRoleUsesTierBadge(r)
                                    ? DvcrChatRoleCapsule(
                                        role: r,
                                        small: false,
                                        badgeImageUrl: widget
                                            .roleBadges[roleBadgeConfigKey(r)]
                                            ?.trim(),
                                        labelOverride: _badgeLabelFor(
                                          r,
                                          widget.roleBadgeLabels,
                                        ),
                                      )
                                    : _RoleBadge(
                                        role: r,
                                        small: false,
                                        imageUrl: widget
                                            .roleBadges[roleBadgeConfigKey(r)]
                                            ?.trim(),
                                      ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: _kBorder),
                    const SizedBox(height: 14),
                    _loading
                        ? const SizedBox(
                            height: 20,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: _kRed,
                                  strokeWidth: 1.5,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (memberSince.isNotEmpty)
                                _ProfileInfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Membre depuis',
                                  value: memberSince,
                                ),
                              _ProfileInfoRow(
                                icon: Icons.star_outline_rounded,
                                label: 'Niveau',
                                value: '$levelName ($level)',
                                infoBadgeLabel:
                                    MemberBadgeInfo.xpLevelLabelQualifies(
                                  levelName,
                                )
                                        ? levelName
                                        : null,
                              ),
                              _ProfileInfoRow(
                                icon: Icons.bolt_rounded,
                                label: 'XP',
                                value: '$xp pts',
                              ),
                              if (warnings > 0)
                                _ProfileInfoRow(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Avertissements',
                                  value: '$warnings',
                                ),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? infoBadgeLabel;
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.infoBadgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _kMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          if (infoBadgeLabel != null)
            MemberBadgeInfoIconButton(
              badgeLabel: infoBadgeLabel,
              iconSize: 14,
              color: _kMuted,
            ),
        ],
      ),
    );
  }
}

// ── Multi-role badges ─────────────────────────────────────────────────────────
class _RoleBadges extends StatelessWidget {
  final Set<UserRole> roles;
  final bool small;
  final int maxBadges;
  final Map<String, String> roleBadges;
  final Map<String, String> roleBadgeLabels;
  const _RoleBadges({
    required this.roles,
    this.small = false,
    this.maxBadges = 2,
    this.roleBadges = const {},
    this.roleBadgeLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    final visible = _publicChatRoles(roles).toList();
    sortRolesByPriority(visible);
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: visible
          .take(maxBadges)
          .map(
            (r) => dvcrRoleUsesTierBadge(r)
                ? DvcrChatRoleCapsule(
                    role: r,
                    small: small,
                    badgeImageUrl: roleBadges[roleBadgeConfigKey(r)]?.trim(),
                    labelOverride: _badgeLabelFor(r, roleBadgeLabels),
                  )
                : _RoleBadge(
                    role: r,
                    small: small,
                    imageUrl: roleBadges[roleBadgeConfigKey(r)]?.trim(),
                  ),
          )
          .toList(),
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;
  final String? imageUrl;
  const _RoleBadge({
    required this.role,
    this.small = false,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final rd = _roleData(role);
    final img = imageUrl?.trim() ?? '';
    final imgD = small ? 12.0 : 14.0;
    final showInfo = MemberBadgeInfo.roleQualifies(role) ||
        MemberBadgeInfo.labelQualifies(rd.$1);
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: rd.$2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: rd.$3.withValues(alpha: 0.22)),
        boxShadow: img.isNotEmpty
            ? [
                BoxShadow(
                  color: rd.$3.withAlpha(35),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (img.isNotEmpty) ...[
            Container(
              width: imgD,
              height: imgD,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rd.$3.withAlpha(160), width: 1),
              ),
              child: ClipOval(
                child: Image.network(
                  img,
                  fit: BoxFit.cover,
                  cacheWidth: (imgD *
                          MediaQuery.devicePixelRatioOf(context))
                      .round()
                      .clamp(24, 96),
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            SizedBox(width: small ? 4 : 5),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: small ? 92 : 128),
            child: Text(
              rd.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: small ? 9.0 : 10.0,
                fontWeight: FontWeight.w700,
                color: rd.$3,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
    return MemberBadgeInfoTrigger(
      enabled: showInfo,
      badgeLabel: rd.$1,
      child: badge,
    );
  }
}
