import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import '../../widgets/admin_system_health_panel.dart';
import '../../widgets/dashboard_match_day_card.dart';
import '../settings/admin_system_maintenance_section.dart';
import 'dashboard_activity_lists.dart';
import 'dashboard_hourly_presence_panel.dart';
import 'dashboard_kpi_panel.dart';

/// Pilotage ? r�gie dense (sant�, match-day, KPIs lignes, activit�).
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final Future<String> _usersCountFuture = FirebaseFirestore.instance
      .collection('users')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _articlesPublishedFuture = FirebaseFirestore
      .instance
      .collection('articles')
      .where('status', isEqualTo: 'published')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _notifsTodayFuture = () async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final snap = await FirebaseFirestore.instance
        .collection('notifications_queue')
        .where('status', isEqualTo: 'sent')
        .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .count()
        .get();
    return '${snap.count}';
  }();

  late final Future<String> _reportsPendingFuture = FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'pending')
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _notifsPendingFuture = FirebaseFirestore.instance
      .collection('notifications_queue')
      .where('status', whereIn: ['pending', 'processing'])
      .count()
      .get()
      .then((s) => '${s.count}');

  late final Future<String> _articlesDraftFuture = FirebaseFirestore.instance
      .collection('articles')
      .where('status', isEqualTo: 'draft')
      .count()
      .get()
      .then((s) => '${s.count}');

  static const _accent = AdminModuleColors.pilotage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('live')
              .doc('current')
              .snapshots(),
          builder: (_, snap) {
            final isLive = snap.data?.exists ?? false;
            return AdminPageHeader(
              title: 'Pilotage',
              subtitle: isLive
                  ? 'R�gie ? un direct est en cours.'
                  : 'R�gie ? activit�, sant� syst�me, jour de match.',
              icon: Icons.home_work_rounded,
              accent: _accent,
              trailing: _LiveDot(isLive: isLive),
            );
          },
        ),
        const SizedBox(height: 10),
        const DashboardMatchDayCard(),
        const SizedBox(height: 10),
        const AdminSystemHealthPanel(),
        const SizedBox(height: 10),
        const AdminMaintenanceCard(),
        const SizedBox(height: 18),
        AdminSection(
          eyebrow: 'R�gie',
          title: 'Indicateurs',
          subtitle: 'Compteurs op�rationnels',
          accent: _accent,
          child: DashboardKpiPanel(
            usersCount: _usersCountFuture,
            articlesPublished: _articlesPublishedFuture,
            articlesDraft: _articlesDraftFuture,
            notifsToday: _notifsTodayFuture,
            notifsPending: _notifsPendingFuture,
            reportsPending: _reportsPendingFuture,
          ),
        ),
        const SizedBox(height: 18),
        AdminSection(
          eyebrow: 'Audience',
          title: 'Présence app / heure',
          subtitle: 'Personnes différentes ayant ouvert l’app (24 h)',
          accent: _accent,
          child: DashboardHourlyPresencePanel(accent: _accent),
        ),
        const SizedBox(height: 18),
        AdminSection(
          eyebrow: 'Flux',
          title: 'Derniers inscrits',
          accent: _accent,
          child: const DashboardRecentUsersList(),
        ),
        const SizedBox(height: 18),
        AdminSection(
          eyebrow: 'Flux',
          title: 'Derni�res notifications',
          accent: _accent,
          child: const DashboardRecentNotifsList(),
        ),
      ],
    );
  }
}

/// Point live discret ? pas de pill � Hors antenne � marketing.
class _LiveDot extends StatelessWidget {
  final bool isLive;
  const _LiveDot({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: isLive ? adminRed : adminGrey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isLive ? 'Live' : 'Off',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isLive ? adminRed : adminGrey,
          ),
        ),
      ],
    );
  }
}
