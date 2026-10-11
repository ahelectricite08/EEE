import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_lineup.dart';
import '../models/match_stats_schema.dart';
import '../models/official_sedan_lineup_draft.dart';
import '../models/sedan_squad.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/home/home_palette.dart';
import '../services/match_lineup_service.dart';
import '../services/sedan_squad_service.dart';
import 'official_sedan_lineup_picker.dart';

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
  final matchId = (d['matchId'] as String? ?? '').trim();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MatchLineupEditorSheet(
      team1Label: team1,
      team2Label: team2,
      matchId: matchId,
      initial: lineups,
    ),
  );
}

class _MatchLineupEditorSheet extends StatefulWidget {
  final String team1Label;
  final String team2Label;
  final String matchId;
  final MatchLineups initial;

  const _MatchLineupEditorSheet({
    required this.team1Label,
    required this.team2Label,
    required this.matchId,
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

  bool get _homeIsSedan =>
      MatchStatsSchema.isSedanTeamLabel(widget.team1Label);
  bool get _awayIsSedan =>
      MatchStatsSchema.isSedanTeamLabel(widget.team2Label);

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

  void _finishSedanBench() {
    final other = _homeIsSedan ? 1 : 0;
    _tabs.animateTo(other);
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
    final bottom = MainShellInsets.safeBottom(context);
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
                            'XI Sedan depuis l’effectif, adversaire à la main',
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
                  Tab(
                    text: widget.team1Label.length > 14
                        ? '${widget.team1Label.substring(0, 14)}…'
                        : widget.team1Label,
                  ),
                  Tab(
                    text: widget.team2Label.length > 14
                        ? '${widget.team2Label.substring(0, 14)}…'
                        : widget.team2Label,
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _SideEditor(
                      form: _home,
                      scrollCtrl: scrollCtrl,
                      isSedanSide: _homeIsSedan,
                      onChanged: () => setState(() {}),
                      onFinishBench: _finishSedanBench,
                    ),
                    _SideEditor(
                      form: _away,
                      scrollCtrl: scrollCtrl,
                      isSedanSide: _awayIsSedan,
                      onChanged: () => setState(() {}),
                      onFinishBench: _finishSedanBench,
                    ),
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
  OfficialSedanLineupDraft? sedan;
  SedanSquad sedanSquad = SedanSquad.empty;

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
      starters: list(side.starters, OfficialSedanLineupDraft.xiSize),
      substitutes: list(side.substitutes, OfficialSedanLineupDraft.benchMax),
    );
  }

  List<String> get _filledStarters => starters
      .map((c) => c.text.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get _filledSubs => substitutes
      .map((c) => c.text.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  MatchLineupSide toSide() {
    final draft = sedan;
    if (draft != null) {
      return MatchLineupSide(
        coach: coach.text,
        starters: draft.starterLineupNames(sedanSquad),
        substitutes: draft.benchLineupNames(sedanSquad),
      );
    }
    return MatchLineupSide(
      coach: coach.text,
      starters: starters.map((c) => c.text).toList(),
      substitutes: substitutes.map((c) => c.text).toList(),
    );
  }

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
  final bool isSedanSide;
  final VoidCallback onChanged;
  final VoidCallback? onFinishBench;

  const _SideEditor({
    required this.form,
    required this.scrollCtrl,
    required this.isSedanSide,
    required this.onChanged,
    this.onFinishBench,
  });

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
        if (isSedanSide)
          _SedanSquadCompose(
            form: form,
            onChanged: onChanged,
            onFinishBench: onFinishBench,
          )
        else
          const _ManualAwayFields(),
        if (!isSedanSide) _ManualNameSlots(form: form),
      ],
    );
  }
}

class _SedanSquadCompose extends StatelessWidget {
  final _SideForm form;
  final VoidCallback onChanged;
  final VoidCallback? onFinishBench;

  const _SedanSquadCompose({
    required this.form,
    required this.onChanged,
    this.onFinishBench,
  });

  void _hydrate(SedanSquad squad) {
    form.sedanSquad = squad;
    if (squad.isEmpty) return;
    if (form.sedan == null) {
      form.sedan = OfficialSedanLineupDraft.fromNames(
        starters: form._filledStarters,
        substitutes: form._filledSubs,
        squad: squad,
      );
      onChanged();
      return;
    }
    if (form.sedan!.resolveUnmatched(squad)) onChanged();
  }

  void _scheduleHydrate(BuildContext context, SedanSquad squad) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _hydrate(squad);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SedanSquad>(
      stream: SedanSquadService.watch(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: homeGreen),
            ),
          );
        }
        final squad = snap.data ?? SedanSquad.empty;
        form.sedanSquad = squad;
        final draft = form.sedan;
        if (draft == null ||
            draft.unmatchedStarters.isNotEmpty ||
            draft.unmatchedBench.isNotEmpty) {
          _scheduleHydrate(context, squad);
        }
        if (squad.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Effectif vide — ajoute les joueurs dans Admin → Équipes & stades, '
                'ou saisis les noms à la main.',
                style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
              ),
              const SizedBox(height: 12),
              _ManualNameSlots(form: form),
            ],
          );
        }
        if (draft == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: homeGreen),
            ),
          );
        }
        return OfficialSedanLineupPicker(
          squad: squad,
          draft: draft,
          onChanged: onChanged,
          onFinishBench: onFinishBench,
        );
      },
    );
  }
}

class _ManualAwayFields extends StatelessWidget {
  const _ManualAwayFields();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Adversaire : saisie manuelle. On n’a pas l’effectif à l’avance — '
        'tape les noms (titulaires puis banc).',
        style: GoogleFonts.inter(fontSize: 12, color: homeMutedText, height: 1.35),
      ),
    );
  }
}

class _ManualNameSlots extends StatelessWidget {
  final _SideForm form;

  const _ManualNameSlots({required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      hintText: 'Ex. Martin',
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
