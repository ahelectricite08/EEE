// ignore_for_file: unused_element, unused_element_parameter

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/dvcr_share_service.dart';
import '../../utils/share_helper.dart';
import '../../widgets/prono_leaderboard_style.dart';
import 'prono_palette.dart';
import 'prono_predict_extras.dart';
import 'prono_shell.dart';
import '../../models/match_model.dart';
import '../../services/prono_social_activity_service.dart';
import '../../services/prono_social_service.dart';
import '../../services/match_service.dart';
import '../../services/season_config_service.dart';

part 'prono_social_pages.dart';

// ── Surfaces (alignées prono_palette / app claire) ────────────────────────────
const _kBg = pronoBg;
const _kCard = pronoSurface;
const _kBorder = pronoBorder;
const _kRed = pronoRed;
const _kGold = pronoGold;
const _kGreen = pronoGreen;
const _kGrey = pronoGrey;
const _kText = pronoText;
const _kMutedText = pronoMutedText;
const _kSurfaceMuted = pronoSurfaceMuted;

String? _matchLogoUrl(Map<String, dynamic> match, String key) {
  final v = match[key];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: pronoReward,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _kMutedText,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSocialRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  final Color actionColor;

  const _CompactSocialRow({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    this.actionColor = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
                  ),
                ],
              ),
            ),
            Text(
              action,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: actionColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusPill({
    required this.label,
    this.accent = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(100)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

class _DuelLine extends StatelessWidget {
  final String name;
  final String score;
  final String points;
  final Color scoreColor;

  const _DuelLine({
    required this.name,
    required this.score,
    required this.points,
    this.scoreColor = pronoSocialDuel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          Text(
            score,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scoreColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$points pt',
            style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
          ),
        ],
      ),
    );
  }
}

class _PendingFriendRow extends StatelessWidget {
  final String requestId;
  final String currentUid;
  final String currentName;
  final String otherUid;
  final String otherName;

  const _PendingFriendRow({
    required this.requestId,
    required this.currentUid,
    required this.currentName,
    required this.otherUid,
    required this.otherName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$otherName veut devenir ton ami',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await PronoSocialService.acceptFriendRequest(
                requestId: requestId,
                currentUid: currentUid,
                currentName: currentName,
                otherUid: otherUid,
                otherName: otherName,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pronoSocialFriend,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ACCEPTER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await PronoSocialService.declineFriendRequest(
                requestId: requestId,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pronoSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                'REFUSER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kMutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsSectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final Color chipColor;

  const _FriendsSectionTitle({
    required this.title,
    required this.count,
    this.chipColor = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: 1.1,
            ),
          ),
        ),
        _ChipLabel(label: '$count', color: chipColor),
      ],
    );
  }
}

class _FriendsEmptyLabel extends StatelessWidget {
  final String text;

  const _FriendsEmptyLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, color: _kMutedText),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _DuelHubRow extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> duel;
  final VoidCallback onTap;

  const _DuelHubRow({
    required this.uid,
    required this.duel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (duel['status'] ?? 'pending').toString();
    final isPending = status == 'pending';
    final isOpponent = (duel['opponentUid'] ?? '') == uid;
    final label = status == 'won'
        ? ((duel['winnerUid'] == uid) ? 'GAGNE' : 'PERDU')
        : status == 'draw'
        ? 'NUL'
        : status == 'cancelled'
        ? 'ANNULE'
        : status == 'declined'
        ? 'REFUSE'
        : status == 'in_progress'
        ? 'EN COURS'
        : 'EN ATTENTE';

    // Si duel en attente et utilisateur est l'opposant → card avec Accept/Decline
    if (isPending && isOpponent) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pronoSocialDuel.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: pronoSocialDuel,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (duel['matchLabel'] ?? 'Duel').toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'DUEL EN ATTENTE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${duel['ownerName'] ?? 'Joueur'} te défie !',
              style: GoogleFonts.inter(fontSize: 11, color: pronoSocialDuel),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final duelId = duel['id']?.toString() ?? '';
                      await PronoSocialService.acceptDuel(duelId: duelId);
                      if (!context.mounted) return;
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => PronoDuelPickPage(
                            duelId: duelId,
                            currentUid: uid,
                            matchLabel:
                                (duel['matchLabel'] ?? 'Duel').toString(),
                          ),
                        ),
                      );
                      if (saved == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Score duel enregistré',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withAlpha(80),
                        ),
                      ),
                      child: Text(
                        'ACCEPTER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => PronoSocialService.declineDuel(
                      duelId: duel['id']?.toString() ?? '',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _kRed.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kRed.withAlpha(70)),
                      ),
                      child: Text(
                        'REFUSER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: label == 'EN COURS'
                ? pronoSocialDuel.withAlpha(70)
                : label == 'GAGNE'
                ? _kGreen.withAlpha(90)
                : _kBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: label == 'EN COURS'
                    ? pronoSocialDuel.withAlpha(18)
                    : label == 'GAGNE'
                    ? _kGreen.withAlpha(18)
                    : Colors.white.withAlpha(4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                label == 'EN COURS'
                    ? Icons.bolt_rounded
                    : label == 'GAGNE'
                    ? Icons.emoji_events_rounded
                    : label == 'PERDU'
                    ? Icons.close_rounded
                    : Icons.sports_martial_arts_rounded,
                size: 17,
                color: label == 'EN COURS'
                    ? pronoSocialDuel
                    : label == 'GAGNE'
                    ? _kGreen
                    : label == 'PERDU'
                    ? _kRed
                    : Colors.white70,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (duel['matchLabel'] ?? 'Duel').toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${duel['ownerName'] ?? 'Membre'} vs ${duel['opponentName'] ?? 'Membre'}',
                    style: GoogleFonts.inter(fontSize: 11, color: _kGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: label, accent: pronoSocialDuel),
          ],
        ),
      ),
    );
  }
}

