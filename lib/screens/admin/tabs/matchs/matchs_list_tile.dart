import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_model.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../../widgets/admin_match_quick_actions.dart';
import 'match_editor.dart';
import 'matchs_replay_sheet.dart';

/// Ligne match Admin — densifiée, accent Préparation, sans chrome décoratif.
class MatchAdminListTile extends StatelessWidget {
  final DocumentSnapshot docSnap;
  final bool staleUpcomingDate;

  const MatchAdminListTile({
    super.key,
    required this.docSnap,
    this.staleUpcomingDate = false,
  });

  static String _fieldStr(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'finished':
        return 'TERMINÉ';
      case 'live':
        return 'LIVE';
      default:
        return 'À VENIR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = docSnap.data() as Map<String, dynamic>;
    var t1 = _fieldStr(d, 'team1');
    var t2 = _fieldStr(d, 'team2');
    if (t1.isEmpty) t1 = 'Équipe 1';
    if (t2.isEmpty) t2 = 'Équipe 2';
    final s1 = MatchModel.parseScoreField(d['score1'] ?? d['homeScore']);
    final s2 = MatchModel.parseScoreField(d['score2'] ?? d['awayScore']);
    final status = (d['status'] ?? 'upcoming').toString();
    final comp = _fieldStr(d, 'competition');
    final hasReplay = d['replayVideoId'] != null;
    final accent = AdminModuleColors.preparation;
    final statusColor = status == 'finished'
        ? AdminModuleColors.apresMatch
        : status == 'live'
            ? AdminModuleColors.live
            : accent;
    final rawDate = d['date'];
    final dateStr = rawDate is Timestamp
        ? '${rawDate.toDate().day.toString().padLeft(2, '0')}/'
            '${rawDate.toDate().month.toString().padLeft(2, '0')}/'
            '${rawDate.toDate().year}'
        : '';
    final teamStyle = GoogleFonts.barlowCondensed(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: adminTextPrimary,
      height: 1.15,
    );

    return Material(
      color: adminCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: adminBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchEditorScreen(doc: docSnap),
            fullscreenDialog: true,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t1,
                              style: teamStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              s1 != null && s2 != null ? '$s1–$s2' : 'VS',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: s1 != null ? 16 : 12,
                                fontWeight: FontWeight.w900,
                                color: s1 != null
                                    ? adminTextPrimary
                                    : adminGrey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              t2,
                              style: teamStyle,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Actions',
                            color: adminCard,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: adminBorder),
                            ),
                            onSelected: (v) => _onMenu(context, v),
                            itemBuilder: (_) => [
                              _item('edit', Icons.edit_rounded, 'Modifier'),
                              _item(
                                'replay',
                                Icons.video_call_rounded,
                                hasReplay ? 'Éditer replay' : 'Ajouter replay',
                              ),
                              _item(
                                'delete',
                                Icons.delete_rounded,
                                'Supprimer',
                                color: adminRed,
                              ),
                            ],
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: adminGrey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          if (comp.isNotEmpty) ...[
                            if (dateStr.isNotEmpty)
                              Text(
                                ' · ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: adminGreyLight,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                comp,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: adminTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          AdminStatusChip(
                            label: _statusLabel(status),
                            color: statusColor,
                          ),
                          if (staleUpcomingDate) ...[
                            const SizedBox(width: 6),
                            const AdminStatusChip(
                              label: 'DATE PASSÉE',
                              color: adminOrange,
                            ),
                          ],
                          if (hasReplay) ...[
                            const SizedBox(width: 6),
                            AdminStatusChip(label: 'REPLAY', color: accent),
                          ],
                        ],
                      ),
                      if (staleUpcomingDate) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Passe le statut en Terminé (ou Live) : la date est déjà passée.',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: adminOrange,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      AdminMatchQuickActions(
                        matchId: docSnap.id,
                        team1: t1,
                        team2: t2,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String v) async {
    if (v == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchEditorScreen(doc: docSnap),
          fullscreenDialog: true,
        ),
      );
    } else if (v == 'replay') {
      showMatchReplaySheet(context, docSnap);
    } else if (v == 'delete') {
      final ok = await adminConfirm(context, 'Supprimer ce match ?');
      if (ok) await docSnap.reference.delete();
    }
  }

  PopupMenuItem<String> _item(
    String v,
    IconData icon,
    String label, {
    Color? color,
  }) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? adminTextPrimary),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? adminTextPrimary,
              ),
            ),
          ],
        ),
      );
}
