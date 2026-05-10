part of 'prono_screen.dart';

class _SocialAppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const _SocialAppBarTitle({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 50,
          margin: const EdgeInsets.only(right: 10, top: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: pronoAccentStripeColors(accent),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: pronoText,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pronoMutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PronoSocialPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  /// Barre AppBar, filet, bandeau gauche des cartes ( « extérieur » ).
  final Color pageAccent;
  /// Voile intérieur cartes + dégradé corps ; null = neutre (ex. duels rouge seul).
  final Color? innerAccent;

  const _PronoSocialPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.pageAccent = pronoGreen,
    this.innerAccent,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final fillTint = innerAccent ?? pageAccent;
    return PronoSocialPageAccent(
      stripeAccent: pageAccent,
      innerAccent: innerAccent,
      child: Scaffold(
        backgroundColor: pronoBg,
        appBar: AppBar(
          backgroundColor: pronoBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: pronoText,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: _SocialAppBarTitle(
            title: title,
            subtitle: subtitle,
            accent: pageAccent,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Color.lerp(pageAccent, pronoBorder, 0.55)!
                  .withValues(alpha: 0.88),
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(
                  const Color(0xFFF8F5ED),
                  fillTint,
                  innerAccent != null ? 0.058 : 0.04,
                )!,
                pronoBg,
                Color.lerp(
                  const Color(0xFFEDE8DC),
                  fillTint,
                  innerAccent != null ? 0.048 : 0.035,
                )!,
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: CustomScrollView(
              clipBehavior: Clip.hardEdge,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 26 + bottom),
                  sliver: SliverToBoxAdapter(
                    child: child,
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


class _SocialNextStepCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final String actionLabel;
  final Color accent;

  const _SocialNextStepCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.accent = pronoSocialLeague,
  });

  @override
  Widget build(BuildContext context) {
    return PronoSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _kMutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withAlpha(90)),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialActivityFeedCard extends StatelessWidget {
  final String uid;

  const _SocialActivityFeedCard({required this.uid});

  IconData _iconFor(String type) {
    switch (type) {
      case 'league_created':
      case 'league_joined':
        return Icons.groups_rounded;
      case 'duel_created':
      case 'duel_accepted':
        return Icons.sports_martial_arts_rounded;
      case 'friend_request':
      case 'friend_accepted':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'league_created':
      case 'league_joined':
        return pronoSocialLeague;
      case 'duel_created':
      case 'duel_accepted':
        return pronoSocialDuel;
      case 'friend_request':
      case 'friend_accepted':
        return pronoSocialFriend;
      default:
        return _kText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SocialActivityItem>>(
      future: PronoSocialActivityService.readCachedForUser(uid),
      builder: (context, cacheSnap) {
        final cached = cacheSnap.data ?? const <SocialActivityItem>[];
        return StreamBuilder<List<SocialActivityItem>>(
          stream: PronoSocialActivityService.watchForUser(uid),
          builder: (context, liveSnap) {
            final items = liveSnap.data ?? cached;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: PronoSectionCard(
                key: ValueKey('social-activity-${items.length}'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVITE COMMUNAUTE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: pronoGreen,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      const _FriendsEmptyLabel(
                        text: 'Aucune activite communautaire recente.',
                      )
                    else
                      ...items.take(5).map((item) {
                        final accent = _colorFor(item.type);
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.96, end: 1),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: accent.withAlpha(18),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _iconFor(item.type),
                                      color: accent,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _kText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _kMutedText,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PronoFriendsPage extends StatefulWidget {
  final String currentUid;
  final String displayName;

  const PronoFriendsPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  State<PronoFriendsPage> createState() => _PronoFriendsPageState();
}

class _PronoFriendsPageState extends State<PronoFriendsPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final found = await PronoSocialService.searchUsers(_searchCtrl.text);
    if (!mounted) return;
    setState(() {
      _results = found
          .where((user) => (user['uid'] ?? '') != widget.currentUid)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'AMIS',
      subtitle:
          'Demandes, invitations, amis confirmés — puis recherche pour inviter.',
      pageAccent: pronoSocialFriend,
      innerAccent: pronoGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PronoSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: PronoSocialService.userDocStream(widget.currentUid),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data();
                    final social =
                        (userData?['social'] as Map<String, dynamic>?) ??
                        const {};
                    final friendNames =
                        (social['friendNames'] as Map<String, dynamic>?) ??
                        const {};
                    final friendIds =
                        (social['friends'] as List?)
                            ?.whereType<String>()
                            .toList() ??
                        const <String>[];
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: PronoSocialService.friendRequestsForUser(
                        widget.currentUid,
                      ),
                      builder: (context, receivedSnap) {
                        final received = receivedSnap.data?.docs ?? const [];
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: PronoSocialService.sentFriendRequestsForUser(
                            widget.currentUid,
                          ),
                          builder: (context, sentSnap) {
                            final sent = sentSnap.data?.docs ?? const [];
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FriendsSectionTitle(
                                  title: 'Demandes recues',
                                  count: received.length,
                                  chipColor: pronoSocialFriend,
                                ),
                                const SizedBox(height: 8),
                                if (received.isEmpty)
                                  const _FriendsEmptyLabel(
                                    text: 'Aucune demande recue.',
                                  )
                                else
                                  ...received.map((request) {
                                    final data = request.data();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _PendingFriendRow(
                                        requestId: request.id,
                                        currentUid: widget.currentUid,
                                        currentName: widget.displayName,
                                        otherUid: (data['fromUid'] ?? '')
                                            .toString(),
                                        otherName:
                                            (data['fromName'] ?? 'Utilisateur')
                                                .toString(),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 12),
                                _FriendsSectionTitle(
                                  title: 'Invitations envoyées',
                                  count: sent.length,
                                  chipColor: pronoSocialFriend,
                                ),
                                const SizedBox(height: 8),
                                if (sent.isEmpty)
                                  const _FriendsEmptyLabel(
                                    text: 'Aucune invitation en attente.',
                                  )
                                else
                                  ...sent.map((request) {
                                    final data = request.data();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _CompactSocialRow(
                                        title: (data['toName'] ?? 'Utilisateur')
                                            .toString(),
                                        subtitle:
                                            'Invitation envoyée, en attente de réponse.',
                                        action: 'EN ATTENTE',
                                        onTap: () {},
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 12),
                                _FriendsSectionTitle(
                                  title: 'Amis confirmes',
                                  count: friendIds.length,
                                  chipColor: pronoSocialFriend,
                                ),
                                const SizedBox(height: 8),
                                if (friendIds.isEmpty)
                                  const _FriendsEmptyLabel(
                                    text: 'Aucun ami confirme pour le moment.',
                                  )
                                else
                                  ...friendIds.map((friendUid) {
                                    final friendName =
                                        (friendNames[friendUid] ?? 'Ami DVCR')
                                            .toString();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _kSurfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(color: _kBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                friendName,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _kText,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PronoDuelMatchPickerPage(
                                                        currentUid:
                                                            widget.currentUid,
                                                        currentName:
                                                            widget.displayName,
                                                        opponentUid: friendUid,
                                                        opponentName:
                                                            friendName,
                                                      ),
                                                ),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: pronoSocialDuel
                                                      .withAlpha(18),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: pronoSocialDuel
                                                        .withAlpha(80),
                                                  ),
                                                ),
                                                child: Text(
                                                  'DEFIER',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: pronoSocialDuel,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                _FriendsSectionTitle(
                  title: 'Ajouter un ami',
                  count: _results.length,
                  chipColor: pronoSocialFriend,
                ),
                const SizedBox(height: 8),
                _SocialField(
                  controller: _searchCtrl,
                  label: 'Nom ou email',
                  focusColor: pronoSocialFriend,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _search,
                  child: _PrimaryAction(
                    label: 'RECHERCHER UN MEMBRE',
                    backgroundColor: pronoSocialFriend,
                  ),
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._results.map((user) {
                    final otherUid = (user['uid'] ?? '').toString();
                    final otherName = PronoSocialService.resolveDisplayName(
                      data: user,
                      fallback: 'Membre DVCR',
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CompactSocialRow(
                        title: otherName,
                        subtitle: 'Envoyer une invitation a ce membre.',
                        action: 'AJOUTER',
                        actionColor: pronoSocialFriend,
                        onTap: () async {
                          await PronoSocialService.sendFriendRequest(
                            fromUid: widget.currentUid,
                            fromName: widget.displayName,
                            toUid: otherUid,
                            toName: otherName,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invitation envoyée à $otherName'),
                              backgroundColor: _kGreen,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class PronoDuelsPage extends StatelessWidget {
  final String currentUid;
  final String displayName;

  const PronoDuelsPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'DUELS',
      subtitle:
          'Chaque joueur saisit un score « fun » réservé au duel (ex. 10-0) : '
          'ça ne modifie pas ton prono championnat.',
      pageAccent: pronoSocialDuel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PronoSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comment lancer un duel ?',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: pronoText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '1. Choisis un ami confirmé (depuis ici ou depuis Amis).\n'
                  '2. Choisis un match à venir (7 jours max, pronos ouverts).\n'
                  '3. Après la création du duel, saisis ton score duel (libre, 0-99). '
                  'Ton adversaire fait pareil une fois le duel accepté.\n'
                  'À la fin du match réel, le duel est noté à partir de ces scores uniquement.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pronoMutedText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PronoDuelFriendPickerPage(
                        currentUid: currentUid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                  child: _PrimaryAction(
                    label: 'LANCER UN DUEL (CHOISIR UN AMI)',
                    backgroundColor: pronoSocialDuel,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PronoFriendsPage(
                        currentUid: currentUid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                  child: _SecondaryAction(label: 'OUVRIR LA LISTE D’AMIS'),
                ),
              ],
            ),
          ),
          _SocialActivityFeedCard(uid: currentUid),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelsForUser(currentUid),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? const [];
              final pending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final active = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final finished = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final doc in docs) {
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                if (status == 'cancelled' || status == 'declined') {
                  doc.reference.delete();
                  continue;
                }
                if (status == 'pending') {
                  pending.add(doc);
                } else if (status == 'in_progress') {
                  active.add(doc);
                } else {
                  finished.add(doc);
                }
              }

              return PronoSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FriendsSectionTitle(
                      title: 'En attente',
                      count: pending.length,
                      chipColor: pronoSocialDuel,
                    ),
                    const SizedBox(height: 8),
                    if (pending.isEmpty)
                      const _FriendsEmptyLabel(text: 'Aucun duel en attente.')
                    else
                      ...pending.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DuelHubRow(
                            uid: currentUid,
                            duel: {'id': doc.id, ...doc.data()},
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PronoDuelDetailPage(
                                  duelId: doc.id,
                                  currentUid: currentUid,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _FriendsSectionTitle(
                      title: 'En cours',
                      count: active.length,
                      chipColor: pronoSocialDuel,
                    ),
                    const SizedBox(height: 8),
                    if (active.isEmpty)
                      const _FriendsEmptyLabel(text: 'Aucun duel en cours.')
                    else
                      ...active.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DuelHubRow(
                            uid: currentUid,
                            duel: {'id': doc.id, ...doc.data()},
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PronoDuelDetailPage(
                                  duelId: doc.id,
                                  currentUid: currentUid,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _FriendsSectionTitle(
                      title: 'Termines',
                      count: finished.length,
                      chipColor: pronoSocialDuel,
                    ),
                    const SizedBox(height: 8),
                    if (finished.isEmpty)
                      const _FriendsEmptyLabel(text: 'Aucun duel termine.')
                    else
                      ...finished.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DuelHubRow(
                            uid: currentUid,
                            duel: {'id': doc.id, ...doc.data()},
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PronoDuelDetailPage(
                                  duelId: doc.id,
                                  currentUid: currentUid,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DuelRivalStat>>(
            future: PronoSocialService.duelRivalStatsAmongFriends(currentUid),
            builder: (context, rivalSnap) {
              if (rivalSnap.connectionState == ConnectionState.waiting) {
                return PronoSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FriendsSectionTitle(
                        title: 'Classement avec tes potes',
                        count: 0,
                        chipColor: pronoSocialDuel,
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            color: pronoSocialDuel,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final rivals = rivalSnap.data ?? const <DuelRivalStat>[];
              return PronoSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FriendsSectionTitle(
                      title: 'Classement avec tes potes',
                      count: rivals.length,
                      chipColor: pronoSocialDuel,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uniquement tes amis confirmés. Points duel : 3 par victoire, '
                      '1 par nul (duels terminés).',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pronoMutedText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rivals.isEmpty)
                      Text(
                        'Ajoute des amis dans l’onglet Social, puis termine des duels avec eux : '
                        'leurs noms et points apparaîtront ici (ex. Thibault 3 pts, Axel 1 pt).',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: pronoMutedText,
                          height: 1.4,
                        ),
                      )
                    else
                      ...rivals.take(20).toList().asMap().entries.map((e) {
                        final rank = e.key + 1;
                        final r = e.value;
                        final pts = r.duelPoints;
                        final ptsLabel = pts == 1
                            ? '1 point'
                            : pts == 0
                                ? '0 point'
                                : '$pts points';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: pronoSurfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pronoBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#$rank',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: rank <= 3
                                          ? pronoSocialDuel
                                          : pronoText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.opponentName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: pronoText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${r.wins}V · ${r.draws}N · ${r.losses}D',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: pronoMutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  ptsLabel,
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: pronoSocialDuel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PronoLeaguesPage extends StatefulWidget {
  final String currentUid;
  final String displayName;

  const PronoLeaguesPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  State<PronoLeaguesPage> createState() => _PronoLeaguesPageState();
}

class _PronoLeaguesPageState extends State<PronoLeaguesPage> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'LIGUES',
      subtitle: 'Crée une ligue, partage le code, ouvre le classement dans chaque fiche.',
      pageAccent: pronoSocialLeague,
      innerAccent: pronoGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SocialNextStepCard(
            eyebrow: 'EN BREF',
            title: 'Mini-championnat entre amis',
            body:
                'Même règles de points que le global : ici tu ne vois que les membres de la ligue.',
            actionLabel: '1 CODE = TOUT LE MONDE ENTRE',
            accent: pronoSocialLeague,
          ),
          const SizedBox(height: 12),
          _SocialActivityFeedCard(uid: widget.currentUid),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.leaguesForUser(widget.currentUid),
            builder: (context, snap) {
              final leagues = snap.data?.docs ?? const [];
              return PronoSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FriendsSectionTitle(
                      title: 'Créer une ligue',
                      count: 0,
                      chipColor: pronoSocialLeague,
                    ),
                    const SizedBox(height: 8),
                    _SocialField(
                      controller: _nameCtrl,
                      label: 'Nom de la ligue',
                      focusColor: pronoSocialLeague,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final code = await PronoSocialService.createLeague(
                          ownerUid: widget.currentUid,
                          ownerName: widget.displayName,
                          name: name,
                        );
                        if (!context.mounted) return;
                        if (code == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Ce nom de ligue est déjà utilisé (même nom, espaces ignorés, insensible à la casse).',
                              ),
                              backgroundColor: _kRed,
                            ),
                          );
                          return;
                        }
                        _nameCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ligue creee. Code invitation : $code',
                            ),
                            backgroundColor: _kGreen,
                          ),
                        );
                      },
                      child: _PrimaryAction(
                        label: 'CREER MA LIGUE',
                        backgroundColor: pronoSocialLeague,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FriendsSectionTitle(
                      title: 'Rejoindre avec un code',
                      count: 0,
                      chipColor: pronoSocialLeague,
                    ),
                    const SizedBox(height: 8),
                    _SocialField(
                      controller: _codeCtrl,
                      label: 'Code de ligue',
                      focusColor: pronoSocialLeague,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final code = _codeCtrl.text.trim().toUpperCase();
                        if (code.isEmpty || _joining) return;
                        setState(() => _joining = true);
                        try {
                          final ok = await PronoSocialService.joinLeague(
                            uid: widget.currentUid,
                            displayName: widget.displayName,
                            code: code,
                          );
                          if (ok) _codeCtrl.clear();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Ligue rejointe avec succes.'
                                    : 'Code de ligue introuvable.',
                              ),
                              backgroundColor: ok ? _kGreen : _kRed,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _joining = false);
                        }
                      },
                      child: _SecondaryAction(
                        label: _joining
                            ? 'REJOINDRE...'
                            : 'REJOINDRE AVEC LE CODE',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FriendsSectionTitle(
                      title: 'Mes ligues',
                      count: leagues.length,
                      chipColor: pronoSocialLeague,
                    ),
                    const SizedBox(height: 8),
                    if (leagues.isEmpty)
                      const _FriendsEmptyLabel(
                        text: 'Tu n es dans aucune ligue pour le moment.',
                      )
                    else
                      ...leagues.map((league) {
                        final data = league.data();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CompactSocialRow(
                            title: (data['name'] ?? 'Ligue privee').toString(),
                            subtitle:
                                'Code ${(data['code'] ?? '-')} · ${(data['memberCount'] ?? 0)} membre(s)',
                            action: 'OUVRIR',
                            actionColor: pronoSocialLeague,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PronoLeagueDetailPage(
                                  leagueId: league.id,
                                  league: data,
                                  currentUid: widget.currentUid,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PronoLeaderboardPage extends StatelessWidget {
  final String currentUid;

  const PronoLeaderboardPage({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: PronoLbStyle.bg,
      appBar: AppBar(
        backgroundColor: PronoLbStyle.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: pronoText,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: _SocialAppBarTitle(
          title: 'CLASSEMENT',
          subtitle: 'Top 50 · points & scores exacts',
          accent: pronoGold,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Color.lerp(pronoGold, pronoBorder, 0.5)!.withValues(alpha: 0.9),
          ),
        ),
      ),
      body: PronoSocialPageAccent(
        stripeAccent: pronoGold,
        innerAccent: pronoGreen,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('prono_leaderboard')
            .orderBy('points', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: pronoGreen,
                strokeWidth: 2,
              ),
            );
          }
          final docs =
              snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final myIndex = docs.indexWhere((d) => d.id == currentUid);
          final myRank = myIndex >= 0 ? myIndex + 1 : null;

          if (docs.isEmpty) {
            return ListView(
              padding: EdgeInsets.fromLTRB(14, 14, 14, bottom),
              children: const [
                PronoLbTitleBlock(
                  title: 'CLASSEMENT PRONOS',
                  subtitle: 'Aucune entrée pour le moment.',
                ),
              ],
            );
          }

          List<Widget> rowSlice(int start, int endIncl) {
            final out = <Widget>[];
            for (var i = start; i <= endIncl && i < docs.length; i++) {
              final d = docs[i];
              final data = d.data();
              final rank = i + 1;
              out.add(
                PronoLbDataRow(
                  displayRank: rank,
                  title: (data['displayName'] ?? 'Membre').toString(),
                  points: (data['points'] as num?)?.toInt() ?? 0,
                  exactScores: (data['exactScores'] as num?)?.toInt() ?? 0,
                  podiumHighlight: rank <= 3,
                  isMe: uid != null && d.id == uid,
                ),
              );
            }
            return out;
          }

          final inTop20 = myRank != null && myRank >= 1 && myRank <= 20;
          final showPeloton620 = inTop20 && docs.length > 5;
          final showNeighbor =
              myRank != null && myRank > 20 && myRank <= docs.length;
          final secondBlock = showPeloton620 || showNeighbor;

          final tableChildren = <Widget>[
            const PronoLbColumnHeader(
              nameLabel: 'Pronostiqueur',
              showExactColumn: true,
            ),
          ];

          if (uid != null) {
            tableChildren.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PronoLbStyle.green,
                    side: BorderSide(
                      color: PronoLbStyle.green.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: Text(
                    'Partager ma place',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    Map<String, dynamic>? myData;
                    if (myIndex >= 0) myData = docs[myIndex].data();
                    final pts = (myData?['points'] as num?)?.toInt() ?? 0;
                    final ex = (myData?['exactScores'] as num?)?.toInt() ?? 0;
                    final name = myData?['displayName']?.toString();
                    DvcrShare.share(
                      ShareHelper.tournamentRankingShareText(
                        tournamentLabel: 'Classement global DVCR',
                        rank: myRank,
                        points: pts,
                        exactScores: ex,
                        displayName: name,
                      ),
                    );
                  },
                ),
              ),
            );
          }

          tableChildren.addAll(rowSlice(0, math.min(4, docs.length - 1)));

          if (secondBlock) {
            final label = showNeighbor
                ? 'Rang $myRank · autour de toi'
                : '6e – ${math.min(20, docs.length)}e place';
            tableChildren.add(PronoLbZoneDivider(label: label));
            if (showNeighbor) {
              final lo = math.max(5, myIndex - 3);
              final hi = math.min(docs.length - 1, myIndex + 3);
              tableChildren.addAll(rowSlice(lo, hi));
            } else {
              tableChildren.addAll(rowSlice(5, math.min(19, docs.length - 1)));
            }
            if (showNeighbor) {
              tableChildren.add(
                PronoLbFootnote(
                  text:
                      'Podium fixe + fenêtre autour du $myRankᵉ rang : pas de liste interminable.',
                ),
              );
            }
          } else {
            tableChildren.add(
              PronoLbFootnote(
                text: uid == null
                    ? 'Connecte-toi : on t’affiche le podium puis ta zone dans le classement.'
                    : myRank == null
                        ? 'Tu n’es pas encore dans le top 50 affiché ici — continue à pronostiquer pour remonter.'
                        : (myRank <= 5)
                            ? 'Tu es dans le top 5 — le bloc 6–20 apparaît dès qu’il y a assez de monde classé.'
                            : 'Tu es dans le top 20 mais le peloton au-delà du podium n’a pas encore assez de lignes.',
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(12, 10, 12, bottom),
            children: [
              const PronoLbTitleBlock(
                title: 'CLASSEMENT PRONOS',
                subtitle:
                    'Classement global saison : tes points viennent uniquement de tes pronos championnat sur les matchs (scores exacts en colonne à part). '
                    'On affiche le podium (top 5), puis la zone 6ᵉ–20ᵉ si tu y es ; sinon un court extrait autour de ton rang pour garder l’écran lisible.',
              ),
              PronoLbTableShell(children: tableChildren),
              const SizedBox(height: 14),
              _SocialActivityFeedCard(uid: currentUid),
            ],
          );
        },
        ),
      ),
    );
  }
}

/// Classement global des ligues (champ `rankingStats` alimenté par Cloud Function).
class PronoTopLeaguesPage extends StatelessWidget {
  final String currentUid;

  const PronoTopLeaguesPage({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'TOP LIGUES',
      subtitle: 'Puissance = somme des points prono des membres.',
      pageAccent: pronoSocialTopLeaguesBlue,
      innerAccent: pronoGreen,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: PronoSocialService.topLeaguesByMemberPointsStream(limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: pronoSocialTopLeaguesBlue,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (snap.hasError) {
            return PronoSectionCard(
              child: Text(
                'Impossible de charger le classement. Réessaie plus tard.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: pronoMutedText,
                  height: 1.4,
                ),
              ),
            );
          }
          final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (docs.isEmpty) {
            return PronoSectionCard(
              child: Text(
                'Aucune ligue pour l’instant. Les scores agrégés apparaîtront après la prochaine mise à jour serveur.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: pronoMutedText,
                  height: 1.4,
                ),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PronoLbTitleBlock(
                title: 'TOP LIGUES',
                subtitle:
                    'Somme des points prono des membres — podium comme le classement global.',
              ),
              PronoLbTableShell(
                children: [
                  const PronoLbColumnHeader(
                    nameLabel: 'Ligue privée',
                    showExactColumn: false,
                  ),
                  ...docs.asMap().entries.map((e) {
                    final i = e.key;
                    final doc = e.value;
                    final data = doc.data();
                    final stats =
                        (data['rankingStats'] as Map<String, dynamic>?) ??
                            const {};
                    final sum =
                        (stats['memberPointsSum'] as num?)?.toInt() ?? 0;
                    final members = (stats['memberCount'] as num?)?.toInt() ??
                        ((data['memberIds'] as List?)?.length ?? 0);
                    final name = (data['name'] ?? 'Ligue').toString();
                    final code = (data['code'] ?? '').toString();
                    final memberIds =
                        (data['memberIds'] as List?)?.whereType<String>().toList() ??
                            const <String>[];
                    final mine = memberIds.contains(currentUid);
                    return PronoLbDataRow(
                      displayRank: i + 1,
                      title: name,
                      subtitle:
                          '$members membres${code.isNotEmpty ? ' · code $code' : ''}${mine ? ' · ta ligue' : ''}',
                      points: sum,
                      exactScores: null,
                      showExactColumn: false,
                      podiumHighlight: i < 3,
                      isMe: mine,
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class PronoLeagueDetailPage extends StatefulWidget {
  final String leagueId;
  final Map<String, dynamic> league;
  final String currentUid;

  const PronoLeagueDetailPage({
    super.key,
    required this.leagueId,
    required this.league,
    required this.currentUid,
  });

  @override
  State<PronoLeagueDetailPage> createState() => _PronoLeagueDetailPageState();
}

class _PronoLeagueDetailPageState extends State<PronoLeagueDetailPage> {
  bool _sedanOnly = false;

  @override
  Widget build(BuildContext context) {
    final memberIds = (widget.league['memberIds'] as List?) ?? const [];
    final ownerUid = (widget.league['ownerUid'] ?? '').toString();
    final memberCount =
        (widget.league['memberCount'] as num?)?.toInt() ?? memberIds.length;

    return _PronoSocialPageScaffold(
      title: (widget.league['name'] ?? 'Ligue privee').toString(),
      subtitle:
          'Code ${(widget.league['code'] ?? '-')} · $memberCount membre(s)',
      pageAccent: pronoSocialLeague,
      innerAccent: pronoGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Classement interne : bascule « Tous » / « Sedan » pour le même classement, deux filtres de matchs.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pronoMutedText,
                height: 1.4,
              ),
            ),
          ),
          FutureBuilder<List<LeagueStandingEntry>>(
            future: PronoSocialService.leagueLeaderboardFiltered(
              memberIds,
              sedanOnly: _sedanOnly,
            ),
            builder: (context, snap) {
              final rows = snap.data ?? const <LeagueStandingEntry>[];
              return PronoSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LeagueSummaryStat(
                            label: 'MEMBRES',
                            value: '$memberCount',
                            accent: _kText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LeagueSummaryStat(
                            label: 'TABLEAU',
                            value: _sedanOnly ? 'SEDAN' : 'TOUS',
                            accent: pronoSocialLeague,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _sedanOnly = false),
                            child: _CompactSocialRow(
                              title: 'Tous les pronos',
                              subtitle: 'Classement complet',
                              action: !_sedanOnly ? 'ACTIF' : 'VOIR',
                              actionColor: pronoSocialLeague,
                              onTap: () => setState(() => _sedanOnly = false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _sedanOnly = true),
                            child: _CompactSocialRow(
                              title: 'Sedan',
                              subtitle: 'Pronos Sedan uniquement',
                              action: _sedanOnly ? 'ACTIF' : 'VOIR',
                              actionColor: pronoSocialLeague,
                              onTap: () => setState(() => _sedanOnly = true),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: pronoSocialLeague,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (rows.isEmpty)
                      const _FriendsEmptyLabel(
                        text: 'Aucun classement pour le moment.',
                      )
                    else ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: PronoLbTitleBlock(
                          title: 'CLASSEMENT LIGUE',
                          subtitle:
                              'Même présentation que le global : rang, points, scores exacts.',
                        ),
                      ),
                      PronoLbTableShell(
                        children: [
                          const PronoLbColumnHeader(
                            nameLabel: 'Pronostiqueur',
                            showExactColumn: true,
                          ),
                          ...rows.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            final isMe = row.uid == widget.currentUid;
                            return PronoLbDataRow(
                              displayRank: index + 1,
                              title:
                                  row.displayName + (isMe ? ' (moi)' : ''),
                              subtitle:
                                  '${row.totalPredictions} pronos · ${row.goodResults} bons résultats',
                              points: row.points,
                              exactScores: row.exactScores,
                              podiumHighlight: index < 3,
                              isMe: isMe,
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _LeagueHistorySection(
                      memberIds: memberIds,
                      currentUid: widget.currentUid,
                    ),
                    if (ownerUid == widget.currentUid) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await PronoSocialService.deleteLeague(
                            leagueId: widget.leagueId,
                            ownerUid: widget.currentUid,
                          );
                          if (context.mounted) Navigator.of(context).maybePop();
                        },
                        child: _SecondaryAction(label: 'SUPPRIMER LA LIGUE'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PronoDuelDetailPage extends StatelessWidget {
  final String duelId;
  final String currentUid;

  const PronoDuelDetailPage({
    super.key,
    required this.duelId,
    required this.currentUid,
  });

  static String _pickPreview(Map<String, dynamic>? p) {
    if (p == null) return '—';
    final a = p['score1'];
    final b = p['score2'];
    if (a == null || b == null) return '—';
    return '$a-$b';
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'DETAIL DUEL',
      subtitle:
          'Scores affichés = picks duel (fun), pas le prono championnat.',
      pageAccent: pronoSocialDuel,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: PronoSocialService.duelStream(duelId),
        builder: (context, snap) {
          final duel = snap.data?.data();
          if (duel == null) {
            return PronoSectionCard(
              child: Text(
                'Duel introuvable',
                style: GoogleFonts.inter(color: _kText),
              ),
            );
          }
          final status = (duel['status'] ?? 'pending').toString();
          final label = status == 'won'
              ? ((duel['winnerUid'] == currentUid) ? 'GAGNE' : 'PERDU')
              : status == 'draw'
              ? 'NUL'
              : status == 'cancelled'
              ? 'ANNULE'
              : status == 'in_progress'
              ? 'EN COURS'
              : 'EN ATTENTE';
          final canEditPick = status == 'pending' || status == 'in_progress';

          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: PronoSocialService.duelPicksStream(duelId),
            builder: (context, pickSnap) {
              final picks = pickSnap.data ?? const <String, Map<String, dynamic>>{};
              final ownerUid = (duel['ownerUid'] ?? '').toString();
              final oppUid = (duel['opponentUid'] ?? '').toString();
              final ownerPick = picks[ownerUid];
              final oppPick = picks[oppUid];

              final ownerScoreStr = duel['ownerScore'] != null
                  ? duel['ownerScore'].toString()
                  : _pickPreview(ownerPick);
              final oppScoreStr = duel['opponentScore'] != null
                  ? duel['opponentScore'].toString()
                  : _pickPreview(oppPick);

              return PronoSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (duel['matchLabel'] ?? 'Duel prive').toString(),
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(label: label, accent: pronoSocialDuel),
                    const SizedBox(height: 10),
                    Text(
                      'Les points duel (3 / 1 / 0) sont calculés comme en championnat, '
                      'mais à partir des scores saisis ici uniquement.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kMutedText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _LeagueSummaryStat(
                            label: 'STATUT',
                            value: label,
                            accent: label == 'GAGNE'
                                ? _kGreen
                                : label == 'PERDU'
                                ? _kRed
                                : pronoSocialDuel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LeagueSummaryStat(
                            label: 'RECOMPENSE',
                            value: '+${duel['duelXpReward'] ?? 3} XP',
                            accent: pronoReward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DuelLine(
                      name: (duel['ownerName'] ?? 'Joueur 1').toString(),
                      score: ownerScoreStr,
                      points: duel['ownerPoints']?.toString() ?? '-',
                    ),
                    const SizedBox(height: 8),
                    _DuelLine(
                      name: (duel['opponentName'] ?? 'Joueur 2').toString(),
                      score: oppScoreStr,
                      points: duel['opponentPoints']?.toString() ?? '-',
                    ),
                    if (canEditPick) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PronoDuelPickPage(
                                duelId: duelId,
                                currentUid: currentUid,
                                matchLabel:
                                    (duel['matchLabel'] ?? 'Duel').toString(),
                              ),
                            ),
                          );
                        },
                        child: _PrimaryAction(
                          label: 'MON SCORE DUEL',
                          backgroundColor: pronoSocialDuel,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Saisie du score « fun » pour un duel (sous-collection `duel_picks`), hors prono championnat.
class PronoDuelPickPage extends StatefulWidget {
  final String duelId;
  final String currentUid;
  final String matchLabel;

  const PronoDuelPickPage({
    super.key,
    required this.duelId,
    required this.currentUid,
    required this.matchLabel,
  });

  @override
  State<PronoDuelPickPage> createState() => _PronoDuelPickPageState();
}

class _PronoDuelPickPageState extends State<PronoDuelPickPage> {
  final _home = TextEditingController();
  final _away = TextEditingController();
  bool _loading = true;

  @override
  void dispose() {
    _home.dispose();
    _away.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final doc = await FirebaseFirestore.instance
        .collection('prono_duels')
        .doc(widget.duelId)
        .collection('duel_picks')
        .doc(widget.currentUid)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      final d = doc.data() ?? {};
      _home.text = '${d['score1'] ?? ''}';
      _away.text = '${d['score2'] ?? ''}';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final n1 = int.tryParse(_home.text.trim());
    final n2 = int.tryParse(_away.text.trim());
    if (n1 == null || n2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kRed,
          content: Text(
            'Entre deux nombres entiers (0-99).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      );
      return;
    }
    await PronoSocialService.saveDuelPick(
      duelId: widget.duelId,
      uid: widget.currentUid,
      score1: n1,
      score2: n2,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _PronoSocialPageScaffold(
        title: 'SCORE DUEL',
        subtitle: widget.matchLabel,
        pageAccent: pronoSocialDuel,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(
              color: pronoSocialDuel,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    return _PronoSocialPageScaffold(
      title: 'SCORE DUEL',
      subtitle:
          '${widget.matchLabel} — réservé au duel, sans impact sur ton classement prono.',
      pageAccent: pronoSocialDuel,
      child: PronoSectionCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu peux mettre un score irréaliste (ex. 10-0) : seul le duel l’utilise.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kMutedText,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _home,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: _kSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '—',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _away,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kText,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: _kSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _save,
              child: _PrimaryAction(
                label: 'ENREGISTRER MON SCORE DUEL',
                backgroundColor: pronoSocialDuel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PronoDuelFriendPickerPage extends StatelessWidget {
  final String currentUid;
  final String displayName;

  const PronoDuelFriendPickerPage({
    super.key,
    required this.currentUid,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'DUEL — CHOISIR UN AMI',
      subtitle:
          'Amis confirmés uniquement. Tu saisiras ensuite un score duel séparé du championnat.',
      pageAccent: pronoSocialDuel,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: PronoSocialService.userDocStream(currentUid),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data();
          final social =
              (userData?['social'] as Map<String, dynamic>?) ?? const {};
          final friendNames =
              (social['friendNames'] as Map<String, dynamic>?) ?? const {};
          final friendIds =
              (social['friends'] as List?)?.whereType<String>().toList() ??
              const <String>[];

          if (friendIds.isEmpty) {
            return PronoSectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FriendsEmptyLabel(
                    text:
                        'Aucun ami confirmé. Ajoute-en un dans Amis, puis reviens ici.',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PronoFriendsPage(
                          currentUid: currentUid,
                          displayName: displayName,
                        ),
                      ),
                    ),
                    child: _PrimaryAction(
                      label: 'ALLER AUX AMIS',
                      backgroundColor: pronoSocialFriend,
                    ),
                  ),
                ],
              ),
            );
          }

          return PronoSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: friendIds.map((friendUid) {
                final friendName =
                    (friendNames[friendUid] ?? 'Ami DVCR').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactSocialRow(
                    title: friendName,
                    subtitle:
                        'Tu choisis le match, puis ton score duel (indépendant du prono).',
                    action: 'SUIVANT',
                    actionColor: pronoSocialDuel,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PronoDuelMatchPickerPage(
                          currentUid: currentUid,
                          currentName: displayName,
                          opponentUid: friendUid,
                          opponentName: friendName,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class PronoDuelMatchPickerPage extends StatelessWidget {
  final String currentUid;
  final String currentName;
  final String opponentUid;
  final String opponentName;

  const PronoDuelMatchPickerPage({
    super.key,
    required this.currentUid,
    required this.currentName,
    required this.opponentUid,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'LANCER UN DUEL',
      subtitle:
          'Match pour défier $opponentName — après la création, tu saisis '
          'un score duel fun (0-99), indépendant de ton prono championnat.',
      pageAccent: pronoSocialDuel,
      child: StreamBuilder<List<MatchModel>>(
        stream: MatchService.allUpcoming(),
        builder: (context, snap) {
          final now = DateTime.now();
          final matches = (snap.data ?? const <MatchModel>[]).where((m) {
            final daysLeft = m.date.difference(now).inDays;
            return now.isBefore(m.date) && daysLeft <= 7;
          }).toList();

          if (matches.isEmpty) {
            return PronoSectionCard(
              child: const _FriendsEmptyLabel(
                text: 'Aucun match ouvert aux pronos pour le moment.',
              ),
            );
          }

          return PronoSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: matches.map((match) {
                final label = '${match.team1} vs ${match.team2}';
                final dateStr =
                    '${match.date.day}/${match.date.month}/${match.date.year}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactSocialRow(
                    title: label,
                    subtitle: dateStr,
                    action: 'CHOISIR',
                    actionColor: pronoSocialDuel,
                    onTap: () async {
                      final duelId = await PronoSocialService.createDuel(
                        ownerUid: currentUid,
                        ownerName: currentName,
                        opponentUid: opponentUid,
                        opponentName: opponentName,
                        matchId: match.id,
                        matchLabel: label,
                      );
                      if (!context.mounted) return;
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => PronoDuelPickPage(
                            duelId: duelId,
                            currentUid: currentUid,
                            matchLabel: label,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      if (saved == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Défi envoyé à $opponentName — score duel enregistré',
                            ),
                            backgroundColor: _kGreen,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Duel créé : complète ton score depuis Duels > détail du duel.',
                            ),
                            backgroundColor: pronoSocialDuel,
                          ),
                        );
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
