import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../features/prono/domain/prono_lock.dart';
import '../../../models/match_model.dart';
import '../../../navigation/prono_championship_rollout.dart';
import '../../../utils/match_competition.dart';
import '../../../utils/open_prono_for_match.dart';
import '../theme/calendar_theme.dart';
import '../theme/calendar_type.dart';

/// Pied de carte calendrier : « Ton prono 2–1 » seulement si un prono existe.
class CalendarPronoLine extends StatelessWidget {
  final MatchModel match;

  const CalendarPronoLine({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    if (!PronoChampionshipRollout.isHubVisible) {
      return const SizedBox.shrink();
    }
    if (!MatchCompetition.isPronoEligible(
      match.competition,
      matchId: match.id,
    )) {
      return const SizedBox.shrink();
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('predictions')
          .doc('${match.id}_$uid')
          .snapshots(),
      builder: (context, predSnap) {
        if (predSnap.data?.exists != true) {
          return const SizedBox.shrink();
        }
        final data = predSnap.data?.data();
        final p1 = MatchModel.parseScoreField(data?['score1Pred']);
        final p2 = MatchModel.parseScoreField(data?['score2Pred']);
        if (p1 == null || p2 == null) return const SizedBox.shrink();
        final pts = (data?['points'] as num?)?.toInt();
        final label = pronoPostedLine(
          predHome: p1,
          predAway: p2,
          points: pts,
        );
        return GestureDetector(
          onTap: () => openPronoForMatch(
            context,
            matchId: match.id,
            openSheet: true,
            competition: match.competition,
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label.toUpperCase(),
              style: CalendarType.kicker.copyWith(
                color: CalendarTheme.goldDeep,
              ),
            ),
          ),
        );
      },
    );
  }
}
