import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/fff_season_config.dart';
import '../../../../models/season_lifecycle_config.dart';
import '../../../../services/season_config_service.dart';
import '../../../../services/season_lifecycle_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';

/// Fin de saison : messages accueil / calendrier + archivage classement club.
class SeasonLifecycleAdminSection extends StatefulWidget {
  const SeasonLifecycleAdminSection({super.key});

  @override
  State<SeasonLifecycleAdminSection> createState() =>
      _SeasonLifecycleAdminSectionState();
}

class _SeasonLifecycleAdminSectionState extends State<SeasonLifecycleAdminSection> {
  final _headline = TextEditingController();
  final _subline = TextEditingController();
  final _waitTitle = TextEditingController();
  final _waitSub = TextEditingController();
  final _archiveSeason = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _between = false;
  String? _archiveMsg;
  String? _archiveErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await SeasonLifecycleService.getCurrent();
    final fff = await SeasonConfigService.getCurrent();
    if (!mounted) return;
    _apply(c, fff);
    setState(() => _loading = false);
  }

  void _apply(SeasonLifecycleConfig c, FffSeasonConfig fff) {
    _between = c.betweenSeasons;
    _headline.text = c.homeHeadline;
    _subline.text = c.homeSubline;
    _waitTitle.text = c.upcomingWaitTitle;
    _waitSub.text = c.upcomingWaitSubtitle;
    if (_archiveSeason.text.trim().isEmpty) {
      _archiveSeason.text = fff.seasonLabel;
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _subline.dispose();
    _waitTitle.dispose();
    _waitSub.dispose();
    _archiveSeason.dispose();
    super.dispose();
  }

  SeasonLifecycleConfig _readForm() {
    return SeasonLifecycleConfig(
      betweenSeasons: _between,
      homeHeadline: _headline.text.trim().isEmpty
          ? SeasonLifecycleConfig.defaults.homeHeadline
          : _headline.text.trim(),
      homeSubline: _subline.text.trim().isEmpty
          ? SeasonLifecycleConfig.defaults.homeSubline
          : _subline.text.trim(),
      upcomingWaitTitle: _waitTitle.text.trim().isEmpty
          ? SeasonLifecycleConfig.defaults.upcomingWaitTitle
          : _waitTitle.text.trim(),
      upcomingWaitSubtitle: _waitSub.text.trim().isEmpty
          ? SeasonLifecycleConfig.defaults.upcomingWaitSubtitle
          : _waitSub.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SeasonLifecycleService.save(_readForm());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cycle saison enregistré',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: adminGreenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runArchive() async {
    setState(() {
      _archiveMsg = null;
      _archiveErr = null;
    });
    final label = _archiveSeason.text.trim();
    if (label.isEmpty) {
      setState(() => _archiveErr = 'Indique la saison à archiver (ex. 2025-2026).');
      return;
    }
    try {
      final fn =
          FirebaseFunctions.instance.httpsCallable('archiveClubRankingSeason');
      final res = await fn.call(<String, dynamic>{'seasonLabel': label});
      final data = Map<String, dynamic>.from((res.data as Map?) ?? {});
      if (mounted) {
        setState(() {
          _archiveMsg =
              'Archivé : ${data['teamCount'] ?? '?'} lignes → ranking_archive/$label';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _archiveErr = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CYCLE SAISON (CLUB)',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminOrange,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '« Fin de saison » : accueil = message + stade, onglet À venir = texte d’attente, '
          'résultats + classement inchangés. Avant de basculer les ids FFF, archive le classement '
          'ci-dessous pour le retrouver dans Calendrier → Classement (saisons).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.45),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Fin de saison (mode attente)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _between,
                onChanged: (v) => setState(() => _between = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AdminField(ctrl: _headline, label: 'Titre accueil (bloc stade)', maxLines: 2),
        const SizedBox(height: 8),
        AdminField(ctrl: _subline, label: 'Sous-titre accueil', maxLines: 3),
        const SizedBox(height: 8),
        AdminField(ctrl: _waitTitle, label: 'Titre onglet « À venir » (liste vide)'),
        const SizedBox(height: 8),
        AdminField(ctrl: _waitSub, label: 'Texte onglet « À venir »', maxLines: 4),
        const SizedBox(height: 14),
        Text(
          'Archiver le classement club (Firestore)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Copie la collection `ranking` dans `ranking_archive/{saison}` sans l’effacer. '
          'À lancer une fois en fin de saison avant la nouvelle sync FFF.',
          style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _archiveSeason,
                style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                decoration: InputDecoration(
                  hintText: 'ex. 2025-2026',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  filled: true,
                  fillColor: adminCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: adminBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _runArchive,
              child: Text(
                'ARCHIVER',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  color: adminOrange,
                ),
              ),
            ),
          ],
        ),
        if (_archiveMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _archiveMsg!,
              style: GoogleFonts.inter(fontSize: 11, color: adminGreenAccent),
            ),
          ),
        if (_archiveErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _archiveErr!,
              style: GoogleFonts.inter(fontSize: 11, color: adminRed),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: adminGreenAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              _saving ? 'Enregistrement…' : 'Enregistrer cycle + textes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Document : app_config/${SeasonLifecycleConfig.firestoreDocId}',
          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
        ),
      ],
    );
  }
}
