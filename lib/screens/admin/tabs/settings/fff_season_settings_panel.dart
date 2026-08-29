import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/fff_season_config.dart';
import '../../../../services/season_config_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';

/// Admin : paramètres saison / API FFF (`app_config/fff_season`).
class FffSeasonSettingsPanel extends StatefulWidget {
  const FffSeasonSettingsPanel({super.key});

  @override
  State<FffSeasonSettingsPanel> createState() => _FffSeasonSettingsPanelState();
}

class _FffSeasonSettingsPanelState extends State<FffSeasonSettingsPanel> {
  final _cp = TextEditingController();
  final _ph = TextEditingController();
  final _gp = TextEditingController();
  final _club = TextEditingController();
  final _season = TextEditingController();
  final _comp = TextEditingController();
  final _prefix = TextEditingController();
  final _r2Cp = TextEditingController();
  final _r2Ph = TextEditingController();
  final _r2Gp = TextEditingController();
  final _r2Comp = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _fffSyncEnabled = true;
  String? _lastTestMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await SeasonConfigService.getCurrent();
    if (!mounted) return;
    _applyToControllers(c);
    setState(() => _loading = false);
  }

  void _applyToControllers(FffSeasonConfig c) {
    _cp.text = '${c.fffCompetitionId}';
    _ph.text = '${c.fffPhaseId}';
    _gp.text = '${c.fffPouleId}';
    _club.text = '${c.fffClubNo}';
    _season.text = c.seasonLabel;
    _comp.text = c.competitionDisplayName;
    _prefix.text = c.matchDocIdPrefix;
    _r2Cp.text = c.fffR2CompetitionId > 0 ? '${c.fffR2CompetitionId}' : '';
    _r2Ph.text = '${c.fffR2PhaseId}';
    _r2Gp.text = '${c.fffR2PouleId}';
    _r2Comp.text = c.r2CompetitionDisplayName;
    _fffSyncEnabled = c.fffSyncEnabled;
  }

  FffSeasonConfig _readForm() {
    int p(String s, int d) => int.tryParse(s.trim()) ?? d;
    return FffSeasonConfig(
      fffCompetitionId: p(_cp.text, FffSeasonConfig.defaults.fffCompetitionId),
      fffPhaseId: p(_ph.text, FffSeasonConfig.defaults.fffPhaseId),
      fffPouleId: p(_gp.text, FffSeasonConfig.defaults.fffPouleId),
      fffClubNo: p(_club.text, FffSeasonConfig.defaults.fffClubNo),
      seasonLabel: _season.text.trim().isEmpty
          ? FffSeasonConfig.defaults.seasonLabel
          : _season.text.trim(),
      competitionDisplayName: _comp.text.trim().isEmpty
          ? FffSeasonConfig.defaults.competitionDisplayName
          : _comp.text.trim(),
      matchDocIdPrefix: _prefix.text.trim().isEmpty
          ? FffSeasonConfig.defaults.matchDocIdPrefix
          : _prefix.text.trim(),
      fffSyncEnabled: _fffSyncEnabled,
      fffR2CompetitionId: p(_r2Cp.text, 0),
      fffR2PhaseId: p(_r2Ph.text, FffSeasonConfig.defaults.fffR2PhaseId),
      fffR2PouleId: p(_r2Gp.text, FffSeasonConfig.defaults.fffR2PouleId),
      r2CompetitionDisplayName: _r2Comp.text.trim().isEmpty
          ? FffSeasonConfig.defaults.r2CompetitionDisplayName
          : _r2Comp.text.trim(),
    );
  }

  @override
  void dispose() {
    _cp.dispose();
    _ph.dispose();
    _gp.dispose();
    _club.dispose();
    _season.dispose();
    _comp.dispose();
    _prefix.dispose();
    _r2Cp.dispose();
    _r2Ph.dispose();
    _r2Gp.dispose();
    _r2Comp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SeasonConfigService.save(_readForm());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configuration FFF enregistrée',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: adminGreenAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testApi() async {
    setState(() => _lastTestMessage = null);
    try {
      final fn = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('testFffSeasonConfig');
      final res = await fn.call();
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      final ok = data['ok'] == true;
      final serverMsg = data['message']?.toString();
      final msg = (serverMsg != null && serverMsg.isNotEmpty)
          ? serverMsg
          : (ok
              ? 'API OK — ${data['teamCount']} équipe(s) (saison ${data['seasonLabel']})'
              : 'Échec HTTP ${data['status'] ?? data['matchesStatus'] ?? '?'} — ${data['url'] ?? ''}');
      if (mounted) {
        setState(() => _lastTestMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: ok ? adminGreenAccent : adminRed,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      final detail = e.message?.trim().isNotEmpty == true
          ? e.message!
          : e.code;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test API : $detail', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test API : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  Future<void> _syncNow() async {
    try {
      final fn = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('syncFffDataManual');
      // force:true ignore betweenSeasons / fffSyncEnabled (admin explicite).
      final res = await fn.call(<String, dynamic>{'force': true});
      final data = Map<String, dynamic>.from(res.data as Map? ?? {});
      final j = data['journee'];
      final teams = data['rankingTeams'];
      final warning = data['warning']?.toString();
      final msg = warning != null && warning.isNotEmpty
          ? warning
          : (j != null
              ? 'Sync OK — J$j · $teams équipe(s) au classement'
              : 'Synchro FFF terminée (scores + classement)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter()),
            backgroundColor: adminGreenAccent,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      final detail = e.message?.trim().isNotEmpty == true
          ? e.message!
          : e.code;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync : $detail', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: adminOrange),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          'Les Cloud Functions lisent app_config/fff_season. Si le document '
          'est absent, les valeurs par défaut (R1 2025-2026) s’appliquent. '
          'Quand la saison est terminée : désactive la sync ci-dessous ou active '
          '« Fin de saison » dans Cycle saison — plus aucun appel API FFF automatique.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Synchronisation FFF active',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              _fffSyncEnabled
                  ? 'Cron 12 h + sync manuelle autorisées (sauf fin de saison).'
                  : 'Stop : aucun appel API FFF (cron ignoré).',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            value: _fffSyncEnabled,
            activeThumbColor: adminGreenAccent,
            onChanged: (v) => setState(() => _fffSyncEnabled = v),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          ctrl: _cp,
          label: 'ID compétition FFF (fffCompetitionId)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _ph,
          label: 'Phase (fffPhaseId)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _gp,
          label: 'Poule (fffPouleId)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _club,
          label: 'N° club Sedan / CSSA (fffClubNo)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(ctrl: _season, label: 'Libellé saison (ex. 2026-2027)'),
        const SizedBox(height: 10),
        AdminField(ctrl: _comp, label: 'Nom compétition affiché'),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _prefix,
          label: 'Préfixe ID document match (ex. fff_)',
        ),
        const SizedBox(height: 20),
        Text(
          'Classement R2 (équipe réserve)',
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Uniquement le calendrier public (À venir / Résultats, sélecteur R1 | R2) '
          'et l’onglet Classement. Pas d’accueil, pas de « prochain match », '
          'pas la liste admin 1ère. '
          'Coller l’id FFF depuis l’URL epreuves : '
          '/competition/engagement/{id}-regional-2/phase/1/{poule}. '
          'Poule A = 1. Saison 2025-2026 Grand Est : 436258 (périmé). '
          '2026-2027 confirmé : 449972 (ne pas réutiliser 436257 de la 1ère). '
          'Coller 449972 puis sync FFF — l’app n’écrit pas Firestore toute seule.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        AdminField(
          ctrl: _r2Cp,
          label: 'ID compétition FFF R2 (fffR2CompetitionId, vide = off)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _r2Ph,
          label: 'Phase R2 (fffR2PhaseId)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _r2Gp,
          label: 'Poule R2 (fffR2PouleId, A = 1)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        AdminField(
          ctrl: _r2Comp,
          label: 'Nom affiché R2 (ex. Régional 2)',
        ),
        if (_lastTestMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _lastTestMessage!,
            style: GoogleFonts.inter(fontSize: 11, color: adminGold),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: adminOrange,
                foregroundColor: Colors.black,
              ),
              child: Text(
                _saving ? '…' : 'ENREGISTRER',
                style: GoogleFonts.barlowCondensed(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _testApi,
              style: OutlinedButton.styleFrom(
                foregroundColor: adminGold,
                side: const BorderSide(color: adminGold),
              ),
              child: Text(
                'TESTER API FFF',
                style: GoogleFonts.barlowCondensed(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _syncNow,
              style: OutlinedButton.styleFrom(
                foregroundColor: adminTextPrimary,
                side: const BorderSide(color: adminBorder),
              ),
              child: Text(
                'SYNCHRO MAINTENANT',
                style: GoogleFonts.barlowCondensed(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _applyToControllers(FffSeasonConfig.defaults);
                setState(() {});
              },
              child: Text(
                'Réinitialiser défauts',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: adminGrey,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'La sync réécrit `ranking` (R1) depuis le classement FFF. '
          'Si fffR2CompetitionId est renseigné, elle écrit `ranking_r2` '
          'et le calendrier `matches_r2` (jamais `matches`). Cycle saison → '
          '« Classement → 0 pts » ne touche que la 1ère.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
      ],
    );
  }
}
