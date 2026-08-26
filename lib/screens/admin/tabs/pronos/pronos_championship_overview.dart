import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';
import 'prono_leaderboard_admin_sheet.dart';

/// Aperçu rapide des données championnat prono (avant reset ou en cours de saison).
class PronosChampionshipOverview extends StatelessWidget {
  const PronosChampionshipOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAT ACTUEL',
          style: GoogleFonts.barlowCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Compteurs Firestore — touche CLASSEMENT pour voir les personnes. Utile aussi après un reset.',
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.35,
            color: adminGrey,
          ),
        ),
        const SizedBox(height: 12),
        const _ScorePendingPronosButton(),
        const SizedBox(height: 16),
        AdminStatRow(
          stats: [
            AdminStatFuture(
              label: 'PRONOS',
              icon: Icons.sports_soccer_rounded,
              color: adminGold,
              future: FirebaseFirestore.instance
                  .collection('predictions')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'CLASSEMENT',
              icon: Icons.leaderboard_rounded,
              color: adminGold,
              onTap: () => showPronoLeaderboardAdminSheet(context),
              future: FirebaseFirestore.instance
                  .collection('prono_leaderboard')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'DUELS',
              icon: Icons.emoji_events_rounded,
              color: Colors.orange,
              future: FirebaseFirestore.instance
                  .collection('prono_duels')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
            AdminStatFuture(
              label: 'LIGUES',
              icon: Icons.groups_rounded,
              color: adminBlue,
              future: FirebaseFirestore.instance
                  .collection('private_leagues')
                  .count()
                  .get()
                  .then((s) => '${s.count}'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Relance l’attribution auto (matchs `finished` + score, pas encore `pronoScoredAt`).
class _ScorePendingPronosButton extends StatefulWidget {
  const _ScorePendingPronosButton();

  @override
  State<_ScorePendingPronosButton> createState() =>
      _ScorePendingPronosButtonState();
}

class _ScorePendingPronosButtonState extends State<_ScorePendingPronosButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'scoreMatchPronos',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final res = await fn.call();
      final map = Map<String, dynamic>.from(res.data as Map? ?? {});
      final n = map['scored'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n != null
                ? 'Pronos attribués : $n match(s) traité(s).'
                : 'Pronos attribués.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attribution pronos : ${e.message ?? e.code}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attribution pronos : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.playlist_add_check_rounded, size: 18),
        label: Text(
          'Attribuer les points des matchs terminés',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
