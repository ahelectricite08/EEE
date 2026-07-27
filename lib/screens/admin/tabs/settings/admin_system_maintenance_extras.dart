import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import 'admin_system_maintenance_section.dart';

/// Recalcul stats ligues privées (Cloud Function admin).
class AdminRecomputeLeaguesButton extends StatefulWidget {
  const AdminRecomputeLeaguesButton({super.key});

  @override
  State<AdminRecomputeLeaguesButton> createState() =>
      _AdminRecomputeLeaguesButtonState();
}

class _AdminRecomputeLeaguesButtonState
    extends State<AdminRecomputeLeaguesButton> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final fn = FirebaseFunctions.instance
          .httpsCallable('adminRecomputeLeaguePowerRankings');
      final res = await fn.call();
      final map = Map<String, dynamic>.from(res.data as Map? ?? {});
      final n = map['leaguesProcessed'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n != null
                ? 'Stats ligues recalculées ($n ligue(s))'
                : 'Stats ligues recalculées',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recalcul ligues : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _run,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calculate_outlined, size: 18),
        label: Text(
          'Recalcul stats classement des ligues',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Section Système : maintenance + recalcul ligues.
class AdminSystemMaintenanceSection extends StatelessWidget {
  const AdminSystemMaintenanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminMaintenanceCard(),
        SizedBox(height: 12),
        AdminRecomputeLeaguesButton(),
      ],
    );
  }
}
