part of 'home_screen.dart';

class _PronoLeaderboardMiniCard extends StatelessWidget {
  final VoidCallback? onSeeAll;
  const _PronoLeaderboardMiniCard({this.onSeeAll});

  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .orderBy('points', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty && !snap.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
            ),
          );
        }
        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            children: [
              ...docs.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value.data() as Map<String, dynamic>;
                final name = d['displayName'] as String? ?? 'Supporter';
                final points = (d['points'] as num?)?.toInt() ?? 0;
                final exact = (d['exactScores'] as num?)?.toInt() ?? 0;
                final isTop3 = i < 3;
                final rankColor = isTop3 ? _medalColors[i] : _kGrey;
                final medal = i == 0
                    ? '🥇'
                    : i == 1
                    ? '🥈'
                    : i == 2
                    ? '🥉'
                    : null;

                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, color: _kBorder),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: medal != null
                                ? Text(
                                    medal,
                                    style: const TextStyle(fontSize: 18),
                                  )
                                : Text(
                                    '#${i + 1}',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: rankColor,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isTop3
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isTop3 ? _kText : _kGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (exact > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _kGreen.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _kGreen.withAlpha(60),
                                ),
                              ),
                              child: Text(
                                '$exact✓',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _kGreen,
                                ),
                              ),
                            ),
                          Text(
                            '$points pts',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: rankColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              if (onSeeAll != null) ...[
                Divider(height: 1, color: _kBorder),
                GestureDetector(
                  onTap: onSeeAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Voir le classement complet',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TournamentMiniCard extends StatelessWidget {
  final VoidCallback onOpenTab;

  const _TournamentMiniCard({required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TournamentService.activeTournamentsStream(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final doc = snap.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Tournoi';
        final emoji = data['emoji'] ?? '🏆';

        return StreamBuilder<List<TournamentEntry>>(
          stream: TournamentService.leaderboardStream(doc.id),
          builder: (context, lbSnap) {
            final top3 = (lbSnap.data ?? []).take(3).toList();

            return HomeScaleOnPress(
              child: GestureDetector(
                onTap: onOpenTab,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder.withAlpha(200)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A4438).withAlpha(5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 5,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF062921), Color(0xFF1E6B56)],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 320,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, anim) =>
                                            FadeTransition(
                                          opacity: anim,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.06),
                                              end: Offset.zero,
                                            ).animate(anim),
                                            child: child,
                                          ),
                                        ),
                                        child: Text(
                                          name.toUpperCase(),
                                          key: ValueKey<String>(name),
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: _kText,
                                            letterSpacing: 0.28,
                                            height: 1.05,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Voir',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0A4438),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: _kText.withAlpha(150),
                                    ),
                                  ],
                                ),
                              if (top3.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Divider(height: 1, color: _kBorder.withAlpha(180)),
                                const SizedBox(height: 10),
                                ...top3.asMap().entries.map((e) {
                                  final medals = ['🥇', '🥈', '🥉'];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Text(
                                          medals[e.key],
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.value.displayName,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _kTextSub,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${e.value.points} pts',
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0A4438),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ] else ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Pronostique les matchs et grimpe au classement !',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _kTextSub,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }
}
