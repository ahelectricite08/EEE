import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/article_model.dart';
import '../../models/match_model.dart';
import '../articles/articles_screen.dart';
import '../profile/profile_palette.dart';
import '../profile/profile_shell_widgets.dart';
import '../../widgets/dvcr_share_favorite_controls.dart';
import '../chat_screen.dart';
import '../match_detail_screen.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState
    extends State<NotificationsCenterScreen> {
  static const _readPrefsKey = 'notifications_center_read_keys';
  final Set<String> _readKeys = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadReadKeys();
  }

  Future<void> _loadReadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_readPrefsKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _readKeys..clear()..addAll(values);
      _loaded = true;
    });
  }

  Future<void> _markAsRead(String key) async {
    if (key.isEmpty || _readKeys.contains(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final next = {..._readKeys, key}.toList()..sort();
    await prefs.setStringList(_readPrefsKey, next);
    if (!mounted) return;
    setState(() => _readKeys..clear()..addAll(next));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, 'Mes alertes'),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(
                color: profileGold,
                strokeWidth: 2,
              ),
            )
          : DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8F5ED),
                    profileBg,
                    Color(0xFFEDE8DC),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 28 + bottom),
                children: [
                  _HeroIntroCard(),
                  const SizedBox(height: 22),
                  const ProfileInlineSectionTitle(
                    title: 'En direct',
                    icon: Icons.live_tv_rounded,
                    accent: profileRed,
                  ),
                  const SizedBox(height: 12),
                  _LiveAndVotesSection(readKeys: _readKeys, onRead: _markAsRead),
                  const SizedBox(height: 26),
                  const ProfileInlineSectionTitle(
                    title: 'Actus récentes',
                    icon: Icons.article_rounded,
                    accent: profileGold,
                  ),
                  const SizedBox(height: 12),
                  _RecentArticlesSection(readKeys: _readKeys, onRead: _markAsRead),
                  const SizedBox(height: 26),
                  const ProfileInlineSectionTitle(
                    title: 'Derniers résultats',
                    icon: Icons.sports_soccer_rounded,
                    accent: profileGreen,
                  ),
                  const SizedBox(height: 12),
                  _RecentResultsSection(readKeys: _readKeys, onRead: _markAsRead),
                  const SizedBox(height: 26),
                  const ProfileInlineSectionTitle(
                    title: 'Mentions chat',
                    icon: Icons.alternate_email_rounded,
                    accent: profileGold,
                  ),
                  const SizedBox(height: 12),
                  _ChatMentionsSection(readKeys: _readKeys, onRead: _markAsRead),
                ],
              ),
            ),
    );
  }
}

class _HeroIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            profileGold.withValues(alpha: 0.55),
            profileGreen.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: profileGreenDeep.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ProfileElevatedCard(
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: const ProfileSectionHeader(
          title: 'Centre d’alertes',
          subtitle:
              'Live, votes, actus, scores et mentions : ouvre une ligne pour y aller, elle se marque comme vue.',
          icon: Icons.notifications_active_rounded,
          accent: profileGold,
        ),
      ),
    );
  }
}

// ── Sections de données ────────────────────────────────────────────────────────

