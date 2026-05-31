import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/match_stats_sheet_service.dart';
import '../../admin_controller.dart';
import '../../admin_palette.dart';
import '../../../../services/role_permissions_service.dart';

/// Contrôle réservé à l’onglet Direct : bandeau stats chiffrées pendant le live.
class LiveStatsDisplayControl extends StatefulWidget {
  final String matchId;
  final bool compact;

  const LiveStatsDisplayControl({
    super.key,
    required this.matchId,
    this.compact = false,
  });

  @override
  State<LiveStatsDisplayControl> createState() => _LiveStatsDisplayControlState();
}

class _LiveStatsDisplayControlState extends State<LiveStatsDisplayControl> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final admin = AdminControllerProvider.maybeOf(context);
    final canControl = admin == null ||
        admin.can(RolePermissionsService.adminDirect);
    final liveRef =
        FirebaseFirestore.instance.collection('live').doc('current');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: liveRef.snapshots(),
      builder: (context, snap) {
        final live = snap.data?.data() ?? {};
        final mid = (live['matchId'] ?? '').toString().trim();
        if (mid != widget.matchId.trim()) {
          return const SizedBox.shrink();
        }
        final enabled = live['statsEnabled'] == true;

        return Container(
          padding: EdgeInsets.all(widget.compact ? 12 : 14),
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
                  Icon(
                    Icons.live_tv_rounded,
                    size: 16,
                    color: enabled ? const Color(0xFF4A90D9) : adminGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stats chiffrées sur le live',
                      style: GoogleFonts.inter(
                        fontSize: widget.compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                    ),
                  ),
                  if (!canControl)
                    Text(
                      'LECTURE SEULE',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                canControl
                    ? 'Pilotage direct uniquement. La saisie des chiffres se fait dans Statistiques match.'
                    : 'Réservé au rôle Direct. Demandez à la personne au direct d’activer le bandeau.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  enabled ? 'Bandeau visible dans l’app' : 'Bandeau masqué',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                value: enabled,
                onChanged: (!canControl || _busy)
                    ? null
                    : (v) async {
                        setState(() => _busy = true);
                        try {
                          await MatchStatsSheetService.instance
                              .setLiveStatsDisplay(
                            widget.matchId,
                            enabled: v,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Erreur : $e',
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: adminRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                activeThumbColor: adminGold,
              ),
              if (_busy)
                const LinearProgressIndicator(minHeight: 2, color: adminGold),
            ],
          ),
        );
      },
    );
  }
}
