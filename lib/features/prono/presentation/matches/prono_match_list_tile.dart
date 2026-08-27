import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../utils/open_prono_for_match.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';
import '../theme/prono_type.dart';

/// Ligne de calendrier — réglure de journal : gouttière heure, affiche, prono.
class PronoMatchListTile extends StatelessWidget {
  static const _pageAccent = PronoPageAccent.matchs;

  /// Largeur de la gouttière — même axe que le chiffre du jour de l’en-tête.
  static const double _gutterWidth = 52;

  final PronoMatchListItem match;
  final String uid;

  const PronoMatchListTile({
    super.key,
    required this.match,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final locked = !now.isBefore(match.date);
    final daysLeft = match.date.difference(now).inDays;
    final tooEarly = !locked && daysLeft > 7;
    final canProno = !locked && !tooEarly;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .doc('${match.id}_$uid')
          .snapshots(),
      builder: (context, predSnap) {
        final hasPred = predSnap.hasData && predSnap.data!.exists;
        final data = predSnap.data?.data();
        final s1 = data?['score1Pred'];
        final s2 = data?['score2Pred'];
        final playLabel = tooEarly
            ? 'Bientôt'
            : locked
                ? 'Fermé'
                : hasPred
                    ? 'Modif.'
                    : 'Jouer';

        // La barre de gouttière porte l’état — plus de pastille décorative.
        final stateColor = hasPred
            ? _pageAccent.color
            : (canProno ? PronoArenaTheme.gold : PronoArenaTheme.hairline);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canProno
                ? () => openPronoForMatch(context, matchId: match.id)
                : null,
            splashColor: _pageAccent.color.withValues(alpha: 0.06),
            highlightColor: _pageAccent.color.withValues(alpha: 0.04),
            child: Ink(
              decoration: PronoArenaTheme.fixtureTape(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PronoArenaTheme.gutter,
                  14,
                  PronoArenaTheme.gutter,
                  14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _gutterWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('HH:mm', 'fr_FR').format(match.date),
                            style: PronoType.label.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: canProno
                                  ? PronoTokens.text
                                  : PronoTokens.textSoft,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: PronoArenaTheme.animFast,
                            curve: PronoArenaTheme.animCurve,
                            width: 24,
                            height: 2,
                            color: stateColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FixtureTeamLine(
                            url: match.logo1,
                            name: match.team1,
                            dimmed: !canProno && !hasPred,
                          ),
                          const SizedBox(height: 7),
                          _FixtureTeamLine(
                            url: match.logo2,
                            name: match.team2,
                            dimmed: !canProno && !hasPred,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match.competition.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PronoType.kicker.copyWith(
                              color: PronoTokens.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasPred) ...[
                          Text('TON PRONO', style: PronoType.kicker),
                          const SizedBox(height: 3),
                          Text(
                            '$s1–$s2',
                            style: PronoType.scoreCompact.copyWith(
                              color: _pageAccent.color,
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        _StateStamp(label: playLabel, enabled: canProno),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Affiche — écusson discret + nom condensé.
class _FixtureTeamLine extends StatelessWidget {
  final String? url;
  final String name;
  final bool dimmed;

  const _FixtureTeamLine({
    required this.url,
    required this.name,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PronoTeamLogoBadge(url: url, teamName: name, active: !dimmed),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PronoType.fixture.copyWith(
              color: dimmed ? PronoTokens.textMuted : PronoTokens.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tampon d’état — le mot de l’action. Le tap réel, c’est toute la ligne.
class _StateStamp extends StatelessWidget {
  final String label;
  final bool enabled;

  const _StateStamp({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PronoArenaTheme.animFast,
      curve: PronoArenaTheme.animCurve,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      color: enabled ? PronoArenaTheme.ink : PronoArenaTheme.surfaceMuted,
      child: Text(
        label.toUpperCase(),
        style: PronoType.kicker.copyWith(
          letterSpacing: 1.1,
          color: enabled ? PronoArenaTheme.onInk : PronoTokens.textSoft,
        ),
      ),
    );
  }
}

class _PronoTeamLogoBadge extends StatelessWidget {
  final String? url;
  final String teamName;
  final bool active;

  static const double _kLogo = 22;

  const _PronoTeamLogoBadge({
    required this.url,
    required this.teamName,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    Widget logo;
    if (u != null && u.isNotEmpty) {
      logo = ClipOval(
        child: DvcrNetworkImage(
          u,
          width: _kLogo,
          height: _kLogo,
          fit: BoxFit.contain,
          cacheWidth: dvcrCrestCacheWidth(context, _kLogo),
          placeholder: const SizedBox.shrink(),
          errorBuilder: (context, error, stackTrace) =>
              _PronoTeamLogoPlaceholder(teamName: teamName),
        ),
      );
    } else {
      logo = _PronoTeamLogoPlaceholder(teamName: teamName);
    }

    return Opacity(
      opacity: active ? 1 : 0.5,
      child: SizedBox(width: _kLogo, height: _kLogo, child: logo),
    );
  }
}

class _PronoTeamLogoPlaceholder extends StatelessWidget {
  final String teamName;

  static const double _k = 22;

  const _PronoTeamLogoPlaceholder({required this.teamName});

  @override
  Widget build(BuildContext context) {
    final letter = teamName.trim().isNotEmpty
        ? teamName.trim().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      width: _k,
      height: _k,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PronoTokens.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: PronoType.kicker.copyWith(color: PronoTokens.textMuted),
      ),
    );
  }
}
