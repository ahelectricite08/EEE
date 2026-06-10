import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_dialogs.dart';
import '../../../../services/tournament_service.dart';

const _tournamentId = 'worldcup2026';
final _matchesCol = FirebaseFirestore.instance
    .collection('tournaments')
    .doc(_tournamentId)
    .collection('matches');

// Ordre des phases
const _phaseOrder = [
  'Groupe A', 'Groupe B', 'Groupe C', 'Groupe D',
  'Groupe E', 'Groupe F', 'Groupe G', 'Groupe H',
  'Groupe I', 'Groupe J', 'Groupe K', 'Groupe L',
  '32èmes de finale', '16èmes de finale', '8èmes de finale',
  'Quarts de finale', 'Demi-finales', 'Petite finale', 'Finale',
];

class TournamentTab extends StatelessWidget {
  const TournamentTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(width: 3, height: 22,
                decoration: BoxDecoration(color: adminGold,
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text('COUPE DU MONDE 2026',
                style: GoogleFonts.barlowCondensed(fontSize: 20,
                  fontWeight: FontWeight.w900, color: adminTextPrimary,
                  letterSpacing: 1.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showMatchEditor(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE1C15A), adminGold]),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, color: Colors.black, size: 14),
                    const SizedBox(width: 5),
                    Text('AJOUTER', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: Colors.black)),
                  ]),
                ),
              ),
            ],
          ),
        ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: adminBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bandeau lot & partenaire CdM : onglet admin **Pronos & jeux** → Coupe du monde.\n\n'
                    'Sur un match terminé : icône retour = annuler ce match seul (points + score). '
                    'Le bouton RECALCULER ci‑dessous refait tout le CdM (rare, si gros souci).',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.35,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _fixAllMatchDays(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withAlpha(80)),
                      ),
                      child: Text(
                        '🔧 AUTO-FIXER LES JOURNÉES (J1/J2/J3)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue[300],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _confirmRecalculateWorldCupRanking(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: adminGreen.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: adminGreen.withAlpha(100)),
                      ),
                      child: Text(
                        'RECALCULER LE CLASSEMENT CDM',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Liste ────────────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<TournamentMatch>>(
            stream: TournamentService.matchesStream(_tournamentId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: adminGold));
              }
              final matches = snap.data ?? [];
              if (matches.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                      color: adminGrey, size: 48),
                    const SizedBox(height: 12),
                    Text('Aucun match — clique AJOUTER',
                      style: GoogleFonts.inter(color: adminGrey, fontSize: 13)),
                  ]));
              }

              // Grouper par phase et trier par date dans chaque phase
              final Map<String, List<TournamentMatch>> byPhase = {};
              for (final m in matches) {
                byPhase.putIfAbsent(m.phase, () => []).add(m);
              }
              for (final list in byPhase.values) {
                list.sort((a, b) => a.date.compareTo(b.date));
              }

              // Trier les phases dans l'ordre officiel
              final orderedPhases = _phaseOrder
                  .where((p) => byPhase.containsKey(p))
                  .toList();
              // Phases inconnues à la fin
              for (final p in byPhase.keys) {
                if (!orderedPhases.contains(p)) orderedPhases.add(p);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: orderedPhases.length,
                itemBuilder: (context, i) {
                  final phase = orderedPhases[i];
                  final phaseMatches = byPhase[phase]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête de phase
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 10),
                        child: Row(children: [
                          Container(width: 3, height: 16,
                            decoration: BoxDecoration(
                              color: _phaseColor(phase),
                              borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(phase.toUpperCase(),
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: _phaseColor(phase), letterSpacing: 1.2)),
                          const SizedBox(width: 8),
                          Text('• ${phaseMatches.length} match${phaseMatches.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 11, color: adminGrey)),
                        ]),
                      ),
                      ...phaseMatches.map((m) => _MatchCard(match: m)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _phaseColor(String phase) {
    if (phase.startsWith('Groupe')) return adminGold;
    if (phase.contains('32')) return const Color(0xFF4FC3F7);
    if (phase.contains('16')) return const Color(0xFF29B6F6);
    if (phase.contains('Quart')) return const Color(0xFF0288D1);
    if (phase.contains('Demi')) return const Color(0xFFBA68C8);
    if (phase.contains('Petite')) return adminGrey;
    if (phase == 'Finale') return adminGold;
    return adminGold;
  }
}

// ── Carte match ───────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final finished = match.status == 'finished';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          // ── Ligne principale ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                // Équipe 1
                Expanded(
                  child: Row(children: [
                    _Flag(url: match.flag1),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(match.team1,
                        style: GoogleFonts.inter(fontSize: 12,
                          fontWeight: FontWeight.w700, color: adminTextPrimary),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ),

                // Score / vs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: finished
                        ? adminGreen.withAlpha(30)
                        : adminBorder,
                    borderRadius: BorderRadius.circular(6),
                    border: finished
                        ? Border.all(color: adminGreen.withAlpha(80))
                        : null,
                  ),
                  child: Text(
                    finished
                        ? '${match.result1} - ${match.result2}'
                        : 'vs',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: finished ? adminGreen : adminGrey),
                  ),
                ),

                // Équipe 2
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(match.team2,
                          style: GoogleFonts.inter(fontSize: 12,
                            fontWeight: FontWeight.w700, color: adminTextPrimary),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end)),
                      const SizedBox(width: 6),
                      _Flag(url: match.flag2),
                    ]),
                ),

                // Actions
                const SizedBox(width: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!finished)
                    _Btn(icon: Icons.scoreboard_rounded, color: adminGreen,
                      onTap: () => _showResultDialog(context, match)),
                  if (finished) ...[
                    _Btn(
                      icon: Icons.undo_rounded,
                      color: const Color(0xFF6D4C41),
                      onTap: () => _revertMatchToUpcoming(context, match),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 4),
                  _Btn(icon: Icons.edit_rounded, color: adminGold,
                    onTap: () => _showMatchEditor(context, match)),
                  const SizedBox(width: 4),
                  _Btn(icon: Icons.delete_rounded, color: adminRed,
                    onTap: () async {
                      final ok = await adminConfirm(context,
                        'Supprimer ce match ? Action irréversible.');
                      if (ok) await _matchesCol.doc(match.id).delete();
                    }),
                ]),
              ],
            ),
          ),

          // ── Date + Journée ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: adminBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10))),
            child: Row(children: [
              Expanded(child: Text(_fmt(match.date),
                style: GoogleFonts.inter(fontSize: 10, color: adminGrey))),
              if (match.matchDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: adminGold.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: adminGold.withAlpha(70))),
                  child: Text('J${match.matchDay}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: adminGold)),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const days = ['lun','mar','mer','jeu','ven','sam','dim'];
    const months = ['jan','fév','mar','avr','mai','jun',
                    'jul','aoû','sep','oct','nov','déc'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}  •  '
        '${d.hour.toString().padLeft(2,'0')}h${d.minute.toString().padLeft(2,'0')}';
  }
}

