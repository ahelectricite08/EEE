import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/prono_championship_rollout.dart';
import 'match_competition.dart';
import '../features/prono/data/firestore_prono_repository.dart';
import '../features/prono/presentation/matches/prono_matches_feed_page.dart';
import '../features/prono/presentation/theme/prono_tokens.dart';
import '../screens/prono_screen.dart';
import '../services/prono_social_service.dart';
import '../services/user_service.dart';

export '../features/prono/domain/prono_lock.dart';

/// Ouvre l’écran prono sur le match (plein écran). Si [openSheet] est false, ouvre le feed matchs seul (sans prédire).
Future<void> openPronoForMatch(
  BuildContext context, {
  required String matchId,
  bool openSheet = true,
  String? competition,
}) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour pronostiquer.')),
      );
    }
    return;
  }

  if (!MatchCompetition.isPronoEligible(competition, matchId: matchId)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pas de prono sur les matchs de la réserve (R2).'),
        ),
      );
    }
    return;
  }

  if (!PronoChampionshipRollout.isHubVisible) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les pronos championnat arrivent très bientôt — reste connecté.',
          ),
        ),
      );
    }
    return;
  }

  if (!openSheet) {
    if (!context.mounted) return;
    final repo = FirestorePronoRepository();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: PronoTokens.scaffold,
          appBar: AppBar(
            backgroundColor: PronoTokens.surface,
            foregroundColor: PronoTokens.text,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Matchs',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: PronoTokens.text,
              ),
            ),
          ),
          body: PronoMatchesFeedPage(uid: u.uid, repo: repo),
        ),
      ),
    );
    return;
  }

  final data = await UserService.getUserDataByUid(u.uid);
  final name = PronoSocialService.resolveDisplayName(
    data: data,
    email: u.email,
  );
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PronoMatchPredictScreen(
        matchId: matchId,
        uid: u.uid,
        displayName: name,
      ),
    ),
  );
}
