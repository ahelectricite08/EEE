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
        const SizedBox(height: 8),
        const _RescoreMatchPronosButton(),
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

/// Recalcule un match déjà scoré (score FFF corrigé après le 1er attribution).
class _RescoreMatchPronosButton extends StatelessWidget {
  const _RescoreMatchPronosButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _openPicker(context),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(
          'Recalculer un match déjà scoré',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _RescoreMatchSheet(),
    );
  }
}

class _RescoreMatchSheet extends StatefulWidget {
  const _RescoreMatchSheet();

  @override
  State<_RescoreMatchSheet> createState() => _RescoreMatchSheetState();
}

class _RescoreMatchSheetState extends State<_RescoreMatchSheet> {
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    final from = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 21)),
    );
    _future = FirebaseFirestore.instance
        .collection('matches')
        .where('date', isGreaterThanOrEqualTo: from)
        .get()
        .then((snap) {
      final docs = snap.docs.where((d) {
        final data = d.data();
        if (data['status'] != 'finished') return false;
        return data['score1'] != null && data['score2'] != null;
      }).toList()
        ..sort((a, b) {
          final da = a.data()['date'];
          final db = b.data()['date'];
          final ma = da is Timestamp ? da.millisecondsSinceEpoch : 0;
          final mb = db is Timestamp ? db.millisecondsSinceEpoch : 0;
          return mb.compareTo(ma);
        });
      return docs;
    });
  }

  Future<void> _rescore(String matchId) async {
    setState(() => _busyId = matchId);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'scoreMatchPronos',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final res = await fn.call(<String, dynamic>{'matchId': matchId});
      final map = Map<String, dynamic>.from(res.data as Map? ?? {});
      final results = map['results'];
      var nRescored = 0;
      if (results is List && results.isNotEmpty) {
        final first = Map<String, dynamic>.from(results.first as Map? ?? {});
        nRescored = (first['rescored'] as num?)?.toInt() ?? 0;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match recalculé · $nRescored prono(s) corrigé(s).',
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
            'Recalcul : ${e.message ?? e.code}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recalcul : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recalculer un match',
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Corrige les points si le score FFF a changé après la 1re attribution (ex. 1-0 puis 2-0).',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.35),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    'Impossible de charger les matchs : ${snap.error}',
                    style: GoogleFonts.inter(color: adminRed, fontSize: 12),
                  );
                }
                final docs = snap.data ?? const [];
                if (docs.isEmpty) {
                  return Text(
                    'Aucun match terminé avec score sur 21 jours.',
                    style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final t1 = '${d['team1'] ?? '?'}';
                      final t2 = '${d['team2'] ?? '?'}';
                      final s1 = d['score1'];
                      final s2 = d['score2'];
                      final id = docs[i].id;
                      final busy = _busyId == id;
                      return ListTile(
                        dense: true,
                        title: Text(
                          '$t1 $s1–$s2 $t2',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          id,
                          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.replay_rounded, size: 20),
                        onTap: busy || _busyId != null ? null : () => _rescore(id),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
