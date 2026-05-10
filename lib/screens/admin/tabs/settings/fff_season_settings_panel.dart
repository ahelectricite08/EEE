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

  bool _loading = true;
  bool _saving = false;
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
      final msg = ok
          ? 'API OK — ${data['teamCount']} équipe(s) (saison ${data['seasonLabel']})'
          : 'Échec HTTP ${data['status'] ?? '?'} — ${data['url'] ?? ''}';
      if (mounted) {
        setState(() => _lastTestMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: ok ? adminGreenAccent : adminRed,
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
      await fn.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synchro FFF lancée (scores + classement)',
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
          'est absent, les valeurs par défaut (R1 2025-2026) s’appliquent.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4),
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
      ],
    );
  }
}