class _Flag extends StatelessWidget {
  final String url;
  const _Flag({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(width: 22, height: 15,
        decoration: BoxDecoration(color: adminBorder,
          borderRadius: BorderRadius.circular(2)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.network(url, width: 22, height: 15, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 22, height: 15,
          color: adminBorder)),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60))),
      child: Icon(icon, color: color, size: 13)),
  );
}

Future<void> _revertMatchToUpcoming(
  BuildContext context,
  TournamentMatch match,
) async {
  final ok = await adminConfirm(
    context,
    'Annuler uniquement ce match : remettre le score à zéro, retirer les points '
    'CdM gagnés sur ce match (pronos + classement), sans toucher aux autres matchs.',
  );
  if (!ok || !context.mounted) return;
  final data = await _runUndoWorldCupMatchScoring(context, match.id);
  if (!context.mounted) return;
  if (data != null) {
    final cleared = data['predictionsCleared'];
    final adj = data['leaderboardsAdjusted'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Match annulé : $cleared prono(s) remis à zéro, $adj ligne(s) classement ajustées.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
      ),
    );
  }
}

// ── Auto-fix journées pour tous les matchs existants ─────────────────────────
Future<void> _fixAllMatchDays(BuildContext context) async {
  // Confirmation
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: adminCard,
      title: Text('Fixer les journées auto ?',
        style: GoogleFonts.barlowCondensed(color: adminTextPrimary,
          fontSize: 18, fontWeight: FontWeight.w800)),
      content: Text(
        'Chaque équipe : 1er match → J1, 2e → J2, 3e → J3, 4e et + → Phase finale.\n\n'
        'Les journées sont calculées dans l\'ordre chronologique (date du match).\n\n'
        'Appuie ensuite sur RECALCULER pour mettre à jour les classements.',
        style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: Text('FIXER', style: GoogleFonts.inter(color: Colors.blue[300], fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    // Lire tous les matchs triés par date
    final snap = await _matchesCol.orderBy('date').get();
    final docs = snap.docs;

    // Compter les matchs par équipe dans l'ordre chronologique
    final teamCounts = <String, int>{};
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    int fixed = 0;

    for (final doc in docs) {
      final data = doc.data();
      final t1 = (data['team1'] as String? ?? '').toLowerCase().trim();
      final t2 = (data['team2'] as String? ?? '').toLowerCase().trim();
      if (t1.isEmpty || t2.isEmpty) continue;

      final c1 = teamCounts[t1] ?? 0;
      final c2 = teamCounts[t2] ?? 0;
      final day = (c1 > c2 ? c1 : c2) + 1;

      teamCounts[t1] = c1 + 1;
      teamCounts[t2] = c2 + 1;

      if (day <= 3) {
        batch.update(doc.reference, {
          'matchDay': day,
          'isFinale': FieldValue.delete(),
        });
      } else {
        // 4e match et + → phase finale
        batch.update(doc.reference, {
          'matchDay': FieldValue.delete(),
          'isFinale': true,
        });
      }
      fixed++;
    }

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$fixed match(s) mis à jour. Lance maintenant RECALCULER.',
          style: GoogleFonts.inter()),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e', style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
    }
  }
}