class _LiveAndVotesSection extends StatelessWidget {
  final Set<String> readKeys;
  final Future<void> Function(String) onRead;
  const _LiveAndVotesSection({required this.readKeys, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('live').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        final items = <Widget>[];

        for (final doc in docs) {
          final data = doc.data();
          if (doc.id == 'current' && data.isNotEmpty) {
            items.add(_NotifTile(
              notificationKey: 'live_match_current',
              isRead: readKeys.contains('live_match_current'),
              icon: Icons.live_tv_rounded,
              color: profileRed,
              title: 'Live match actif',
              subtitle:
                  '${data['team1'] ?? 'Équipe 1'} vs ${data['team2'] ?? 'Équipe 2'}',
              onTap: () => onRead('live_match_current'),
              isLive: true,
            ));
            if ((data['motmVoteStatus'] as String? ?? '').trim() == 'active') {
              items.add(_NotifTile(
                notificationKey: 'vote_motm_current',
                isRead: readKeys.contains('vote_motm_current'),
                icon: Icons.emoji_events_rounded,
                color: profileGold,
                title: 'Vote Homme du match ouvert',
                subtitle:
                    (data['motmVoteTitle'] as String? ?? 'Vote en cours').trim(),
                onTap: () => onRead('vote_motm_current'),
              ));
            }
          }
          if (doc.id == 'emission' && data['live'] == true) {
            items.add(_NotifTile(
              notificationKey: 'live_emission',
              isRead: readKeys.contains('live_emission'),
              icon: Icons.mic_rounded,
              color: profileGold,
              title: 'Émission DVCR en direct',
              subtitle: (data['title'] as String? ?? 'Studio DVCR').trim(),
              onTap: () => onRead('live_emission'),
              isLive: true,
            ));
            if ((data['pollStatus'] as String? ?? '').trim() == 'active') {
              items.add(_NotifTile(
                notificationKey: 'vote_emission_poll',
                isRead: readKeys.contains('vote_emission_poll'),
                icon: Icons.poll_rounded,
                color: profileRed,
                title: 'Sondage émission actif',
                subtitle:
                    (data['pollTitle'] as String? ?? 'Sondage en direct').trim(),
                onTap: () => onRead('vote_emission_poll'),
              ));
            }
          }
        }

        if (items.isEmpty) {
          return const _EmptyState(
            label:
                'Quand un live ou un vote est actif, tu le verras ici tout de suite.',
            accent: profileRed,
          );
        }
        return Column(children: items);
      },
    );
  }
}

