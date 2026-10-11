import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/prono/presentation/theme/prono_theme.dart';
import '../features/prono/presentation/theme/prono_type.dart';
import '../features/prono/presentation/widgets/prono_predict_stage.dart';
import '../features/prono/presentation/widgets/prono_ui.dart';
import '../models/crowd_xi.dart';
import '../models/lineup_prediction.dart';
import '../models/lineup_xi_verdict.dart';
import '../models/match_lineup.dart';
import '../models/match_model.dart';
import '../models/sedan_squad.dart';
import 'xi_player_verdict_list.dart';
import '../services/app_settings_service.dart';
import '../services/lineup_prediction_service.dart';
import '../services/sedan_squad_service.dart';
import 'lineup_lock_countdown.dart';
import 'xi_mini_pitch.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Jeu « XI probable Sedan » — langage Journal du Sanglier.
//
//  RÉGLURE  → l'effectif : gouttière de numéros, filets, zéro carte empilée.
//  ENCRE    → une seule dalle, le tableau d'affichage de la sélection. Le jeu
//             vit dans un onglet de la fiche match : c'est la seule matière
//             sombre pleine largeur qu'on s'autorise ici.
// ═══════════════════════════════════════════════════════════════════════════

const PronoPageAccent _accent = PronoPageAccent.accueil;
const EdgeInsets _hPad =
    EdgeInsets.symmetric(horizontal: PronoArenaTheme.gutter);

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

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: PronoType.body.copyWith(color: PronoArenaTheme.onInk),
        ),
        backgroundColor: PronoArenaTheme.ink,
      ),
    );
  }

  Future<void> _save(List<SedanSquadPlayer> squadPlayers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notify('Connecte-toi pour enregistrer ton XI.');
      return;
    }
    if (_selectedIds.length != LineupPrediction.requiredPlayers) {
      _notify(
        'Choisis exactement ${LineupPrediction.requiredPlayers} joueurs '
        '(${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}).',
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
      _notify('XI probable enregistré !');
    } catch (e) {
      if (!mounted) return;
      _notify(
        LineupPredictionService.userFacingWriteError(
          e,
          match: widget.match,
          lineups: widget.lineups,
          matchDoc: widget.matchDoc,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!LineupPredictionService.isSedanMatch(widget.match)) {
      return const _EmptyLineupMessage();
    }

    final user = FirebaseAuth.instance.currentUser;
    final official =
        LineupPredictionService.hasOfficialSedanLineup(
      widget.lineups,
      widget.match,
    );

    if (official) {
      return _OfficialXiVerdictView(
        match: widget.match,
        lineups: widget.lineups,
        matchDoc: widget.matchDoc,
      );
    }

    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        if (squadSnap.hasError) {
          return const PronoEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Effectif indisponible',
            body: 'Impossible de charger l’effectif Sedan pour le moment. '
                'Réessaie plus tard.',
            pageAccent: _accent,
          );
        }
        final squad = squadSnap.data ?? SedanSquad.empty;
        return StreamBuilder<LineupPrediction?>(
          stream: user == null
              ? Stream<LineupPrediction?>.value(null)
              : LineupPredictionService.watchUserPrediction(
                  widget.match.id,
                  user.uid,
                ),
          builder: (context, predSnap) {
            // Lecture refusée / stream cassé : on continue sans prono existant.
            final pred = predSnap.hasError ? null : predSnap.data;
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
            final full =
                _selectedIds.length >= LineupPrediction.requiredPlayers;

            return ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                Padding(
                  padding: _hPad,
                  child: _XiMasthead(
                    kickoff: widget.match.date,
                    locked: locked,
                  ),
                ),
                if (user == null)
                  const PronoEmptyState(
                    icon: Icons.person_outline_rounded,
                    title: 'Connecte-toi pour jouer',
                    body: 'Ton XI probable est rattaché à ton compte DVCR.',
                    pageAccent: _accent,
                  )
                else if (squad.isEmpty)
                  const PronoEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Effectif à venir',
                    body: 'L’effectif Sedan n’est pas encore configuré — '
                        'reviens bientôt.',
                    pageAccent: _accent,
                  )
                else ...[
                  const SizedBox(height: 22),
                  _XiSelectionCounter(
                    match: widget.match,
                    selectedIds: _selectedIds,
                    squad: squad,
                    prediction: pred,
                    locked: locked,
                  ),
                  if (_selectedIds.length >=
                      LineupPrediction.requiredPlayers) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: _hPad,
                      child: XiMiniPitch(
                        players: xiFormationSlots(
                          squad.players
                              .where((p) => _selectedIds.contains(p.id))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  for (final group in squad.groupedByPosition()) ...[
                    Padding(
                      padding: _hPad,
                      child: PronoSectionHeader(
                        title: group.$1,
                        countLabel: '${group.$2.length}',
                        pageAccent: _accent,
                      ),
                    ),
                    for (final p in group.$2)
                      _XiPlayerLine(
                        player: p,
                        selected: _selectedIds.contains(p.id),
                        squadFull: full,
                        locked: locked,
                        onTap: locked
                            ? null
                            : () {
                                final selected = _selectedIds.contains(p.id);
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(p.id);
                                  } else if (_selectedIds.length <
                                      LineupPrediction.requiredPlayers) {
                                    _selectedIds.add(p.id);
                                  }
                                });
                              },
                      ),
                    const SizedBox(height: 18),
                  ],
                  if (!locked)
                    Padding(
                      padding: _hPad,
                      child: PronoInkCta(
                        label: pred == null
                            ? 'Enregistrer mon XI'
                            : 'Mettre à jour mon XI',
                        icon: Icons.edit_note_rounded,
                        busy: _saving,
                        onTap: _saving ? null : () => _save(squad.players),
                      ),
                    ),
                  Padding(
                    padding: _hPad,
                    child: PronoFootnote(
                      text:
                          'Les points s’ajoutent au classement Pronos, '
                          'l’XP à ta progression de palier.',
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

// ── En-tête éditorial ───────────────────────────────────────────────────────

/// Kicker fileté, titre condensé, barème en chiffres alignés.
class _XiMasthead extends StatelessWidget {
  final DateTime kickoff;
  final bool locked;

  const _XiMasthead({
    required this.kickoff,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 16, height: 3, color: _accent.color),
            const SizedBox(width: 10),
            Text(
              'XI PROBABLE · SEDAN',
              style: PronoType.kicker.copyWith(color: PronoArenaTheme.text),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Compose ton XI Sedan probable',
          style: PronoType.headline.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 10),
        Text('Choisis les 11 titulaires de Sedan.', style: PronoType.caption),
        const SizedBox(height: 8),
        LineupLockCountdown(
          kickoff: kickoff,
          locked: locked,
          style: PronoType.caption,
        ),
        const SizedBox(height: 20),
        Text('BARÈME', style: PronoType.kickerGoldPaper),
        const SizedBox(height: 10),
        const PronoStatLedger(
          valueColor: PronoArenaTheme.goldDeep,
          cells: [
            (label: '9 sur 11', value: '+1'),
            (label: '10 sur 11', value: '+2'),
            (label: '11 sur 11', value: '+3'),
          ],
        ),
        const SizedBox(height: 10),
        const _XiXpNote(),
      ],
    );
  }
}

/// L'XP du XI vient en plus des points de classement — dit en une ligne pour
/// ne pas surcharger la réglure du barème.
class _XiXpNote extends StatelessWidget {
  const _XiXpNote();

  @override
  Widget build(BuildContext context) {
    return PronoXpScaleBuilder(
      builder: (context, xp) => Text(
        'Points de classement. Ton XI rapporte aussi de l’XP : '
        '+${xp.xiNine}, +${xp.xiTen} ou +${xp.xiPerfect} XP — et '
        '+${xp.xiPlayed} XP rien que pour avoir joué.',
        style: PronoType.meta.copyWith(color: PronoArenaTheme.textMuted),
      ),
    );
  }
}

// ── Tableau d'affichage (la dalle d'encre de l'écran) ───────────────────────

/// Compteur de sélection — le moment fort du jeu, donc la seule matière
/// sombre pleine largeur de l'onglet.
///
/// Deux états sur le même tableau : la sélection en cours (n / 11, répartition
/// par poste, réglure de progression carrée) puis, une fois la compo publiée
/// et le prono scoré, le résultat et les points gagnés.
class _XiSelectionCounter extends StatelessWidget {
  final MatchModel match;
  final Set<String> selectedIds;
  final SedanSquad squad;
  final LineupPrediction? prediction;
  final bool locked;

  const _XiSelectionCounter({
    required this.match,
    required this.selectedIds,
    required this.squad,
    this.prediction,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = selectedIds.length;
    const max = LineupPrediction.requiredPlayers;
    final complete = n >= max;
    final remaining = (max - n).clamp(0, max);
    final counts = <String, int>{
      for (final k in SedanSquadPositions.order) k: 0,
    };
    for (final p in squad.players) {
      if (!selectedIds.contains(p.id)) continue;
      final key = SedanSquadPositions.normalize(p.position);
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      }
    }

    final pred = prediction;
    final scored = pred != null && pred.awarded;
    final matched = pred?.matchedCount;
    final points = pred?.points ?? 0;
    final shown = scored ? (matched ?? 0) : n;

    final progress = scored ? (matched ?? 0) / max : n / max;
    final crowned = scored ? (matched ?? 0) >= max : complete;

    final String? note;
    if (scored) {
      note = matched == null
          ? 'RÉSULTAT ENREGISTRÉ'
          : '$matched BONS NOMS SUR $max';
    } else if (pred != null && locked) {
      note = 'TON XI EST ENREGISTRÉ · VERROUILLÉ';
    } else if (locked) {
      note = 'XI VERROUILLÉ · 2 J 12 H AVANT LE MATCH';
    } else if (!complete) {
      note = remaining == 1
          ? 'ENCORE 1 JOUEUR'
          : 'ENCORE $remaining JOUEURS';
    } else {
      note = 'XI COMPLET — tu peux encore modifier.';
    }

    return SizedBox(
      width: double.infinity,
      child: PronoInkSurface(
        radius: PronoArenaTheme.boardRadius,
        goldEdge: true,
        photoSlot: PronoBannerSlot.xiSlab,
        // Dalle bien plus chargée que les trois autres : petits corps de 9 px et
        // filet de 6 px en plus des grands chiffres. On assombrit davantage.
        veilBoost: 0.10,
        builder: (context, hasPhoto) {
          // L'or du club ne tient pas sur une photo claire (~2,6:1 au point le
          // plus lumineux du voile). L'or clair y remonte au-dessus de 4:1 tout
          // en gardant la distinction. Sans photo, rien ne bouge.
          final accent =
              hasPhoto ? PronoArenaTheme.goldSoft : PronoArenaTheme.gold;
          final kickerAccent = PronoType.kicker.copyWith(color: accent);
          // 40 % de blanc sur photo tombe sous 2,5:1 : on remonte les libellés.
          final faint = hasPhoto
              ? PronoArenaTheme.onInkMuted
              : PronoArenaTheme.onInkSoft;

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              PronoArenaTheme.gutter,
              18,
              PronoArenaTheme.gutter,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PronoXiScoreboard(
                  team1: match.team1,
                  logo1: match.logo1,
                  team2: match.team2,
                  logo2: match.logo2,
                  kicker: 'TON XI',
                  onInk: true,
                  value: scored
                      ? '$shown/$max  +$points pt${points > 1 ? 's' : ''}'
                      : shown == 0
                          ? '—'
                          : '$shown/$max',
                ),
                const SizedBox(height: 16),
                _BoardRule(
                  value: progress,
                  crowned: crowned,
                  accent: accent,
                  onPhoto: hasPhoto,
                ),
                const SizedBox(height: 16),
                _PositionTally(counts: counts, labelColor: faint),
                if (note != null) ...[
                  const SizedBox(height: 14),
                  const _InkHairline(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        color: scored ? accent : faint,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: scored ? kickerAccent : PronoType.kickerOnInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Réglure de progression — un filet carré qui se remplit, pas une pilule.
///
/// L'or ne sert qu'au fait accompli : XI complet, ou XI trouvé au complet une
/// fois scoré. Une jauge dorée dès le 3e joueur banaliserait la seule couleur
/// de distinction du module.
class _BoardRule extends StatelessWidget {
  final double value;
  final bool crowned;
  final Color accent;

  /// Sur photo, un creux à 12 % de blanc disparaît : on le rend plus dense.
  final bool onPhoto;

  const _BoardRule({
    required this.value,
    required this.crowned,
    required this.accent,
    this.onPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final fill = crowned ? accent : PronoArenaTheme.onInk;
    return SizedBox(
      height: 6,
      child: ColoredBox(
        color: onPhoto
            ? PronoArenaTheme.ink.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.12),
        child: TweenAnimationBuilder<double>(
          duration: PronoArenaTheme.animNormal,
          curve: PronoArenaTheme.animCurve,
          tween: Tween<double>(begin: 0, end: target),
          builder: (context, v, _) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v,
                child: ColoredBox(color: fill),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Répartition par poste — quatre chiffres de gouttière sur l'encre.
class _PositionTally extends StatelessWidget {
  final Map<String, int> counts;
  final Color labelColor;

  const _PositionTally({required this.counts, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    final keys = SedanSquadPositions.order;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 34,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${counts[keys[i]] ?? 0}',
                    style: PronoType.numeralGutter.copyWith(
                      fontSize: 26,
                      color: PronoArenaTheme.onInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keys[i],
                    style: PronoType.kicker.copyWith(
                      fontSize: 9,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InkHairline extends StatelessWidget {
  const _InkHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

// ── Effectif en réglure ─────────────────────────────────────────────────────

/// Ligne d'effectif — numéro en gouttière, nom condensé, poste à droite.
/// Sélectionné = barre d'accent verticale + papier teinté, jamais une case
/// à cocher Material.
class _XiPlayerLine extends StatelessWidget {
  final SedanSquadPlayer player;
  final bool selected;
  final bool squadFull;
  final bool locked;
  final VoidCallback? onTap;

  const _XiPlayerLine({
    required this.player,
    required this.selected,
    required this.squadFull,
    required this.locked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !selected && (squadFull || locked);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _accent.color.withValues(alpha: 0.05),
        highlightColor: _accent.color.withValues(alpha: 0.03),
        child: AnimatedContainer(
          duration: PronoArenaTheme.animFast,
          curve: PronoArenaTheme.animCurve,
          decoration: BoxDecoration(
            color: selected ? _accent.wash : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? _accent.color : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: PronoArenaTheme.hairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            PronoArenaTheme.gutter - 3,
            12,
            PronoArenaTheme.gutter,
            12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: SedanPlayerFace(
                  player: player,
                  size: 32,
                  occupied: true,
                  selected: selected,
                  foreground: dimmed
                      ? PronoArenaTheme.edgeHighlight
                      : PronoArenaTheme.text,
                ),
              ),
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PronoType.fixture.copyWith(
                    color: dimmed
                        ? PronoArenaTheme.textSoft
                        : PronoArenaTheme.text,
                  ),
                ),
              ),
              if (player.position != null) ...[
                const SizedBox(width: 10),
                Text(
                  player.position!.toUpperCase(),
                  style: PronoType.meta.copyWith(
                    color: PronoArenaTheme.textSoft,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              _SelectionMark(selected: selected, locked: locked),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampon de titularisation — carré d'encre, aligné sur la géométrie du
/// module (l'encre reste libre à l'échelle d'un contrôle).
class _SelectionMark extends StatelessWidget {
  final bool selected;
  final bool locked;

  const _SelectionMark({required this.selected, required this.locked});

  @override
  Widget build(BuildContext context) {
    if (locked && !selected) return const SizedBox(width: 18);
    return AnimatedContainer(
      duration: PronoArenaTheme.animFast,
      curve: PronoArenaTheme.animCurve,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? _accent.deep : Colors.transparent,
        border: Border.all(
          color: selected
              ? _accent.deep
              : PronoArenaTheme.edgeHighlight,
        ),
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 13,
              color: PronoArenaTheme.onInk,
            )
          : null,
    );
  }
}

// ── États ───────────────────────────────────────────────────────────────────

/// Trois terrains : ta compo, supporters, la bonne — or / rouge.
class _OfficialXiVerdictView extends StatelessWidget {
  final MatchModel match;
  final MatchLineups lineups;
  final Map<String, dynamic> matchDoc;

  const _OfficialXiVerdictView({
    required this.match,
    required this.lineups,
    required this.matchDoc,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final starters = LineupPredictionService.sedanSide(lineups, match)
            ?.starters
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, squadSnap) {
        final squad = squadSnap.data ?? SedanSquad.empty;
        return StreamBuilder<LineupPrediction?>(
          stream: user == null
              ? Stream<LineupPrediction?>.value(null)
              : LineupPredictionService.watchUserPrediction(match.id, user.uid),
          builder: (context, predSnap) {
            final pred = predSnap.hasError ? null : predSnap.data;
            final verdict = LineupXiVerdict.resolve(
              prediction: pred,
              officialSedanStarters: starters,
              squad: squad,
            );
            final marks = LineupXiVerdict.marksFor(
              prediction: pred,
              officialSedanStarters: starters,
              squad: squad,
            );
            final crowd = CrowdXi.fromMatchDoc(matchDoc);
            return ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              children: [
                Padding(
                  padding: _hPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PronoXiScoreboard(
                        team1: match.team1,
                        logo1: match.logo1,
                        team2: match.team2,
                        logo2: match.logo2,
                        kicker: 'TON XI',
                        value: verdict.hasPrediction
                            ? '${verdict.matched}/11  +${verdict.rankingPoints} pt${verdict.rankingPoints > 1 ? 's' : ''}'
                            : '—',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        verdict.hasPrediction
                            ? '9/11 +1  ·  10/11 +2  ·  11/11 +3'
                            : verdict.body,
                        textAlign: TextAlign.center,
                        style: PronoType.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: _hPad,
                  child: XiComparePitches(
                    userMarks: marks,
                    crowd: crowd,
                    officialSedanStarters: starters,
                    squad: squad,
                  ),
                ),
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
      child: PronoEmptyState(
        icon: Icons.groups_outlined,
        title: 'Composition non disponible',
        body: subtitle ?? 'Elle sera affichée dès sa publication.',
        pageAccent: _accent,
      ),
    );
  }
}
