import 'package:flutter/material.dart';

import '../features/prono/presentation/theme/prono_theme.dart';
import '../features/prono/presentation/theme/prono_type.dart';
import '../features/prono/presentation/widgets/prono_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Langage 4 · TABLE — classement sportif.
//
//  Règles : table entièrement en papier — en-tête souligné d’un filet épais,
//  colonnes chiffrées à droite en chiffres tabulaires, filets fins entre les
//  lignes, podium coiffé de métal, TA ligne marquée d’un liseré d’or.
//  L’encre de l’écran est dépensée ailleurs (le bandeau « ta place ») : la
//  table n’en pose aucune. Aucune ListTile, aucune carte.
// ═══════════════════════════════════════════════════════════════════════════

abstract final class PronoLbStyle {
  static const bg = PronoArenaTheme.scaffoldTop;
  static const highlight = PronoArenaTheme.edgeHighlight;
  static const green = PronoArenaTheme.greenBright;
  static const gold = PronoArenaTheme.gold;
  static const text = PronoArenaTheme.text;
  static const muted = PronoArenaTheme.textMuted;
  static const surface = PronoArenaTheme.surface;
  static const surfaceMuted = PronoArenaTheme.surfaceMuted;
  static const border = PronoArenaTheme.border;
  static const hairline = PronoArenaTheme.hairline;
  static const ink = PronoArenaTheme.ink;

  static const double rankCol = 28;
  static const double markCol = 40;
  static const double ptsCol = 46;
  static const double exactCol = 44;
}

/// Chapeau de classement — kicker + phrase de contexte.
class PronoLbTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const PronoLbTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 16, height: 3, color: PronoLbStyle.gold),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.kicker.copyWith(color: PronoLbStyle.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: PronoType.caption),
        ],
      ),
    );
  }
}

/// Podium 2 · 1 · 3 — visages (initiales), anneau métal, marche d’or / argent /
/// bronze. L’encre de l’écran reste réservée au bandeau « ta place ».
class PronoLbPodium extends StatelessWidget {
  final List<({int rank, String name, String score, bool isMe, String? avatarUrl})>
      top;
  final String meLabel;

  const PronoLbPodium({
    super.key,
    required this.top,
    this.meLabel = 'TOI',
  });

  @override
  Widget build(BuildContext context) {
    if (top.isEmpty) return const SizedBox.shrink();

    ({int rank, String name, String score, bool isMe, String? avatarUrl})? pick(
      int rank,
    ) {
      for (final e in top) {
        if (e.rank == rank) return e;
      }
      return null;
    }

    Widget slot(
      ({int rank, String name, String score, bool isMe, String? avatarUrl})? e, {
      required double avatar,
      required double step,
    }) {
      if (e == null) return const Expanded(child: SizedBox.shrink());
      final color = PronoArenaTheme.podiumRankColor(e.rank);
      final first = e.rank == 1;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                PronoRankMark(
                  name: e.name,
                  rank: e.rank,
                  size: avatar,
                  isMe: e.isMe,
                  avatarUrl: e.avatarUrl,
                ),
                Positioned(
                  bottom: -8,
                  child: _PodiumRankPip(rank: e.rank),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PronoType.label.copyWith(
                  fontSize: first ? 14 : 12,
                  color: PronoLbStyle.text,
                ),
              ),
            ),
            if (e.isMe) ...[
              const SizedBox(height: 3),
              Text(
                meLabel.toUpperCase(),
                style: PronoType.kicker.copyWith(
                  letterSpacing: 1.4,
                  color: PronoArenaTheme.goldDeep,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              e.score,
              style: PronoType.scoreCompact.copyWith(
                fontSize: first ? 30 : 22,
                color: color,
              ),
            ),
            Text(
              'PTS',
              style: PronoType.kicker.copyWith(
                fontSize: 8,
                color: PronoLbStyle.muted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: step,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: color,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SizedBox(
        height: 214,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            slot(pick(2), avatar: 56, step: 10),
            slot(pick(1), avatar: 76, step: 16),
            slot(pick(3), avatar: 56, step: 7),
          ],
        ),
      ),
    );
  }
}

class _PodiumRankPip extends StatelessWidget {
  final int rank;

  const _PodiumRankPip({required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = PronoArenaTheme.podiumRankColor(rank);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: PronoArenaTheme.surface, width: 2),
      ),
      child: Text(
        '$rank',
        style: PronoType.rank.copyWith(
          fontSize: 12,
          color: rank == 1 ? PronoArenaTheme.ink : Colors.white,
        ),
      ),
    );
  }
}

class PronoLbTableShell extends StatelessWidget {
  final List<Widget> children;

