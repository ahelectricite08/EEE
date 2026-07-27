import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_stats_schema.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import 'match_stats_editor.dart';
import 'match_player_facts_panel.dart';
import 'stats_publication_controls.dart';

/// Saisie stats — workbench statisticien (publication carte / officiel).
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
            backgroundColor: AdminModuleColors.apresMatch.withAlpha(230),
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
                color: AdminModuleColors.apresMatch,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            color: AdminModuleColors.apresMatch,
          ),
        ),
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
              final pub = MatchStatsPublicationSettings.fromSheet(sheetData);
              final isOfficial = pub.official;
              final workbenchLocked = !pub.workbenchOpen;
              final lastAppSync = matchData['statsPreviewAt'] as Timestamp? ??
                  sheetData['updatedAt'] as Timestamp?;
              final eventsRaw = sheetData['events'] ?? matchData['events'];
              final events = MatchStatsSchema.parseGameEvents(eventsRaw);
              final goalsByPlayer = MatchStatsSchema.goalsByPlayer(events);
              final editorData = {
                'team1': widget.team1,
                'team2': widget.team2,
                'stats': stats,
              };

              return CustomScrollView(
                slivers: [
                  if (goalsByPlayer.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: goalsByPlayer.entries.map((e) {
                            final label = e.value > 1
                                ? '${e.key} · ${e.value} buts'
                                : '${e.key} · 1 but';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AdminModuleColors.apresMatch.withAlpha(22),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AdminModuleColors.apresMatch.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: adminTextPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Dernière sync carte : ${_formatSyncTime(lastAppSync)} · '
                        'Brouillon auto-enregistré · Live = onglet Direct',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: adminGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StatsPublicationControls(
                        matchId: widget.matchId,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: MatchPlayerFactsPanel(
                        events: events,
                        team1: widget.team1,
                        team2: widget.team2,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  if (!isOfficial)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                          () => MatchStatsSheetService
                                              .instance
                                              .syncNow(widget.matchId),
                                          'Sync carte envoyée',
                                        ),
                                icon: const Icon(Icons.sync_rounded, size: 16),
                                label: const Text('Sync carte'),
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
                    ),
                  if (workbenchLocked)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: adminGold.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: adminGold.withAlpha(80)),
                          ),
                          child: Text(
                            'Fiche verrouillée — activez « Débloquer la fiche stats » '
                            'ci-dessus pour modifier les chiffres.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: adminTextPrimary,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      child: IgnorePointer(
                        ignoring: workbenchLocked,
                        child: Opacity(
                          opacity: workbenchLocked ? 0.5 : 1,
                          child: MatchStatsEditor(
                            key: ValueKey(widget.matchId),
                            data: editorData,
                            matchId: widget.matchId,
                            isPublished: isOfficial,
                          ),
                        ),
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
