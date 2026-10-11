import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/official_sedan_lineup_draft.dart';
import '../models/sedan_squad.dart';
import '../screens/home/home_palette.dart';
import 'xi_mini_pitch.dart';

/// Picker staff : tape l’effectif pour poser le XI, puis le banc.
class OfficialSedanLineupPicker extends StatefulWidget {
  final SedanSquad squad;
  final OfficialSedanLineupDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onFinishBench;

  const OfficialSedanLineupPicker({
    super.key,
    required this.squad,
    required this.draft,
    required this.onChanged,
    this.onFinishBench,
  });

  @override
  State<OfficialSedanLineupPicker> createState() =>
      _OfficialSedanLineupPickerState();
}

class _OfficialSedanLineupPickerState extends State<OfficialSedanLineupPicker> {
  final _filterCtrl = TextEditingController();
  String _query = '';

  OfficialSedanLineupDraft get _draft => widget.draft;

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    setState(() {});
    widget.onChanged();
  }

  void _tap(SedanSquadPlayer player) {
    if (_draft.tapPlayer(player)) _notify();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final onBench = draft.phase == OfficialSedanLineupPhase.bench;
    final groups = <(String, List<SedanSquadPlayer>)>[];
    final q = _query;
    for (final group in widget.squad.groupedByPosition()) {
      final filtered = group.$2.where((p) {
        if (q.isEmpty) return true;
        return p.displayLabel.toLowerCase().contains(q) ||
            p.name.toLowerCase().contains(q);
      }).toList();
      if (filtered.isNotEmpty) groups.add((group.$1, filtered));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhaseBanner(
          title: onBench ? 'Sélectionne les remplaçants' : 'Compose le XI',
          count: onBench ? draft.benchCount : draft.xiCount,
          max: onBench
              ? OfficialSedanLineupDraft.benchMax
              : OfficialSedanLineupDraft.xiSize,
          hint: onBench
              ? 'Tape les joueurs restants pour le banc. Pas besoin de tout remplir.'
              : 'Tape les joueurs un par un. À 11, on passe au banc.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                draft.resetXi();
                _notify();
              },
              style: TextButton.styleFrom(
                foregroundColor: homeMutedText,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Recommencer le XI',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (onBench)
              TextButton(
                onPressed: () {
                  draft.resetAll();
                  _notify();
                },
                style: TextButton.styleFrom(
                  foregroundColor: homeMutedText,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'Tout effacer',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (draft.starterIds.isNotEmpty) ...[
          Text(
            'TITULAIRES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: homeMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          _PickedWrap(
            ids: draft.starterIds,
            squad: widget.squad,
            cached: draft.cachedLineupNames,
            accent: homeGreen,
            onRemove: (id) {
              final player = widget.squad.byId(id);
              if (player == null) {
                draft.starterIds.remove(id);
                if (draft.starterIds.length < OfficialSedanLineupDraft.xiSize) {
                  draft.phase = OfficialSedanLineupPhase.xi;
                }
                _notify();
                return;
              }
              _tap(player);
            },
          ),
          const SizedBox(height: 10),
        ],
        if (draft.unmatchedStarters.isNotEmpty)
          _UnmatchedChips(
            label: 'Noms hors effectif (titulaires)',
            names: draft.unmatchedStarters,
            onDismiss: (name) {
              draft.dismissUnmatchedStarter(name);
              _notify();
            },
          ),
        if (onBench &&
            (draft.benchIds.isNotEmpty || draft.unmatchedBench.isNotEmpty)) ...[
          Text(
            'REMPLAÇANTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: homeMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          _PickedWrap(
            ids: draft.benchIds,
            squad: widget.squad,
            cached: draft.cachedLineupNames,
            accent: homeGreenBright,
            onRemove: (id) {
              final player = widget.squad.byId(id);
              if (player == null) {
                draft.benchIds.remove(id);
                _notify();
                return;
              }
              _tap(player);
            },
          ),
          const SizedBox(height: 8),
        ],
        if (draft.unmatchedBench.isNotEmpty)
          _UnmatchedChips(
            label: 'Noms hors effectif (banc)',
            names: draft.unmatchedBench,
            onDismiss: (name) {
              draft.dismissUnmatchedBench(name);
              _notify();
            },
          ),
        TextField(
          controller: _filterCtrl,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          style: GoogleFonts.inter(fontSize: 13, color: homeText),
          decoration: InputDecoration(
            hintText: 'Filtrer l’effectif…',
            hintStyle: GoogleFonts.inter(color: homeMutedText, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: homeMutedText),
            isDense: true,
            filled: true,
            fillColor: homeSurfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: homeBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aucun joueur pour ce filtre.',
              style: GoogleFonts.inter(fontSize: 13, color: homeMutedText),
            ),
          )
        else
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
              child: Text(
                group.$1.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: homeGreen,
                ),
              ),
            ),
            for (final player in group.$2)
              _OfficialSquadPlayerLine(
                player: player,
                role: draft.isStarter(player.id)
                    ? _PickRole.xi
                    : draft.isBench(player.id)
                        ? _PickRole.bench
                        : _PickRole.none,
                dimmed: !draft.isPicked(player.id) &&
                    (draft.remainingXiLocked || draft.remainingBenchLocked),
                onTap: () => _tap(player),
              ),
          ],
        if (onBench) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onFinishBench,
              style: OutlinedButton.styleFrom(
                foregroundColor: homeGreen,
                side: const BorderSide(color: homeGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Terminer le banc',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ensuite tu saisis l’adversaire à la main, puis Enregistrer.',
            style: GoogleFonts.inter(fontSize: 11, color: homeMutedText),
          ),
        ],
      ],
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  final String title;
  final String hint;
  final int count;
  final int max;

  const _PhaseBanner({
    required this.title,
    required this.hint,
    required this.count,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final full = count >= max;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: homeSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: full ? homeGreen.withAlpha(120) : homeBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: homeText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: homeMutedText,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count/$max',
                key: const Key('official-sedan-counter'),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: homeGreen,
                ),
              ),
              Text(
                full ? 'Complet' : 'sélectionné${count > 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: homeMutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickedWrap extends StatelessWidget {
  final List<String> ids;
  final SedanSquad squad;
  final Map<String, String> cached;
  final Color accent;
  final ValueChanged<String> onRemove;

  const _PickedWrap({
    required this.ids,
    required this.squad,
    required this.cached,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final id in ids)
          InputChip(
            visualDensity: VisualDensity.compact,
            backgroundColor: accent.withAlpha(24),
            side: BorderSide(color: accent.withAlpha(80)),
            avatar: SedanPlayerFace(
              player: squad.byId(id),
              size: 22,
              occupied: true,
              selected: true,
              background: homeSurface,
              foreground: homeText,
              border: accent,
            ),
            label: Text(
              squad.byId(id)?.lineupName ?? cached[id] ?? id,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: homeText,
              ),
            ),
            onDeleted: () => onRemove(id),
          ),
      ],
    );
  }
}

