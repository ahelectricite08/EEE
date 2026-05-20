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
