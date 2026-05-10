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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kInput,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kGold.withAlpha(75)),
              boxShadow: [
                BoxShadow(
                  color: _kGreenDeep.withAlpha(12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kRed.withAlpha(18),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kRed.withAlpha(80)),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: _kRed,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Accès chat désactivé',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le chat n’est pas activé pour ton rôle actuellement. Tu peux modifier ça depuis le centre rôles et permissions de l’admin.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _kMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: Text(
                    'Retour',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kGold,
                    ),
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

/// Pastille « en ligne » légèrement animée (effet chat vivant).
class _HeaderOnlinePulse extends StatefulWidget {
  const _HeaderOnlinePulse();

  @override
  State<_HeaderOnlinePulse> createState() => _HeaderOnlinePulseState();
}

class _HeaderOnlinePulseState extends State<_HeaderOnlinePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF66BB6A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF66BB6A).withValues(alpha: 0.45),
              blurRadius: 5,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Channel header compact (paysage) ─────────────────────────────────────────
class _ChannelHeaderCompact extends StatelessWidget {
  final UserRole? role;
  final Set<UserRole> roles;
  final Map<String, String> roleBadges;
  final double topPad;
  const _ChannelHeaderCompact({
    this.role,
    this.roles = const {},
    this.roleBadges = const {},
    this.topPad = 0,
  });

  @override
  Widget build(BuildContext context) {
    final UserRole? headerBadgeRole =
        roles.isEmpty && role != null
            ? _chatHeaderPrimaryBadgeRole(role!, roles)
            : null;
    return Container(
      decoration: BoxDecoration(
        color: _kSheet,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(color: _kGold.withAlpha(50)),
        ),
        boxShadow: [
          BoxShadow(
            color: _kGreenDeep.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: topPad + 8, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kGold.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGold.withAlpha(55)),
            ),
            child: const Icon(Icons.forum_rounded, color: _kGreenDeep, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'COMMUNAUTÉ DVCR',
            style: GoogleFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kText,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (roles.isNotEmpty)
            _RoleBadges(
              roles: _chatHeaderBadgeRoles(roles),
              small: true,
              maxBadges: 1,
              roleBadges: roleBadges,
            )
          else if (headerBadgeRole != null)
            _RoleBadge(
              role: headerBadgeRole,
              small: true,
              imageUrl:
                  roleBadges[roleBadgeConfigKey(headerBadgeRole)]?.trim(),
            ),
        ],
      ),
    );
  }
}

// ── Channel header ────────────────────────────────────────────────────────────
class _ChannelHeader extends StatelessWidget {
  final UserRole? role;
  final Set<UserRole> roles;
  final Map<String, String> roleBadges;
  final int level;
  final String levelLabel;
  final int xp;
  final double topPad;
  const _ChannelHeader({
    this.role,
    this.roles = const {},
    this.roleBadges = const {},
    this.level = 0,
    this.levelLabel = '',
    this.xp = 0,
    this.topPad = 0,
  });

