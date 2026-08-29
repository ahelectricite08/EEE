import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/first_scorer_bet.dart';
import '../../../../services/first_scorer_bet_service.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Admin — visibilité du pari « 1er buteur du match ».
class FirstScorerBetAdminSection extends StatefulWidget {
  const FirstScorerBetAdminSection({super.key});

  @override
  State<FirstScorerBetAdminSection> createState() =>
      _FirstScorerBetAdminSectionState();
}

class _FirstScorerBetAdminSectionState extends State<FirstScorerBetAdminSection> {
  StreamSubscription<FirstScorerBetConfig>? _sub;
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = FirstScorerBetService.instance.watchConfig().listen((cfg) {
      if (!mounted) return;
      setState(() {
        _enabled = cfg.enabled;
        _loading = false;
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _setEnabled(bool v) async {
    setState(() {
      _enabled = v;
      _saving = true;
      _error = null;
    });
    try {
      await FirstScorerBetService.instance.setEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enabled = !v;
        _error = 'Impossible d’enregistrer : $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Pari 1er buteur',
      icon: Icons.sports_soccer_rounded,
      color: adminGold,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encart sur la feuille de prono des matchs Sedan / CSSA '
                    '(domicile ou extérieur). Effectif CSSA déjà saisi. '
                    'OFF = rien dans l’app. '
                    'app_config/${FirstScorerBetConfig.firestoreDocId}.enabled',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Pari 1er buteur du match',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Visible sur Pronos · fiche prono du match'
                          : 'Masqué — rien dans l’app',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    value: _enabled,
                    activeThumbColor: adminGold,
                    onChanged: _saving ? null : _setEnabled,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 11, color: adminRed),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
