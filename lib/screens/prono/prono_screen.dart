// ignore_for_file: unused_element, unused_element_parameter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/app_settings_service.dart';
import '../../services/dvcr_share_service.dart';
import '../../utils/share_helper.dart';
import '../../widgets/prono_leaderboard_style.dart';
import '../../features/prono/domain/leaderboard_window.dart';
import '../../features/prono/presentation/theme/prono_theme.dart';
import '../../features/prono/presentation/theme/prono_tokens.dart';
import '../../features/prono/presentation/theme/prono_type.dart';
import '../../features/prono/presentation/widgets/prono_ui.dart';
import '../../features/prono/presentation/widgets/prono_predict_stage.dart';
import 'prono_palette.dart';
import 'prono_predict_extras.dart';
import '../../models/match_model.dart';
import '../../services/prono_social_service.dart';
import '../../services/match_service.dart';
import '../../services/season_config_service.dart';
import '../../models/user_role.dart';

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

/// Cellule de relevé — un chiffre, une étiquette. Pas de boîte.
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.stat.copyWith(
              fontSize: 28,
              color: PronoArenaTheme.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.kicker.copyWith(
              fontSize: 9,
              color: PronoArenaTheme.textSoft,
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
    this.actionColor = pronoSocialPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: actionColor.withValues(alpha: 0.06),
        child: Ink(
          decoration: PronoArenaTheme.fixtureTape(),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.label,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _InkWord(label: action, color: actionColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mot d’action compact sur encre — remplace les pilules Material.
class _InkWord extends StatelessWidget {
  final String label;
  final Color color;

  const _InkWord({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      color: color,
      child: Text(
        label.toUpperCase(),
        style: PronoType.kicker.copyWith(
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Statut — un mot en capitales adossé à un filet de couleur.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusPill({
    required this.label,
    this.accent = pronoGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 3, height: 13, color: accent),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: PronoType.kicker.copyWith(color: accent, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

/// Ligne de duel — réglure : nom, score condensé, points.
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
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PronoType.label,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            score,
            style: PronoType.scoreCompact.copyWith(
              fontSize: 20,
              color: scoreColor,
            ),
          ),
          const SizedBox(width: 12),
          Text('$points pt', style: PronoType.meta),
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
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.label,
                ),
                const SizedBox(height: 2),
                Text('veut devenir ton ami', style: PronoType.meta),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
            child: const _InkWord(
              label: 'Accepter',
              color: PronoArenaTheme.ink,
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () async {
              await PronoSocialService.declineFriendRequest(
                requestId: requestId,
              );
            },
            child: Text(
              'REFUSER',
              style: PronoType.kicker.copyWith(
                color: PronoArenaTheme.textSoft,
                letterSpacing: 1,
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
    this.chipColor = pronoSocialPurple,
  });

  @override
  Widget build(BuildContext context) {
    return PronoSectionHeader(
      title: title,
      countLabel: '$count',
      pageAccent: PronoPageAccent.social,
    );
  }
}

class _FriendsEmptyLabel extends StatelessWidget {
  final String text;

  const _FriendsEmptyLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 26,
            margin: const EdgeInsets.only(right: 12, top: 2),
            color: PronoArenaTheme.edgeHighlight,
          ),
          Expanded(child: Text(text, style: PronoType.caption)),
        ],
      ),
    );
  }
}

/// Compteur discret — capitales espacées dans un cadre fin.
class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: PronoType.kicker.copyWith(color: color, letterSpacing: 1),
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
                color: pronoSocialPurple,
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
                        color: PronoTokens.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PronoTokens.border),
                      ),
                      child: Text(
                        'ACCEPTER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kGreen,
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
                        color: PronoTokens.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PronoTokens.border),
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
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
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
                color: PronoTokens.textMuted,
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
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${duel['ownerName'] ?? 'Membre'} vs ${duel['opponentName'] ?? 'Membre'}',
                    style: GoogleFonts.inter(fontSize: 11, color: _kMutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: label, accent: pronoSocialPurple),
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
  final ValueChanged<String>? onSubmitted;

  const _SocialField({
    required this.controller,
    required this.label,
    this.focusColor = pronoSocialPurple,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PronoType.kicker.copyWith(color: PronoArenaTheme.textSoft),
        ),
        TextField(
          controller: controller,
          style: PronoType.body,
          cursorColor: focusColor,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PronoArenaTheme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: focusColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Action pleine largeur — encre par défaut, capitales condensées.
class _PrimaryAction extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color? foregroundColor;

  const _PrimaryAction({
    required this.label,
    this.backgroundColor = pronoSocialPurple,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ??
        (ThemeData.estimateBrightnessForColor(backgroundColor) ==
                Brightness.dark
            ? Colors.white
            : PronoArenaTheme.ink);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: PronoType.cta.copyWith(color: fg),
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: PronoArenaTheme.surface,
        borderRadius: BorderRadius.circular(PronoArenaTheme.inkRadius),
        border: Border.all(color: PronoArenaTheme.border),
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: PronoType.cta.copyWith(
          fontSize: 15,
          color: PronoArenaTheme.text,
        ),
      ),
    );
  }
}

/// Initiale de membre — disque ivoire cerclé, jamais un avatar Material.
class _SocialAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _SocialAvatar({required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PronoArenaTheme.surface,
        border: Border.all(color: PronoArenaTheme.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: PronoType.title.copyWith(
          fontSize: size * 0.46,
          color: PronoArenaTheme.textMuted,
        ),
      ),
    );
  }
}

class _SocialSectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SocialSectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return PronoSectionHeader(
      title: title,
      countLabel: count == null ? null : '$count',
      pageAccent: PronoPageAccent.social,
    );
  }
}

