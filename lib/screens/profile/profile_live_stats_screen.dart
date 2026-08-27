import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../screens/admin/tabs/stats/match_stats_editor.dart';
import '../../services/live_state_service.dart';
import '../../services/match_stats_sheet_service.dart';
import 'profile_palette.dart';
import 'profile_shell_widgets.dart';
import 'profile_type.dart';

/// Saisie stats live depuis le profil (statisticien / admin).
class ProfileLiveStatsScreen extends StatefulWidget {
  const ProfileLiveStatsScreen({super.key});

  @override
  State<ProfileLiveStatsScreen> createState() => _ProfileLiveStatsScreenState();
}

class _ProfileLiveStatsScreenState extends State<ProfileLiveStatsScreen> {
  String _preparedId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: profileBg,
      appBar: ProfileSubpageAppBar.build(context, 'Faire les stats'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: LiveStateService.watchCurrentSnapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucun live en cours.',
                  style: ProfileType.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snap.data!.data() ?? <String, dynamic>{};
          final matchId = (data['matchId'] as String? ?? '').trim();
          if (matchId.isNotEmpty && matchId != _preparedId) {
            _preparedId = matchId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MatchStatsSheetService.instance.prepareSession(matchId);
            });
          }
          if (matchId.isEmpty) {
            return Center(
              child: Text(
                'Match introuvable pour ce live.',
                style: ProfileType.body,
              ),
            );
          }
          final statsRaw = data['stats'];
          final editorData = Map<String, dynamic>.from(data);
          if (statsRaw is Map) {
            editorData['stats'] = Map<String, dynamic>.from(statsRaw);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            children: [
              Text(
                '${(data['team1'] as String? ?? 'Équipe 1').trim()} — '
                '${(data['team2'] as String? ?? 'Équipe 2').trim()}',
                style: ProfileType.section,
              ),
              const SizedBox(height: 4),
              Text(
                'Les compteurs s’écrivent sur le live, comme dans l’admin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: profileMutedText,
                ),
              ),
              const SizedBox(height: 12),
              MatchStatsEditor(
                data: editorData,
                matchId: matchId,
              ),
            ],
          );
        },
      ),
    );
  }
}
