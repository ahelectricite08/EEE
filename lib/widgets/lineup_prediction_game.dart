import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lineup_prediction.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/sedan_squad.dart';
import '../services/lineup_prediction_service.dart';
import '../services/sedan_squad_service.dart';
import '../screens/matches/match_detail_palette.dart';
import 'sedan_squad_player_picker.dart';

/// Jeu fan : composer un XI Sedan probable avant publication officielle.
class LineupPredictionGame extends StatefulWidget {
  final MatchModel match;
  final MatchLineups lineups;
  final Map<String, dynamic> matchDoc;

  const LineupPredictionGame({
    super.key,
    required this.match,
    required this.lineups,
    required this.matchDoc,
  });

  @override
  State<LineupPredictionGame> createState() => _LineupPredictionGameState();
}

class _LineupPredictionGameState extends State<LineupPredictionGame> {
  final Set<String> _selectedIds = {};
  bool _saving = false;
  bool _hydrated = false;

  bool get _locked => LineupPredictionService.isPredictionLockedFromMatchDoc(
        widget.matchDoc,
        match: widget.match,
        lineups: widget.lineups,
      );

  Future<void> _save(List<SedanSquadPlayer> squadPlayers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour enregistrer ton XI.')),
      );
      return;
    }
    if (_selectedIds.length != LineupPrediction.requiredPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choisis exactement ${LineupPrediction.requiredPlayers} joueurs '
            '(${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}).',
          ),
        ),
      );
      return;
    }
    final ordered = squadPlayers
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    setState(() => _saving = true);
    try {
      await LineupPredictionService.savePrediction(
        LineupPrediction(
          id: LineupPrediction.docId(widget.match.id, user.uid),
          matchId: widget.match.id,
          uid: user.uid,
          displayName: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Membre',
          playerNames: ordered.map((p) => p.name).toList(),
          playerIds: ordered.map((p) => p.id).toList(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'XI probable enregistré !',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: MatchDetailPalette.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LineupPredictionService.isSedanMatch(widget.match)) {
      return _EmptyLineupMessage();
    }

    final user = FirebaseAuth.instance.currentUser;
    final official =
        LineupPredictionService.hasOfficialSedanLineup(
      widget.lineups,
      widget.match,
    );

    if (official) {
      return _EmptyLineupMessage(
        subtitle: 'La composition officielle est disponible ci-dessus.',
      );
    }

    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.data ?? SedanSquad.empty;
        return StreamBuilder<LineupPrediction?>(
          stream: user == null
              ? Stream<LineupPrediction?>.value(null)
              : LineupPredictionService.watchUserPrediction(
                  widget.match.id,
                  user.uid,
                ),
          builder: (context, predSnap) {
            final pred = predSnap.data;
            if (!_hydrated && pred != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _hydrated) return;
                setState(() {
                  _selectedIds.clear();
                  if (pred.playerIds.isNotEmpty) {
                    _selectedIds.addAll(pred.playerIds);
                  } else {
                    for (final p in squad.players) {
                      if (pred.playerNames.any(
                        (n) =>
                            n.trim().toLowerCase() == p.name.toLowerCase(),
                      )) {
                        _selectedIds.add(p.id);
                      }
                    }
                  }
                  _hydrated = true;
                });
              });
            }

            final locked = _locked || (pred?.awarded == true);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MatchDetailPalette.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MatchDetailPalette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_soccer_rounded,
                            color: MatchDetailPalette.gold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Compose ton XI Sedan probable',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: MatchDetailPalette.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Avant la composition officielle, choisis 11 joueurs. '
                        'Points au classement général Pronos : '
                        '9/11 → +1 · 10/11 → +2 · 11/11 → +3.\n'
                        'Verrouillé au coup d’envoi ou dès publication de la compo.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.45,
                          color: MatchDetailPalette.grey,
                        ),
                      ),
                      if (pred != null && pred.awarded) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Résultat : ${pred.matchedCount ?? '—'}/11 '
                          '(+${pred.points ?? 0} pt${(pred.points ?? 0) > 1 ? 's' : ''})',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MatchDetailPalette.green,
                          ),
                        ),
                      ] else if (pred != null && locked) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ton XI est verrouillé — en attente de la compo officielle.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MatchDetailPalette.gold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (user == null)
                  Text(
                    'Connecte-toi pour participer.',
                    style: GoogleFonts.inter(
                      color: MatchDetailPalette.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (squad.isEmpty)
                  Text(
                    'Effectif Sedan pas encore configuré — reviens bientôt.',
                    style: GoogleFonts.inter(
                      color: MatchDetailPalette.grey,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        '${_selectedIds.length}/${LineupPrediction.requiredPlayers}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: MatchDetailPalette.gold,
                        ),
                      ),
                      const Spacer(),
                      if (!locked)
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showSedanSquadMultiPicker(
                              context,
                              title: 'XI probable Sedan',
                              maxSelection: LineupPrediction.requiredPlayers,
                              alreadySelectedNames: squad.players
                                  .where((p) => _selectedIds.contains(p.id))
                                  .map((p) => p.name)
                                  .toSet(),
                              accent: MatchDetailPalette.green,
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _selectedIds
                                  ..clear()
                                  ..addAll(picked.map((p) => p.id));
                              });
                            }
                          },
                          icon: const Icon(Icons.groups_rounded, size: 18),
                          label: const Text('Sélecteur'),
                          style: TextButton.styleFrom(
                            foregroundColor: MatchDetailPalette.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...squad.players.map((p) {
                    final selected = _selectedIds.contains(p.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected
                            ? MatchDetailPalette.green.withAlpha(28)
                            : MatchDetailPalette.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: locked
                              ? null
                              : () {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(p.id);
                                    } else if (_selectedIds.length <
                                        LineupPrediction.requiredPlayers) {
                                      _selectedIds.add(p.id);
                                    }
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? MatchDetailPalette.green
                                    : MatchDetailPalette.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    p.number?.toString() ?? '·',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      color: MatchDetailPalette.gold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: MatchDetailPalette.text,
                                    ),
                                  ),
                                ),
                                if (p.position != null)
                                  Text(
                                    p.position!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: MatchDetailPalette.grey,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: selected
                                      ? MatchDetailPalette.green
                                      : MatchDetailPalette.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  if (!locked)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : () => _save(squad.players),
                        style: FilledButton.styleFrom(
                          backgroundColor: MatchDetailPalette.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                pred == null
                                    ? 'ENREGISTRER MON XI'
                                    : 'METTRE À JOUR MON XI',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _EmptyLineupMessage extends StatelessWidget {
  final String? subtitle;

  const _EmptyLineupMessage({this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: MatchDetailPalette.grey.withAlpha(80),
          ),
          const SizedBox(height: 12),
          Text(
            'Composition non disponible',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MatchDetailPalette.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle ?? 'Elle sera affichée dès sa publication.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MatchDetailPalette.grey.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }
}
