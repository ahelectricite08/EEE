import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_settings_service.dart';
import '../../services/prono_social_service.dart';
import '../../services/xp_service.dart';
import '../../utils/remote_image_url.dart';
import '../../widgets/hub_hero_photo.dart';
import 'profile_palette.dart';
import 'profile_type.dart';

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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = currentUid != null && currentUid == uid;
    final profileStream = isSelf
        ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
        : FirebaseFirestore.instance
            .collection('prono_leaderboard')
            .doc(uid)
            .snapshots();

    return Scaffold(
      backgroundColor: profileBg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, userSnap) {
          final userData = userSnap.data?.data();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: XpService.levelsDocStream(),
            builder: (context, configSnap) {
              final config = configSnap.data?.data();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.leaderboardEntryStream(uid),
                builder: (context, boardSnap) {
                  final boardData = boardSnap.data?.data() ?? {};
                  final pronoProfile =
                      (userData?['pronoProfile'] as Map<String, dynamic>?) ??
                          {};
                  final data = {...boardData, ...pronoProfile};
                  final name = userData?['displayName'] as String? ??
                      displayName ??
                      'Membre';
                  final xp = XpService.displayXp(userData);
                  final level =
                      PronoSocialService.levelFromXp(xp, config: config);
                  final levelLabel =
                      PronoSocialService.levelLabelFromXp(xp, config: config);
                  final levelImageUrl =
                      PronoSocialService.levelImageFromXp(xp, config: config);
                  final progress =
                      PronoSocialService.progressInLevel(xp, config: config);
                  final points = (data['points'] as num?)?.toInt() ?? 0;
                  final total =
                      (data['totalPredictions'] as num?)?.toInt() ?? 0;
                  final exact = (data['exactScores'] as num?)?.toInt() ?? 0;
                  final good = (data['goodResults'] as num?)?.toInt() ?? 0;
                  final duelWins = (data['duelWins'] as num?)?.toInt() ?? 0;
                  final accuracy =
                      total > 0 ? ((exact + good) / total * 100) : 0.0;

                  return CustomScrollView(
                    slivers: [
                      _PublicProfileHeroSliver(
                        name: name,
                        level: level,
                        levelImageUrl: levelImageUrl,
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PaperCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NIVEAU & PROGRESSION',
                                        style: ProfileType.kicker),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _LevelThumb(
                                          level: level,
                                          imageUrl: levelImageUrl,
                                          size: 52,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                levelLabel.toUpperCase(),
                                                style: ProfileType.title
                                                    .copyWith(fontSize: 20),
                                              ),
                                              Text(
                                                '$xp XP total · Niveau $level',
                                                style: ProfileType.caption,
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
                                        minHeight: 4,
                                        backgroundColor: profileHairline,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                          profileGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _PaperCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PRONOS', style: ProfileType.kicker),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCell(
                                            label: 'POINTS',
                                            value: '$points',
                                          ),
                                        ),
                                        _VRule(),
                                        Expanded(
                                          child: _StatCell(
                                            label: 'PRONOS',
                                            value: '$total',
                                          ),
                                        ),
                                        _VRule(),
                                        Expanded(
                                          child: _StatCell(
                                            label: 'RÉUSSITE',
                                            value:
                                                '${accuracy.toStringAsFixed(0)}%',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: profileHairline,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCell(
                                            label: 'EXACTS',
                                            value: '$exact',
                                          ),
                                        ),
                                        _VRule(),
                                        Expanded(
                                          child: _StatCell(
                                            label: 'BONS RÉS.',
                                            value: '$good',
                                          ),
                                        ),
                                        _VRule(),
                                        Expanded(
                                          child: _StatCell(
                                            label: 'DUELS ✓',
                                            value: '$duelWins',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
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
}

class _PublicProfileHeroSliver extends StatelessWidget {
  final String name;
  final int level;
  final String? levelImageUrl;

  const _PublicProfileHeroSliver({
    required this.name,
    required this.level,
    required this.levelImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      expandedHeight: topPad + 52 + 168,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 52,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Container(width: 3, height: 16, color: profileGreenBright),
            const SizedBox(width: 8),
            Text('PROFIL', style: ProfileType.nameplate),
          ],
        ),
      ),
      flexibleSpace: _PublicHeroSpace(
        name: name,
        level: level,
        levelImageUrl: levelImageUrl,
      ),
    );
  }
}

class _PublicHeroSpace extends StatelessWidget {
  final String name;
  final int level;
  final String? levelImageUrl;

  const _PublicHeroSpace({
    required this.name,
    required this.level,
    required this.levelImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = context
            .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final maxExtent = settings?.maxExtent ?? constraints.maxHeight;
        final minExtent = settings?.minExtent ?? constraints.maxHeight;
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final delta = maxExtent - minExtent;
        final t = delta <= 0
            ? 0.0
            : (1 - (current - minExtent) / delta).clamp(0.0, 1.0);
        final alignment = Alignment.lerp(
          const Alignment(0, -0.28),
          const Alignment(0, -1),
          t,
        )!;
        final veilTop = 0.30 + 0.34 * t;
        final veilMid = 0.06 + 0.46 * t;
        final veilLow = 0.72 + 0.16 * t;
        final lockupOpacity = (1 - t * 1.7).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF151515))),
            Positioned.fill(
              child: HubHeroPhoto(
                slot: HubHeroSlot.profile,
                alignment: alignment,
                fallbackAsset:
                    ProfileHeroBackgroundSettings.defaultAssetPath,
                cacheWidth: profileImageCacheWidth(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                filterQuality: FilterQuality.low,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: veilTop),
                      Colors.black.withValues(alpha: veilMid),
                      Colors.black.withValues(alpha: veilLow),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.34, 0.78, 1.0],
                  ),
                ),
              ),
            ),
            if (lockupOpacity > 0)
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Opacity(
                  opacity: lockupOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LevelThumb(
                        level: level,
                        imageUrl: levelImageUrl,
                        size: 64,
                        onPhoto: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileType.masthead.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LevelThumb extends StatelessWidget {
  final int level;
  final String? imageUrl;
  final double size;
  final bool onPhoto;

  const _LevelThumb({
    required this.level,
    required this.imageUrl,
    required this.size,
    this.onPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPhoto ? Colors.white.withValues(alpha: 0.12) : profileSurfaceMuted,
          border: Border.all(
            color: onPhoto
                ? Colors.white.withValues(alpha: 0.45)
                : profileHairline,
          ),
        ),
        child: ClipOval(
          child: url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: profileImageCacheWidth(context, size),
                  headers: kDvcrImageHttpHeaders,
                  errorBuilder: (_, __, ___) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Text(
          'L$level',
          style: GoogleFonts.barlowCondensed(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w900,
            color: onPhoto ? Colors.white : profileGreen,
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
        return _PaperCard(
          child: Row(
            children: [
              Text(
                '#$rank',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: profileGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rang dans le classement',
                      style: ProfileType.kicker,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rank <= 3
                          ? 'Top $rank du classement général'
                          : 'Position $rank sur ${docs.length}',
                      style: ProfileType.label,
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

class _PaperCard extends StatelessWidget {
  final Widget child;
  const _PaperCard({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: profilePaper(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      );
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: ProfileType.kicker),
          const SizedBox(height: 4),
          Text(value, style: ProfileType.figure),
        ],
      );
}

class _VRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: profileHairline,
      );
}