  const PronoLbTableShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class PronoLbColumnHeader extends StatelessWidget {
  final String nameLabel;
  final bool showExactColumn;

  const PronoLbColumnHeader({
    super.key,
    required this.nameLabel,
    this.showExactColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    // En-tête PAPIER : le filet bas épais tient lieu de barre. Aucun texte
    // clair ici, tout se lit en encre sur l’ivoire.
    final head = PronoType.kicker.copyWith(color: PronoLbStyle.muted);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: PronoArenaTheme.tableHeaderPaper(),
      child: Row(
        children: [
          SizedBox(
            width: PronoLbStyle.rankCol,
            child: Text('#', style: head),
          ),
          const SizedBox(width: PronoLbStyle.markCol),
          Expanded(
            child: Text(
              nameLabel.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: head,
            ),
          ),
          SizedBox(
            width: PronoLbStyle.ptsCol,
            child: Text(
              'PTS',
              textAlign: TextAlign.right,
              // Colonne qui décide du classement : plein noir, pas de l’or
              // (illisible en petit corps sur ivoire).
              style: PronoType.kicker.copyWith(color: PronoLbStyle.text),
            ),
          ),
          if (showExactColumn) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: PronoLbStyle.exactCol,
              child: Text(
                'EXACTS',
                textAlign: TextAlign.right,
                style: head.copyWith(fontSize: 9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rupture de zone — « … » entre le top et tes voisins de classement.
class PronoLbZoneDivider extends StatelessWidget {
  final String label;

  const PronoLbZoneDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PronoLbStyle.surfaceMuted,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: PronoArenaTheme.edgeHighlight),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: PronoType.kicker.copyWith(color: PronoLbStyle.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: PronoArenaTheme.edgeHighlight),
          ),
        ],
      ),
    );
  }
}

/// Ligne de classement. Ta ligne reste du papier, marquée d’un liseré d’or à
/// gauche et d’un rang en or — la dalle sombre est déjà dépensée par l’écran.
class PronoLbDataRow extends StatelessWidget {
  final int displayRank;
  final String title;
  final String? subtitle;
  final int points;
  final String? pointsLabel;
  final int? exactScores;
  final int? xiCount;
  final bool podiumHighlight;
  final bool isMe;
  final bool showExactColumn;
  final bool dense;
  final String meLabel;
  final String? avatarUrl;
  final String? uid;
  final VoidCallback? onTap;

  const PronoLbDataRow({
    super.key,
    required this.displayRank,
    required this.title,
    this.subtitle,
    required this.points,
    this.pointsLabel,
    this.exactScores,
    this.xiCount,
    required this.podiumHighlight,
    required this.isMe,
    this.showExactColumn = true,
    this.dense = false,
    this.meLabel = 'TOI',
    this.avatarUrl,
    this.uid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPodium = podiumHighlight || displayRank <= 3;
    final podiumColor = PronoArenaTheme.podiumRankColor(displayRank);
    const fg = PronoLbStyle.text;
    const muted = PronoLbStyle.muted;
    final xi = xiCount ?? 0;

    final row = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 7 : 11,
      ),
      decoration: isMe
          ? const BoxDecoration(
              color: PronoArenaTheme.surface,
              border: Border(
                left: BorderSide(color: PronoArenaTheme.gold, width: 3),
                bottom: BorderSide(color: PronoArenaTheme.hairline),
              ),
            )
          : const BoxDecoration(
              color: PronoArenaTheme.surface,
              border: Border(
                bottom: BorderSide(color: PronoArenaTheme.hairline),
              ),
            ),
      child: Row(
        children: [
          SizedBox(
            width: PronoLbStyle.rankCol,
            child: Text(
              '$displayRank',
              style: PronoType.rank.copyWith(
                color: isMe
                    ? PronoLbStyle.gold
                    : (isPodium ? podiumColor : PronoLbStyle.muted),
                fontSize: 17,
              ),
            ),
          ),
          SizedBox(
            width: PronoLbStyle.markCol,
            child: PronoRankMark(
              name: title,
              rank: displayRank,
              size: dense ? 28 : 32,
              isMe: isMe,
              avatarUrl: avatarUrl,
              uid: uid,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PronoType.label.copyWith(color: fg),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Text(
                        meLabel.toUpperCase(),
                        style: PronoType.kicker.copyWith(
                          letterSpacing: 1.4,
                          color: PronoArenaTheme.goldDeep,
                        ),
                      ),
                    ],
                  ],
                ),
                if ((subtitle != null && subtitle!.trim().isNotEmpty) ||
                    xi > 0) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PronoType.meta.copyWith(color: muted),
                        ),
                      // Non négociable : le « XI 11/11 » reste sur toutes les
                      // lignes, y compris la tienne (désormais en papier).
                      if (xi > 0) PronoXiChip(count: xi),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: PronoLbStyle.ptsCol,
            child: Text(
              pointsLabel ?? '$points',
              textAlign: TextAlign.right,
              style: PronoType.scoreCompact.copyWith(
                fontSize: 23,
                color: isPodium && !isMe ? podiumColor : fg,
              ),
            ),
          ),
          if (showExactColumn) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: PronoLbStyle.exactCol,
              child: Text(
                '${exactScores ?? 0}',
                textAlign: TextAlign.right,
                style: PronoType.meta.copyWith(fontSize: 13, color: muted),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class PronoLbFootnote extends StatelessWidget {
  final String text;

  const PronoLbFootnote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: PronoFootnote(text: text),
    );
  }
}