// ── Phases considérées comme "phase finale" (pas de matchDay auto) ───────────
const _kFinalePhases = {
  '32èmes de finale', '16èmes de finale', '8èmes de finale',
  'Quarts de finale', 'Demi-finales', 'Petite finale', 'Finale',
};

/// Calcule la journée automatiquement selon l'historique des équipes.
/// Retourne null si > 3 matchs (= phase finale).
Future<int?> _autoMatchDay(String team1, String team2,
    {String? excludeMatchId}) async {
  final snap = await _matchesCol.get();
  final t1 = team1.trim().toLowerCase();
  final t2 = team2.trim().toLowerCase();
  int count1 = 0, count2 = 0;
  for (final doc in snap.docs) {
    if (excludeMatchId != null && doc.id == excludeMatchId) continue;
    final d = doc.data();
    final mt1 = (d['team1'] as String? ?? '').toLowerCase();
    final mt2 = (d['team2'] as String? ?? '').toLowerCase();
    if (mt1 == t1 || mt2 == t1) count1++;
    if (mt1 == t2 || mt2 == t2) count2++;
  }
  final day = (count1 > count2 ? count1 : count2) + 1;
  return day <= 3 ? day : null;
}

// ── Dialog ajout/édition match ────────────────────────────────────────────────
void _showMatchEditor(BuildContext context, TournamentMatch? existing) {
  showDialog(
    context: context,
    builder: (_) => _MatchEditorDialog(existing: existing),
  );
}