class _UnmatchedChips extends StatelessWidget {
  final String label;
  final List<String> names;
  final ValueChanged<String> onDismiss;

  const _UnmatchedChips({
    required this.label,
    required this.names,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: homeMutedText,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in names)
                InputChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    name,
                    style: GoogleFonts.inter(fontSize: 11, color: homeText),
                  ),
                  onDeleted: () => onDismiss(name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PickRole { none, xi, bench }

class _OfficialSquadPlayerLine extends StatelessWidget {
  final SedanSquadPlayer player;
  final _PickRole role;
  final bool dimmed;
  final VoidCallback onTap;

  const _OfficialSquadPlayerLine({
    required this.player,
    required this.role,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = role != _PickRole.none;
    final accent = role == _PickRole.bench ? homeGreenBright : homeGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('official-sedan-${player.id}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(22) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: homeHairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
          child: Row(
            children: [
              SedanPlayerFace(
                player: player,
                size: 32,
                occupied: true,
                selected: selected,
                background: homeSurfaceMuted,
                foreground: dimmed ? homeMutedText : homeText,
                border: selected ? accent : homeBorder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: dimmed ? homeMutedText : homeText,
                  ),
                ),
              ),
              if (player.position != null) ...[
                const SizedBox(width: 8),
                Text(
                  player.position!.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: homeMutedText,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              _RoleMark(role: role),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleMark extends StatelessWidget {
  final _PickRole role;

  const _RoleMark({required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == _PickRole.none) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          border: Border.all(color: homeBorder),
        ),
      );
    }
    final bench = role == _PickRole.bench;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bench ? homeGreenBright : homeGreen,
      ),
      child: Icon(
        Icons.check_rounded,
        size: 13,
        color: Colors.white.withAlpha(230),
      ),
    );
  }
}