  @override
  Widget build(BuildContext context) {
    final UserRole? headerBadgeRole =
        roles.isEmpty && role != null
            ? _chatHeaderPrimaryBadgeRole(role!, roles)
            : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.network(
              _kChatHeroBg,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.35),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(88),
                    Colors.black.withAlpha(45),
                    _kGreen.withAlpha(185),
                    _kGreenDeep,
                  ],
                  stops: const [0.0, 0.28, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, topPad + 6, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(165),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(200)),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: _kGreenDeep,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kGold.withAlpha(38),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withAlpha(85)),
                        ),
                        child: Text(
                          'SALONS & CHAT',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'COMMUNAUTÉ DVCR',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.35,
                          height: 1,
                          shadows: const [
                            Shadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const _HeaderOnlinePulse(),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Membres connectés',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ),
                          if (level > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(28),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _kGold.withAlpha(90)),
                              ),
                              child: Text(
                                '${levelLabel.isNotEmpty ? levelLabel : _levelLabel(level)} · Niv.$level',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _kGold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (roles.isNotEmpty)
                  _RoleBadges(
                    roles: _chatHeaderBadgeRoles(roles),
                    small: true,
                    maxBadges: 1,
                    roleBadges: roleBadges,
                  )
                else if (headerBadgeRole != null)
                  _RoleBadge(
                    role: headerBadgeRole,
                    small: true,
                    imageUrl:
                        roleBadges[roleBadgeConfigKey(headerBadgeRole)]?.trim(),
                  ),
              ],
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
        final liveDocs = allDocs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['isLive'] == true &&
                (d.data() as Map<String, dynamic>)['archived'] != true)
            .toList();
        final isLiveMode = liveDocs.isNotEmpty;
        final docs = isLiveMode
            ? liveDocs
            : allDocs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['archived'] != true)
                .toList();

        // Auto-switch to live salon when live mode activates
        if (isLiveMode && liveDocs.isNotEmpty) {
          final liveId = liveDocs.first.id;
          if (currentId != liveId) {
            final liveName =
                (liveDocs.first.data() as Map<String, dynamic>)['name']
                        as String? ??
                    'Live';
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onSwitch(liveId, liveName));
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGold.withAlpha(85)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              children: [
              if (isLiveMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kRed.withAlpha(18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kRed.withAlpha(60)),
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
                GestureDetector(
                  onTap: onAdd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child:
                          Icon(Icons.add_rounded, size: 18, color: _kGold),
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: _kGold.withValues(alpha: 0.22),
          highlightColor: _kGreen.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 10,
                vertical: isSelected ? 6 : 5,
              ),
              decoration: BoxDecoration(
                color: isSelected ? _kGreenDeep : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? _kGold : _kBorder,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _kGold.withAlpha(50),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? Colors.white : _kMuted,
                    letterSpacing: isSelected ? 0.2 : 0.1,
                  ),
                  child: Text('# $name'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pinned message bar ────────────────────────────────────────────────────────
class _PinnedBar extends StatelessWidget {
  final String salonId;
  final bool canUnpin;
  final VoidCallback onUnpin;
  const _PinnedBar({
    required this.salonId,
    required this.canUnpin,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .doc(salonId)
          .snapshots(),
      builder: (_, snap) {
        final pinned =
            (snap.data?.data() as Map<String, dynamic>?)?['pinned']
                as Map<String, dynamic>?;
        if (pinned == null) return const SizedBox.shrink();
        final text = pinned['text'] as String? ?? '';
        final firstName = pinned['firstName'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(242),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGold.withAlpha(65)),
            boxShadow: [
              BoxShadow(
                color: _kGreenDeep.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin_rounded, size: 13, color: _kGold),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$firstName : $text',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ),
              if (canUnpin)
                GestureDetector(
                  onTap: onUnpin,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close_rounded, size: 14, color: _kMuted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Courte apparition pour le dernier message (le tien), en bas de liste inversée.
class _MineBubbleEntrance extends StatefulWidget {
  final Widget child;
  const _MineBubbleEntrance({required this.child});

  @override
  State<_MineBubbleEntrance> createState() => _MineBubbleEntranceState();
}

class _MineBubbleEntranceState extends State<_MineBubbleEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
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
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────
class _MessageList extends StatelessWidget {
  final ScrollController scroll;
  final String salonId;
  final String currentUid;
  final UserRole? role;
  final Set<UserRole> currentUserRoles;
  final Map<String, dynamic> emojiConfig;
  final Map<String, String> roleBadges;
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
    required this.role,
    required this.currentUserRoles,
    required this.emojiConfig,
    required this.roleBadges,
    required this.onDelete,
    required this.onReport,
    required this.onReply,
    required this.onPin,
    required this.onBan,
    required this.onWarn,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .doc(salonId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                decoration: BoxDecoration(
                  color: _kInput.withAlpha(245),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _kGold.withAlpha(55)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: _kGreen,
                ),
                const SizedBox(height: 14),
                Text(
                  'Le salon est tout calme',
                  style: GoogleFonts.inter(fontSize: 14, color: _kText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lance la conversation, on t\'écoute !',
                  style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
                ),
                  ],
                ),
              ),
            ),
          );
        }

        final docs = snap.data!.docs
            .where((d) => (d.data() as Map)['isDeleted'] != true)
            .toList();

        final insetBottom = MediaQuery.of(ctx).viewInsets.bottom;
        return ListView.builder(
          controller: scroll,
          reverse: true,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(0, 4, 0, 6 + insetBottom),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;

            final nextData = i < docs.length - 1
                ? docs[i + 1].data() as Map<String, dynamic>
                : null;
            final isGrouped =
                nextData != null &&
                nextData['uid'] == data['uid'] &&
                _diffMin(nextData['createdAt'], data['createdAt']) < 5;

            final msgUid = data['uid'] as String? ?? '';
            final msgName = data['firstName'] as String? ?? 'Membre';
            final msgText = data['text'] as String? ?? '';
            final isMine = msgUid == currentUid;

            Widget tile = _MessageTile(
              data: data,
              docId: doc.id,
              isMine: isMine,
              isGrouped: isGrouped,
              role: role,
              currentUid: currentUid,
              currentUserRoles: currentUserRoles,
              emojiConfig: emojiConfig,
              roleBadges: roleBadges,
              onDelete: () => onDelete(doc.id),
              onReport: () => onReport(doc.id, msgText, msgUid, msgName),
              onReply: () => onReply({
                'id': doc.id,
                'text': msgText,
                'firstName': msgName,
              }),
              onPin: () => onPin(doc.id, msgText, msgName),
              onBan: () => onBan(msgUid, msgName),
              onWarn: () => onWarn(msgUid, msgName),
              onReact: (emoji) => onReact(doc.id, emoji),
            );
            if (i == 0 && isMine) {
              tile = _MineBubbleEntrance(child: tile);
            }
            return KeyedSubtree(
              key: ValueKey(doc.id),
              child: tile,
            );
          },
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
      stream: FirebaseFirestore.instance.collection('chat_typing').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
        final typers = snap.data!.docs
            .where((d) {
              if (d.id == currentUid) return false;
              final ts = d['typingAt'];
              if (ts is! Timestamp) return false;
              if (!ts.toDate().isAfter(cutoff)) return false;
              final dSalonId = d.data() is Map
                  ? (d.data() as Map)['salonId'] as String?
                  : null;
              return dSalonId == salonId;
            })
            .map((d) => d['name'] as String? ?? 'Quelqu\'un')
            .toList();

        if (typers.isEmpty) return const SizedBox.shrink();

        final label = typers.length == 1
            ? '${typers[0]} écrit un message…'
            : '${typers.take(2).join(' et ')} écrivent…';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _kBg.withAlpha(228),
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              _DotsAnimation(),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _kMuted,
                  fontStyle: FontStyle.italic,
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
        color: Color(0xFF1A1A1A),
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

// ── Message tile ──────────────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isMine;
  final bool isGrouped;
  final UserRole? role;
  final String currentUid;
  final Set<UserRole> currentUserRoles;
  final Map<String, dynamic> emojiConfig;
  final Map<String, String> roleBadges;
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
    required this.role,
    required this.currentUid,
    required this.currentUserRoles,
    required this.emojiConfig,
    required this.roleBadges,
    required this.onDelete,
    required this.onReport,
    required this.onReply,
    required this.onPin,
    required this.onBan,
    required this.onWarn,
    required this.onReact,
  });

  bool get _isAdmin => role == UserRole.admin;
  bool get _isCM => role == UserRole.communityManager;
  bool get _canMod => _isAdmin || _isCM;
  bool get _canReport =>
      UserService.canReportMessage(role); // admin + CM + Team DVCR

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
    final nameColor = isModNotice ? _kGold : rd.$4;
    final bubbleColor = isModNotice
        ? const Color(0xFFFFF6E8)
        : (isMine ? const Color(0xFFEAF5F0) : const Color(0xFFFFFCF8));
    final bubbleBorderColor = isModNotice
        ? _kGold.withValues(alpha: 0.5)
        : (isMine ? const Color(0xFFC5E0D6) : _kGold.withValues(alpha: 0.22));
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : "?"}${lastName.isNotEmpty ? lastName[0] : ""}'
            .toUpperCase();
    final emojiMap = _emojiValueMap(emojiConfig);

    final reactions = <String, int>{};
    final myReactions = <String>{};
    if (reactionsRaw != null) {
      for (final entry in reactionsRaw.entries) {
        final uids = (entry.value as List?)?.cast<String>() ?? [];
        if (uids.isNotEmpty) {
          reactions[entry.key] = uids.length;
          if (uids.contains(currentUid)) myReactions.add(entry.key);
        }
      }
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showActions(context);
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: isGrouped ? 3 : 10,
          bottom: 3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar avec bordure rôle
            SizedBox(
              width: 44,
              child: isGrouped
                  ? null
                  : isModNotice
                  ? Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGold.withAlpha(26),
                          border: Border.all(color: _kGold.withAlpha(100)),
                          boxShadow: [
                            BoxShadow(
                              color: _kGold.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: _kGold,
                          size: 18,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _canMod && !isMine
                          ? () => _showUserProfile(context, data, roleBadges)
                          : null,
                      child: _ChatAvatar(
                        initials: initials,
                        roles: msgRoles,
                        roleBadges: roleBadges,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Bulle + réactions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isGrouped ? 16 : 6),
                      topRight: const Radius.circular(18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isGrouped ? 16 : 6),
                          topRight: const Radius.circular(18),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                        border: Border.all(color: bubbleBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: isModNotice
                                ? _kGold.withValues(alpha: 0.12)
                                : _kGreenDeep.withValues(
                                    alpha: isMine ? 0.06 : 0.07,
                                  ),
                            blurRadius: isModNotice ? 16 : (isMine ? 12 : 14),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                          isModNotice
                                              ? firstName
                                              : (isMine ? 'Toi' : firstName),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isModNotice
                                                ? _kGold
                                                : (isMine ? _kGreen : nameColor),
                                            letterSpacing: 0.15,
                                          ),
                                        ),
                                      ),
                                      if (ts != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          _fmtTs(ts),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: _kMuted.withValues(
                                              alpha: isMine ? 0.72 : 0.9,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (isModNotice)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _kGold.withAlpha(22),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: _kGold.withAlpha(70),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 12,
                                            color: _kGold.withValues(alpha: 0.95),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Message équipe',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: _kGold,
                                              letterSpacing: 0.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    _RoleBadges(
                                      roles: msgRoles,
                                      small: true,
                                      roleBadges: roleBadges,
                                      maxBadges: 4,
                                    ),
                                ],
                              ),
                            ),
                          if (replyTo != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFFDCEEE6)
                                    : _kBg.withAlpha(244),
                                borderRadius: BorderRadius.circular(8),
                                border: const Border(
                                  left: BorderSide(color: _kGold, width: 2.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    replyTo['firstName'] as String? ??
                                        'Membre',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _kGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    replyTo['text'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _ChatRichText(
                            text: text,
                            emojiMap: emojiMap,
                            textColor: _kText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Réactions
                  if (reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: reactions.entries.map((e) {
                          final mine = myReactions.contains(e.key);
                          return GestureDetector(
                            onTap: () => onReact(e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? _kGold.withAlpha(36)
                                    : Colors.white.withAlpha(208),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: mine
                                      ? _kGold.withAlpha(120)
                                      : _kBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _EmojiInline(
                                    token: e.key,
                                    emojiMap: emojiMap,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${e.value}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: mine ? _kGold : _kMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            // Bouton répondre (uniquement en tête de groupe pour alléger la droite).
            if (!isGrouped)
              GestureDetector(
                onTap: onReply,
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreenDeep.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 15,
                    color: _kGreen.withValues(alpha: 0.85),
                  ),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Réactions rapides
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '🔥', '😂', '👏', '😮']
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onReact(e);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
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
                Navigator.pop(context);
                onReply();
              },
            ),
            // Suppression : soi-même + admin/CM + Team DVCR (signalement)
            if (((_canReport && !isMine) || isMine) && !isNotice) ...[
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF5350),
                ),
                title: Text(
                  isMine
                      ? 'Supprimer mon message'
                      : _canMod
                      ? 'Supprimer'
                      : 'Signaler & supprimer',
                  style: GoogleFonts.inter(color: _kText, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
            if (_canMod && !isMine && !isNotice) ...[
              ListTile(
                leading: const Icon(Icons.push_pin_rounded, color: _kGold),
                title: Text(
                  'Épingler',
                  style: GoogleFonts.inter(color: _kText, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
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
                  Navigator.pop(context);
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
                  Navigator.pop(context);
                  onBan();
                },
              ),
            ],
            if (_isCM && !_isAdmin && !isMine && !isNotice)
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: Color(0xFFFFB74D),
                ),
                title: Text(
                  'Signaler à l\'admin',
                  style: GoogleFonts.inter(color: _kText, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onReport();
                },
              ),
            const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserProfile(BuildContext context, Map<String, dynamic> msgData, Map<String, String> badges) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserProfileSheet(msgData: msgData, roleBadges: badges),
    );
  }

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ── Barre ban ─────────────────────────────────────────────────────────────────
class _BannedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: _kGreenDeep.withAlpha(18),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
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

  const _EmojiInline({
    required this.token,
    required this.emojiMap,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = emojiMap[token];
    final imageUrl = (emoji?['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(token, style: TextStyle(fontSize: size));
          },
        ),
      );
    }
    return Text(token, style: TextStyle(fontSize: size));
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
                color: _kGold,
                fontWeight: FontWeight.w700,
              ),
            );
          }
          if (emojiMap.containsKey(segment)) {
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

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final Map<String, dynamic>? replyTo;
  final List<Map<String, dynamic>> customEmojis;
  final List<Map<String, dynamic>> mentionSuggestions;
  final void Function(Map<String, dynamic>) onMentionSelected;
  final VoidCallback onClearReply;
  final double bottomPad;

  const _InputBar({
    required this.ctrl,
    required this.onSend,
    required this.replyTo,
    required this.customEmojis,
    required this.mentionSuggestions,
    required this.onMentionSelected,
    required this.onClearReply,
    this.bottomPad = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      decoration: BoxDecoration(
        color: _kSheet,
        border: Border(top: BorderSide(color: _kGold.withAlpha(45))),
        boxShadow: [
          BoxShadow(
            color: _kGreenDeep.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final canSend = ctrl.text.trim().isNotEmpty;
          return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mentionSuggestions.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: isLandscape ? 80 : 160),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  color: _kSheet,
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
                            color: _kInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorder),
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
                                      color: _kGold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      display,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _kText,
                                      ),
                                    ),
                                    Text(
                                      '@$handle',
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
              color: _kBg,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: customEmojis.map((emoji) {
                    final value = (emoji['value'] ?? '').toString().trim();
                    final imageUrl = (emoji['imageUrl'] ?? '')
                        .toString()
                        .trim();
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
                        margin: const EdgeInsets.only(right: 8, bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _kInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  imageUrl,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      value,
                                      style: const TextStyle(fontSize: 16),
                                    );
                                  },
                                ),
                              )
                            else
                              Text(value, style: const TextStyle(fontSize: 16)),
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
              color: Colors.white,
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
                          replyTo!['firstName'] as String? ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGold,
                          ),
                        ),
                        Text(
                          replyTo!['text'] as String? ?? '',
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
              left: 14,
              right: 14,
              top: isLandscape ? 4 : 10,
              bottom:
                  (isLandscape ? 4 : 10) +
                  (MediaQuery.of(context).viewInsets.bottom > 0
                      ? 0.0
                      : MediaQuery.of(context).padding.bottom),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(
                          Icons.waving_hand_rounded,
                          size: 18,
                          color: _kGold.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _kText,
                              height: 1.25,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Dis bonjour au salon…',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: _kMuted.withValues(alpha: 0.75),
                              ),
                              border: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedScale(
                  scale: canSend ? 1.0 : 0.92,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: canSend ? 1.0 : 0.5,
                    child: Material(
                      color: Colors.transparent,
                        child: InkWell(
                        onTap: canSend ? onSend : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kGreen.withValues(alpha: canSend ? 0.92 : 0.5),
                                _kGreenDeep.withValues(alpha: canSend ? 1.0 : 0.55),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: canSend
                                ? [
                                    BoxShadow(
                                      color: _kGreen.withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
          );
        },
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const _OnlineDot({this.userData});

  @override
  Widget build(BuildContext context) {
    final isOnline = userData?['isOnline'] as bool? ?? false;
    final lastSeen = userData?['lastSeen'];
    // Considéré en ligne si flag true ET lastSeen < 5 min
    bool online = false;
    if (isOnline && lastSeen is Timestamp) {
      online = DateTime.now().difference(lastSeen.toDate()).inMinutes < 5;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF4CAF50) : _kBorder,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          online ? 'En ligne' : 'Hors ligne',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: online ? const Color(0xFF4CAF50) : _kMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UserProfileSheet extends StatefulWidget {
  final Map<String, dynamic> msgData;
  final Map<String, String> roleBadges;
  const _UserProfileSheet({required this.msgData, required this.roleBadges});
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

    final level = _xpToLevel(xp);

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    Text(
                      '$firstName $lastName'.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OnlineDot(userData: _userData),
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
                            value: '${_levelLabel(level)} ($level)',
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
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _kMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
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
  const _RoleBadges({
    required this.roles,
    this.small = false,
    this.maxBadges = 2,
    this.roleBadges = const {},
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
    return Container(
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
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            SizedBox(width: small ? 4 : 5),
          ],
          Text(
            rd.$1,
            style: GoogleFonts.inter(
              fontSize: small ? 9.0 : 10.0,
              fontWeight: FontWeight.w700,
              color: rd.$3,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