class _MatchEditorDialog extends StatefulWidget {
  final TournamentMatch? existing;
  const _MatchEditorDialog({this.existing});

  @override
  State<_MatchEditorDialog> createState() => _MatchEditorDialogState();
}

class _MatchEditorDialogState extends State<_MatchEditorDialog> {
  late final TextEditingController team1Ctrl;
  late final TextEditingController team2Ctrl;
  late final TextEditingController flag1Ctrl;
  late final TextEditingController flag2Ctrl;
  late String selectedPhase;
  late DateTime selectedDate;

  int? _autoDay;          // null = pas encore calculé ou phase finale
  bool _detecting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    team1Ctrl = TextEditingController(text: ex?.team1 ?? '');
    team2Ctrl = TextEditingController(text: ex?.team2 ?? '');
    flag1Ctrl  = TextEditingController(text: ex?.flag1 ?? '');
    flag2Ctrl  = TextEditingController(text: ex?.flag2 ?? '');
    selectedPhase = ex?.phase ?? 'Groupe A';
    selectedDate  = ex?.date ?? DateTime.now().add(const Duration(days: 1));
    _autoDay = ex?.matchDay;

    // Déclenche la détection dès que l'une des équipes change
    team1Ctrl.addListener(_onTeamsChanged);
    team2Ctrl.addListener(_onTeamsChanged);

