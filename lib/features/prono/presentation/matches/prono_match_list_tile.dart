import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../utils/open_prono_for_match.dart';
import '../../domain/models/prono_match_list_item.dart';
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
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
            border: Border.all(
              color: PronoTokens.cardBorderHighlight(canProno),
              width: 1,
            ),
            boxShadow: PronoTokens.cardShadow(context),
          ),
          child: ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 1),
            child: Material(
              color: PronoTokens.surface,
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: PronoTokens.barStripeColors(active: canProno),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: PronoTokens.surfaceMuted.withAlpha(180),
                                borderRadius:
                                    BorderRadius.circular(PronoTokens.radiusSm),
                              ),
                              child: Text(
                                match.competition.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: PronoTokens.accentGold,
                                  letterSpacing: 0.85,
                                ),
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
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          match.team1,
                                          style:
                                              GoogleFonts.barlowCondensed(
                                            fontSize: 19,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    'vs',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
                                          style:
                                              GoogleFonts.barlowCondensed(
                                            fontSize: 19,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hasPred) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Ton prono : ${(predSnap.data!.data()!['score1Pred'])} - ${(predSnap.data!.data()!['score2Pred'])}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PronoTokens.accent,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: canProno
                                    ? () => openPronoForMatch(context,
                                        matchId: match.id)
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: PronoTokens.accent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      PronoTokens.surfaceMuted,
                                  disabledForegroundColor: PronoTokens.textSoft,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: canProno ? 1 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      PronoTokens.radiusMd,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  tooEarly
                                      ? 'Bientôt ouvert'
                                      : locked
                                          ? 'Match terminé'
                                          : hasPred
                                              ? 'Modifier mon prono'
                                              : 'Pronostiquer',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
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
  }
}

class _PronoTeamLogoBadge extends StatelessWidget {
  final String? url;
  final String teamName;

  static const double _kLogo = 40;

  const _PronoTeamLogoBadge({
    required this.url,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    if (u != null && u.isNotEmpty) {
      return SizedBox(
        width: _kLogo,
        height: _kLogo,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            u,
            width: _kLogo,
            height: _kLogo,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: _kLogo,
              height: _kLogo,
              child: Center(
                child: SizedBox(
                  width: _kLogo * 0.45,
                  height: _kLogo * 0.45,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PronoTokens.accent.withAlpha(140),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _PronoTeamLogoPlaceholder(teamName: teamName),
          ),
        ),
      );
    }
    return _PronoTeamLogoPlaceholder(teamName: teamName);
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PronoTokens.border.withAlpha(120)),
      ),
      child: Text(
        letter,
        style: GoogleFonts.barlowCondensed(
          fontSize: _k * 0.45,
          fontWeight: FontWeight.w900,
          color: PronoTokens.textSoft,
        ),
      ),
    );
  }
}
