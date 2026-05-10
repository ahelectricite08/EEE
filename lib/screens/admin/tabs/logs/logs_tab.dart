import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/admin/application/admin_action_logger.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';

// ── LogsTab ────────────────────────────────────────────────────────────────────
class LogsTab extends StatefulWidget {
  const LogsTab();

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  /// `legacy` → collection [admin_logs] ; `audit` → [admin_audit_logs].
  String _source = 'legacy';
  String _filter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _types = [
    'all', 'match', 'article', 'user', 'settings', 'badge',
  ];

  static const _typeLabels = {
    'all': 'TOUS',
    'match': 'MATCHS',
    'article': 'ARTICLES',
    'user': 'USERS',
    'settings': 'PARAMÈTRES',
    'badge': 'BADGES',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionName =
        _source == 'audit' ? 'admin_audit_logs' : 'admin_logs';

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection(collectionName)
        .orderBy('timestamp', descending: true)
        .limit(100);

    if (_source == 'legacy' && _filter != 'all') {
      q = q.where('type', isEqualTo: _filter);
    }

    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3, height: 20,
                decoration: BoxDecoration(color: adminOrange, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(
                'JOURNAL ADMIN',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20, fontWeight: FontWeight.w900, color: adminTextPrimary, letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              FutureBuilder<AggregateQuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection(collectionName)
                    .count()
                    .get(),
                builder: (_, snap) {
                  final count = snap.data?.count ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminOrange.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: adminOrange.withAlpha(60)),
                    ),
                    child: Text(
                      '$count entrées',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: adminOrange),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'legacy',
                  label: Text('Historique'),
                  icon: Icon(Icons.list_alt_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'audit',
                  label: Text('Audit'),
                  icon: Icon(Icons.verified_rounded, size: 16),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (s) =>
                  setState(() => _source = s.first),
            ),
          ),
        ),

        // ── Search ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'Rechercher une action...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: adminGrey),
                suffixIcon: _search.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                        child: const Icon(Icons.close_rounded, size: 16, color: adminGrey),
                      )
                    : null,
              ),
            ),
          ),
        ),

        // ── Filtres (types — surtout historique) ───────────────────────────────
        if (_source == 'legacy')
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final t = _types[i];
                return AdminFilterBtn(
                  label: _typeLabels[t]!,
                  selected: _filter == t,
                  onTap: () => setState(() => _filter = t),
                );
              },
            ),
          ),
        if (_source == 'legacy') const SizedBox(height: 10),

        // ── Logs list ───────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: adminGold));
              }

              var docs = snap.data!.docs;

              // Client-side search filter
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final action = (data['action'] ?? '').toString().toLowerCase();
                  final adminName = (data['adminName'] ?? data['email'] ?? '')
                      .toString()
                      .toLowerCase();
                  final target = (data['target'] ??
                          data['resourceId'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  final resType =
                      (data['resourceType'] ?? '').toString().toLowerCase();
                  if (_source == 'audit' &&
                      _filter != 'all' &&
                      resType != _filter) {
                    return false;
                  }
                  return action.contains(_search) ||
                      adminName.contains(_search) ||
                      target.contains(_search) ||
                      resType.contains(_search);
                }).toList();
              } else if (_source == 'audit' && _filter != 'all') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final resType =
                      (data['resourceType'] ?? '').toString().toLowerCase();
                  return resType == _filter;
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: adminCard, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: adminBorder),
                        ),
                        child: const Icon(Icons.history_rounded, color: adminGrey, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text('Aucun log', style: GoogleFonts.inter(color: adminGrey, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'Les actions admin apparaîtront ici',
                        style: GoogleFonts.inter(color: adminGrey, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _source == 'audit'
                    ? _AuditLogRow(doc: docs[i])
                    : _LogRow(doc: docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── LogRow ─────────────────────────────────────────────────────────────────────
class _LogRow extends StatelessWidget {
  final DocumentSnapshot doc;
  const _LogRow({required this.doc});

  static const _typeColors = {
    'match': adminRed,
    'article': adminGold,
    'user': adminGreenAccent,
    'settings': adminOrange,
    'badge': adminPurple,
    'xp': adminBlue,
  };

  static const _typeIcons = {
    'match': Icons.emoji_events_rounded,
    'article': Icons.article_rounded,
    'user': Icons.person_rounded,
    'settings': Icons.settings_rounded,
    'badge': Icons.military_tech_rounded,
    'xp': Icons.trending_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final action = d['action'] ?? 'Action inconnue';
    final adminName = d['adminName'] ?? 'Admin';
    final type = d['type'] ?? 'other';
    final target = d['target'] ?? '';
    final ts = d['timestamp'];
    final color = _typeColors[type] ?? adminGrey;
    final icon = _typeIcons[type] ?? Icons.info_rounded;

    String timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = "À l'instant";
      } else if (diff.inMinutes < 60) {
        timeStr = 'Il y a ${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        timeStr = 'Il y a ${diff.inHours}h';
      } else {
        timeStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: adminTextPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      adminName,
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    if (target.isNotEmpty) ...[
                      Text(' · ', style: GoogleFonts.inter(fontSize: 10, color: adminGrey)),
                      Expanded(
                        child: Text(
                          target,
                          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(height: 4),
              Text(timeStr, style: GoogleFonts.inter(fontSize: 9, color: adminGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Audit row (admin_audit_logs) ──────────────────────────────────────────────
class _AuditLogRow extends StatelessWidget {
  final DocumentSnapshot doc;
  const _AuditLogRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final action = d['action'] ?? '—';
    final email = (d['email'] ?? d['uid'] ?? '').toString();
    final resType = (d['resourceType'] ?? 'audit').toString();
    final resId = (d['resourceId'] ?? '').toString();
    final ts = d['timestamp'];
    final color = adminBlue;

    String timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      timeStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$action',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                ),
                if (resId.isNotEmpty)
                  Text(
                    '$resType · $resId',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
              ],
            ),
          ),
          Text(timeStr, style: GoogleFonts.inter(fontSize: 9, color: adminGrey)),
        ],
      ),
    );
  }
}

// ── Helper to write admin logs from anywhere ────────────────────────────────────
Future<void> writeAdminLog({
  required String action,
  required String type,
  String? adminName,
  String? adminUid,
  String? target,
  Map<String, dynamic>? extra,
}) async {
  try {
    await FirebaseFirestore.instance.collection('admin_logs').add({
      'action': action,
      'type': type,
      'adminName': adminName ?? 'Admin',
      'adminUid': adminUid,
      'target': target ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await AdminActionLogger.log(
        action: action,
        resourceType: type,
        resourceId: (target ?? '').isNotEmpty ? target : null,
        metadata: {
          if (adminName != null) 'adminName': adminName,
          if (extra != null) 'extra': extra,
        },
      );
    }
  } catch (_) {
    // Silently fail — logs are best-effort
  }
}
