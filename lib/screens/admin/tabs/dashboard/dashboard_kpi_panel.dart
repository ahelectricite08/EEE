import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../../dashboard_matches_finished_by_season.dart';

/// Indicateurs Pilotage en lignes densifiées — pas de big-number cards.
class DashboardKpiPanel extends StatelessWidget {
  final Future<String> usersCount;
  final Future<String> articlesPublished;
  final Future<String> articlesDraft;
  final Future<String> notifsToday;
  final Future<String> notifsPending;
  final Future<String> reportsPending;

  const DashboardKpiPanel({
    super.key,
    required this.usersCount,
    required this.articlesPublished,
    required this.articlesDraft,
    required this.notifsToday,
    required this.notifsPending,
    required this.reportsPending,
  });

  static const _accent = AdminModuleColors.pilotage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KpiFutureRow(
          label: 'Utilisateurs',
          icon: Icons.people_outline_rounded,
          future: usersCount,
        ),
        const _KpiDivider(),
        _KpiFutureRow(
          label: 'Articles publiés',
          icon: Icons.article_outlined,
          future: articlesPublished,
          trailingFuture: articlesDraft,
          trailingLabel: 'brouillons',
        ),
        const _KpiDivider(),
        _KpiFutureRow(
          label: 'Notifs aujourd\'hui',
          icon: Icons.notifications_none_rounded,
          future: notifsToday,
          trailingFuture: notifsPending,
          trailingLabel: 'en file',
        ),
        const _KpiDivider(),
        const DashboardMatchesFinishedBySeason(dense: true),
        const _KpiDivider(),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('live').snapshots(),
          builder: (_, snap) {
            final active = (snap.data?.docs.isNotEmpty ?? false);
            return _KpiStaticRow(
              label: 'Hub live',
              icon: Icons.podcasts_rounded,
              value: active ? 'Actif' : 'Inactif',
              valueColor: active ? adminRed : adminGrey,
            );
          },
        ),
        const _KpiDivider(),
        _KpiFutureRow(
          label: 'Signalements',
          icon: Icons.flag_outlined,
          future: reportsPending,
          warnIfNonZero: true,
        ),
      ],
    );
  }
}

class _KpiDivider extends StatelessWidget {
  const _KpiDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: adminBorder.withAlpha(160));
}

class _KpiFutureRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<String> future;
  final Future<String>? trailingFuture;
  final String? trailingLabel;
  final bool warnIfNonZero;

  const _KpiFutureRow({
    required this.label,
    required this.icon,
    required this.future,
    this.trailingFuture,
    this.trailingLabel,
    this.warnIfNonZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: future,
      builder: (_, snap) {
        final raw = snap.data;
        final loading = snap.connectionState == ConnectionState.waiting &&
            raw == null;
        final err = snap.hasError;
        Color? vc;
        if (warnIfNonZero && raw != null && raw != '0' && raw != '–') {
          vc = adminOrange;
        }
        return _KpiRowShell(
          icon: icon,
          label: label,
          valueChild: err
              ? Icon(Icons.warning_amber_rounded, size: 16, color: adminRed)
              : loading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DashboardKpiPanel._accent,
                      ),
                    )
                  : Text(
                      raw ?? '–',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: vc ?? adminTextPrimary,
                        height: 1,
                      ),
                    ),
          trailing: trailingFuture == null
              ? null
              : FutureBuilder<String>(
                  future: trailingFuture,
                  builder: (_, t) => Text(
                    '${t.data ?? '–'} ${trailingLabel ?? ''}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: adminGrey,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _KpiStaticRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Color? valueColor;

  const _KpiStaticRow({
    required this.label,
    required this.icon,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return _KpiRowShell(
      icon: icon,
      label: label,
      valueChild: Text(
        value,
        style: GoogleFonts.barlowCondensed(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: valueColor ?? adminTextPrimary,
          height: 1,
        ),
      ),
    );
  }
}

class _KpiRowShell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget valueChild;
  final Widget? trailing;

  const _KpiRowShell({
    required this.icon,
    required this.label,
    required this.valueChild,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: DashboardKpiPanel._accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: adminTextPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 12),
          ],
          valueChild,
        ],
      ),
    );
  }
}
