import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/prono_social_service.dart';

const _kBg     = Color(0xFFF5F2E9);
const _kCard   = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E1D6);
const _kGold   = Color(0xFFC8A436);
const _kRed    = Color(0xFFBA203C);
const _kGreen  = Color(0xFF0A4438);
const _kGrey   = Color(0xFF5C6560);
const _kText   = Color(0xFF1A2522);

class PublicProfileScreen extends StatelessWidget {
  final String uid;
  final String? displayName;

  const PublicProfileScreen({
    super.key,
    required this.uid,
    this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.pronoConfigStream(),
            builder: (context, configSnap) {
              final config = configSnap.data?.data();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.leaderboardEntryStream(uid),
                builder: (context, boardSnap) {
                  final boardData = boardSnap.data?.data() ?? {};
                  final pronoProfile = (userData?['pronoProfile'] as Map<String, dynamic>?) ?? {};
                  final data = {...boardData, ...pronoProfile};
                  final mergedForXp =
                      PronoSocialService.mergeLeaderboardAndPronoProfileForXp(
                    boardSnap.data?.data(),
                    userData,
                  );

                  final name = userData?['displayName'] as String? ??
                      displayName ?? 'Supporter';
                  final xp = PronoSocialService.resolvedPronoDisplayXp(
                    mergedLeaderboardStats: mergedForXp,
                    userDocData: userData,
                    config: config,
                  );
                  final level = PronoSocialService.levelFromXp(xp, config: config);
                  final levelLabel = PronoSocialService.levelLabelFromXp(xp, config: config);
                  final levelImageUrl = PronoSocialService.levelImageFromXp(xp, config: config);
                  final progress = PronoSocialService.progressInLevel(xp, config: config);
                  final points = (data['points'] as num?)?.toInt() ?? 0;
                  final total = (data['totalPredictions'] as num?)?.toInt() ?? 0;
                  final exact = (data['exactScores'] as num?)?.toInt() ?? 0;
                  final good = (data['goodResults'] as num?)?.toInt() ?? 0;
                  final duelWins = (data['duelWins'] as num?)?.toInt() ?? 0;
                  final accuracy = total > 0 ? ((exact + good) / total * 100) : 0.0;

                  return CustomScrollView(
                    slivers: [
                      // ── AppBar ─────────────────────────────────────────
                      SliverAppBar(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        expandedHeight: 160,
                        pinned: true,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            color: _kGreen,
                            child: SafeArea(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 36),
                                  // Avatar niveau
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: _kGold.withAlpha(25),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: _kGold.withAlpha(120), width: 2),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: levelImageUrl != null
                                        ? Image.network(levelImageUrl, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _levelFallback(level))
                                        : _levelFallback(level),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    name,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Niveau & XP ──────────────────────────
                              _Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionLabel('NIVEAU & PROGRESSION'),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: _kGold.withAlpha(18),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: _kGold.withAlpha(80)),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: levelImageUrl != null
                                              ? Image.network(levelImageUrl, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _levelFallback(level))
                                              : _levelFallback(level),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                levelLabel.toUpperCase(),
                                                style: GoogleFonts.barlowCondensed(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: _kText,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              Text(
                                                '$xp XP total · Niveau $level',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: _kGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 7,
                                        backgroundColor: _kBorder,
                                        valueColor: const AlwaysStoppedAnimation(_kGold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Stats pronos ─────────────────────────
                              _Card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionLabel('PRONOS'),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: _StatCell(label: 'POINTS', value: '$points', color: _kGold)),
                                        _Divider(),
                                        Expanded(child: _StatCell(label: 'PRONOS', value: '$total', color: _kText)),
                                        _Divider(),
                                        Expanded(child: _StatCell(label: 'RÉUSSITE', value: '${accuracy.toStringAsFixed(0)}%', color: _kGreen)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(height: 1, color: _kBorder),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: _StatCell(label: 'EXACTS', value: '$exact', color: _kRed)),
                                        _Divider(),
                                        Expanded(child: _StatCell(label: 'BONS RÉS.', value: '$good', color: _kGold)),
                                        _Divider(),
                                        Expanded(child: _StatCell(label: 'DUELS ✓', value: '$duelWins', color: _kText)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── Rang classement ──────────────────────
                              _RankCard(uid: uid),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _levelFallback(int level) => Center(
    child: Text(
      'L$level',
      style: GoogleFonts.barlowCondensed(
        fontSize: 20, fontWeight: FontWeight.w900, color: _kGold,
      ),
    ),
  );
}

class _RankCard extends StatelessWidget {
  final String uid;
  const _RankCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .orderBy('points', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final idx = docs.indexWhere((d) => d.id == uid);
        if (idx < 0) return const SizedBox.shrink();

        final rank = idx + 1;
        final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;
        final rankColor = rank == 1
            ? const Color(0xFFFFD700)
            : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
            ? const Color(0xFFCD7F32)
            : _kGold;

        return _Card(
          child: Row(
            children: [
              Text(
                medal ?? '#$rank',
                style: medal != null
                    ? const TextStyle(fontSize: 32)
                    : GoogleFonts.barlowCondensed(
                        fontSize: 28, fontWeight: FontWeight.w900, color: rankColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rang dans le classement',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank <= 3 ? 'Top $rank du classement général !' : 'Position $rank sur ${docs.length}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 9, fontWeight: FontWeight.w800, color: _kGrey, letterSpacing: 1.2,
    ),
  );
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _kGrey, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.barlowCondensed(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: _kBorder);
}
