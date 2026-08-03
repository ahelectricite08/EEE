import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/match_stats_schema.dart';
import '../screens/admin/admin_module_colors.dart';
import '../screens/admin/admin_palette.dart';
import '../services/match_coach_audio_service.dart';
import 'match_coach_audio_sheet.dart';
import 'match_commentary_record_sheet.dart';
import 'match_event_audio_play_button.dart';
import 'match_event_video_play_button.dart';
import 'match_highlight_attach_sheet.dart';
import 'match_highlight_export_panel.dart';

/// Après le live : audio / clips vMix / export résumé sur un match terminé.
class MatchPostMediaAdminPanel extends StatefulWidget {
  const MatchPostMediaAdminPanel({super.key});

  @override
  State<MatchPostMediaAdminPanel> createState() =>
      _MatchPostMediaAdminPanelState();
}

class _MatchPostMediaAdminPanelState extends State<MatchPostMediaAdminPanel> {
  String? _matchId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .orderBy('date', descending: true)
          .limit(25)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          // Fallback sans index composite : lecture récente filtrée client.
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .orderBy('date', descending: true)
                .limit(40)
                .snapshots(),
            builder: (context, snap2) {
              final docs = (snap2.data?.docs ?? [])
                  .where((d) => (d.data()['status'] ?? '') == 'finished')
                  .take(25)
                  .toList();
              return _buildBody(docs);
            },
          );
        }
        return _buildBody(snap.data?.docs ?? []);
      },
    );
  }

  Widget _buildBody(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: adminBorder),
        ),
        child: Text(
          'Aucun match terminé récent — dès qu’un live est archivé, '
          'tu pourras ici refaire l’audio, joindre les clips et exporter le résumé.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.35),
        ),
      );
    }

    final ids = docs.map((d) => d.id).toList();
    final selectedId =
        _matchId != null && ids.contains(_matchId) ? _matchId! : docs.first.id;
    if (_matchId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _matchId = selectedId);
      });
    }

    final selected = docs.firstWhere((d) => d.id == selectedId);
    final data = selected.data();
    final team1 = (data['team1'] ?? '').toString();
    final team2 = (data['team2'] ?? '').toString();
    final date = data['date'];
    DateTime? dt;
    if (date is Timestamp) dt = date.toDate();
    final dateLabel =
        dt != null ? DateFormat('dd/MM HH:mm').format(dt) : '';

    final events = MatchStatsSchema.eventsFromMatchDoc(data)
        .where((e) {
          final t = (e['type'] ?? '').toString();
          return const {
            'goal',
            'own_goal',
            'yellow',
            'red',
            'substitution',
            'goal_cancelled',
            'goal_disallowed',
            'offside',
          }.contains(t);
        })
        .toList()
      ..sort((a, b) {
        final ma = (a['minute'] as num?)?.toInt() ?? 0;
        final mb = (b['minute'] as num?)?.toInt() ?? 0;
        return mb.compareTo(ma);
      });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminModuleColors.apresMatch.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.movie_filter_rounded,
                  size: 16, color: AdminModuleColors.apresMatch),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MÉDIAS POST-MATCH',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AdminModuleColors.apresMatch,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Parole du coach, audio faits de jeu, clips vMix et export résumé.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            dropdownColor: adminCard,
            decoration: InputDecoration(
              labelText: 'Match terminé',
              labelStyle: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              filled: true,
              fillColor: adminSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
            items: docs.map((d) {
              final m = d.data();
              final t1 = (m['team1'] ?? '?').toString();
              final t2 = (m['team2'] ?? '?').toString();
              final raw = m['date'];
              var dl = '';
              if (raw is Timestamp) {
                dl = DateFormat('dd/MM').format(raw.toDate());
              }
              return DropdownMenuItem(
                value: d.id,
                child: Text(
                  '$dl · $t1 – $t2',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _matchId = v);
            },
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel.isEmpty ? '$team1 – $team2' : '$dateLabel · $team1 – $team2',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _CoachAudioAdminRow(matchId: selectedId),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Text(
              'Aucun fait de jeu sur cette fiche.',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            )
          else
            ...events.map((g) {
              final typ = (g['type'] ?? '').toString();
              final line = MatchStatsSchema.eventPlayerLine(g);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        "${g['minute'] ?? '?'}'",
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AdminModuleColors.apresMatch,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$line · $typ',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    MatchEventAudioRecordButton(
                      matchId: selectedId,
                      event: g,
                      accent: AdminModuleColors.apresMatch,
                      onRecord: () async {
                        final eid = (g['id'] ?? '').toString().trim();
                        if (eid.isEmpty) return;
                        final ok = await showMatchCommentaryRecordSheet(
                          context,
                          matchId: selectedId,
                          eventId: eid,
                          type: typ,
                          minute: (g['minute'] as num?)?.toInt() ?? 0,
                          player: (g['player'] ?? '').toString(),
                          team: (g['team'] ?? '').toString(),
                        );
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Audio publié',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: adminGreen,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    MatchEventVideoAttachButton(
                      accent: AdminModuleColors.apresMatch,
                      onAttach: () async {
                        final eid = (g['id'] ?? '').toString().trim();
                        if (eid.isEmpty) return;
                        final ok = await showMatchHighlightAttachSheet(
                          context,
                          matchId: selectedId,
                          eventId: eid,
                          type: typ,
                          minute: (g['minute'] as num?)?.toInt() ?? 0,
                          player: (g['player'] ?? '').toString(),
                          team: (g['team'] ?? '').toString(),
                        );
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Clip publié',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: adminGreen,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          MatchHighlightExportPanel(matchId: selectedId, compact: true),
        ],
      ),
    );
  }
}

/// Bloc admin : publier / remplacer / supprimer la parole du coach.
class _CoachAudioAdminRow extends StatelessWidget {
  final String matchId;
  const _CoachAudioAdminRow({required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MatchCoachAudio?>(
      stream: MatchCoachAudioService.instance.watch(matchId),
      builder: (context, snap) {
        final audio = snap.data;
        final hasAudio = audio != null && audio.isReady;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: adminSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AdminModuleColors.apresMatch.withAlpha(70),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: AdminModuleColors.apresMatch,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PAROLE DU COACH',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminModuleColors.apresMatch,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (hasAudio)
                    ValueListenableBuilder<int>(
                      valueListenable:
                          MatchCommentaryPlayer.instance.playingListenable,
                      builder: (context, _, __) {
                        final playing =
                            MatchCommentaryPlayer.instance.playingUrl ==
                                audio.audioUrl;
                        return IconButton(
                          tooltip: playing ? 'Arrêter' : 'Écouter',
                          onPressed: () => MatchCommentaryPlayer.instance
                              .toggle(audio.audioUrl),
                          icon: Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: AdminModuleColors.apresMatch,
                          ),
                        );
                      },
                    ),
                ],
              ),
              Text(
                hasAudio
                    ? (audio.title.trim().isNotEmpty
                        ? audio.title.trim()
                        : 'Audio publié — visible sur Résumé')
                    : 'Aucun audio — enregistre ou importe un fichier.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: hasAudio ? adminTextPrimary : adminGrey,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await showMatchCoachAudioSheet(
                          context,
                          matchId: matchId,
                        );
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Parole du coach publiée',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: adminGreen,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        hasAudio
                            ? Icons.refresh_rounded
                            : Icons.mic_rounded,
                        size: 16,
                      ),
                      label: Text(
                        hasAudio ? 'Remplacer' : 'Ajouter',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminModuleColors.apresMatch,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (hasAudio) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: adminCard,
                            title: Text(
                              'Supprimer ?',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                color: adminTextPrimary,
                              ),
                            ),
                            content: Text(
                              'La parole du coach sera retirée de la fiche match.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: adminGrey,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  'Annuler',
                                  style: GoogleFonts.inter(color: adminGrey),
                                ),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: adminRed,
                                ),
                                child: Text(
                                  'Supprimer',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await MatchCoachAudioService.instance.delete(matchId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Parole du coach supprimée',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: adminGrey,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: adminRed,
                        side: BorderSide(color: adminRed.withAlpha(120)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Suppr.',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