    // Si on édite un match existant, montrer le jour déjà calculé
    if (ex != null) _detectDay();
  }

  @override
  void dispose() {
    team1Ctrl.removeListener(_onTeamsChanged);
    team2Ctrl.removeListener(_onTeamsChanged);
    team1Ctrl.dispose();
    team2Ctrl.dispose();
    flag1Ctrl.dispose();
    flag2Ctrl.dispose();
    super.dispose();
  }

  void _onTeamsChanged() {
    if (team1Ctrl.text.trim().isNotEmpty && team2Ctrl.text.trim().isNotEmpty) {
      _detectDay();
    }
  }

  Future<void> _detectDay() async {
    final t1 = team1Ctrl.text.trim();
    final t2 = team2Ctrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) return;
    if (_kFinalePhases.contains(selectedPhase)) {
      if (mounted) setState(() { _autoDay = null; _detecting = false; });
      return;
    }
    if (mounted) setState(() => _detecting = true);
    final day = await _autoMatchDay(t1, t2, excludeMatchId: widget.existing?.id);
    if (mounted) setState(() { _autoDay = day; _detecting = false; });
  }

  Future<void> _save() async {
    final t1 = team1Ctrl.text.trim();
    final t2 = team2Ctrl.text.trim();
    if (t1.isEmpty || t2.isEmpty) return;

    setState(() => _saving = true);

    // Déterminer si c'est une phase finale
    final isFinalePhase = _kFinalePhases.contains(selectedPhase);

    // Pour les phases de groupe : calculer la journée automatiquement
    int? day;
    if (!isFinalePhase) {
      day = await _autoMatchDay(t1, t2, excludeMatchId: widget.existing?.id);
      // Si > J3 calculé (4e match+) → traité comme phase finale aussi
      if (day == null) {} // déjà null = phase finale
    }

    final base = <String, dynamic>{
      'team1': t1,
      'team2': t2,
      'flag1': flag1Ctrl.text.trim(),
      'flag2': flag2Ctrl.text.trim(),
      'phase': selectedPhase,
      'date': Timestamp.fromDate(selectedDate),
      'status': widget.existing?.status ?? 'upcoming',
    };

    if (widget.existing == null) {
      // Création
      if (day != null) {
        base['matchDay'] = day;
        // pas isFinale
      } else {
        // Phase finale (explicite ou 4e match+)
        base['isFinale'] = true;
      }
      await _matchesCol.add(base);
    } else {
      // Édition
      if (day != null) {
        base['matchDay'] = day;
        base['isFinale'] = FieldValue.delete();
      } else {
        base['matchDay'] = FieldValue.delete();
        base['isFinale'] = true;
      }
      await _matchesCol.doc(widget.existing!.id).update(base);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Dialog(
      backgroundColor: adminCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isNew ? 'AJOUTER UN MATCH' : 'MODIFIER LE MATCH',
              style: GoogleFonts.barlowCondensed(fontSize: 18,
                fontWeight: FontWeight.w900, color: adminTextPrimary,
                letterSpacing: 1.2)),
            const SizedBox(height: 16),
            _Field(ctrl: team1Ctrl, label: 'Équipe 1'),
            const SizedBox(height: 10),
            _Field(ctrl: team2Ctrl, label: 'Équipe 2'),
            const SizedBox(height: 10),
            _Field(ctrl: flag1Ctrl, label: 'Logo équipe 1 (URL)'),
            const SizedBox(height: 10),
            _Field(ctrl: flag2Ctrl, label: 'Logo équipe 2 (URL)'),
            const SizedBox(height: 10),

            // ── Badge journée auto ─────────────────────────────────────────
            if (team1Ctrl.text.isNotEmpty && team2Ctrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kFinalePhases.contains(selectedPhase)
                      ? Colors.purple.withAlpha(25)
                      : _autoDay != null
                          ? adminGold.withAlpha(25) : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _kFinalePhases.contains(selectedPhase)
                        ? Colors.purple.withAlpha(80)
                        : _autoDay != null
                            ? adminGold.withAlpha(80) : Colors.grey.withAlpha(80)),
                ),
                child: Row(children: [
                  if (_detecting)
                    const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: adminGold))
                  else
                    Icon(Icons.auto_awesome_rounded, size: 14,
                      color: _kFinalePhases.contains(selectedPhase)
                          ? Colors.purple[200]
                          : _autoDay != null ? adminGold : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _detecting
                        ? 'Calcul de la journée...'
                        : _kFinalePhases.contains(selectedPhase)
                            ? 'Phase finale (pas de journée)'
                            : _autoDay != null
                                ? 'Journée auto : J$_autoDay'
                                : 'Journée indéterminée',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _kFinalePhases.contains(selectedPhase)
                          ? Colors.purple[200]
                          : _autoDay != null ? adminGold : Colors.grey),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _detectDay,
                    child: Text('RE-CALC',
                      style: GoogleFonts.inter(fontSize: 10,
                        fontWeight: FontWeight.w700, color: adminGrey)),
                  ),
                ]),
              ),
            const SizedBox(height: 10),

            // Phase
            Text('Phase', style: GoogleFonts.inter(
              fontSize: 11, color: adminGrey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: adminBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: adminBorder)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _phaseOrder.contains(selectedPhase)
                      ? selectedPhase : _phaseOrder.first,
                  dropdownColor: adminCard, isExpanded: true,
                  style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                  items: _phaseOrder.map((p) => DropdownMenuItem(
                    value: p, child: Text(p))).toList(),
                  onChanged: (v) {
                    setState(() => selectedPhase = v!);
                    _detectDay();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Date
            Text('Date & heure', style: GoogleFonts.inter(
              fontSize: 11, color: adminGrey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2026), lastDate: DateTime(2027),
                  builder: (_, c) => Theme(data: ThemeData.dark(), child: c!));
                if (d == null || !mounted) return;
                final t = await showTimePicker(context: context,
                  initialTime: TimeOfDay.fromDateTime(selectedDate),
                  builder: (_, c) => Theme(data: ThemeData.dark(), child: c!));
                if (!mounted) return;
                setState(() => selectedDate = DateTime(d.year, d.month, d.day,
                  t?.hour ?? selectedDate.hour, t?.minute ?? selectedDate.minute));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: adminBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, color: adminGold, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                    '  ${selectedDate.hour.toString().padLeft(2, '0')}h'
                    '${selectedDate.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary)),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: adminBorder,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('ANNULER', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12,
                      fontWeight: FontWeight.w700, color: adminGrey))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _saving ? adminGold.withAlpha(120) : adminGold,
                    borderRadius: BorderRadius.circular(8)),
                  child: _saving
                      ? const Center(child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
                      : Text('ENREGISTRER', textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12,
                            fontWeight: FontWeight.w700, color: Colors.black))))),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Dialog saisie résultat ────────────────────────────────────────────────────
