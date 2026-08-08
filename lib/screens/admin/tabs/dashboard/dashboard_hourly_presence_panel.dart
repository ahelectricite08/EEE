import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_hourly_presence_service.dart';
import '../../admin_palette.dart';

/// Visiteurs uniques heure par heure (admin only).
class DashboardHourlyPresencePanel extends StatefulWidget {
  final Color accent;
  const DashboardHourlyPresencePanel({super.key, required this.accent});

  @override
  State<DashboardHourlyPresencePanel> createState() =>
      _DashboardHourlyPresencePanelState();
}

class _DashboardHourlyPresencePanelState
    extends State<DashboardHourlyPresencePanel> {
  late Future<List<AppHourlyPresenceBucket>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppHourlyPresenceService.instance.loadRecent(hours: 24);
  }

  void _reload() {
    setState(() {
      _future = AppHourlyPresenceService.instance.loadRecent(hours: 24);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppHourlyPresenceBucket>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.accent,
                ),
              ),
            ),
          );
        }
        final rows = snap.data ?? const <AppHourlyPresenceBucket>[];
        final max = rows.fold<int>(
          1,
          (m, r) => r.uniqueVisitors > m ? r.uniqueVisitors : m,
        );
        final todayTotal = rows
            .where((r) =>
                r.hourKey.startsWith(AppHourlyPresenceService.todayPrefix()))
            .fold<int>(0, (a, r) => a + r.uniqueVisitors);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aujourd’hui (somme des heures) : $todayTotal passages uniques/heure',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _reload,
                  icon: Icon(Icons.refresh_rounded,
                      size: 18, color: widget.accent),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chaque ligne = personnes différentes ayant ouvert l’app pendant cette heure.',
              style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
            ),
            const SizedBox(height: 12),
            ...rows.take(24).map((r) {
              final ratio = r.uniqueVisitors / max;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        r.label.split(' · ').last,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: adminBorder,
                          color: widget.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${r.uniqueVisitors}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: widget.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

}
