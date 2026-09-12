import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/live_event_player_source.dart';
import '../models/sedan_squad.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/admin/admin_palette.dart';
import '../screens/home/home_palette.dart';
import '../services/sedan_squad_service.dart';

/// Champ joueur live : compo du match si elle existe, sinon repli.
class LiveEventPlayerPicker extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final LiveEventPlayerSource source;
  final VoidCallback onChanged;
  final bool adminStyle;

  const LiveEventPlayerPicker({
    super.key,
    required this.controller,
    required this.label,
    required this.source,
    required this.onChanged,
    this.adminStyle = false,
  });

  Color get _surface => adminStyle ? adminCard : homeSurface;
  Color get _mutedFill => adminStyle ? adminSurface : homeSurfaceMuted;
  Color get _text => adminStyle ? adminTextPrimary : homeText;
  Color get _muted => adminStyle ? adminGrey : homeMutedText;
  Color get _hairline => adminStyle ? adminBorder : homeHairline;
  Color get _filet => adminStyle ? adminGreenAccent : homeGreen;

  @override
  Widget build(BuildContext context) {
    final hint = source.hasLineupPlayers
        ? 'Compo du match ou saisie'
        : source.useSedanSquadFallback
            ? 'Effectif ou saisie manuelle'
            : LiveEventPlayerSource.quietOpponentHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          style: GoogleFonts.inter(color: _text, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: _mutedFill,
            labelStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _hairline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _filet, width: 1),
            ),
          ),
        ),
        if (source.hasLineupPlayers) ...[
          const SizedBox(height: 10),
          Text(
            'COMPOSITION',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _muted,
            ),
          ),
          const SizedBox(height: 6),
          if (source.starters.isNotEmpty)
            _ChipWrap(
              names: source.starters,
              selected: controller.text.trim(),
              onPick: _pick,
              filet: _filet,
              hairline: _hairline,
              surface: _surface,
              text: _text,
            ),
          if (source.substitutes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'REMPLAÇANTS',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: _muted,
              ),
            ),
            const SizedBox(height: 6),
            _ChipWrap(
              names: source.substitutes,
              selected: controller.text.trim(),
              onPick: _pick,
              filet: _filet,
              hairline: _hairline,
              surface: _surface,
              text: _text,
            ),
          ],
        ] else if (source.useSedanSquadFallback) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openSquadSheet(context),
            icon: Icon(Icons.groups_outlined, size: 18, color: _filet),
            label: Text(
              'Choisir dans l’effectif',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: _filet,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _filet,
              side: BorderSide(color: _hairline, width: 1),
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ] else if (source.opponentWithoutLineup) ...[
          const SizedBox(height: 8),
          Text(
            LiveEventPlayerSource.quietOpponentHint,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ],
    );
  }

  void _pick(String name) {
    controller.text = name;
    onChanged();
  }

  Future<void> _openSquadSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaperNameSheet(
        title: label,
        adminStyle: adminStyle,
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      _pick(picked);
    }
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> names;
  final String selected;
  final ValueChanged<String> onPick;
  final Color filet;
  final Color hairline;
  final Color surface;
  final Color text;

  const _ChipWrap({
    required this.names,
    required this.selected,
    required this.onPick,
    required this.filet,
    required this.hairline,
    required this.surface,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in names)
          _PaperChip(
            label: name,
            selected: selected == name,
            onTap: () => onPick(name),
            filet: filet,
            hairline: hairline,
            surface: surface,
            text: text,
          ),
      ],
    );
  }
}

/// Ivoire + filet 1 px. Vert en texte / bordure, jamais en fond gras.
class _PaperChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color filet;
  final Color hairline;
  final Color surface;
  final Color text;

  const _PaperChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.filet,
    required this.hairline,
    required this.surface,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? filet : hairline,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? filet : text,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperNameSheet extends StatefulWidget {
  final String title;
  final bool adminStyle;

  const _PaperNameSheet({
    required this.title,
    required this.adminStyle,
  });

  @override
  State<_PaperNameSheet> createState() => _PaperNameSheetState();
}

class _PaperNameSheetState extends State<_PaperNameSheet> {
  final _filterCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminStyle = widget.adminStyle;
    final surface = adminStyle ? adminCard : homeSurface;
    final text = adminStyle ? adminTextPrimary : homeText;
    final muted = adminStyle ? adminGrey : homeMutedText;
    final hairline = adminStyle ? adminBorder : homeHairline;
    final filet = adminStyle ? adminGreenAccent : homeGreen;
    final bottom = MainShellInsets.safeBottom(context);
    final inset = MainShellInsets.keyboardBottom(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: hairline, width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hairline,
                  borderRadius: BorderRadius.circular(2),
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
                          fontWeight: FontWeight.w800,
                          color: text,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _filterCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: GoogleFonts.inter(color: text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filtrer…',
                    hintStyle: GoogleFonts.inter(color: muted),
                    prefixIcon: Icon(Icons.search_rounded, color: muted),
                    filled: true,
                    fillColor: adminStyle ? adminSurface : homeSurfaceMuted,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: hairline, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: filet, width: 1),
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
                        child: CircularProgressIndicator(color: filet),
                      );
                    }
                    if (squad.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Effectif vide — saisie manuelle possible.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: muted, fontSize: 13),
                          ),
                        ),
                      );
                    }
                    final q = _query;
                    final groups = <(String, List<SedanSquadPlayer>)>[];
                    for (final group in squad.groupedByPosition()) {
                      final filtered = group.$2.where((p) {
                        if (q.isEmpty) return true;
                        return p.displayLabel.toLowerCase().contains(q) ||
                            p.name.toLowerCase().contains(q);
                      }).toList();
                      if (filtered.isNotEmpty) {
                        groups.add((group.$1, filtered));
                      }
                    }
                    if (groups.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucun joueur',
                          style: GoogleFonts.inter(color: muted),
                        ),
                      );
                    }
                    return ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        12 + bottom + inset,
                      ),
                      children: [
                        for (final group in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                            child: Text(
                              group.$1.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                                color: filet,
                              ),
                            ),
                          ),
                          ...group.$2.map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: surface,
                                child: InkWell(
                                  onTap: () =>
                                      Navigator.pop(context, p.lineupName),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: hairline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            p.number?.toString() ?? '·',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: filet,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: text,
                                            ),
                                          ),
                                        ),
                                        if (p.position != null)
                                          Text(
                                            p.position!,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: muted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