void _showResultDialog(BuildContext context, TournamentMatch match) {
  int score1 = match.result1 ?? 0;
  int score2 = match.result2 ?? 0;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: adminCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('RÉSULTAT', style: GoogleFonts.barlowCondensed(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: adminTextPrimary, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text('${match.team1}  vs  ${match.team2}',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ScoreStepper(label: match.team1, value: score1,
                  onChanged: (v) => setState(() => score1 = v)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('-', style: GoogleFonts.barlowCondensed(
                    fontSize: 36, color: adminTextPrimary))),
                _ScoreStepper(label: match.team2, value: score2,
                  onChanged: (v) => setState(() => score2 = v)),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: adminBorder,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('ANNULER', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12,
                      fontWeight: FontWeight.w700, color: adminGrey))))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () async {
                  await _matchesCol.doc(match.id).update({
                    'result1': score1, 'result2': score2, 'status': 'finished',
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: adminGreen,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('VALIDER', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12,
                      fontWeight: FontWeight.w700, color: adminTextPrimary))))),
            ]),
          ]),
        ),
      ),
    ),
  );
}

// ── Widgets helpers ───────────────────────────────────────────────────────────
class _ScoreStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreStepper({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis),
    const SizedBox(height: 8),
    Row(mainAxisSize: MainAxisSize.min, children: [
      _StepBtn(icon: Icons.remove,
        onTap: () => onChanged((value - 1).clamp(0, 20))),
      SizedBox(width: 44, child: Text('$value',
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(fontSize: 36,
          fontWeight: FontWeight.w900, color: adminTextPrimary))),
      _StepBtn(icon: Icons.add, onTap: () => onChanged(value + 1)),
    ]),
  ]);
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 32, height: 32,
      decoration: BoxDecoration(color: adminBorder,
        borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: adminTextPrimary, size: 16)));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _Field({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, color: adminGrey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(controller: ctrl,
        style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
        decoration: InputDecoration(
          filled: true, fillColor: adminBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: adminGold)))),
    ],
  );
}

Future<Map<String, dynamic>?> _runUndoWorldCupMatchScoring(
  BuildContext context,
  String matchId, {
  bool showErrorSnack = true,
}) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('undoWorldCupMatchScoring');
    final res = await callable.call(<String, dynamic>{'matchId': matchId});
    final raw = res.data;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  } catch (e) {
    if (showErrorSnack && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Annulation du match impossible : $e',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
    return null;
  }
}

Future<Map<String, dynamic>?> _runWorldCupLeaderboardRecalculate(
  BuildContext context, {
  bool showStatsSnack = true,
  bool showErrorSnack = true,
}) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('recalculateWorldCupLeaderboard');
    final res = await callable.call();
    final raw = res.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (showStatsSnack && context.mounted) {
      final rescored = data['finishedMatchesRescored'];
      final preds = data['predictionsReset'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Classement CdM : $rescored match(s) rescordés, $preds prono(s) remis à zéro.',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
    return data;
  } catch (e) {
    if (showErrorSnack && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recalcul impossible : $e',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
    return null;
  }
}

Future<void> _confirmRecalculateWorldCupRanking(BuildContext context) async {
  final ok = await adminConfirm(
    context,
    'Remettre à zéro les points sur tous les pronos CdM, vider le classement, '
    'puis tout recalculer depuis les matchs terminés ? '
    'Aucune notification push ne sera renvoyée.',
  );
  if (!ok || !context.mounted) return;
  await _runWorldCupLeaderboardRecalculate(context);
}
