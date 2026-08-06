import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sedan_squad.dart';
import '../navigation/main_shell_insets.dart';
import '../services/sedan_squad_service.dart';

/// Ouvre un bottom sheet pour choisir un joueur Sedan (sélection unique).
/// Retourne le joueur ou null si annulé.
Future<SedanSquadPlayer?> showSedanSquadSinglePicker(
  BuildContext context, {
  String title = 'Choisir un joueur',
  Color? accent,
}) async {
  final accentColor = accent ?? const Color(0xFF2E7D32);
  return showModalBottomSheet<SedanSquadPlayer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SedanSquadPickerSheet(
      title: title,
      accent: accentColor,
      multiSelect: false,
      maxSelection: 1,
    ),
  );
}

/// Ouvre un bottom sheet multi-sélection (composition).
/// [alreadySelected] = noms déjà dans les champs (pour pré-cocher).
Future<List<SedanSquadPlayer>?> showSedanSquadMultiPicker(
  BuildContext context, {
  String title = 'Composition Sedan',
  int maxSelection = 11,
  Set<String> alreadySelectedNames = const {},
  Color? accent,
}) async {
  final accentColor = accent ?? const Color(0xFF2E7D32);
  final result = await showModalBottomSheet<List<SedanSquadPlayer>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SedanSquadPickerSheet(
      title: title,
      accent: accentColor,
      multiSelect: true,
      maxSelection: maxSelection,
      preselectedNames: alreadySelectedNames,
    ),
  );
  return result;
}

class _SedanSquadPickerSheet extends StatefulWidget {
  final String title;
  final Color accent;
  final bool multiSelect;
  final int maxSelection;
  final Set<String> preselectedNames;

  const _SedanSquadPickerSheet({
    required this.title,
    required this.accent,
    required this.multiSelect,
    required this.maxSelection,
    this.preselectedNames = const {},
  });

  @override
  State<_SedanSquadPickerSheet> createState() => _SedanSquadPickerSheetState();
}

class _SedanSquadPickerSheetState extends State<_SedanSquadPickerSheet> {
  final _filterCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  String _query = '';
  bool _preselectedApplied = false;
  List<SedanSquadPlayer> _latestPlayers = const [];

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  void _applyPreselectionOnce(List<SedanSquadPlayer> players) {
    if (_preselectedApplied || widget.preselectedNames.isEmpty) {
      _preselectedApplied = true;
      return;
    }
    _preselectedApplied = true;
    final norm = widget.preselectedNames
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    for (final p in players) {
      final candidates = {
        p.name.trim().toLowerCase(),
        p.lineupName.trim().toLowerCase(),
        p.displayLabel.trim().toLowerCase(),
      };
      if (candidates.any(norm.contains)) {
        _selectedIds.add(p.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MainShellInsets.safeBottom(context);
    final inset = MainShellInsets.keyboardBottom(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: widget.accent,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (widget.multiSelect)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${_selectedIds.length}/${widget.maxSelection}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _filterCtrl,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filtrer…',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<SedanSquad>(
                  stream: SedanSquadService.watch(),
                  builder: (context, snap) {
                    final squad = snap.data ?? SedanSquad.empty;
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: widget.accent),
                      );
                    }
                    if (squad.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Effectif vide — ajoute des joueurs dans Admin → Équipes & stades.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }
                    _latestPlayers = squad.players;
                    _applyPreselectionOnce(squad.players);
                    final filtered = squad.players.where((p) {
                      if (_query.isEmpty) return true;
                      return p.displayLabel.toLowerCase().contains(_query) ||
                          p.name.toLowerCase().contains(_query);
                    }).toList();

                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom + inset),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final selected = _selectedIds.contains(p.id);
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selected: selected,
                          selectedTileColor: widget.accent.withAlpha(40),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: widget.accent.withAlpha(50),
                            child: Text(
                              p.number?.toString() ?? '·',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: widget.accent,
                              ),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: p.position != null
                              ? Text(
                                  p.position!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                )
                              : null,
                          trailing: widget.multiSelect
                              ? Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? widget.accent
                                      : Colors.white38,
                                )
                              : null,
                          onTap: () {
                            if (!widget.multiSelect) {
                              Navigator.pop(context, p);
                              return;
                            }
                            setState(() {
                              if (selected) {
                                _selectedIds.remove(p.id);
                              } else if (_selectedIds.length <
                                  widget.maxSelection) {
                                _selectedIds.add(p.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (widget.multiSelect)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final picked = _latestPlayers
                            .where((p) => _selectedIds.contains(p.id))
                            .toList();
                        Navigator.pop(context, picked);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'VALIDER (${_selectedIds.length})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Champ joueur avec bouton effectif (côté Sedan) + saisie manuelle.
class SedanPlayerNameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool showSquadPicker;
  final Color? accent;
  final String? hint;

  const SedanPlayerNameField({
    super.key,
    required this.controller,
    required this.label,
    this.showSquadPicker = true,
    this.accent,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? const Color(0xFF2E7D32);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              filled: true,
              fillColor: Colors.white.withAlpha(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (showSquadPicker) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton.filled(
              tooltip: 'Effectif Sedan',
              onPressed: () async {
                final p = await showSedanSquadSinglePicker(
                  context,
                  title: label,
                  accent: accentColor,
                );
                if (p != null) {
                  controller.text = p.lineupName;
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: accentColor.withAlpha(40),
                foregroundColor: accentColor,
              ),
              icon: const Icon(Icons.groups_rounded),
            ),
          ),
        ],
      ],
    );
  }
}
