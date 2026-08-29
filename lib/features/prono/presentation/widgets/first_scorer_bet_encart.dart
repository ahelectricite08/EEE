import 'package:flutter/material.dart';

import '../../../../models/first_scorer_bet.dart';
import '../../../../models/sedan_squad.dart';
import '../../../../services/first_scorer_bet_service.dart';
import '../../../../services/sedan_squad_service.dart';
import '../../domain/prono_lock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/prono_theme.dart';
import '../theme/prono_type.dart';

/// Encart « 1er buteur du match » sur la feuille de prono.
/// Switch admin OFF ou match hors Sedan / CSSA → [SizedBox.shrink].
class FirstScorerBetEncart extends StatelessWidget {
  final String matchId;
  final String uid;
  final String displayName;
  final Map<String, dynamic> match;

  const FirstScorerBetEncart({
    super.key,
    required this.matchId,
    required this.uid,
    required this.displayName,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FirstScorerBetConfig>(
      stream: FirstScorerBetService.instance.watchConfig(),
      initialData: FirstScorerBetService.instance.lastKnown,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? FirstScorerBetConfig.defaults;
        if (!cfg.showInApp) return const SizedBox.shrink();
        if (!firstScorerBetMatchInvolvesCssaFromMap(match)) {
          return const SizedBox.shrink();
        }

        final dateRaw = match['date'];
        final kickoff = dateRaw is Timestamp ? dateRaw.toDate() : null;
        final locked = kickoff == null || isMatchPronoLocked(kickoff);

        return StreamBuilder<FirstScorerBetPick?>(
          stream: FirstScorerBetService.instance.watchPick(matchId, uid),
          builder: (context, pickSnap) {
            final pick = pickSnap.data;
            return StreamBuilder<SedanSquad>(
              stream: SedanSquadService.watch(),
              builder: (context, squadSnap) {
                final squad = squadSnap.data ?? SedanSquad.empty;
                return Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: _FirstScorerBetBody(
                  matchId: matchId,
                  uid: uid,
                  displayName: displayName,
                  locked: locked,
                  pick: pick,
                  squad: squad,
                ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FirstScorerBetBody extends StatefulWidget {
  final String matchId;
  final String uid;
  final String displayName;
  final bool locked;
  final FirstScorerBetPick? pick;
  final SedanSquad squad;

  const _FirstScorerBetBody({
    required this.matchId,
    required this.uid,
    required this.displayName,
    required this.locked,
    required this.pick,
    required this.squad,
  });

  @override
  State<_FirstScorerBetBody> createState() => _FirstScorerBetBodyState();
}

class _FirstScorerBetBodyState extends State<_FirstScorerBetBody> {
  bool _saving = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: PronoType.caption.copyWith(
          color: PronoArenaTheme.onInk,
        )),
        backgroundColor: PronoArenaTheme.ink,
      ),
    );
  }

  Future<void> _pickOpponent() async {
    if (widget.locked || _saving) return;
    setState(() => _saving = true);
    try {
      await FirstScorerBetService.instance.saveOpponentPick(
        matchId: widget.matchId,
        uid: widget.uid,
        displayName: widget.displayName,
      );
    } catch (e) {
      if (mounted) _toast(FirstScorerBetService.userFacingWriteError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPlayer(SedanSquadPlayer player) async {
    if (widget.locked || _saving) return;
    setState(() => _saving = true);
    try {
      await FirstScorerBetService.instance.saveSedanPick(
        matchId: widget.matchId,
        uid: widget.uid,
        displayName: widget.displayName,
        player: player,
      );
    } catch (e) {
      if (mounted) _toast(FirstScorerBetService.userFacingWriteError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pick = widget.pick;
    final locked = widget.locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 16, height: 3, color: PronoArenaTheme.gold),
            const SizedBox(width: 10),
            Text(
              '1ER BUTEUR DU MATCH',
              style: PronoType.kicker.copyWith(color: PronoArenaTheme.text),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          locked
              ? (pick == null
                  ? 'Pari verrouillé — coup d’envoi.'
                  : 'Pari verrouillé — coup d’envoi. Ton pari : ${pick.lockedLabel}')
              : 'Buteur CSSA : +${FirstScorerBetConfig.sedanHitPoints} pts '
                  'et +${FirstScorerBetConfig.sedanHitXp} XP. '
                  'Adversaire : +${FirstScorerBetConfig.opponentHitPoints} pt. '
                  'Se verrouille à l’heure du match, comme le prono.',
          style: PronoType.caption,
        ),
        if (locked && (pick?.xp != null || pick?.points != null)) ...[
          const SizedBox(height: 6),
          Text(
            _firstScorerResultLabel(pick!),
            style: PronoType.meta.copyWith(
              color: _firstScorerResultPositive(pick)
                  ? PronoArenaTheme.greenBright
                  : PronoArenaTheme.textSoft,
            ),
          ),
        ],
        if (!locked) ...[
          const SizedBox(height: 14),
          _ChoiceRow(
            selected: pick?.isOpponent == true,
            label: 'Adversaire',
            note: '+1 si c’est eux qui ouvrent',
            onTap: _saving ? null : _pickOpponent,
          ),
          const SizedBox(height: 10),
          if (widget.squad.isEmpty)
            Text(
              'Effectif Sedan pas encore saisi — tu peux quand même parier « Adversaire ».',
              style: PronoType.meta,
            )
          else
            ...widget.squad.groupedByPosition().map((group) {
              final label = group.$1;
              final players = group.$2;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: PronoType.kicker.copyWith(
                        color: PronoArenaTheme.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...players.map((p) {
                      final selected = pick?.isSedanPlayer == true &&
                          (pick!.playerId == p.id ||
                              normalizeLoose(pick.playerName) ==
                                  normalizeLoose(p.name));
                      return _ChoiceRow(
                        selected: selected,
                        label: p.displayLabel,
                        onTap: _saving ? null : () => _pickPlayer(p),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}

String normalizeLoose(String raw) => raw.trim().toLowerCase();

String _firstScorerResultLabel(FirstScorerBetPick pick) {
  final xp = pick.xp ?? 0;
  final pts = pick.points ?? 0;
  if (xp > 0 && pts > 0) return '+$pts pts · +$xp XP';
  if (xp > 0) return '+$xp XP';
  if (pts > 0) return '+$pts pt${pts > 1 ? 's' : ''}';
  return '0 pt';
}

bool _firstScorerResultPositive(FirstScorerBetPick pick) =>
    (pick.xp ?? 0) > 0 || (pick.points ?? 0) > 0;

class _ChoiceRow extends StatelessWidget {
  final bool selected;
  final String label;
  final String? note;
  final VoidCallback? onTap;

  const _ChoiceRow({
    required this.selected,
    required this.label,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: PronoArenaTheme.fixtureTape(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                color: selected
                    ? PronoArenaTheme.gold
                    : PronoArenaTheme.hairline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PronoType.title.copyWith(
                        fontSize: 17,
                        color: selected
                            ? PronoArenaTheme.text
                            : PronoArenaTheme.textMuted,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(note!, style: PronoType.meta),
                    ],
                  ],
                ),
              ),
              if (selected)
                Text(
                  'TON PARI',
                  style: PronoType.kicker.copyWith(
                    color: PronoArenaTheme.goldDeep,
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