class _SocialField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color focusColor;

  const _SocialField({
    required this.controller,
    required this.label,
    this.focusColor = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: _kText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: _kMutedText, fontSize: 12),
        filled: true,
        fillColor: _kSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: focusColor),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color? foregroundColor;

  _PrimaryAction({
    required this.label,
    this.backgroundColor = pronoGreen,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ??
        (ThemeData.estimateBrightnessForColor(backgroundColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withAlpha(55),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;

  const _SecondaryAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _kText,
        ),
      ),
    );
  }
}

class _LeagueSummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _LeagueSummaryStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _kMutedText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueHistorySection extends StatelessWidget {
  final List<dynamic> memberIds;
  final String currentUid;
  final Color loaderColor;
  final Color selfHighlightColor;

  const _LeagueHistorySection({
    required this.memberIds,
    required this.currentUid,
    this.loaderColor = pronoGreen,
    this.selfHighlightColor = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return PronoSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pronos des potes (saison)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Même prono championnat que partout : après le résultat officiel, '
            'tu vois ici le score mis par chaque membre de la ligue.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMutedText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<LeagueHistoryMatch>>(
            future: PronoSocialService.leagueHistory(memberIds, limit: 12),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: loaderColor,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }
              final rows = snap.data ?? const <LeagueHistoryMatch>[];
              if (rows.isEmpty) {
                return Text(
                  'Dès que plusieurs membres ont pronostiqué le même match, '
                  'il apparaît ici avec leurs scores.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _kMutedText,
                    height: 1.35,
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows.map((m) {
                  final hasResult =
                      m.resultScore1 != null && m.resultScore2 != null;
                  final dateLabel = m.matchDate != null
                      ? DateFormat(
                          "EEE d MMM · HH'h'mm",
                          'fr_FR',
                        ).format(m.matchDate!)
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kSurfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.team1} — ${m.team2}',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _kText,
                            ),
                          ),
                          if (dateLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              dateLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kMutedText,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            hasResult
                                ? 'Résultat : ${m.resultScore1} — ${m.resultScore2}'
                                : 'Résultat pas encore saisi sur le match',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: hasResult ? _kGreen : _kMutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...m.predictions.map((p) {
                            final mine = p.uid == currentUid;
                            final pts = p.points;
                            final ptsLabel = pts == null
                                ? '—'
                                : (pts == 3
                                    ? '3 pts (exact)'
                                    : pts == 1
                                        ? '1 pt'
                                        : '0 pt');
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.displayName + (mine ? ' (toi)' : ''),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: mine ? selfHighlightColor : _kText,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${p.score1Pred} — ${p.score2Pred}',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _kText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ptsLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _kMutedText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PronoSheet extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> match;
  final String uid;
  final String displayName;
  /// Plein écran (route) : pas de handle ni coins arrondis type bottom sheet.
  final bool embeddedInRoute;

  const _PronoSheet({
    required this.matchId,
    required this.match,
    required this.uid,
    required this.displayName,
    this.embeddedInRoute = false,
  });
  @override
  State<_PronoSheet> createState() => _PronoSheetState();
}

class _PronoSheetState extends State<_PronoSheet> {
  int _s1 = 1, _s2 = 1;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final doc = await FirebaseFirestore.instance
        .collection('predictions')
        .doc('${widget.matchId}_${widget.uid}')
        .get();
    if (doc.exists && mounted) {
      final d = doc.data()!;
      setState(() {
        _s1 = (d['score1Pred'] as int?) ?? 1;
        _s2 = (d['score2Pred'] as int?) ?? 1;
      });
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final docRef = FirebaseFirestore.instance
        .collection('predictions')
        .doc('${widget.matchId}_${widget.uid}');
    final snap = await docRef.get();
    final season = widget.match['fffSeason'] as String? ??
        (await SeasonConfigService.getCurrent()).seasonLabel;

    if (snap.exists) {
      await docRef.update({
        'score1Pred': _s1,
        'score2Pred': _s2,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'matchId': widget.matchId,
        'uid': widget.uid,
        'displayName': widget.displayName,
        'score1Pred': _s1,
        'score2Pred': _s2,
        'points': null,
        'season': season,
        'matchDate': widget.match['date'],
        'team1': widget.match['team1'] ?? '',
        'team2': widget.match['team2'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final isNew = !snap.exists;
    await PronoSocialService.registerPrediction(
      uid: widget.uid,
      displayName: widget.displayName,
      isNewPrediction: isNew,
    );

    if (isNew) {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('awardXp').call({'eventType': 'vote_prono'});
      } catch (_) {}
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t1 = widget.match['team1'] ?? '';
    final t2 = widget.match['team2'] ?? '';
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Prono enregistré : $t1 $_s1 - $_s2 $t2',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        backgroundColor: _kGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final team1 = widget.match['team1'] as String? ?? 'Équipe 1';
    final team2 = widget.match['team2'] as String? ?? 'Équipe 2';
    final logo1 = _matchLogoUrl(widget.match, 'logo1');
    final logo2 = _matchLogoUrl(widget.match, 'logo2');
    final date = widget.match['date'] as Timestamp;
    final embedded = widget.embeddedInRoute;

    const _bg = Color(0xFFF5F2E9);
    const _surface = Color(0xFFFFFFFF);
    const _border = Color(0xFFDDD8CC);
    const _text = Color(0xFF173C31);
    const _muted = Color(0xFF6E776F);

    final sheetBg = embedded ? pronoBg : _bg;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!embedded) ...[
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 4),
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kRed.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: _kRed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TON PRONOSTIC',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _text,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      DateFormat(
                        "dd MMMM yyyy · HH'h'mm",
                        'fr_FR',
                      ).format(date.toDate()),
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_loaded) ...[
            PronoOutcomeCommunityBar(matchId: widget.matchId),
            const SizedBox(height: 12),
            Prono1x2QuickPicks(
              onPick: (a, b) => setState(() {
                _s1 = a;
                _s2 = b;
              }),
            ),
            const SizedBox(height: 16),
          ],

          if (!_loaded)
            const Center(
              child: CircularProgressIndicator(color: _kRed, strokeWidth: 2),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Center(
                          child: _PronoTeamLogo(
                            url: logo1,
                            name: team1,
                            borderColor: _border,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          team1.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          child: _Stepper(
                            value: _s1,
                            onChanged: (v) => setState(() => _s1 = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Text(
                      '–',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 32,
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Center(
                          child: _PronoTeamLogo(
                            url: logo2,
                            name: team2,
                            borderColor: _border,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          team2.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          child: _Stepper(
                            value: _s2,
                            onChanged: (v) => setState(() => _s2 = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Points hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PointHint(
                  icon: Icons.star_rounded,
                  iconColor: _kGold,
                  pts: '3 pts',
                  label: 'Score exact',
                  light: true,
                ),
                Container(width: 1, height: 28, color: _border),
                _PointHint(
                  icon: Icons.check_circle_rounded,
                  iconColor: _kGreen,
                  pts: '1 pt',
                  label: 'Bon résultat',
                  light: true,
                ),
                Container(width: 1, height: 28, color: _border),
                _PointHint(
                  icon: Icons.cancel_rounded,
                  iconColor: _kRed,
                  pts: '0 pt',
                  label: 'Mauvais prono',
                  light: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bouton valider
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _saving ? _border : _kRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _saving
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Text(
                      'VALIDER MON PRONO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
    );

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: embedded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: embedded ? 8 : 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + (embedded ? 24 : 28),
      ),
      child: content,
    );
  }
}

/// Route plein écran pour pronostiquer (remplace le bottom sheet depuis le hub / les cartes).
class PronoMatchPredictScreen extends StatefulWidget {
  final String matchId;
  final String uid;
  final String displayName;

  const PronoMatchPredictScreen({
    super.key,
    required this.matchId,
    required this.uid,
    required this.displayName,
  });

  @override
  State<PronoMatchPredictScreen> createState() => _PronoMatchPredictScreenState();
}

class _PronoMatchPredictScreenState extends State<PronoMatchPredictScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final doc = snap.data;
        final exists = doc?.exists ?? false;
        final match = doc?.data();

        return Scaffold(
          backgroundColor: pronoBg,
          appBar: AppBar(
            backgroundColor: pronoSurface,
            foregroundColor: pronoText,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: pronoText,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: exists && match != null
                ? _PronoPredictAppBarTitle(match: match)
                : Text(
                    'Pronostic',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: pronoText,
                    ),
                  ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: pronoBorder),
            ),
          ),
          body: waiting
              ? const Center(
                  child: CircularProgressIndicator(
                    color: pronoGreen,
                    strokeWidth: 2.2,
                  ),
                )
              : !exists || match == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Match introuvable ou supprimé.',
                      style: GoogleFonts.inter(
                        color: pronoMutedText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _PronoSheet(
                    matchId: widget.matchId,
                    match: match,
                    uid: widget.uid,
                    displayName: widget.displayName,
                    embeddedInRoute: true,
                  ),
                ),
        );
      },
    );
  }
}

/// Logos `logo1` / `logo2` sur le doc Firestore `matches` (même source que le détail match).
class _PronoTeamLogo extends StatelessWidget {
  final String? url;
  final String name;
  final Color borderColor;

  const _PronoTeamLogo({
    required this.url,
    required this.name,
    required this.borderColor,
  });

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: pronoGreen.withAlpha(28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final t = name.trim();
    final letter = t.isEmpty
        ? '?'
        : String.fromCharCode(t.runes.first).toUpperCase();
    return Container(
      color: pronoSurfaceMuted,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.barlowCondensed(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: pronoGreenDeep,
        ),
      ),
    );
  }
}

class _PronoPredictAppBarTitle extends StatelessWidget {
  final Map<String, dynamic> match;

  const _PronoPredictAppBarTitle({required this.match});

  @override
  Widget build(BuildContext context) {
    final t1 = (match['team1'] ?? '').toString();
    final t2 = (match['team2'] ?? '').toString();
    final u1 = _matchLogoUrl(match, 'logo1');
    final u2 = _matchLogoUrl(match, 'logo2');

    return Row(
      children: [
        _AppBarLogoChip(url: u1),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$t1 — $t2',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: pronoText,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _AppBarLogoChip(url: u2),
      ],
    );
  }
}

class _AppBarLogoChip extends StatelessWidget {
  final String? url;

  const _AppBarLogoChip({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: pronoBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: url != null
              ? Image.network(
                  url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.shield_rounded,
                    size: 16,
                    color: pronoGrey,
                  ),
                )
              : Icon(Icons.shield_rounded, size: 16, color: pronoGrey),
        ),
      ),
    );
  }
}

class _PointHint extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String pts, label;
  final bool light;
  const _PointHint({
    required this.icon,
    required this.iconColor,
    required this.pts,
    required this.label,
    this.light = false,
  });
  @override
  Widget build(BuildContext context) {
    final textColor = light ? const Color(0xFF173C31) : Colors.white;
    final mutedColor = light ? const Color(0xFF6E776F) : _kGrey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 2),
        Text(
          pts,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: mutedColor)),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          enabled: value > 0,
          onTap: value > 0 ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 18),
        Text(
          '$value',
          style: GoogleFonts.inter(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: _kGold,
          ),
        ),
        const SizedBox(width: 18),
        _StepBtn(
          icon: Icons.add_rounded,
          enabled: true,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(
          icon,
          color: enabled ? pronoText : pronoGrey,
          size: 20,
        ),
      ),
    );
  }
}

