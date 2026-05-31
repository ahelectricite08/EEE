import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_stats_schema.dart';
import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_controller.dart';
import '../../admin_palette.dart';
import '../../../../services/role_permissions_service.dart';

/// Publication fiche / carte — onglet Statistiques match (pas le bandeau live).
class StatsPublicationControls extends StatefulWidget {
  final String matchId;
  final bool compact;

  const StatsPublicationControls({
    super.key,
    required this.matchId,
    this.compact = false,
  });

  @override
  State<StatsPublicationControls> createState() =>
      _StatsPublicationControlsState();
}

class _StatsPublicationControlsState extends State<StatsPublicationControls> {
  bool _busy = false;

  Future<void> _apply(MatchStatsPublicationSettings next) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MatchStatsSheetService.instance.updatePublicationSettings(
        widget.matchId,
        next,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Publication fiche mise à jour',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: adminGold.withAlpha(230),
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          title,
          style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
        ),
        content: Text(
          body,
          style: GoogleFonts.inter(color: adminGrey, fontSize: 12, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'CONFIRMER',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onToggle(
    MatchStatsPublicationSettings current, {
    bool? workbenchOpen,
    bool? cardDisplay,
    bool? official,
  }) async {
    final next = MatchStatsPublicationSettings(
      workbenchOpen: workbenchOpen ?? current.workbenchOpen,
      liveDisplay: current.liveDisplay,
      cardDisplay: cardDisplay ?? current.cardDisplay,
      official: official ?? current.official,
    );

    if (official == true && !current.official) {
      final ok = await _confirm(
        'Publier officiellement ?',
        'Les stats deviennent la référence sur la fiche match. '
            'Le bandeau live reste géré depuis l’onglet Direct.',
      );
      if (!ok) return;
    }

    if (official == false && current.official) {
      final ok = await _confirm(
        'Rouvrir en brouillon ?',
        'La fiche repasse en mode modifiable pour les statisticiens.',
      );
      if (!ok) return;
    }

    await _apply(next);
  }

  String _statusLabel(MatchStatsPublicationSettings pub, bool liveOn) {
    if (pub.official) return 'Officiel';
    if (pub.cardDisplay) return 'Carte (preview)';
    if (!pub.workbenchOpen) return 'Verrouillé';
    return 'Brouillon';
  }

  Color _statusColor(MatchStatsPublicationSettings pub) {
    if (pub.official) return const Color(0xFF4CAF50);
    if (pub.cardDisplay) return const Color(0xFF4A90D9);
    if (!pub.workbenchOpen) return const Color(0xFF9E9E9E);
    return adminGold;
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminControllerProvider.maybeOf(context);
    final canPublish = admin == null ||
        admin.can(RolePermissionsService.adminStats);
    final sheetRef = MatchStatsSheetService.instance.docRef(widget.matchId);
    final liveRef =
        FirebaseFirestore.instance.collection('live').doc('current');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: sheetRef.snapshots(),
      builder: (context, sheetSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: liveRef.snapshots(),
          builder: (context, liveSnap) {
            final sheet = sheetSnap.data?.data() ?? {};
            final pub = MatchStatsPublicationSettings.fromSheet(sheet);
            final stats = MatchStatsSchema.normalizeMap(
              sheet['stats'] as Map<String, dynamic>?,
            );
            final hasNumericStats = !MatchStatsSchema.isEmpty(stats);
            final live = liveSnap.data?.data() ?? {};
            final liveOn = live['statsEnabled'] == true &&
                (live['matchId'] ?? '').toString().trim() ==
                    widget.matchId.trim();
            final statusColor = _statusColor(pub);
            final pad = widget.compact ? 12.0 : 14.0;

            Widget toggle({
              required String title,
              required String subtitle,
              required bool value,
              required ValueChanged<bool> onChanged,
              bool enabled = true,
            }) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: widget.compact,
                title: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: widget.compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: widget.compact ? 9 : 10,
                    color: adminGrey,
                    height: 1.3,
                  ),
                ),
                value: value,
                onChanged: (!canPublish || _busy || !enabled)
                    ? null
                    : onChanged,
                activeThumbColor: adminGold,
              );
            }

            return Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.publish_rounded, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Publication fiche & carte',
                          style: GoogleFonts.inter(
                            fontSize: widget.compact ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(28),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withAlpha(100)),
                        ),
                        child: Text(
                          _statusLabel(pub, liveOn).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: adminBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.live_tv_rounded,
                          size: 14,
                          color: liveOn
                              ? const Color(0xFF4A90D9)
                              : adminGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveOn
                                ? 'Bandeau live : ACTIF (onglet Direct)'
                                : 'Bandeau live : inactif — activable uniquement depuis Direct',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: liveOn
                                  ? const Color(0xFF4A90D9)
                                  : adminGrey,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!canPublish) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Vous n’avez pas le rôle Statistiques match. '
                      'Contactez un statisticien pour publier sur la carte.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminRed.withAlpha(220),
                        height: 1.35,
                      ),
                    ),
                  ] else if (!widget.compact) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Score et buteurs : live / éditeur match. '
                      'Ici : chiffres + affichage carte + clôture officielle.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminGrey,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  toggle(
                    title: 'Débloquer la fiche stats',
                    subtitle:
                        'Autorise la saisie rapide (brouillon statisticien).',
                    value: pub.workbenchOpen,
                    onChanged: (v) => _onToggle(pub, workbenchOpen: v),
                  ),
                  toggle(
                    title: 'Afficher sur la carte match',
                    subtitle: hasNumericStats
                        ? 'Preview calendrier / fiche (non officiel).'
                        : 'Saisissez des chiffres avant d’activer.',
                    value: pub.cardDisplay,
                    enabled: hasNumericStats || pub.cardDisplay,
                    onChanged: (v) => _onToggle(pub, cardDisplay: v),
                  ),
                  toggle(
                    title: 'Publication officielle',
                    subtitle: 'Clôture définitive sur la fiche match.',
                    value: pub.official,
                    enabled: hasNumericStats || pub.official,
                    onChanged: (v) => _onToggle(pub, official: v),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: adminGold,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
