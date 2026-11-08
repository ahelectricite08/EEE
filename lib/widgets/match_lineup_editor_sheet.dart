import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_lineup.dart';
import '../models/match_stats_schema.dart';
import '../models/official_sedan_lineup_draft.dart';
import '../models/sedan_squad.dart';
import '../navigation/main_shell_insets.dart';
import '../screens/home/home_palette.dart';
import '../services/match_lineup_service.dart';
import '../services/sedan_squad_service.dart';
import '../utils/opponent_lineup_parse.dart';
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
  bool _persistBusy = false;
  bool _persistDirty = false;
  bool _readyToPop = false;

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

  Future<void> _persistSilent() async {
    _persistDirty = true;
    if (_persistBusy) return;
    _persistBusy = true;
    try {
      while (_persistDirty) {
        _persistDirty = false;
        await MatchLineupService.instance.saveLineups(
          home: _home.toSide(),
          away: _away.toSide(),
          showOnCard: _showOnCard,
        );
      }
    } catch (_) {
      _persistDirty = true;
    } finally {
      _persistBusy = false;
    }
  }

  Future<void> _leave({bool snack = false}) async {
    if (_readyToPop) return;
    await _persistSilent();
    if (!mounted) return;
    setState(() => _readyToPop = true);
    Navigator.pop(context);
    if (!snack) return;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _persistSilent();
      if (mounted) await _leave(snack: true);
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboard > 80;
    return PopScope(
      canPop: _readyToPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: DraggableScrollableSheet(
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
                            'Sedan au tap, adversaire : un nom + Entrée (ou coller la liste)',
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
                      onPressed: _saving ? null : () => _leave(),
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
                      onPersist: _persistSilent,
                      onFinishBench: _finishSedanBench,
                    ),
                    _SideEditor(
                      form: _away,
                      scrollCtrl: scrollCtrl,
                      isSedanSide: _awayIsSedan,
                      onChanged: () => setState(() {}),
                      onPersist: _persistSilent,
                      onFinishBench: _finishSedanBench,
                    ),
                  ],
                ),
              ),
              if (!keyboardOpen)
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
        ),
      ),
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
  final Future<void> Function()? onPersist;
  final VoidCallback? onFinishBench;

  const _SideEditor({
    required this.form,
    required this.scrollCtrl,
    required this.isSedanSide,
    required this.onChanged,
    this.onPersist,
    this.onFinishBench,
  });

  List<Widget> _coachFields() {
    return [
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (isSedanSide) {
      return ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          ..._coachFields(),
          _SedanSquadCompose(
            form: form,
            onChanged: onChanged,
            onFinishBench: onFinishBench,
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: _ManualLineupComposer(
            form: form,
            onChanged: onChanged,
            onPersist: onPersist,
            leading: _coachFields(),
          ),
        ),
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
              _ManualLineupComposer(
                form: form,
                onChanged: onChanged,
                dockInput: false,
              ),
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

class _ManualLineupComposer extends StatefulWidget {
  final _SideForm form;
  final VoidCallback onChanged;
  final Future<void> Function()? onPersist;
  final List<Widget> leading;
  final bool dockInput;

  const _ManualLineupComposer({
    required this.form,
    required this.onChanged,
    this.onPersist,
    this.leading = const [],
    this.dockInput = true,
  });

  @override
  State<_ManualLineupComposer> createState() => _ManualLineupComposerState();
}

class _ManualLineupComposerState extends State<_ManualLineupComposer> {
  final _addCtrl = TextEditingController();
  final _focus = FocusNode();

  static const _xi = OfficialSedanLineupDraft.xiSize;
  static const _bench = OfficialSedanLineupDraft.benchMax;

  @override
  void dispose() {
    _addCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<String> get _names {
    return [
      ...widget.form.starters.map((c) => c.text.trim()),
      ...widget.form.substitutes.map((c) => c.text.trim()),
    ].where((e) => e.isNotEmpty).toList();
  }

  void _apply(List<String> names) {
    final capped = names.take(_xi + _bench).toList();
    for (var i = 0; i < widget.form.starters.length; i++) {
      widget.form.starters[i].text = i < capped.length && i < _xi ? capped[i] : '';
    }
    final bench = capped.skip(_xi).toList();
    for (var i = 0; i < widget.form.substitutes.length; i++) {
      widget.form.substitutes[i].text = i < bench.length ? bench[i] : '';
    }
    setState(() {});
    widget.onChanged();
    unawaited(widget.onPersist?.call());
  }

  void _ingest(String raw) {
    final parsed = parseOpponentLineupNames(raw);
    if (parsed.isEmpty) return;
    final seen = {for (final n in _names) n.toLowerCase()};
    final next = [..._names];
    for (final name in parsed) {
      if (seen.contains(name.toLowerCase())) continue;
      seen.add(name.toLowerCase());
      next.add(name);
    }
    _apply(next);
  }

  void _submit() {
    final raw = _addCtrl.text;
    if (raw.trim().isEmpty) return;
    _ingest(raw);
    _addCtrl.clear();
    _focus.requestFocus();
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    if (text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rien à coller.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    _ingest(text);
  }

  void _removeAt(int index) {
    final names = [..._names];
    if (index < 0 || index >= names.length) return;
    names.removeAt(index);
    _apply(names);
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;
    final xi = names.take(_xi).toList();
    final bench = names.skip(_xi).toList();
    final full = names.length >= _xi + _bench;

    final chips = <Widget>[
      Text(
        'Un nom + Entrée. Ou copie les 11 d’un coup et Colle la liste.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: homeMutedText,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          TextButton.icon(
            onPressed: full ? null : _paste,
            icon: const Icon(Icons.content_paste_rounded, size: 16),
            label: Text(
              'Coller la liste',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: homeGreen),
          ),
          const Spacer(),
          if (names.isNotEmpty)
            TextButton(
              onPressed: () => _apply(const []),
              style: TextButton.styleFrom(foregroundColor: homeMutedText),
              child: Text(
                'Tout effacer',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      _chipHeader('TITULAIRES', '${xi.length}/$_xi'),
      const SizedBox(height: 8),
      if (xi.isEmpty)
        Text(
          'Personne pour l’instant.',
          style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < xi.length; i++)
              _nameChip(
                label: '${i + 1}  ${xi[i]}',
                accent: homeGreen,
                onDeleted: () => _removeAt(i),
              ),
          ],
        ),
      const SizedBox(height: 16),
      _chipHeader('BANC', '${bench.length}/$_bench'),
      const SizedBox(height: 8),
      if (bench.isEmpty)
        Text(
          'Optionnel.',
          style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < bench.length; i++)
              _nameChip(
                label: bench[i],
                accent: homeGreenBright,
                onDeleted: () => _removeAt(_xi + i),
              ),
          ],
        ),
    ];

    final input = Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: TextField(
        controller: _addCtrl,
        focusNode: _focus,
        enabled: !full,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        onChanged: (v) {
          if (v.contains('\n') || v.contains('\t') || _looksLikeBulk(v)) {
            _ingest(v);
            _addCtrl.clear();
          }
        },
        decoration: InputDecoration(
          hintText: full
              ? 'Liste complète'
              : (xi.length < _xi
                  ? 'Titulaire ${xi.length + 1} — Entrée pour valider'
                  : 'Remplaçant — Entrée pour valider'),
          hintStyle: GoogleFonts.inter(color: homeMutedText, fontSize: 13),
          isDense: true,
          filled: true,
          fillColor: homeSurfaceMuted,
          suffixIcon: IconButton(
            tooltip: 'Ajouter',
            onPressed: full ? null : _submit,
            icon: const Icon(Icons.add_rounded, color: homeGreen),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: homeBorder),
          ),
        ),
        style: GoogleFonts.inter(
          fontSize: 15,
          color: homeText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final scroll = ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      children: [
        ...widget.leading,
        ...chips,
      ],
    );

    if (!widget.dockInput) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.leading,
          ...chips,
          input,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: scroll),
        const ColoredBox(color: homeHairline, child: SizedBox(height: 1)),
        input,
      ],
    );
  }

  bool _looksLikeBulk(String v) =>
      v.split(',').where((e) => e.trim().isNotEmpty).length >= 3;

  Widget _chipHeader(String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: homeMutedText,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: homeGreen,
          ),
        ),
      ],
    );
  }

  Widget _nameChip({
    required String label,
    required Color accent,
    required VoidCallback onDeleted,
  }) {
    return InputChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: homeText,
        ),
      ),
      onDeleted: onDeleted,
      deleteIconColor: homeMutedText,
      backgroundColor: homeSurfaceMuted,
      side: BorderSide(color: accent.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
