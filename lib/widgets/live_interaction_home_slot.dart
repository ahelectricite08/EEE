import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/live_state_service.dart';
import '../services/match_rating_service.dart';
import '../services/motm_vote_service.dart';
import 'match_rating_home_card.dart';
import 'motm_vote_home_card.dart';

/// Accueil : homme du match OU note du match (après fin de match).
class LiveInteractionHomeSlot extends StatelessWidget {
  final bool isAdmin;

  const LiveInteractionHomeSlot({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: LiveStateService.watchCurrentSnapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();

        // Fin de match : note du match (prioritaire sur homme du match).
        if (MatchRatingService.takesPriorityOverMotm(data)) {
          if (MatchRatingService.isFulltimeDeclared(data) &&
              !MatchRatingService.isRatingActive(data)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MatchRatingService.ensureRatingOpen(data);
            });
          }
          if (MatchRatingService.hasVisibleRating(data) ||
              MatchRatingService.isFulltimeDeclared(data)) {
            return const MatchRatingHomeSlot();
          }
          return const SizedBox.shrink();
        }

        if (!MotmVoteService.hasVisibleVote(data)) {
          return const SizedBox.shrink();
        }

        if ((data['motmVoteStatus'] as String? ?? '').trim() == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            MotmVoteService.ensureVoteState(data);
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: MotmVoteHomeCard(liveData: data, isAdmin: isAdmin),
        );
      },
    );
  }
}
