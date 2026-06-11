import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_lineup.dart';
import '../screens/home/home_palette.dart';
import '../services/match_lineup_service.dart';

Future<void> showMatchLineupEditorSheet(BuildContext context) async {
  final snap = await FirebaseFirestore.instance
      .collection('live')
      .doc('current')
      .get();
  if (!context.mounted) return;
  if (!snap.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aucun live actif.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
    return;
  }

  final d = snap.data() ?? {};
  final lineups = MatchLineups.fromDoc(d);
  final team1 = (d['team1'] as String? ?? 'Domicile').trim();
  final team2 = (d['team2'] as String? ?? 'Extérieur').trim();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MatchLineupEditorSheet(
      team1Label: team1,
      team2Label: team2,
      initial: lineups,
    ),
  );
}

class _MatchLineupEditorSheet extends StatefulWidget {
  final String team1Label;
  final String team2Label;
  final MatchLineups initial;

  const _MatchLineupEditorSheet({
    required this.team1Label,
    required this.team2Label,
    required this.initial,
  });

  @override
  State<_MatchLineupEditorSheet> createState() =>
      _MatchLineupEditorSheetState();
}

class _MatchLineupEditorSheetState extends State<_MatchLineupEditorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late bool _showOnCard;
  late _SideForm _home;
  late _SideForm _away;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _showOnCard = widget.initial.showOnCard;
    _home = _SideForm.fromSide(widget.initial.home);
    _away = _SideForm.fromSide(widget.initial.away);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _home.dispose();
    _away.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await MatchLineupService.instance.saveLineups(
        home: _home.toSide(),
        away: _away.toSide(),
        showOnCard: _showOnCard,
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compositions enregistrées.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: homeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: homeRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: homeSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: homeBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'COMPOSITIONS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: homeMutedText,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Titulaires, remplaçants & coach',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: homeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: homeMutedText),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                value: _showOnCard,
                activeTrackColor: homeGreen.withAlpha(120),
                activeThumbColor: homeGreen,
                title: Text(
                  'Afficher sur la carte match',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: homeText,
                  ),
                ),
                subtitle: Text(
                  'Masqué si les stats sont activées sur la carte.',
                  style: GoogleFonts.inter(fontSize: 11, color: homeMutedText),
                ),
                onChanged: (v) => setState(() => _showOnCard = v),
              ),
              TabBar(
                controller: _tabs,
                labelColor: homeGreen,
                unselectedLabelColor: homeMutedText,
                indicatorColor: homeGreen,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                tabs: [
                  Tab(text: widget.team1Label.length > 14
                      ? '${widget.team1Label.substring(0, 14)}…'
                      : widget.team1Label),
                  Tab(text: widget.team2Label.length > 14
                      ? '${widget.team2Label.substring(0, 14)}…'
                      : widget.team2Label),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _SideEditor(form: _home, scrollCtrl: scrollCtrl),
                    _SideEditor(form: _away, scrollCtrl: scrollCtrl),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 12 + bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: homeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'ENREGISTRER',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
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

class _SideForm {
  final TextEditingController coach;
  final List<TextEditingController> starters;
  final List<TextEditingController> substitutes;

  _SideForm({
    required this.coach,
    required this.starters,
    required this.substitutes,
  });

  factory _SideForm.fromSide(MatchLineupSide side) {
    List<TextEditingController> list(List<String> names, int slots) {
      final out = <TextEditingController>[];
      for (var i = 0; i < slots; i++) {
        out.add(TextEditingController(text: i < names.length ? names[i] : ''));
      }
      return out;
    }

    return _SideForm(
      coach: TextEditingController(text: side.coach),
      starters: list(side.starters, 11),
      substitutes: list(side.substitutes, 7),
    );
  }

  MatchLineupSide toSide() => MatchLineupSide(
        coach: coach.text,
        starters: starters.map((c) => c.text).toList(),
        substitutes: substitutes.map((c) => c.text).toList(),
      );

  void dispose() {
    coach.dispose();
    for (final c in starters) {
      c.dispose();
    }
    for (final c in substitutes) {
      c.dispose();
    }
  }
}

class _SideEditor extends StatelessWidget {
  final _SideForm form;
  final ScrollController scrollCtrl;

  const _SideEditor({required this.form, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Text(
          'Entraîneur',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: homeMutedText,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: form.coach,
          decoration: InputDecoration(
            hintText: 'Nom du coach',
            hintStyle: GoogleFonts.inter(color: homeMutedText, fontSize: 13),
            filled: true,
            fillColor: homeSurfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: homeBorder),
            ),
          ),
          style: GoogleFonts.inter(color: homeText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'TITULAIRES (11)',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: homeMutedText,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(form.starters.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: homeGreen,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: form.starters[i],
                    decoration: InputDecoration(
                      hintText: 'Ex. 9 Dupont',
                      isDense: true,
                      filled: true,
                      fillColor: homeSurfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: homeBorder),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: homeText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'REMPLAÇANTS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: homeMutedText,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(form.substitutes.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: form.substitutes[i],
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: homeMutedText.withAlpha(180),
                ),
                hintText: 'Remplaçant ${i + 1}',
                isDense: true,
                filled: true,
                fillColor: homeSurfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: homeBorder),
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: homeText,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ],
    );
  }
}
