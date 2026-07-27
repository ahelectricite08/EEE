import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';

/// Derniers inscrits — lignes plates densifiées.
class DashboardRecentUsersList extends StatelessWidget {
  const DashboardRecentUsersList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminModuleColors.pilotage,
                ),
              ),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text(
            'Aucun inscrit récent',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: adminBorder.withAlpha(140)),
              _UserRow(doc: docs[i]),
            ],
          ],
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _UserRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final name = (d['displayName'] ?? d['name'] ?? '').toString();
    final email = (d['email'] ?? '').toString();
    final role = (d['role'] ?? 'supporter').toString();
    final initial = (name.isNotEmpty
            ? name[0]
            : email.isNotEmpty
                ? email[0]
                : '?')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AdminModuleColors.pilotage.withAlpha(28),
            child: Text(
              initial,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AdminModuleColors.pilotage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (name.isNotEmpty)
                  Text(
                    email,
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          AdminStatusChip(
            label: role.toUpperCase(),
            color: role == 'admin'
                ? adminRed
                : role == 'partenaire'
                    ? AdminModuleColors.pilotage
                    : adminGrey,
          ),
        ],
      ),
    );
  }
}

/// Dernières notifications — lignes plates densifiées.
class DashboardRecentNotifsList extends StatelessWidget {
  const DashboardRecentNotifsList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications_queue')
          .orderBy('sentAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        if (snap.data!.docs.isEmpty) {
          return Text(
            'Aucune notification envoyée',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          );
        }
        final docs = snap.data!.docs;
        return Column(
          children: [
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: adminBorder.withAlpha(140)),
              _NotifRow(doc: docs[i]),
            ],
          ],
        );
      },
    );
  }
}

class _NotifRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _NotifRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final status = (d['status'] ?? 'pending').toString();
    final statusColor = status == 'sent'
        ? adminGreenAccent
        : status == 'error'
            ? adminRed
            : adminOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (d['title'] ?? '').toString(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  (d['body'] ?? '').toString(),
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AdminStatusChip(label: status.toUpperCase(), color: statusColor),
        ],
      ),
    );
  }
}
