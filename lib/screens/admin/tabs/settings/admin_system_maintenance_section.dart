import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../../../../services/app_settings_service.dart';

export 'admin_system_maintenance_extras.dart';

/// Pause notifications push — barre d'alerte sobre (pas carte marketing).
class AdminMaintenanceCard extends StatefulWidget {
  const AdminMaintenanceCard({super.key});

  @override
  State<AdminMaintenanceCard> createState() => _AdminMaintenanceCardState();
}

class _AdminMaintenanceCardState extends State<AdminMaintenanceCard> {
  bool _saving = false;
  bool _savingBypass = false;
  bool _expanded = false;

  Future<void> _setBypassToCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecte-toi pour définir ton compte exempté.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _savingBypass = true);
    try {
      await AppSettingsService.setMaintenanceBypassUid(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ton compte est exempté des push en maintenance.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
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
      if (mounted) setState(() => _savingBypass = false);
    }
  }

  Future<void> _toggle(bool paused) async {
    if (_saving) return;
    if (paused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Activer le mode maintenance ?',
            style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
          ),
          content: Text(
            'Aucune notification push ne partira (live, actus, stats, rappels match…), '
            'sauf sur le compte « téléphone de test » défini ci-dessous.',
            style: GoogleFonts.inter(color: adminGrey, fontSize: 12, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ACTIVER', style: GoogleFonts.inter(color: adminOrange)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      await AppSettingsService.setNotificationsPaused(paused);
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: AppSettingsService.adminMaintenanceStream(),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final paused = data['notificationsPaused'] == true;
        final bypassUid =
            (data['maintenanceBypassUid'] ?? '').toString().trim();
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final bypassIsMe = bypassUid.isNotEmpty && bypassUid == myUid;
        final accent = paused ? adminOrange : adminGrey;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: paused ? adminOrange.withAlpha(14) : adminSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: paused ? adminOrange.withAlpha(90) : adminBorder,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              paused
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.notifications_paused_outlined,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                paused
                                    ? 'Notifications en pause'
                                    : 'Pause notifications push',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: adminTextPrimary,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: paused,
                              onChanged: _saving ? null : _toggle,
                              activeTrackColor: adminOrange.withAlpha(140),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                        Text(
                          paused
                              ? 'Push coupées (sauf compte exempté).'
                              : 'Coupe les push pendant tes tests.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminGrey,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Compte exempté',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AdminModuleColors.pilotage,
                                ),
                              ),
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: adminGrey,
                              ),
                            ],
                          ),
                        ),
                        if (_expanded || paused) ...[
                          const SizedBox(height: 4),
                          Text(
                            bypassUid.isEmpty
                                ? 'Aucun compte exempté.'
                                : bypassIsMe
                                    ? 'Ton compte est exempté.'
                                    : 'Exempté : ${bypassUid.length > 12 ? '${bypassUid.substring(0, 8)}…' : bypassUid}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed: _savingBypass
                                    ? null
                                    : _setBypassToCurrentUser,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Utiliser mon compte',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (bypassUid.isNotEmpty)
                                TextButton(
                                  onPressed: _savingBypass
                                      ? null
                                      : () => AppSettingsService
                                          .setMaintenanceBypassUid(null),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Retirer',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: adminGrey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
