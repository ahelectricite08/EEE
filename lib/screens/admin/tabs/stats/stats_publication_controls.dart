import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_stats_schema.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_palette.dart';
import 'stats_admin_helpers.dart';

/// Boutons admin pour changer l’état publication (À saisir / En direct / Officiel).
class StatsPublicationControls extends StatefulWidget {
  final String matchId;
  final bool compact;

  const StatsPublicationControls({
    super.key,
    required this.matchId,
    this.compact = false,
  });

  @override
  State<StatsPublicationControls> createState() =>
      _StatsPublicationControlsState();
}

class _StatsPublicationControlsState extends State<StatsPublicationControls> {
  bool _busy = false;

  Future<void> _setState(
    BuildContext context,
    MatchStatsPublicationState target,
    String okLabel,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MatchStatsSheetService.instance.setPublicationState(
        widget.matchId,
        target,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(okLabel, style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(230),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndSet(
    BuildContext context, {
    required String title,
    required String body,
    required MatchStatsPublicationState target,
    required String okLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          title,
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Text(
          body,
          style: GoogleFonts.inter(color: adminGrey, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CONFIRMER',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _setState(context, target, okLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId);
    final sheetRef = FirebaseFirestore.instance
        .collection('match_stats')
        .doc(widget.matchId);

    return StreamBuilder<DocumentSnapshot>(
      stream: matchRef.snapshots(),
      builder: (context, matchSnap) {
        return StreamBuilder<DocumentSnapshot>(
          stream: sheetRef.snapshots(),
          builder: (context, sheetSnap) {
            final matchData =
                matchSnap.data?.data() as Map<String, dynamic>? ?? {};
            final sheetData =
                sheetSnap.data?.data() as Map<String, dynamic>? ?? {};
            final step = statsWorkflowStep(
              matchData,
              sheetState: sheetData['state']?.toString(),
            );
            final label = statsWorkflowLabel(step);
            final color = statsWorkflowColor(step);

            Widget chip(
              String text,
              StatsWorkflowStep targetStep,
              MatchStatsPublicationState targetState,
              String confirmTitle,
              String confirmBody,
              String okLabel,
            ) {
              final selected = step == targetStep;
              return Expanded(
                child: OutlinedButton(
                  onPressed: _busy || selected
                      ? null
                      : () => _confirmAndSet(
                            context,
                            title: confirmTitle,
                            body: confirmBody,
                            target: targetState,
                            okLabel: okLabel,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selected ? Colors.black : adminTextPrimary,
                    backgroundColor: selected ? adminGold.withAlpha(200) : null,
                    side: BorderSide(
                      color: selected ? adminGold : adminBorder,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: widget.compact ? 8 : 10,
                      horizontal: 4,
                    ),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: widget.compact ? 9 : 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.all(widget.compact ? 12 : 14),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'État publication stats',
                          style: GoogleFonts.inter(
                            fontSize: widget.compact ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(28),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withAlpha(100)),
                        ),
                        child: Text(
                          label.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Bloqué en « Officiel » après des tests ? Repasse en « En direct » '
                      'pour que les stats live se mettent à jour dans l’app.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      chip(
                        'À saisir',
                        StatsWorkflowStep.prepare,
                        MatchStatsPublicationState.draft,
                        'Repasse à « À saisir » ?',
                        'Le match n’est plus clôturé côté stats. '
                            'Les chiffres restent en brouillon (pas de preview app).',
                        'État : à saisir',
                      ),
                      const SizedBox(width: 6),
                      chip(
                        'En direct',
                        StatsWorkflowStep.live,
                        MatchStatsPublicationState.preview,
                        'Repasse en « En direct » ?',
                        'Les stats seront à nouveau publiées dans l’app '
                            '(preview + flux live si le match est en cours).',
                        'État : en direct',
                      ),
                      const SizedBox(width: 6),
                      chip(
                        'Officiel',
                        StatsWorkflowStep.official,
                        MatchStatsPublicationState.published,
                        'Clôturer les stats ?',
                        'Les stats deviennent officielles sur la fiche match '
                            '(comme après « Terminer »).',
                        'État : officiel',
                      ),
                    ],
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: adminGold,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
