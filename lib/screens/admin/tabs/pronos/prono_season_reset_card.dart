import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';

/// Reset complet saison prono championnat (onglet Jeux → Championnat).
class PronoSeasonResetCard extends StatefulWidget {
  const PronoSeasonResetCard({super.key});

  @override
  State<PronoSeasonResetCard> createState() => _PronoSeasonResetCardState();
}

class _PronoSeasonResetCardState extends State<PronoSeasonResetCard> {
  late final TextEditingController _seasonCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _seasonCtrl = TextEditingController(text: _seasonLabel());
  }

  @override
  void dispose() {
    _seasonCtrl.dispose();
    super.dispose();
  }

  String _seasonLabel() {
    final now = DateTime.now();
    if (now.month >= 7) return '${now.year}-${now.year + 1}';
    return '${now.year - 1}-${now.year}';
  }

  Future<void> _runFullReset() async {
    final season = _seasonCtrl.text.trim();
    if (season.isEmpty) return;

    final ok = await adminConfirm(
      context,
      'Reset complet de la saison prono « $season » ?\n\n'
      'Seront supprimés : pronos, classement, duels, ligues privées, '
      'stats par match et profils prono utilisateurs.\n\n'
      'Seront conservés : réglages de visibilité, Esti\'DVCR, XP global '
      'hors profil prono.\n\n'
      'Action irréversible — à lancer avant la reprise des matchs.',
    );
    if (!ok || !mounted) return;

    setState(() => _loading = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('resetPronoSeason');
      final result = await callable.call({
        'season': season,
        'fullReset': true,
        'skipArchive': true,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final counts =
          Map<String, dynamic>.from((data['counts'] as Map?) ?? const {});
      if (!mounted) return;

      final parts = <String>[
        if (counts['predictions'] != null) '${counts['predictions']} prono(s)',
        if (counts['prono_leaderboard'] != null)
          '${counts['prono_leaderboard']} classement(s)',
        if (counts['prono_duels'] != null) '${counts['prono_duels']} duel(s)',
        if (counts['private_leagues'] != null)
          '${counts['private_leagues']} ligue(s)',
      ];
      final summary =
          parts.isEmpty ? 'Aucune donnée à effacer.' : parts.join(' · ');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Saison prête : $summary',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: adminRed,
          content: Text('Erreur reset saison : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminRed.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOUVELLE SAISON',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: adminRed,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Remet le championnat prono à zéro avant la reprise des matchs. '
            'Les joueurs repartent sans historique ni classement.',
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 12),
          AdminField(
            ctrl: _seasonCtrl,
            label: 'Libellé saison (ex. 2025-2026)',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _runFullReset,
              style: FilledButton.styleFrom(
                backgroundColor: adminRed,
                foregroundColor: adminOnAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: adminOnAccent,
                      ),
                    )
                  : Text(
                      'RESET COMPLET SAISON PRONO',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