class _RecentArticlesSection extends StatelessWidget {
  final Set<String> readKeys;
  final Future<void> Function(String) onRead;
  const _RecentArticlesSection({required this.readKeys, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('articles')
          .where('status', isEqualTo: 'published')
          .orderBy('created_at', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyState(
            label: 'Les derniers articles publiés apparaîtront ici.',
            accent: profileGold,
          );
        }
        return Column(
          children: docs.map((doc) {
            final article = ArticleModel.fromFirestore(doc);
            return _NotifTile(
              notificationKey: 'article_${article.id}',
              isRead: readKeys.contains('article_${article.id}'),
              icon: Icons.article_rounded,
              color: profileGold,
              title: article.title,
              subtitle: article.categoryForShare,
              onTap: () async {
                await onRead('article_${article.id}');
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(article: article),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _RecentResultsSection extends StatelessWidget {
  final Set<String> readKeys;
  final Future<void> Function(String) onRead;
  const _RecentResultsSection({required this.readKeys, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyState(
            label:
                'Les derniers scores enregistrés dans l’app s’afficheront ici.',
            accent: profileGreen,
          );
        }
        return Column(
          children: docs.map((doc) {
            final match = MatchModel.fromFirestore(doc);
            return _MatchResultTile(
              match: match,
              isRead: readKeys.contains('match_${match.id}'),
              onTap: () async {
                await onRead('match_${match.id}');
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchDetailScreen(match: match),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChatMentionsSection extends StatelessWidget {
  final Set<String> readKeys;
  final Future<void> Function(String) onRead;
  const _ChatMentionsSection({required this.readKeys, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
        label: 'Connecte-toi pour voir tes mentions dans le chat.',
        accent: profileGold,
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        final handle = _buildHandle(userSnap.data?.data());
        if (handle.isEmpty) {
          return const _EmptyState(
            label: 'Complète ton profil pour activer les mentions @pseudo.',
            accent: profileGold,
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('messages')
              .where('mentions', arrayContains: handle)
              .limit(5)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const _EmptyState(
                label: 'Aucune mention récente avec ton pseudo.',
                accent: profileGold,
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                return _NotifTile(
                  notificationKey: 'mention_${doc.id}',
                  isRead: readKeys.contains('mention_${doc.id}'),
                  icon: Icons.alternate_email_rounded,
                  color: profileGold,
                  title:
                      '${(data['firstName'] as String? ?? 'Membre').trim()} t\'a mentionné',
                  subtitle: (data['text'] as String? ?? '').trim(),
                  onTap: () async {
                    await onRead('mention_${doc.id}');
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  String _buildHandle(Map<String, dynamic>? data) {
    final first = (data?['firstName'] as String? ?? '').trim().toLowerCase();
    final last = (data?['lastName'] as String? ?? '').trim().toLowerCase();
    final display =
        (data?['displayName'] as String? ?? '').trim().toLowerCase();
    final base = first.isNotEmpty
        ? '$first${last.isNotEmpty ? '_${last[0]}' : ''}'
        : display;
    return base
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  }
}

// ── Tiles ──────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final String notificationKey;
  final bool isRead;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLive;

  const _NotifTile({
    required this.notificationKey,
    required this.isRead,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isRead
        ? profileBorder
        : color.withValues(alpha: 0.28);
    final stripe = isRead
        ? profileBorder.withValues(alpha: 0.45)
        : color;

    return KeyedSubtree(
      key: ValueKey<String>(notificationKey),
      child: ProfileListRow(
        accentStripe: color,
        stripeColor: stripe,
        cardBorderColor: borderColor,
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isRead ? 0.07 : 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.26),
            ),
          ),
          child: Icon(
            icon,
            color: isRead ? color.withValues(alpha: 0.55) : color,
            size: 23,
          ),
        ),
        middle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (isLive && !isRead) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: profileRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: profileRed.withValues(alpha: 0.55),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      color: isRead ? profileMutedText : profileText,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: profileMutedText.withValues(
                    alpha: isRead ? 0.65 : 1,
                  ),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          isRead ? Icons.check_rounded : Icons.chevron_right_rounded,
          color: isRead
              ? profileMutedText.withValues(alpha: 0.45)
              : profileGreen.withValues(alpha: 0.4),
          size: 22,
        ),
      ),
    );
  }
}

class _MatchResultTile extends StatelessWidget {
  final MatchModel match;
  final bool isRead;
  final VoidCallback? onTap;

  const _MatchResultTile({
    required this.match,
    required this.isRead,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasScores = match.score1 != null && match.score2 != null;
    final borderColor = isRead
        ? profileBorder
        : profileGreen.withValues(alpha: 0.28);
    final stripe = isRead
        ? profileBorder.withValues(alpha: 0.45)
        : profileGreen;
    const r = 20.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(r),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: profileGreenDeep.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 72,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: stripe,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(r - 1),
                      ),
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: profileGreen.withValues(alpha: isRead ? 0.07 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: profileGreen.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      Icons.sports_soccer_rounded,
                      color: isRead
                          ? profileGreen.withValues(alpha: 0.55)
                          : profileGreen,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          match.team1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: isRead
                                ? profileMutedText
                                : profileText.withValues(alpha: 0.92),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: profileSurfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: profileGreen.withValues(alpha: 0.22),
                              ),
                            ),
                            child: hasScores
                                ? Text(
                                    '${match.score1} — ${match.score2}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      color: isRead
                                          ? profileMutedText
                                          : profileText,
                                    ),
                                  )
                                : Text(
                                    'Score à venir',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: profileMutedText,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.team2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: isRead
                                ? profileMutedText
                                : profileText.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DvcrMatchShareFavoriteRow(
                        match: match,
                        mutedIconColor:
                            profileMutedText.withValues(alpha: 0.85),
                        activeFavoriteColor: profileGold,
                        iconSize: 19,
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        isRead
                            ? Icons.check_rounded
                            : Icons.chevron_right_rounded,
                        color: isRead
                            ? profileMutedText.withValues(alpha: 0.45)
                            : profileGreen.withValues(alpha: 0.38),
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String label;
  final Color accent;

  const _EmptyState({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileEmptyHint(
      icon: Icons.notifications_none_rounded,
      accent: accent,
      title: 'Rien pour l’instant',
      body: label,
    );
  }
}
