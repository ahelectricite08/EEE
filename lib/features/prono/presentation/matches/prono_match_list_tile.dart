import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../utils/open_prono_for_match.dart';
import '../../domain/models/prono_match_list_item.dart';
import '../theme/prono_theme.dart';
import '../theme/prono_tokens.dart';

class PronoMatchListTile extends StatelessWidget {
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
        final playLabel = tooEarly
            ? 'Bientôt'
            : locked
                ? 'Terminé'
                : hasPred
                    ? 'Modifier'
                    : 'Jouer';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: PronoTheme.cardDecoration(
            radius: PronoTokens.radiusMd,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PronoTokens.radiusMd - 1),
            child: Material(
              color: PronoTokens.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.competition.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: PronoTokens.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _PronoTeamLogoBadge(
                                url: match.logo1,
                                teamName: match.team1,
                                active: canProno,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  match.team1,
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: PronoTokens.text,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '–',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: PronoTokens.textSoft,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  match.team2,
                                  textAlign: TextAlign.end,
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: PronoTokens.text,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _PronoTeamLogoBadge(
                                url: match.logo2,
                                teamName: match.team2,
                                active: canProno,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat("EEE d MMM · HH:mm", 'fr_FR')
                          .format(match.date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: PronoTokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasPred) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ton prono : ${(predSnap.data!.data()!['score1Pred'])} - ${(predSnap.data!.data()!['score2Pred'])}',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: PronoPageAccent.matchs.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PlayChipButton(
                        label: playLabel,
                        enabled: canProno,
                        onPressed: canProno
                            ? () => openPronoForMatch(context,
                                matchId: match.id)
                            : null,
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
  }
}

class _PlayChipButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const _PlayChipButton({
    required this.label,
    required this.enabled,
    this.onPressed,
  });

  @override
  State<_PlayChipButton> createState() => _PlayChipButtonState();
}

class _PlayChipButtonState extends State<_PlayChipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled && widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled && widget.onPressed != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: PronoTokens.animFast,
        curve: PronoTokens.animCurve,
        child: AnimatedContainer(
          duration: PronoTokens.animNormal,
          curve: PronoTokens.animCurve,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: PronoTheme.playChipDecoration(
            enabled: widget.enabled,
            pageAccent: PronoPageAccent.matchs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.enabled) ...[
                Icon(
                  widget.label == 'Modifier'
                      ? Icons.edit_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: widget.enabled
                      ? PronoPageAccent.matchs.onColor
                      : PronoTokens.textSoft,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label.toUpperCase(),
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: widget.enabled
                      ? PronoPageAccent.matchs.onColor
                      : PronoTokens.textSoft,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PronoTeamLogoBadge extends StatelessWidget {
  final String? url;
  final String teamName;
  final bool active;

  static const double _kLogo = 44;

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
        child: Image.network(
          u,
          width: _kLogo,
          height: _kLogo,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _PronoTeamLogoPlaceholder(teamName: teamName),
        ),
      );
    } else {
      logo = _PronoTeamLogoPlaceholder(teamName: teamName);
    }

    return Container(
      width: _kLogo + 4,
      height: _kLogo + 4,
      padding: const EdgeInsets.all(2),
      decoration: PronoTheme.teamLogoRing(active: active),
      child: logo,
    );
  }
}

class _PronoTeamLogoPlaceholder extends StatelessWidget {
  final String teamName;

  static const double _k = 40;

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
      decoration: BoxDecoration(
        color: PronoTokens.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: GoogleFonts.barlowCondensed(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: PronoTokens.textMuted,
        ),
      ),
    );
  }
}
