import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_stats_schema.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_palette.dart';
import 'match_stats_editor.dart';
import 'stats_admin_helpers.dart';
import 'stats_workflow_ui.dart';

/// Saisie stats — 3 étapes : Préparer → En direct → Officiel.
class MatchStatsWorkbenchScreen extends StatefulWidget {
  final String matchId;
  final String team1;
  final String team2;

  const MatchStatsWorkbenchScreen({
    super.key,
    required this.matchId,
    required this.team1,
    required this.team2,
  });

  @override
  State<MatchStatsWorkbenchScreen> createState() =>
      _MatchStatsWorkbenchScreenState();
}

class _MatchStatsWorkbenchScreenState extends State<MatchStatsWorkbenchScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    MatchStatsSheetService.instance.prepareSession(widget.matchId);
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(okMessage, style: GoogleFonts.inter()),
            backgroundColor: adminGold.withAlpha(230),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  String _formatSyncTime(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à $h:$m';
  }

  Future<bool> _confirm(String title, String body) async {
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
              'OK',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final matchRef =
        FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
    final sheetRef = MatchStatsSheetService.instance.docRef(widget.matchId);

    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: adminBg,
        foregroundColor: adminTextPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SAISIE STATS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${widget.team1} · ${widget.team2}',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: sheetRef.snapshots(),
        builder: (context, sheetSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: matchRef.snapshots(),
            builder: (context, matchSnap) {
              final matchData = matchSnap.data?.data() ?? {};
              final sheetData = sheetSnap.data?.data() ?? {};
              final stats = MatchStatsSchema.normalizeMap(
                (sheetData['stats'] as Map<String, dynamic>?) ??
                    (matchData['stats'] as Map<String, dynamic>?),
              );
              final step = statsWorkflowStep(
                {
                  ...matchData,
                  if (sheetData['state'] != null)
                    'statsState': sheetData['state'],
                },
              );
              final isOfficial = step == StatsWorkflowStep.official;
              final lastAppSync = matchData['statsPreviewAt'] as Timestamp? ??
                  sheetData['updatedAt'] as Timestamp?;
              final editorData = {
                'team1': widget.team1,
                'team2': widget.team2,
                'stats': stats,
              };

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: StatsWorkflowStepper(step: step),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Dernière publication app : ${_formatSyncTime(lastAppSync)} · '
                      'Saisie auto-enregistrée',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isOfficial
                        ? FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (!await _confirm(
                                      'Rouvrir pour corriger ?',
                                      'Tu pourras modifier puis terminer à nouveau.',
                                    )) {
                                      return;
                                    }
                                    await _run(
                                      () => MatchStatsSheetService.instance
                                          .reopen(widget.matchId),
                                      'Saisie rouverte',
                                    );
                                  },
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Rouvrir pour corriger'),
                            style: FilledButton.styleFrom(
                              backgroundColor: adminGold,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(44),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                            () => MatchStatsSheetService
                                                .instance
                                                .syncNow(widget.matchId),
                                            'Publié dans l\'app',
                                          ),
                                  icon: const Icon(Icons.sync_rounded, size: 16),
                                  label: const Text('Publier'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4A90D9),
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          if (!await _confirm(
                                            'Terminer le match ?',
                                            'Stats officielles sur la fiche match.',
                                          )) {
                                            return;
                                          }
                                          await _run(
                                            () => MatchStatsSheetService
                                                .instance
                                                .finalize(widget.matchId),
                                            'Match terminé — stats officielles',
                                          );
                                        },
                                  icon: const Icon(Icons.flag_rounded, size: 16),
                                  label: const Text('Terminer'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: adminGreenAccent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: MatchStatsEditor(
                        key: ValueKey(widget.matchId),
                        data: editorData,
                        matchId: widget.matchId,
                        isPublished: isOfficial,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
