import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_form_widgets.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';

/// Statut d’envoi pour un bénévole (Team DVCR).
class BenevoleRecipientDelivery {
  const BenevoleRecipientDelivery({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.status,
    this.skipReason,
    this.iosSent = 0,
    this.iosFailed = 0,
    this.androidSent = 0,
    this.androidFailed = 0,
  });

  final String uid;
  final String displayName;
  final String email;
  /// received | failed | skipped
  final String status;
  final String? skipReason;
  final int iosSent;
  final int iosFailed;
  final int androidSent;
  final int androidFailed;

  bool get received => status == 'received';
  bool get failed => status == 'failed';

  static int _statInt(Map<String, dynamic>? map, String key) {
    if (map == null) return 0;
    final v = map[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static BenevoleRecipientDelivery fromMap(Map<String, dynamic> raw) {
    final ps = raw['platformStats'];
    Map<String, dynamic> ios = {};
    Map<String, dynamic> android = {};
    if (ps is Map) {
      ios = Map<String, dynamic>.from(ps['ios'] as Map? ?? {});
      android = Map<String, dynamic>.from(ps['android'] as Map? ?? {});
    }
    return BenevoleRecipientDelivery(
      uid: (raw['uid'] ?? '').toString(),
      displayName: (raw['displayName'] ?? '').toString(),
      email: (raw['email'] ?? '').toString(),
      status: (raw['status'] ?? 'skipped').toString(),
      skipReason: raw['skipReason']?.toString(),
      iosSent: _statInt(ios, 'sent'),
      iosFailed: _statInt(ios, 'failed'),
      androidSent: _statInt(android, 'sent'),
      androidFailed: _statInt(android, 'failed'),
    );
  }

  static List<BenevoleRecipientDelivery> parseList(Map<String, dynamic> data) {
    final raw = data['recipientDeliveries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => BenevoleRecipientDelivery.fromMap(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  static ({int iosSent, int iosFailed, int androidSent, int androidFailed})
      parsePlatformStats(Map<String, dynamic> data) {
    final raw = data['platformStats'];
    if (raw is Map) {
      final ios = Map<String, dynamic>.from(raw['ios'] as Map? ?? {});
      final android = Map<String, dynamic>.from(raw['android'] as Map? ?? {});
      return (
        iosSent: _statInt(ios, 'sent'),
        iosFailed: _statInt(ios, 'failed'),
        androidSent: _statInt(android, 'sent'),
        androidFailed: _statInt(android, 'failed'),
      );
    }
    return (iosSent: 0, iosFailed: 0, androidSent: 0, androidFailed: 0);
  }

  static String skipReasonLabel(String? reason) {
    switch (reason) {
      case 'no_token':
        return 'Aucun token FCM';
      case 'wrong_platform':
        return 'Plateforme non ciblée';
      case 'not_team_dvcr':
        return 'Pas Team DVCR';
      case 'user_not_found':
        return 'Compte introuvable';
      case 'delivery_failed':
        return 'Échec d’envoi';
      default:
        return reason ?? 'Non envoyé';
    }
  }

  String platformDetail(String targetPlatform) {
    final parts = <String>[];
    if (targetPlatform == 'all' || targetPlatform == 'ios') {
      if (iosSent > 0) parts.add('iOS ✓');
      if (iosFailed > 0) parts.add('iOS ✗');
      if (targetPlatform == 'ios' && iosSent == 0 && iosFailed == 0) {
        parts.add('iOS —');
      }
    }
    if (targetPlatform == 'all' || targetPlatform == 'android') {
      if (androidSent > 0) parts.add('Android ✓');
      if (androidFailed > 0) parts.add('Android ✗');
      if (targetPlatform == 'android' &&
          androidSent == 0 &&
          androidFailed == 0) {
        parts.add('Android —');
      }
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

class BenevolePlatformStatChip extends StatelessWidget {
  final String platform;
  final int sent;
  final int failed;

  const BenevolePlatformStatChip({
    super.key,
    required this.platform,
    required this.sent,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = platform == 'ios';
    final label = isIos ? 'iOS' : 'Android';
    final icon = isIos ? Icons.phone_iphone_rounded : Icons.android_rounded;
    final color = isIos ? adminPurple : adminGreenAccent;
    final hasSent = sent > 0;
    final hasFailed = failed > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(hasSent ? 22 : 12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(hasSent ? 120 : 60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSent ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 14,
            color: hasSent ? color : adminOrange,
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            hasFailed
                ? '$label : $sent envoyé${sent > 1 ? 's' : ''} · $failed échec${failed > 1 ? 's' : ''}'
                : '$label : $sent envoyé${sent > 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class BenevoleRecipientDeliveryList extends StatelessWidget {
  final List<BenevoleRecipientDelivery> recipients;
  final String targetPlatform;
  final bool compact;

  const BenevoleRecipientDeliveryList({
    super.key,
    required this.recipients,
    required this.targetPlatform,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return Text(
        'Aucun détail par bénévole (envoi antérieur à la mise à jour).',
        style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
      );
    }

    final received = recipients.where((r) => r.received).length;
    final failed = recipients.where((r) => r.failed).length;
    final skipped = recipients.length - received - failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AdminStatusChip(
              label: '$received reçu${received > 1 ? 's' : ''}',
              color: adminGreenAccent,
            ),
            if (failed > 0)
              AdminStatusChip(
                label: '$failed échec${failed > 1 ? 's' : ''}',
                color: adminRed,
              ),
            if (skipped > 0)
              AdminStatusChip(
                label: '$skipped ignoré${skipped > 1 ? 's' : ''}',
                color: adminOrange,
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        ...recipients.map((r) => _RecipientRow(
              recipient: r,
              targetPlatform: targetPlatform,
              compact: compact,
            )),
      ],
    );
  }
}

class _RecipientRow extends StatelessWidget {
  final BenevoleRecipientDelivery recipient;
  final String targetPlatform;
  final bool compact;

  const _RecipientRow({
    required this.recipient,
    required this.targetPlatform,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = recipient.received
        ? adminGreenAccent
        : recipient.failed
            ? adminRed
            : adminOrange;
    final statusIcon = recipient.received
        ? Icons.check_circle_rounded
        : recipient.failed
            ? Icons.cancel_rounded
            : Icons.remove_circle_outline_rounded;
    final statusLabel = recipient.received
        ? 'Reçu'
        : recipient.failed
            ? 'Échec'
            : 'Ignoré';

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipient.displayName.isNotEmpty
                      ? recipient.displayName
                      : recipient.uid,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: adminTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (recipient.email.isNotEmpty)
                  Text(
                    recipient.email,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: adminGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 3),
                Text(
                  recipient.received
                      ? recipient.platformDetail(targetPlatform)
                      : BenevoleRecipientDelivery.skipReasonLabel(
                          recipient.skipReason,
                        ),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: recipient.received ? adminGrey : adminOrange,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          AdminStatusChip(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}

class BenevoleLastSendResultPanel extends StatelessWidget {
  final String? queueDocId;

  const BenevoleLastSendResultPanel({super.key, required this.queueDocId});

  Future<void> _cancel(BuildContext context, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Annuler la notification ?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Si l’envoi a déjà commencé, certains bénévoles peuvent déjà l’avoir reçue.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Garder', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Annuler l’envoi',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final ref =
          FirebaseFirestore.instance.collection('notifications_queue').doc(docId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final status = (snap.data()?['status'] ?? 'pending').toString();
        if (status != 'pending' && status != 'processing') {
          throw StateError('Déjà terminé ($status)');
        }
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notification annulée',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’annuler : $e',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docId = queueDocId;
    if (docId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications_queue')
          .doc(docId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? 'pending').toString();
        final targetPlatform = (data['targetPlatform'] ?? 'all').toString();

        if (status == 'pending' || status == 'processing') {
          final inFlight = status == 'processing';
          return AdminModuleSection(
            eyebrow: 'Suivi',
            title: inFlight ? 'Envoi en cours…' : 'En file d’attente…',
            subtitle: inFlight
                ? 'Distribution aux bénévoles Team DVCR.'
                : 'En attente du worker — tu peux encore annuler.',
            accent: adminGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: adminGold,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La Cloud Function traite la notification…',
                        style: TextStyle(fontSize: 12, color: adminGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _cancel(context, docId),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      'Annuler',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(foregroundColor: adminRed),
                  ),
                ),
              ],
            ),
          );
        }

        final recipients = BenevoleRecipientDelivery.parseList(data);
        final stats = BenevoleRecipientDelivery.parsePlatformStats(data);
        final showIos = targetPlatform == 'all' || targetPlatform == 'ios';
        final showAndroid =
            targetPlatform == 'all' || targetPlatform == 'android';

        return AdminModuleSection(
          eyebrow: 'Résultat',
          title: status == 'sent'
              ? 'Notification envoyée'
              : status == 'skipped'
                  ? 'Envoi ignoré'
                  : status == 'cancelled'
                      ? 'Notification annulée'
                      : 'Échec d’envoi',
          subtitle: (data['title'] ?? '').toString(),
          accent: status == 'sent'
              ? adminGreenAccent
              : status == 'skipped'
                  ? adminOrange
                  : status == 'cancelled'
                      ? adminGrey
                      : adminRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status == 'sent' || data['platformStats'] != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showIos)
                      BenevolePlatformStatChip(
                        platform: 'ios',
                        sent: stats.iosSent,
                        failed: stats.iosFailed,
                      ),
                    if (showAndroid)
                      BenevolePlatformStatChip(
                        platform: 'android',
                        sent: stats.androidSent,
                        failed: stats.androidFailed,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else if (status == 'skipped') ...[
                Text(
                  (data['skipReason'] ?? '').toString() == 'maintenance'
                      ? 'Bloqué : mode maintenance actif.'
                      : 'Aucun appareil trouvé pour cette cible.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: adminOrange,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (status == 'cancelled') ...[
                Text(
                  (data['cancelNote'] ?? 'Envoi annulé.').toString(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: adminGrey,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ] else if ((data['error'] ?? '').toString().isNotEmpty) ...[
                Text(
                  (data['error'] ?? '').toString(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: adminRed,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'DÉTAIL PAR BÉNÉVOLE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              BenevoleRecipientDeliveryList(
                recipients: recipients,
                targetPlatform: targetPlatform,
              ),
            ],
          ),
        );
      },
    );
  }
}

class BenevoleHistoryEntry extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic> data;

  const BenevoleHistoryEntry({
    super.key,
    required this.data,
    this.docId,
  });

  @override
  State<BenevoleHistoryEntry> createState() => _BenevoleHistoryEntryState();
}

class _BenevoleHistoryEntryState extends State<BenevoleHistoryEntry> {
  bool _expanded = false;

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En file';
      case 'processing':
        return 'En cours';
      case 'sent':
        return 'Envoyé';
      case 'skipped':
        return 'Ignoré';
      case 'cancelled':
        return 'Annulé';
      case 'error':
        return 'Erreur';
      default:
        return status;
    }
  }

  Future<void> _cancel() async {
    final docId = widget.docId;
    if (docId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Annuler ?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Arrêter cet envoi s’il est encore en file ou en cours.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Annuler l’envoi',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final ref =
          FirebaseFirestore.instance.collection('notifications_queue').doc(docId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final st = (snap.data()?['status'] ?? '').toString();
        if (st != 'pending' && st != 'processing') {
          throw StateError('Déjà terminé');
        }
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Annulation impossible : $e'),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = (d['status'] ?? 'pending').toString();
    final statusColor = status == 'sent'
        ? adminGreenAccent
        : status == 'error'
            ? adminRed
            : status == 'skipped'
                ? adminOrange
                : status == 'cancelled'
                    ? adminGrey
                    : status == 'processing'
                        ? adminGold
                        : adminOrange;
    final ts = d['sentAt'] ?? d['skippedAt'] ?? d['cancelledAt'] ?? d['createdAt'];
    var timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      timeStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final platform = (d['targetPlatform'] ?? 'all').toString();
    final targetIds = d['targetUserIds'];
    final selectionCount = targetIds is List ? targetIds.length : 0;
    final recipients = BenevoleRecipientDelivery.parseList(d);
    final receivedCount = recipients.where((r) => r.received).length;
    final stats = BenevoleRecipientDelivery.parsePlatformStats(d);
    final showIos = platform == 'all' || platform == 'ios';
    final showAndroid = platform == 'all' || platform == 'android';
    final hasRecipientDetail = recipients.isNotEmpty;
    final canCancel = status == 'pending' || status == 'processing';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: hasRecipientDetail
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: adminTextPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            d['body'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminGrey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              AdminStatusChip(
                                label: _statusLabel(status),
                                color: statusColor,
                              ),
                              if (platform != 'all')
                                AdminStatusChip(
                                  label: platform.toUpperCase(),
                                  color: adminGrey,
                                ),
                              if (selectionCount > 0)
                                AdminStatusChip(
                                  label: '$selectionCount sélec.',
                                  color: adminGold,
                                ),
                              if (receivedCount > 0)
                                AdminStatusChip(
                                  label: '$receivedCount reçu${receivedCount > 1 ? 's' : ''}',
                                  color: adminGreenAccent,
                                ),
                            ],
                          ),
                          if (status == 'sent' || d['platformStats'] != null) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (showIos)
                                  BenevolePlatformStatChip(
                                    platform: 'ios',
                                    sent: stats.iosSent,
                                    failed: stats.iosFailed,
                                  ),
                                if (showAndroid)
                                  BenevolePlatformStatChip(
                                    platform: 'android',
                                    sent: stats.androidSent,
                                    failed: stats.androidFailed,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        if (canCancel)
                          IconButton(
                            tooltip: 'Annuler',
                            onPressed: _cancel,
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: adminRed,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (hasRecipientDetail)
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: adminGrey,
                          ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: adminGrey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_expanded && hasRecipientDetail) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: adminBorder),
                  const SizedBox(height: 10),
                  BenevoleRecipientDeliveryList(
                    recipients: recipients,
                    targetPlatform: platform,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
