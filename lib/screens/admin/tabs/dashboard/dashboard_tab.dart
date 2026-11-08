import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_controller.dart';
import '../../admin_interior_hub.dart';
import '../../admin_module_colors.dart';
import '../../admin_nav_model.dart';
import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';
import '../../admin_tab_registry.dart';
import '../../staff_postes.dart';
import '../../widgets/admin_system_health_panel.dart';
import '../../widgets/dashboard_match_day_card.dart';
import '../settings/admin_system_maintenance_section.dart';
import 'dashboard_activity_lists.dart';
import 'dashboard_hourly_presence_panel.dart';
import 'dashboard_kpi_panel.dart';

/// Pilotage — régie dense (santé, match-day, KPIs lignes, activité).
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
    return AdminInteriorHub(
      title: 'Vue d’ensemble',
      subtitle: 'Tes pages d’abord. Santé et activité à part.',
      icon: Icons.home_work_rounded,
      accent: _accent,
      trailing: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('live')
            .doc('current')
            .snapshots(),
        builder: (_, snap) =>
            _LiveDot(isLive: snap.data?.exists ?? false),
      ),
      indexHeader: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PosteHome(),
          SizedBox(height: 16),
          DashboardMatchDayCard(),
        ],
      ),
      items: [
        const AdminInteriorItem(
          title: 'Santé système',
          subtitle: 'Firebase, maintenance, alertes.',
          icon: Icons.monitor_heart_rounded,
          group: 'Régie',
          child: Column(
            children: [
              AdminSystemHealthPanel(),
              SizedBox(height: 10),
              AdminMaintenanceCard(),
            ],
          ),
        ),
        AdminInteriorItem(
          title: 'Indicateurs',
          subtitle: 'Compteurs opérationnels du jour.',
          icon: Icons.analytics_rounded,
          group: 'Régie',
          child: DashboardKpiPanel(
            usersCount: _usersCountFuture,
            articlesPublished: _articlesPublishedFuture,
            articlesDraft: _articlesDraftFuture,
            notifsToday: _notifsTodayFuture,
            notifsPending: _notifsPendingFuture,
            reportsPending: _reportsPendingFuture,
          ),
        ),
        const AdminInteriorItem(
          title: 'Présence app',
          subtitle: 'Personnes différentes sur 24 h.',
          icon: Icons.schedule_rounded,
          group: 'Audience',
          child: DashboardHourlyPresencePanel(accent: _accent),
        ),
        const AdminInteriorItem(
          title: 'Derniers inscrits',
          subtitle: 'Nouveaux comptes.',
          icon: Icons.person_add_alt_1_rounded,
          group: 'Flux',
          child: DashboardRecentUsersList(),
        ),
        const AdminInteriorItem(
          title: 'Dernières notifications',
          subtitle: 'File d’envoi récente.',
          icon: Icons.notifications_none_rounded,
          group: 'Flux',
          child: DashboardRecentNotifsList(),
        ),
      ],
    );
  }
}

/// Point live discret — pas de pill « Hors antenne » marketing.
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

class _PosteHome extends StatelessWidget {
  const _PosteHome();

  @override
  Widget build(BuildContext context) {
    final ctrl = AdminController.maybeOf(context);
    if (ctrl == null) return const SizedBox.shrink();
    final poste = StaffPostes.primaryOf(ctrl.userRoles);
    final allowed = ctrl.allowedIndices.toSet();
    final tools = AdminPageCatalog.sorted(
      adminTabDefs.where((t) => allowed.contains(t.index)).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (poste != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(adminPaperRadius),
              border: Border.all(color: adminHairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: poste.color.withAlpha(22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(poste.icon, color: poste.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TON POSTE · ${poste.label.toUpperCase()}',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: adminTextPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        poste.mission,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.35,
                          color: adminGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const AdminSectionTitle(label: 'TES PAGES'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(adminPaperRadius),
            border: Border.all(color: adminHairline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: adminHairline),
                _DirectoryRow(
                  tab: tools[i],
                  onTap: () => ctrl.navigateTo(tools[i].index),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  final AdminTabDef tab;
  final VoidCallback onTap;

  const _DirectoryRow({required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final who = AdminPageCatalog.postesForPermission(tab.permission)
        .where((p) => p.shortLabel != 'Admin')
        .map((p) => p.shortLabel)
        .join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(tab.icon, size: 18, color: tab.universe.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                  Text(
                    who.isEmpty
                        ? tab.universe.label
                        : '${tab.universe.label} · $who',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: adminGrey, size: 20),
          ],
        ),
      ),
    );
  }
}