// ── Onglet Classement ─────────────────────────────────────────────────────────
class PronoBanner extends StatelessWidget {
  final String uid;
  const PronoBanner({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        // Premier match championnat
        final docs = snap.data!.docs.where((d) {
          final comp = ((d.data() as Map)['competition'] as String? ?? '')
              .toUpperCase();
          return !comp.contains('COUPE');
        }).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        final nextDoc = docs.first;
        final m = nextDoc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            final u = FirebaseAuth.instance.currentUser;
            if (u == null) return;
            final name = (u.displayName ?? '').trim().isNotEmpty
                ? u.displayName!.trim()
                : 'Membre';
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PronoMatchPredictScreen(
                  matchId: nextDoc.id,
                  uid: u.uid,
                  displayName: name,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF2A2A2A)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: Color(0xFFC8A436),
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  'PRONOS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC8A436),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 13, color: const Color(0xFF2A2A2A)),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('predictions')
                        .doc('${nextDoc.id}_$uid')
                        .snapshots(),
                    builder: (_, predSnap) {
                      final hasPred = predSnap.hasData && predSnap.data!.exists;
                      final String matchLabel =
                          '${m['team1'] ?? ''} vs ${m['team2'] ?? ''}';
                      if (hasPred) {
                        final p = predSnap.data!.data() as Map<String, dynamic>;
                        return Text(
                          '$matchLabel · ${p['score1Pred']}-${p['score2Pred']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      return Text(
                        '$matchLabel · Pronostiquer →',
                        style: GoogleFonts.inter(fontSize: 13, color: _kGrey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
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