class _SocialListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? leadingInitial;
  final IconData? leadingIcon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SocialListTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leadingInitial,
    this.leadingIcon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: PronoPageAccent.social.color.withValues(alpha: 0.05),
        child: Ink(
          decoration: PronoArenaTheme.fixtureTape(),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              if (leadingInitial != null) ...[
                _SocialAvatar(name: leadingInitial!, size: 34),
                const SizedBox(width: 12),
              ] else if (leadingIcon != null) ...[
                SizedBox(
                  width: 30,
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: PronoPageAccent.social.color,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.title.copyWith(fontSize: 19),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.arrow_forward_rounded,
                color: PronoArenaTheme.textSoft,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chiffre de ligue — relevé, pas une tuile.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.stat.copyWith(fontSize: 26, color: accent),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PronoType.kicker.copyWith(
            fontSize: 9,
            color: PronoArenaTheme.textSoft,
          ),
        ),
      ],
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
    this.loaderColor = pronoSocialPurple,
    this.selfHighlightColor = pronoSocialPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PronoSectionHeader(
          title: 'Pronos des potes',
          pageAccent: PronoPageAccent.social,
        ),
        const SizedBox(height: 6),
        Text(
          'Après le résultat officiel, tu vois ici le score posé par chaque '
          'membre de la ligue.',
          style: PronoType.caption,
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<LeagueHistoryMatch>>(
          future: PronoSocialService.leagueHistory(memberIds, limit: 12),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const PronoLoadingTape(rows: 2, horizontalPadding: 0);
            }
            final rows = snap.data ?? const <LeagueHistoryMatch>[];
            if (rows.isEmpty) {
              return _FriendsEmptyLabel(
                text: 'Dès que plusieurs membres ont pronostiqué le même '
                    'match, il apparaît ici avec leurs scores.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows.map((m) {
                return _LeagueHistoryMatchBlock(
                  match: m,
                  currentUid: currentUid,
                  selfHighlightColor: selfHighlightColor,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// Un match de l’historique de ligue — affiche, résultat, puis les scores
/// posés par chaque membre, en réglure.
class _LeagueHistoryMatchBlock extends StatelessWidget {
  final LeagueHistoryMatch match;
  final String currentUid;
  final Color selfHighlightColor;

  const _LeagueHistoryMatchBlock({
    required this.match,
    required this.currentUid,
    required this.selfHighlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult =
        match.resultScore1 != null && match.resultScore2 != null;
    final dateLabel = match.matchDate != null
        ? DateFormat("EEE d MMM · HH'h'mm", 'fr_FR').format(match.matchDate!)
        : '';

    return Container(
      decoration: PronoArenaTheme.fixtureTape(),
      padding: const EdgeInsets.only(top: 16, bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dateLabel.isNotEmpty)
            Text(dateLabel.toUpperCase(), style: PronoType.kicker),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${match.team1} — ${match.team2}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.fixture,
                ),
              ),
              const SizedBox(width: 12),
              if (hasResult)
                Text(
                  '${match.resultScore1} – ${match.resultScore2}',
                  style: PronoType.scoreCompact.copyWith(
                    fontSize: 22,
                    color: PronoArenaTheme.greenBright,
                  ),
                )
              else
                Text('EN ATTENTE', style: PronoType.kicker),
            ],
          ),
          const SizedBox(height: 12),
          ...match.predictions.map((p) {
            final mine = p.uid == currentUid;
            final pts = p.points;
            final ptsLabel = pts == null
                ? '—'
                : (pts == 3
                    ? '+3'
                    : pts == 1
                        ? '+1'
                        : '0');
            return Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      ptsLabel,
                      style: PronoType.rank.copyWith(
                        fontSize: 15,
                        color: pts == 3
                            ? PronoArenaTheme.greenBright
                            : (pts == 1
                                ? PronoArenaTheme.text
                                : PronoArenaTheme.textSoft),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p.displayName + (mine ? ' · toi' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.meta.copyWith(
                        fontSize: 12,
                        color: mine
                            ? selfHighlightColor
                            : PronoArenaTheme.textMuted,
                        fontWeight:
                            mine ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${p.score1Pred} – ${p.score2Pred}',
                    style: PronoType.scoreCompact.copyWith(fontSize: 16),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Corps du moment prono : la scène d’encre, les raccourcis, la tendance,
/// et la barre d’action ancrée en bas.
class _PronoSheet extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> match;
  final String uid;
  final String displayName;

  const _PronoSheet({
    required this.matchId,
    required this.match,
    required this.uid,
    required this.displayName,
  });
  @override
  State<_PronoSheet> createState() => _PronoSheetState();
}

class _PronoSheetState extends State<_PronoSheet> {
  int _s1 = 0, _s2 = 0;
  bool _saving = false;
  bool _loaded = false;
  bool _editing = false;

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
        _editing = true;
        _s1 = (d['score1Pred'] as num?)?.toInt() ?? 0;
        _s2 = (d['score2Pred'] as num?)?.toInt() ?? 0;
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
        await FirebaseFunctions.instance
            .httpsCallable('awardXp')
            .call({'eventType': 'vote_prono'});
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

    if (!_loaded) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: PronoArenaTheme.textSoft,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final kicker = DateFormat("EEEE d MMMM · HH'h'mm", 'fr_FR')
        .format(date.toDate());

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            clipBehavior: Clip.hardEdge,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PronoPredictStage(
                  kicker: kicker,
                  stamp: _editing ? 'Prono posé' : null,
                  team1: team1,
                  team2: team2,
                  logo1: logo1,
                  logo2: logo2,
                  score1: _s1,
                  score2: _s2,
                  onScore1Changed: (v) => setState(() => _s1 = v),
                  onScore2Changed: (v) => setState(() => _s2 = v),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 3,
                          color: PronoArenaTheme.greenBright,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RACCOURCIS',
                          style: PronoType.kicker
                              .copyWith(color: PronoArenaTheme.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Prono1x2QuickPicks(
                      score1: _s1,
                      score2: _s2,
                      onPick: (a, b) => setState(() {
                        _s1 = a;
                        _s2 = b;
                      }),
                    ),
                    const SizedBox(height: 30),
                    PronoOutcomeCommunityBar(
                      matchId: widget.matchId,
                      team1: team1,
                      team2: team2,
                    ),
                    const SizedBox(height: 26),
                    const PronoFootnote(
                      heading: 'Barème',
                      text:
                          'Score exact : 3 pts. Bon résultat 1-N-2 : 1 pt. '
                          'Sinon 0. Tu peux modifier ton score tant que le '
                          'match n’a pas commencé.',
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        _PredictActionBar(
          label: _editing ? 'Mettre à jour' : 'Valider mon prono',
          busy: _saving,
          onTap: _save,
        ),
      ],
    );
  }
}

/// Barre d’action ancrée — le geste final ne scrolle jamais hors de l’écran.
class _PredictActionBar extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _PredictActionBar({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: PronoArenaTheme.surface,
        border: Border(top: BorderSide(color: PronoArenaTheme.hairline)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
      child: PronoInkCta(
        label: label,
        busy: busy,
        onTap: busy ? null : onTap,
      ),
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
          backgroundColor: PronoArenaTheme.scaffoldTop,
          // L’app bar prolonge la scène d’encre : tout le haut de l’écran est
          // un tableau d’affichage, du statut système jusqu’aux chiffres.
          appBar: AppBar(
            backgroundColor: PronoArenaTheme.ink,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 52,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  color: PronoArenaTheme.gold,
                ),
                const SizedBox(width: 9),
                Text('PRONOSTIC', style: PronoType.nameplate),
              ],
            ),
          ),
          body: waiting
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: PronoArenaTheme.textSoft,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : !exists || match == null
                  ? const PronoErrorState(
                      title: 'Match introuvable',
                      body:
                          'Ce match n’est plus au calendrier. Reviens à la liste '
                          'pour choisir une autre affiche.',
                    )
                  : _PronoSheet(
                      matchId: widget.matchId,
                      match: match,
                      uid: widget.uid,
                      displayName: widget.displayName,
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
    final textColor = light ? pronoText : Colors.white;
    final mutedColor = light ? pronoMutedText : _kGrey;
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
          style: GoogleFonts.barlowCondensed(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: _kText,
            height: 1,
            letterSpacing: -0.8,
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
          color: PronoTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PronoTokens.border),
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

