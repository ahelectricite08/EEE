part of 'prono_screen.dart';

const _socialPageAccent = PronoPageAccent.social;

class _SocialAppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SocialAppBarTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final stripe = PronoTokens.pageBarStripeColors(_socialPageAccent);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 32,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: stripe,
            ),
          ),
        ),
        Flexible(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                    height: 0.95,
                    letterSpacing: 0.3,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PronoTokens.textMuted,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _socialAppBarStripeHeight = 2.0;
const _socialAppBarBorderHeight = 1.0;

double _socialAppBarHeight(BuildContext context) {
  final topPad = MediaQuery.paddingOf(context).top;
  return topPad +
      kToolbarHeight +
      _socialAppBarStripeHeight +
      _socialAppBarBorderHeight;
}

PreferredSizeWidget _buildSocialPageAppBar({
  required BuildContext context,
  required String title,
  required String subtitle,
}) {
  final accent = _socialPageAccent.color;
  final topPad = MediaQuery.paddingOf(context).top;
  final toolbarBlock = kToolbarHeight + _socialAppBarBorderHeight;

  return PreferredSize(
    preferredSize: Size.fromHeight(_socialAppBarHeight(context)),
    child: Material(
      color: PronoTokens.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPad),
          Container(height: _socialAppBarStripeHeight, color: accent),
          SizedBox(
            height: toolbarBlock,
            child: AppBar(
              // Safe-area already applied via SizedBox(topPad) above.
              // primary:true would nest another SafeArea and squash the
              // toolbar inside this fixed-height box (broken social headers).
              primary: false,
              backgroundColor: PronoTokens.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: kToolbarHeight,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: PronoTokens.text,
                  size: 18,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              leadingWidth: 48,
              titleSpacing: 0,
              centerTitle: false,
              title: Align(
                alignment: Alignment.centerLeft,
                child: _SocialAppBarTitle(
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              bottom: PreferredSize(
                preferredSize:
                    const Size.fromHeight(_socialAppBarBorderHeight),
                child: Container(
                  height: _socialAppBarBorderHeight,
                  color: PronoTokens.border,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

const _leaderboardIntro =
    'Classement saison prono DVCR : points cumulés sur tous les matchs championnat (hors duels).';
const _leaderboardBullets = <String>[
  '3 pts score exact · 1 pt bon résultat 1-X-2 · 0 pt sinon',
  'Top 20 + ta place (et tes voisins) — mis à jour après chaque match.',
];

class _SocialPageIntro extends StatelessWidget {
  final String text;
  final List<String> bullets;

  const _SocialPageIntro({
    required this.text,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    final accent = _socialPageAccent.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PronoTokens.surface,
        borderRadius: BorderRadius.circular(PronoTokens.radiusMd),
        border: Border.all(color: PronoTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: accent,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PronoTokens.text,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        bullet,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PronoTokens.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardEmptyCard extends StatelessWidget {
  const _LeaderboardEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: PronoTokens.tileFillDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: PronoTokens.iconBadgeDecoration(
              radius: 12,
              accent: PronoIconAccent.social,
            ),
            child: Icon(
              Icons.leaderboard_rounded,
              color: _socialPageAccent.color,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pas encore de classement',
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PronoTokens.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dès qu’un match est joué, les points sont calculés et les pronostiqueurs apparaissent ici.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: PronoTokens.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PronoSocialPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PronoSocialPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PronoThemeScope(
      pageAccent: _socialPageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildSocialPageAppBar(
            context: context,
            title: title,
            subtitle: subtitle,
          ),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              clipBehavior: Clip.hardEdge,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottom),
                  sliver: SliverToBoxAdapter(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
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
  bool _searching = false;
  bool _didSearch = false;
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _didSearch = true;
        _searchError = 'Saisis au moins 2 caractères.';
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _didSearch = true;
    });
    try {
      final found = await PronoSocialService.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = found
            .where((user) => (user['uid'] ?? '') != widget.currentUid)
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
        _searchError = 'Recherche impossible. Réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'AMIS',
      subtitle: 'Invitations, amis confirmés et recherche.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.userDocStream(widget.currentUid),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final social =
                  (userData?['social'] as Map<String, dynamic>?) ?? const {};
              final friendNames =
                  (social['friendNames'] as Map<String, dynamic>?) ?? const {};
              final friendIds =
                  (social['friends'] as List?)?.whereType<String>().toList() ??
                  const <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.friendRequestsForUser(
                  widget.currentUid,
                ),
                builder: (context, receivedSnap) {
                  final received = receivedSnap.data?.docs ?? const [];
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: PronoSocialService.sentFriendRequestsForUser(
                      widget.currentUid,
                    ),
                    builder: (context, sentSnap) {
                      final sent = sentSnap.data?.docs ?? const [];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (received.isNotEmpty) ...[
                            _SocialSectionHeader(
                              title: 'Demandes reçues',
                              count: received.length,
                            ),
                            ...received.map((request) {
                              final data = request.data();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PendingFriendRow(
                                  requestId: request.id,
                                  currentUid: widget.currentUid,
                                  currentName: widget.displayName,
                                  otherUid:
                                      (data['fromUid'] ?? '').toString(),
                                  otherName:
                                      (data['fromName'] ?? 'Utilisateur')
                                          .toString(),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (sent.isNotEmpty) ...[
                            _SocialSectionHeader(
                              title: 'Invitations envoyées',
                              count: sent.length,
                            ),
                            ...sent.map((request) {
                              final data = request.data();
                              return _SocialListTile(
                                title: (data['toName'] ?? 'Utilisateur')
                                    .toString(),
                                subtitle: 'En attente de réponse',
                                leadingInitial:
                                    (data['toName'] ?? 'U').toString(),
                                trailing: Text(
                                  'EN ATTENTE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: PronoTokens.textMuted,
                                  ),
                                ),
                                onTap: () {},
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          _SocialSectionHeader(
                            title: 'Amis confirmés',
                            count: friendIds.length,
                          ),
                          if (friendIds.isEmpty)
                            const _FriendsEmptyLabel(
                              text: 'Aucun ami confirmé pour le moment.',
                            )
                          else
                            ...friendIds.map((friendUid) {
                              final friendName =
                                  (friendNames[friendUid] ?? 'Ami DVCR')
                                      .toString();
                              return _SocialListTile(
                                title: friendName,
                                subtitle: 'Défier en duel',
                                leadingInitial: friendName,
                                trailing: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PronoDuelMatchPickerPage(
                                        currentUid: widget.currentUid,
                                        currentName: widget.displayName,
                                        opponentUid: friendUid,
                                        opponentName: friendName,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _socialPageAccent.color
                                          .withAlpha(22),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _socialPageAccent.color
                                            .withAlpha(80),
                                      ),
                                    ),
                                    child: Text(
                                      'DÉFIER',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _socialPageAccent.color,
                                      ),
                                    ),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PronoDuelMatchPickerPage(
                                      currentUid: widget.currentUid,
                                      currentName: widget.displayName,
                                      opponentUid: friendUid,
                                      opponentName: friendName,
                                    ),
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
          const SizedBox(height: 16),
          _SocialSectionHeader(title: 'Ajouter un ami'),
          _SocialField(
            controller: _searchCtrl,
            label: 'Pseudo, prénom ou email',
            focusColor: _socialPageAccent.color,
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _searching ? null : _search,
            child: Opacity(
              opacity: _searching ? 0.7 : 1,
              child: _PrimaryAction(
                label: _searching ? 'RECHERCHE…' : 'RECHERCHER',
                backgroundColor: _socialPageAccent.color,
              ),
            ),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            _FriendsEmptyLabel(text: _searchError!),
          ] else if (_didSearch && !_searching && _results.isEmpty) ...[
            const SizedBox(height: 12),
            const _FriendsEmptyLabel(
              text:
                  'Aucun inscrit trouvé. Essaie le prénom / pseudo (début du nom) ou l’email exact du compte.',
            ),
          ] else if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._results.map((user) {
              final otherUid = (user['uid'] ?? '').toString();
              final otherName = PronoSocialService.resolveDisplayName(
                data: user,
                fallback: UserRole.teamDvcr.displayName,
              );
              return _SocialListTile(
                title: otherName,
                subtitle: 'Envoyer une invitation',
                leadingInitial: otherName,
                trailing: GestureDetector(
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
                  child: Text(
                    'AJOUTER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _socialPageAccent.color,
                    ),
                  ),
                ),
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
              );
            }),
          ],
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
      subtitle: 'Scores fun réservés au duel — pas le prono championnat.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              label: 'LANCER UN DUEL',
              backgroundColor: _socialPageAccent.color,
            ),
          ),
          const SizedBox(height: 8),
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
            child: const _SecondaryAction(label: 'OUVRIR LA LISTE D’AMIS'),
          ),
          const SizedBox(height: 20),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SocialSectionHeader(
                    title: 'En attente',
                    count: pending.length,
                  ),
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
                  _SocialSectionHeader(
                    title: 'En cours',
                    count: active.length,
                  ),
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
                  _SocialSectionHeader(
                    title: 'Terminés',
                    count: finished.length,
                  ),
                  if (finished.isEmpty)
                    const _FriendsEmptyLabel(text: 'Aucun duel terminé.')
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
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<DuelRivalStat>>(
            future: PronoSocialService.duelRivalStatsAmongFriends(currentUid),
            builder: (context, rivalSnap) {
              if (rivalSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: PronoTokens.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }
              final rivals = rivalSnap.data ?? const <DuelRivalStat>[];
              if (rivals.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SocialSectionHeader(
                    title: 'Classement potes',
                    count: rivals.length,
                  ),
                  PronoLbTableShell(
                    children: [
                      const PronoLbColumnHeader(
                        nameLabel: 'Adversaire',
                        showExactColumn: false,
                      ),
                      ...rivals.take(20).toList().asMap().entries.map((e) {
                        final rank = e.key + 1;
                        final r = e.value;
                        return PronoLbDataRow(
                          displayRank: rank,
                          title: r.opponentName,
                          subtitle: '${r.wins}V · ${r.draws}N · ${r.losses}D',
                          points: r.duelPoints,
                          exactScores: null,
                          showExactColumn: false,
                          podiumHighlight: rank <= 3,
                          isMe: false,
                        );
                      }),
                    ],
                  ),
                ],
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
      subtitle: 'Mini-championnat entre amis — mêmes règles de points.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SocialField(
            controller: _nameCtrl,
            label: 'Nom de la ligue',
            focusColor: _socialPageAccent.color,
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
                  content: Text('Ligue créée. Code invitation : $code'),
                  backgroundColor: _kGreen,
                ),
              );
            },
            child: _PrimaryAction(
              label: 'CRÉER MA LIGUE',
              backgroundColor: _socialPageAccent.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SocialField(
                  controller: _codeCtrl,
                  label: 'Code de ligue',
                  focusColor: _socialPageAccent.color,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
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
                                ? 'Ligue rejointe avec succès.'
                                : 'Code de ligue introuvable.',
                          ),
                          backgroundColor: ok ? _kGreen : _kRed,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _joining = false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: PronoTokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PronoTokens.border),
                    ),
                    child: Text(
                      _joining ? '…' : 'REJOINDRE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: PronoTokens.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.leaguesForUser(widget.currentUid),
            builder: (context, snap) {
              final leagues = snap.data?.docs ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SocialSectionHeader(
                    title: 'Mes ligues',
                    count: leagues.length,
                  ),
                  if (leagues.isEmpty)
                    const _FriendsEmptyLabel(
                      text: 'Tu n’es dans aucune ligue pour le moment.',
                    )
                  else
                    ...leagues.map((league) {
                      final data = league.data();
                      return _SocialListTile(
                        title: (data['name'] ?? 'Ligue privée').toString(),
                        subtitle:
                            'Code ${(data['code'] ?? '-')} · ${(data['memberCount'] ?? 0)} membre(s)',
                        leadingIcon: Icons.groups_rounded,
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
                      );
                    }),
                ],
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
    return PronoThemeScope(
      pageAccent: _socialPageAccent,
      child: DecoratedBox(
        decoration: PronoTokens.scaffoldDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildSocialPageAppBar(
            context: context,
            title: 'CLASSEMENT',
            subtitle: 'Top 20 · ta place toujours visible',
          ),
          body: StreamBuilder<GlobalLeaderboardView>(
            stream: PronoSocialService.watchGlobalLeaderboardWindow(currentUid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, bottom),
                  children: const [
                    _SocialPageIntro(
                      text: _leaderboardIntro,
                      bullets: _leaderboardBullets,
                    ),
                    SizedBox(height: 32),
                    Center(
                      child: CircularProgressIndicator(
                        color: PronoTokens.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                );
              }

              final view = snap.data;
              if (view == null || view.top.isEmpty) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, bottom),
                  children: const [
                    _SocialPageIntro(
                      text: _leaderboardIntro,
                      bullets: _leaderboardBullets,
                    ),
                    SizedBox(height: 14),
                    _LeaderboardEmptyCard(),
                  ],
                );
              }

              Widget rowFor(GlobalLeaderboardRow r) {
                return PronoLbDataRow(
                  displayRank: r.rank,
                  title: r.displayName,
                  points: r.points,
                  exactScores: r.exactScores,
                  podiumHighlight: r.rank <= 3,
                  isMe: r.uid == currentUid,
                );
              }

              final tableChildren = <Widget>[
                const PronoLbColumnHeader(
                  nameLabel: 'Pronostiqueur',
                  showExactColumn: true,
                ),
              ];

              if (view.myRank != null && view.me != null) {
                tableChildren.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Text(
                      view.totalCount > 0
                          ? 'Tu es ${view.myRank}e sur ${view.totalCount}'
                          : 'Tu es ${view.myRank}e',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PronoTokens.text,
                      ),
                    ),
                  ),
                );
                tableChildren.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _socialPageAccent.color,
                        side: BorderSide(
                          color: _socialPageAccent.color.withValues(alpha: 0.45),
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
                        final me = view.me!;
                        DvcrShare.share(
                          ShareHelper.tournamentRankingShareText(
                            tournamentLabel: 'Classement global DVCR',
                            rank: view.myRank,
                            points: me.points,
                            exactScores: me.exactScores,
                            displayName: me.displayName,
                          ),
                          context: context,
                        );
                      },
                    ),
                  ),
                );
              } else {
                tableChildren.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Text(
                      'Pose ton premier prono pour apparaître au classement.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PronoTokens.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                );
              }

              for (final r in view.top) {
                tableChildren.add(rowFor(r));
              }

              if (view.neighbors.isNotEmpty) {
                tableChildren.add(const PronoLbZoneDivider(label: '…'));
                for (final r in view.neighbors) {
                  tableChildren.add(rowFor(r));
                }
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(20, 14, 20, bottom),
                children: [
                  const _SocialPageIntro(
                    text: _leaderboardIntro,
                    bullets: _leaderboardBullets,
                  ),
                  const SizedBox(height: 14),
                  PronoLbTableShell(children: tableChildren),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Classement global des ligues (puissance = somme points prono des membres).
///
/// Règle produit : toute ligue privée compte dès 1 membre (pas de seuil min).
/// Les points viennent de `prono_leaderboard` (agrégés dans `rankingStats`).
class PronoTopLeaguesPage extends StatelessWidget {
  final String currentUid;

  const PronoTopLeaguesPage({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return _PronoSocialPageScaffold(
      title: 'TOP LIGUES',
      subtitle: 'Puissance = somme des points prono des membres.',
      child: StreamBuilder<List<TopLeagueRow>>(
        stream: PronoSocialService.topLeaguesByMemberPointsStream(limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: PronoTokens.accent,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (snap.hasError) {
            return Text(
              'Impossible de charger le classement. Réessaie plus tard.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: PronoTokens.textMuted,
                height: 1.4,
              ),
            );
          }
          final rows = snap.data ?? const <TopLeagueRow>[];
          if (rows.isEmpty) {
            return Text(
              'Aucune ligue pour l’instant.\n'
              'Crée une ligue privée ou rejoins-en une avec un code — '
              'elle apparaîtra ici dès qu’elle existe (même avec 1 membre).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: PronoTokens.textMuted,
                height: 1.4,
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PronoLbTitleBlock(
                title: 'TOP LIGUES',
                subtitle: 'Somme des points prono des membres (dès 1 membre).',
              ),
              PronoLbTableShell(
                children: [
                  const PronoLbColumnHeader(
                    nameLabel: 'Ligue privée',
                    showExactColumn: false,
                  ),
                  ...rows.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    final mine = row.memberIds.contains(currentUid);
                    return PronoLbDataRow(
                      displayRank: i + 1,
                      title: row.name,
                      subtitle:
                          '${row.memberCount} membre${row.memberCount > 1 ? 's' : ''}'
                          '${mine ? ' · ta ligue' : ''}',
                      points: row.memberPointsSum,
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
    final isMember = memberIds.contains(widget.currentUid) ||
        ownerUid == widget.currentUid;
    final code = (widget.league['code'] ?? '').toString().trim();
    // Code visible uniquement pour membres / owner (pas pour une ligue adverse).
    final subtitle = isMember && code.isNotEmpty
        ? 'Code $code · $memberCount membre(s)'
        : '$memberCount membre(s)';

    return _PronoSocialPageScaffold(
      title: (widget.league['name'] ?? 'Ligue privée').toString(),
      subtitle: subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<LeagueStandingEntry>>(
            future: PronoSocialService.leagueLeaderboardFiltered(
              memberIds,
              sedanOnly: _sedanOnly,
            ),
            builder: (context, snap) {
              final rows = snap.data ?? const <LeagueStandingEntry>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sedanOnly = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_sedanOnly
                                  ? _socialPageAccent.color.withAlpha(22)
                                  : PronoTokens.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_sedanOnly
                                    ? _socialPageAccent.color.withAlpha(90)
                                    : PronoTokens.border,
                              ),
                            ),
                            child: Text(
                              'Tous',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: !_sedanOnly
                                    ? _socialPageAccent.color
                                    : PronoTokens.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sedanOnly = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _sedanOnly
                                  ? _socialPageAccent.color.withAlpha(22)
                                  : PronoTokens.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _sedanOnly
                                    ? _socialPageAccent.color.withAlpha(90)
                                    : PronoTokens.border,
                              ),
                            ),
                            child: Text(
                              'Sedan',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _sedanOnly
                                    ? _socialPageAccent.color
                                    : PronoTokens.textMuted,
                              ),
                            ),
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
                          color: PronoTokens.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (rows.isEmpty)
                    const _FriendsEmptyLabel(
                      text: 'Aucun classement pour le moment.',
                    )
                  else ...[
                    Builder(
                      builder: (context) {
                        final sliced = sliceLeaderboardWindow<LeagueStandingEntry>(
                          sortedEntries: rows,
                          uidOf: (e) => e.uid,
                          currentUid: widget.currentUid,
                        );
                        final plan = sliced.plan;
                        final children = <Widget>[
                          const PronoLbColumnHeader(
                            nameLabel: 'Pronostiqueur',
                            showExactColumn: true,
                          ),
                          if (plan.myRank != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Text(
                                'Tu es ${plan.myRank}e sur ${rows.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: PronoTokens.text,
                                ),
                              ),
                            ),
                          ...sliced.top.map((e) {
                            final row = e.data;
                            final isMe = row.uid == widget.currentUid;
                            return PronoLbDataRow(
                              displayRank: e.rank,
                              title: row.displayName + (isMe ? ' (moi)' : ''),
                              subtitle:
                                  '${row.totalPredictions} pronos · ${row.goodResults} bons résultats',
                              points: row.points,
                              exactScores: row.exactScores,
                              podiumHighlight: e.rank <= 3,
                              isMe: isMe,
                            );
                          }),
                          if (sliced.neighbors.isNotEmpty) ...[
                            const PronoLbZoneDivider(label: '…'),
                            ...sliced.neighbors.map((e) {
                              final row = e.data;
                              final isMe = row.uid == widget.currentUid;
                              return PronoLbDataRow(
                                displayRank: e.rank,
                                title:
                                    row.displayName + (isMe ? ' (moi)' : ''),
                                subtitle:
                                    '${row.totalPredictions} pronos · ${row.goodResults} bons résultats',
                                points: row.points,
                                exactScores: row.exactScores,
                                podiumHighlight: false,
                                isMe: isMe,
                              );
                            }),
                          ],
                        ];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PronoLbTitleBlock(
                              title: 'CLASSEMENT LIGUE',
                              subtitle: rows.length <= 20
                                  ? 'Rang, points, scores exacts.'
                                  : 'Top 20 · ta place toujours visible.',
                            ),
                            PronoLbTableShell(children: children),
                          ],
                        );
                      },
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
                      child: const _SecondaryAction(label: 'SUPPRIMER LA LIGUE'),
                    ),
                  ],
                ],
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
      title: 'DÉTAIL DUEL',
      subtitle: 'Scores duel fun — pas le prono championnat.',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: PronoSocialService.duelStream(duelId),
        builder: (context, snap) {
          final duel = snap.data?.data();
          if (duel == null) {
            return Text(
              'Duel introuvable',
              style: GoogleFonts.inter(color: PronoTokens.text),
            );
          }
          final status = (duel['status'] ?? 'pending').toString();
          final label = status == 'won'
              ? ((duel['winnerUid'] == currentUid) ? 'GAGNÉ' : 'PERDU')
              : status == 'draw'
                  ? 'NUL'
                  : status == 'cancelled'
                      ? 'ANNULÉ'
                      : status == 'in_progress'
                          ? 'EN COURS'
                          : 'EN ATTENTE';
          final canEditPick = status == 'pending' || status == 'in_progress';

          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: PronoSocialService.duelPicksStream(duelId),
            builder: (context, pickSnap) {
              final picks =
                  pickSnap.data ?? const <String, Map<String, dynamic>>{};
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

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: PronoTokens.tileFillDecoration(
                      radius: PronoTokens.radiusMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (duel['matchLabel'] ?? 'Duel privé').toString(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: PronoTokens.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusPill(
                          label: label,
                          accent: _socialPageAccent.color,
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
                        const SizedBox(height: 10),
                        Text(
                          '+${duel['duelXpReward'] ?? 3} XP si victoire',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PronoTokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEditPick) ...[
                    const SizedBox(height: 12),
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
                        backgroundColor: _socialPageAccent.color,
                      ),
                    ),
                  ],
                ],
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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(
              color: PronoTokens.accent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    return _PronoSocialPageScaffold(
      title: 'SCORE DUEL',
      subtitle: widget.matchLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _home,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: PronoTokens.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PronoTokens.border),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '—',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _away,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: PronoTokens.text,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: PronoTokens.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PronoTokens.border),
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
              label: 'ENREGISTRER',
              backgroundColor: _socialPageAccent.color,
            ),
          ),
        ],
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
      title: 'CHOISIR UN AMI',
      subtitle: 'Amis confirmés uniquement.',
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    backgroundColor: _socialPageAccent.color,
                  ),
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: friendIds.map((friendUid) {
              final friendName =
                  (friendNames[friendUid] ?? 'Ami DVCR').toString();
              return _SocialListTile(
                title: friendName,
                subtitle: 'Choisir le match ensuite',
                leadingInitial: friendName,
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
              );
            }).toList(),
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
      subtitle: 'Match pour défier $opponentName',
      child: StreamBuilder<List<MatchModel>>(
        stream: MatchService.allUpcoming(),
        builder: (context, snap) {
          final now = DateTime.now();
          final matches = (snap.data ?? const <MatchModel>[]).where((m) {
            final daysLeft = m.date.difference(now).inDays;
            return now.isBefore(m.date) && daysLeft <= 7;
          }).toList();

          if (matches.isEmpty) {
            return const _FriendsEmptyLabel(
              text: 'Aucun match ouvert aux pronos pour le moment.',
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: matches.map((match) {
              final label = '${match.team1} vs ${match.team2}';
              final dateStr =
                  '${match.date.day}/${match.date.month}/${match.date.year}';
              return _SocialListTile(
                title: label,
                subtitle: dateStr,
                leadingIcon: Icons.sports_soccer_rounded,
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
                          'Duel créé : complète ton score depuis Duels > détail.',
                        ),
                        backgroundColor: _socialPageAccent.color,
                      ),
                    );
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
