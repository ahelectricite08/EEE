import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';

/// Archive les classements prono championnat (onglet Pronos admin).
class PronoSeasonResetCard extends StatefulWidget {
  const PronoSeasonResetCard({super.key});

  @override
  State<PronoSeasonResetCard> createState() => _PronoSeasonResetCardState();
}

class _PronoSeasonResetCardState extends State<PronoSeasonResetCard> {
  late final TextEditingController _seasonCtrl;
  bool _loading = false;
  int? _previewLeaderboardCount;
  int? _previewLeaguesCount;

  @override
  void initState() {
    super.initState();
    _seasonCtrl = TextEditingController(text: _seasonLabel());
    _loadPreviewCounts();
  }

  Future<void> _loadPreviewCounts() async {
    try {
      final lb = await FirebaseFirestore.instance
          .collection('prono_leaderboard')
          .count()
          .get();
      final lg = await FirebaseFirestore.instance
          .collection('private_leagues')
          .count()
          .get();
      if (!mounted) return;
      setState(() {
        _previewLeaderboardCount = lb.count;
        _previewLeaguesCount = lg.count;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewLeaderboardCount = null;
        _previewLeaguesCount = null;
      });
    }
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

  Future<void> _runReset() async {
    final season = _seasonCtrl.text.trim();
    if (season.isEmpty) return;

    final ok = await adminConfirm(
      context,
      'Archiver et vider les classements pour la saison « $season » ?\n\n'
      'Seront réinitialisés : le classement général (prono_leaderboard) et les '
      'totaux de classement des ligues (rankingStats).\n\n'
      'Seront conservés : XP utilisateurs, pronos, duels, ligues et membres.',
    );
    if (!ok || !mounted) return;

    setState(() => _loading = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('resetPronoSeason');
      final result = await callable.call({'season': season});
      final data = Map<String, dynamic>.from(result.data as Map);
      final counts =
          Map<String, dynamic>.from((data['counts'] as Map?) ?? const {});
      final archiveId = (data['archiveId'] as String?) ?? '';
      if (!mounted) return;
      final lb = counts['pronoLeaderboard'] ?? 0;
      final leagues = counts['privateLeaguesUpdated'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Classements réinitialisés : $lb entrée(s) classement, $leagues ligue(s). '
            'Archive : $archiveId',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
        ),
      );
      await _loadPreviewCounts();
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            adminGold.withAlpha(22),
            adminCard,
            adminBlue.withAlpha(12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminBorderLight),
        boxShadow: adminCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIN DE SAISON — CLASSEMENTS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Archive le classement général et remet les totaux des ligues à zéro. '
            'Pronos, duels, membres et XP inchangés.',
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _PreviewChip(
                icon: Icons.emoji_events_outlined,
                label: 'Classement',
                value: _previewLeaderboardCount == null
                    ? '…'
                    : '$_previewLeaderboardCount',
              ),
              _PreviewChip(
                icon: Icons.groups_outlined,
                label: 'Ligues',
                value: _previewLeaguesCount == null
                    ? '…'
                    : '$_previewLeaguesCount',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdminField(
                  ctrl: _seasonCtrl,
                  label: 'Libellé saison (traçabilité)',
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _runReset,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: adminGoldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: adminTextPrimary,
                            ),
                          )
                        : Text(
                            'ARCHIVER\nCLASSEMENTS',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              height: 1.05,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: adminGrey),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
