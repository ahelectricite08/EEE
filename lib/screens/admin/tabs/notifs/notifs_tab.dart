import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_module_shell.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';

class NotifsTab extends StatefulWidget {
  final bool embedded;

  const NotifsTab({super.key, this.embedded = false});

  @override
  State<NotifsTab> createState() => _NotifsTabState();
}

class _NotifsTabState extends State<NotifsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _articleIdCtrl = TextEditingController();
  final _matchIdCtrl = TextEditingController();

  String _topic = 'dvcr_alerts';
  /// all | ios | android
  String _targetPlatform = 'all';
  /// none | article | match | live | actus | prono
  String _actionType = 'none';
  /// Envoi uniquement sur les appareils du compte admin connecté (bypass maintenance).
  bool _testOnlyMyDevices = false;
  bool _sending = false;
  String? _lastQueueDocId;

  static const _maxTitle = 100;
  static const _maxBody = 360;

  static const _topics = [
    ('dvcr_alerts', 'Alertes générales', Icons.notifications_active_rounded),
    ('dvcr_live', 'Live', Icons.videocam_rounded),
    ('dvcr_articles', 'Actus', Icons.newspaper_rounded),
  ];

  static const _templates = <(String label, String title, String body, String topic)>[
    ('Vierge', '', '', 'dvcr_alerts'),
    (
      'Live',
      'En direct',
      'Le live du CS Sedan Ardennes commence — ouvre l’app pour suivre le match.',
      'dvcr_live',
    ),
    (
      'Actu',
      'Nouvel article',
      'Un nouvel article est disponible sur DVCR.',
      'dvcr_articles',
    ),
    (
      'Rappel',
      'Rappel',
      'Pense à ouvrir l’app pour ne rien manquer.',
      'dvcr_alerts',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _bodyCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _articleIdCtrl.dispose();
    _matchIdCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate((String, String, String, String) t) {
    setState(() {
      _titleCtrl.text = t.$2;
      _bodyCtrl.text = t.$3;
      _topic = t.$4;
      if (t.$4 == 'dvcr_live') {
        _actionType = 'live';
      } else if (t.$4 == 'dvcr_articles') {
        _actionType = 'actus';
      } else {
        _actionType = 'none';
      }
    });
  }

  void _fillFromQueueDoc(Map<String, dynamic> d) {
    setState(() {
      _titleCtrl.text = (d['title'] ?? '').toString();
      _bodyCtrl.text = (d['body'] ?? '').toString();
      _topic = (d['topic'] ?? 'dvcr_alerts').toString();
      _actionType = (d['actionType'] ?? 'none').toString();
      if (!['none', 'article', 'match', 'live', 'actus', 'prono']
          .contains(_actionType)) {
        _actionType = 'none';
      }
      final tp = (d['targetPlatform'] ?? 'all').toString();
      if (['all', 'ios', 'android'].contains(tp)) {
        _targetPlatform = tp;
      }
      _articleIdCtrl.text = (d['articleId'] ?? '').toString();
      _matchIdCtrl.text = (d['matchId'] ?? '').toString();
      _testOnlyMyDevices = (d['testOnlyUid'] ?? '').toString().isNotEmpty;
    });
  }

  static String _topicShortLabel(String topic) {
    switch (topic) {
      case 'dvcr_live':
        return 'Live';
      case 'dvcr_articles':
        return 'Actus';
      default:
        return 'Alertes';
    }
  }

  static String _actionShortLabel(String? raw) {
    switch (raw) {
      case 'article':
        return 'Article';
      case 'match':
        return 'Match';
      case 'live':
        return 'Direct';
      case 'actus':
        return 'Liste actus';
      case 'prono':
        return 'Prono';
      default:
        return 'Centre notifs';
    }
  }

  static int _statInt(Map<String, dynamic>? map, String key) {
    if (map == null) return 0;
    final v = map[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static ({int iosSent, int iosFailed, int androidSent, int androidFailed})
      _parsePlatformStats(Map<String, dynamic> d) {
    final raw = d['platformStats'];
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
    final count = _statInt(d, 'recipientsCount');
    final platform = (d['targetPlatform'] ?? 'all').toString();
    if (platform == 'ios') {
      return (iosSent: count, iosFailed: 0, androidSent: 0, androidFailed: 0);
    }
    if (platform == 'android') {
      return (iosSent: 0, iosFailed: 0, androidSent: count, androidFailed: 0);
    }
    return (iosSent: 0, iosFailed: 0, androidSent: 0, androidFailed: 0);
  }

  static String statusLabel(String status) {
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
        return status.isEmpty ? '—' : status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'sent':
        return adminGreenAccent;
      case 'error':
        return adminRed;
      case 'skipped':
        return adminOrange;
      case 'cancelled':
        return adminGrey;
      case 'processing':
        return AdminModuleColors.preparation;
      case 'pending':
        return adminOrange;
      default:
        return adminGrey;
    }
  }

  static bool canCancelStatus(String status) =>
      status == 'pending' || status == 'processing';

  Future<void> _cancelQueueItem(String docId) async {
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
          'Si l’envoi a déjà commencé, certains appareils peuvent déjà l’avoir reçue.',
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
    if (ok != true || !mounted) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('notifications_queue')
          .doc(docId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final status = (snap.data()?['status'] ?? 'pending').toString();
        if (!canCancelStatus(status)) {
          throw StateError('Statut actuel : ${statusLabel(status)}');
        }
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': FirebaseAuth.instance.currentUser?.uid,
        });
      });
      if (!mounted) return;
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
      if (!mounted) return;
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

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    if (_sending) return;
    if (title.length > _maxTitle || body.length > _maxBody) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Texte trop long (titre ≤ $_maxTitle, message ≤ $_maxBody).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_testOnlyMyDevices && (uid == null || uid.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecte-toi avec ton compte admin pour le test sur ton téléphone.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'body': body,
        'topic': _topic,
        'createdAt': FieldValue.serverTimestamp(),
        // sentAt sert aussi de clé de tri historique (legacy) = heure de mise en file.
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'actionType': _actionType,
        'articleId': _articleIdCtrl.text.trim(),
        'matchId': _matchIdCtrl.text.trim(),
        'targetPlatform': _testOnlyMyDevices ? 'all' : _targetPlatform,
        'targetAudience': 'all',
        'createdBy': uid,
      };
      if (_testOnlyMyDevices && uid != null) {
        payload['testOnlyUid'] = uid;
      }
      final docRef = await FirebaseFirestore.instance
          .collection('notifications_queue')
          .add(payload);
      if (!mounted) return;
      setState(() {
        _lastQueueDocId = docRef.id;
        _actionType = 'none';
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _articleIdCtrl.clear();
      _matchIdCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _testOnlyMyDevices
                ? 'Test mis en file — suivi ci-dessous.'
                : 'Notification mise en file — envoi en arrière-plan.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Échec de mise en file : $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _platformStrip() {
    if (_testOnlyMyDevices) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: adminGold.withAlpha(22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: adminGold.withAlpha(100)),
        ),
        child: Row(
          children: [
            Icon(Icons.science_rounded, size: 16, color: adminGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mode test : tous tes appareils enregistrés (iPhone + Android si connectés).',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: adminGold,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _platformSegment(
            value: 'all',
            label: 'Tous',
            subtitle: 'iOS + Android',
            icon: Icons.devices_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _platformSegment(
            value: 'ios',
            label: 'iPhone',
            subtitle: 'iOS uniquement',
            icon: Icons.phone_iphone_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _platformSegment(
            value: 'android',
            label: 'Android',
            subtitle: 'Android uniquement',
            icon: Icons.android_rounded,
          ),
        ),
      ],
    );
  }

  Widget _platformSegment({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final sel = _targetPlatform == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _targetPlatform = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? AdminModuleColors.preparation.withAlpha(24) : adminSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? AdminModuleColors.preparation.withAlpha(180) : adminBorder,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: sel ? AdminModuleColors.preparation : adminGrey),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: sel ? adminTextPrimary : adminGrey,
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: sel ? AdminModuleColors.preparation.withAlpha(200) : adminGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelStrip() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _topics.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _channelSegment(
                topicValue: _topics[i].$1,
                label: _topics[i].$2,
                icon: _topics[i].$3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _channelSegment({
    required String topicValue,
    required String label,
    required IconData icon,
  }) {
    final sel = _topic == topicValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _topic = topicValue),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: sel ? adminCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? AdminModuleColors.preparation.withAlpha(200) : Colors.transparent,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: sel ? AdminModuleColors.preparation : adminGrey),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: sel ? adminTextPrimary : adminGrey,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip(String value, String label, IconData icon) {
    final sel = _actionType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _actionType = value),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AdminModuleColors.preparation.withAlpha(28) : adminSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? AdminModuleColors.preparation.withAlpha(160) : adminBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: sel ? AdminModuleColors.preparation : adminGrey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel ? AdminModuleColors.preparation : adminTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Titre de la notification'
        : _titleCtrl.text.trim();
    final bodyLines = _bodyCtrl.text.trim().isEmpty
        ? 'Message affiché sous le titre sur l’appareil.'
        : _bodyCtrl.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16, color: adminGrey),
              const SizedBox(width: 8),
              Text(
                'APERÇU',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!_testOnlyMyDevices)
                _PlatformTargetBadge(platform: _targetPlatform),
              const SizedBox(width: 6),
              Text(
                _topicShortLabel(_topic),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AdminModuleColors.preparation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: adminGold.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    color: adminGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DVCR',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: adminGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bodyLines,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: adminGrey,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _sending ? null : _send,
        icon: _sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: adminOnAccent,
                ),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          _sending ? 'MISE EN FILE…' : 'ENVOYER LA NOTIFICATION',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AdminModuleColors.preparation,
          foregroundColor: adminOnAccent,
          disabledBackgroundColor: AdminModuleColors.preparation.withAlpha(80),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _lastSendResultPanel() {
    final docId = _lastQueueDocId;
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
        final d = snap.data!.data() as Map<String, dynamic>? ?? {};
        final status = (d['status'] ?? 'pending').toString();
        if (status == 'pending' || status == 'processing') {
          final inFlight = status == 'processing';
          return AdminModuleSection(
            eyebrow: 'Suivi',
            title: inFlight ? 'Envoi en cours…' : 'En file d’attente…',
            subtitle: inFlight
                ? 'La Cloud Function distribue les push (iOS / Android).'
                : 'En attente du worker — tu peux encore annuler.',
            accent: AdminModuleColors.preparation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminModuleColors.preparation,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        inFlight
                            ? 'Distribution FCM en arrière-plan…'
                            : 'Mise en file réussie — démarrage imminent.',
                        style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _cancelQueueItem(docId),
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

        return AdminModuleSection(
          eyebrow: 'Résultat',
          title: status == 'sent'
              ? 'Notification envoyée'
              : status == 'skipped'
                  ? 'Envoi ignoré'
                  : status == 'cancelled'
                      ? 'Notification annulée'
                      : 'Échec d’envoi',
          subtitle: (d['title'] ?? '').toString(),
          accent: statusColor(status),
          child: _DeliveryResultBody(data: d),
        );
      },
    );
  }

  Widget _historyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications_queue')
          .orderBy('sentAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur historique : ${snap.error}',
              style: GoogleFonts.inter(color: adminRed, fontSize: 13),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AdminModuleColors.preparation),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: adminSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: adminBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.outbox_rounded,
                  size: 40,
                  color: adminGrey.withAlpha(160),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucune notification envoyée',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'L’historique affiche le statut et le détail iOS / Android.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _HistoryTile(
              data: data,
              onReload: () => _fillFromQueueDoc(data),
              onCancel: canCancelStatus((data['status'] ?? '').toString())
                  ? () => _cancelQueueItem(doc.id)
                  : null,
              onCopy: () async {
                final text = '${data['title'] ?? ''}\n${data['body'] ?? ''}';
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copié',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleLen = _titleCtrl.text.length;
    final bodyLen = _bodyCtrl.text.length;
    final titleOk = titleLen <= _maxTitle;
    final bodyOk = bodyLen <= _maxBody;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, widget.embedded ? 8 : 12, 16, 28),
      children: [
        if (!widget.embedded) ...[
          AdminModuleHeader(
            title: 'Notifications',
            subtitle:
                'Push générales avec ciblage iOS / Android et suivi d’envoi par appareil.',
            icon: Icons.notifications_active_rounded,
            accent: AdminModuleColors.preparation,
          ),
          const SizedBox(height: 16),
        ],

        AdminModuleSection(
          eyebrow: 'Composer',
          title: 'Nouvelle notification',
          subtitle: _testOnlyMyDevices
              ? 'Test sur ton compte — exempté de la maintenance push.'
              : 'Choisis la plateforme, rédige le message, puis envoie.',
          accent: AdminModuleColors.preparation,
          wrapInCard: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: adminCardDecoration(
                  radius: 16,
                  borderColor: AdminModuleColors.preparation.withAlpha(55),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CANAL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _channelStrip(),
                    const SizedBox(height: 16),
                    Text(
                      'AUDIENCE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _platformStrip(),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _testOnlyMyDevices,
                      onChanged: (v) => setState(() => _testOnlyMyDevices = v),
                      activeTrackColor: adminGold.withAlpha(140),
                      title: Text(
                        'Test sur mon compte uniquement',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Envoie sur ton iPhone/Android connectés — exempté de la maintenance.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: adminGrey,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: adminSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MODÈLES RAPIDES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates
                          .map(
                            (t) => ActionChip(
                              label: Text(
                                t.$1,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: adminSurface,
                              side: const BorderSide(color: adminBorder),
                              onPressed: () => _applyTemplate(t),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    AdminField(
                      ctrl: _titleCtrl,
                      label: 'Titre',
                      hint: 'Titre de la notification',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$titleLen / $_maxTitle',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: titleOk ? adminGrey : adminRed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AdminField(
                      ctrl: _bodyCtrl,
                      label: 'Message',
                      maxLines: 4,
                      hint: 'Corps du message',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$bodyLen / $_maxBody',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: bodyOk ? adminGrey : adminRed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'OUVERTURE AU TAP (OPTIONNEL)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        _actionChip('none', 'Centre notifs', Icons.notifications_none_rounded),
                        _actionChip('actus', 'Liste actus', Icons.article_outlined),
                        _actionChip('article', 'Article (id)', Icons.link_rounded),
                        _actionChip('match', 'Fiche match', Icons.sports_soccer_rounded),
                        _actionChip('live', 'Écran Live', Icons.live_tv_rounded),
                        _actionChip('prono', 'Prono', Icons.leaderboard_rounded),
                      ],
                    ),
                    if (_actionType == 'article') ...[
                      const SizedBox(height: 8),
                      AdminField(
                        ctrl: _articleIdCtrl,
                        label: 'ID document article (Firestore)',
                        hint: 'ex. abc123…',
                      ),
                    ],
                    if (_actionType == 'match') ...[
                      const SizedBox(height: 8),
                      AdminField(
                        ctrl: _matchIdCtrl,
                        label: 'ID match (Firestore)',
                        hint: 'ex. match_…',
                      ),
                    ],
                    const SizedBox(height: 14),
                    _previewCard(),
                    const SizedBox(height: 16),
                    _sendButton(),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_lastQueueDocId != null) ...[
          const SizedBox(height: 20),
          _lastSendResultPanel(),
        ],

        const SizedBox(height: 22),
        AdminModuleSection(
          eyebrow: 'Historique',
          title: 'Derniers envois',
          subtitle:
              'File / en cours / envoyé / annulé — annule un pending via l’icône rouge.',
          accent: adminGrey,
          wrapInCard: false,
          child: _historyList(),
        ),
      ],
    );
  }
}

class _PlatformTargetBadge extends StatelessWidget {
  final String platform;

  const _PlatformTargetBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (platform) {
      'ios' => ('iOS', Icons.phone_iphone_rounded, const Color(0xFF007AFF)),
      'android' => ('Android', Icons.android_rounded, adminGreenAccent),
      _ => ('Tous', Icons.devices_rounded, AdminModuleColors.preparation),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformStatChip extends StatelessWidget {
  final String platform;
  final int sent;
  final int failed;

  const _PlatformStatChip({
    required this.platform,
    required this.sent,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = platform == 'ios';
    final label = isIos ? 'iPhone' : 'Android';
    final icon = isIos ? Icons.phone_iphone_rounded : Icons.android_rounded;
    final color = isIos ? const Color(0xFF007AFF) : adminGreenAccent;
    final hasSent = sent > 0;
    final hasFailed = failed > 0;

    if (!hasSent && !hasFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: adminSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: adminGrey),
            const SizedBox(width: 6),
            Text(
              '$label : 0',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: adminGrey,
              ),
            ),
          ],
        ),
      );
    }

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

class _DeliveryResultBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DeliveryResultBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? '').toString();
    final stats = _NotifsTabState._parsePlatformStats(data);
    final targetPlatform = (data['targetPlatform'] ?? 'all').toString();
    final skipReason = (data['skipReason'] ?? '').toString();
    final err = (data['error'] ?? '').toString();
    final showIos = targetPlatform == 'all' || targetPlatform == 'ios';
    final showAndroid = targetPlatform == 'all' || targetPlatform == 'android';
    final sendMode = (data['sendMode'] ?? '').toString();
    final isTopicFanout = sendMode.startsWith('topic_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == 'sent') ...[
          if (!isTopicFanout)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showIos)
                  _PlatformStatChip(
                    platform: 'ios',
                    sent: stats.iosSent,
                    failed: stats.iosFailed,
                  ),
                if (showAndroid)
                  _PlatformStatChip(
                    platform: 'android',
                    sent: stats.androidSent,
                    failed: stats.androidFailed,
                  ),
              ],
            ),
          if (!isTopicFanout) const SizedBox(height: 10),
          Text(
            _deliverySummary(stats, targetPlatform, sendMode: sendMode),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminGrey,
              height: 1.4,
            ),
          ),
        ] else if (status == 'skipped') ...[
          Text(
            skipReason == 'maintenance'
                ? 'Bloqué : mode maintenance actif (utilise le test sur ton compte ou désactive la maintenance).'
                : 'Aucun appareil trouvé pour cette cible — vérifie les tokens FCM enregistrés.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminOrange,
              height: 1.4,
            ),
          ),
          if (data['platformStats'] != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showIos)
                  _PlatformStatChip(
                    platform: 'ios',
                    sent: stats.iosSent,
                    failed: stats.iosFailed,
                  ),
                if (showAndroid)
                  _PlatformStatChip(
                    platform: 'android',
                    sent: stats.androidSent,
                    failed: stats.androidFailed,
                  ),
              ],
            ),
          ],
        ] else if (status == 'cancelled') ...[
          Text(
            (data['cancelNote'] ?? 'Envoi annulé.').toString(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminGrey,
              height: 1.4,
            ),
          ),
          if (data['platformStats'] != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showIos)
                  _PlatformStatChip(
                    platform: 'ios',
                    sent: stats.iosSent,
                    failed: stats.iosFailed,
                  ),
                if (showAndroid)
                  _PlatformStatChip(
                    platform: 'android',
                    sent: stats.androidSent,
                    failed: stats.androidFailed,
                  ),
              ],
            ),
          ],
        ] else if (err.isNotEmpty) ...[
          Text(
            err,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminRed,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  String _deliverySummary(
    ({int iosSent, int iosFailed, int androidSent, int androidFailed}) stats,
    String targetPlatform, {
    String sendMode = '',
  }) {
    if (sendMode.startsWith('topic_')) {
      return 'Envoyé via topic FCM à tous les abonnés club (hors désinscription).';
    }
    final iosOk = stats.iosSent > 0;
    final androidOk = stats.androidSent > 0;
    if (targetPlatform == 'ios') {
      return iosOk
          ? 'Envoyé sur ${stats.iosSent} appareil${stats.iosSent > 1 ? 's' : ''} iPhone.'
          : 'Aucun iPhone n’a reçu la notification.';
    }
    if (targetPlatform == 'android') {
      return androidOk
          ? 'Envoyé sur ${stats.androidSent} appareil${stats.androidSent > 1 ? 's' : ''} Android.'
          : 'Aucun appareil Android n’a reçu la notification.';
    }
    if (iosOk && androidOk) {
      return 'Reçu sur iPhone et Android — ${stats.iosSent + stats.androidSent} appareil${stats.iosSent + stats.androidSent > 1 ? 's' : ''} au total.';
    }
    if (iosOk) {
      return 'Reçu uniquement sur iPhone (${stats.iosSent} appareil${stats.iosSent > 1 ? 's' : ''}). Aucun Android.';
    }
    if (androidOk) {
      return 'Reçu uniquement sur Android (${stats.androidSent} appareil${stats.androidSent > 1 ? 's' : ''}). Aucun iPhone.';
    }
    return 'Aucun appareil n’a confirmé la réception.';
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReload;
  final VoidCallback onCopy;
  final VoidCallback? onCancel;

  const _HistoryTile({
    required this.data,
    required this.onReload,
    required this.onCopy,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final skipReason = (data['skipReason'] ?? '').toString();
    final statusColor = _NotifsTabState.statusColor(status);
    final ts = data['sentAt'] ?? data['skippedAt'] ?? data['cancelledAt'] ?? data['createdAt'];
    String timeStr = '';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      timeStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final topic = (data['topic'] ?? '').toString();
    final err = (data['error'] ?? '').toString();
    final targetPlatform = (data['targetPlatform'] ?? 'all').toString();
    final stats = _NotifsTabState._parsePlatformStats(data);
    final showIos = targetPlatform == 'all' || targetPlatform == 'ios';
    final showAndroid = targetPlatform == 'all' || targetPlatform == 'android';
    final sendMode = (data['sendMode'] ?? '').toString();
    final isTopicFanout = sendMode.startsWith('topic_');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: adminCardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onReload,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['body'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminGrey,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (err.isNotEmpty && status == 'error') ...[
                        const SizedBox(height: 6),
                        Text(
                          err,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminRed,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (status == 'skipped' && skipReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          skipReason == 'maintenance'
                              ? 'Bloqué : mode maintenance.'
                              : 'Bloqué : aucun appareil trouvé.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminOrange,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (status == 'cancelled') ...[
                        const SizedBox(height: 6),
                        Text(
                          (data['cancelNote'] ?? 'Annulé par un admin.').toString(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminGrey,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AdminStatusChip(
                            label: _NotifsTabState._topicShortLabel(topic),
                            color: AdminModuleColors.preparation,
                          ),
                          AdminStatusChip(
                            label: _NotifsTabState._actionShortLabel(
                              data['actionType']?.toString(),
                            ),
                            color: adminGrey,
                          ),
                          _PlatformTargetBadge(platform: targetPlatform),
                          if (isTopicFanout)
                            AdminStatusChip(
                              label: 'Topic club',
                              color: adminGreenAccent,
                            ),
                        ],
                      ),
                      if (!isTopicFanout &&
                          (status == 'sent' || data['platformStats'] != null)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (showIos)
                              _PlatformStatChip(
                                platform: 'ios',
                                sent: stats.iosSent,
                                failed: stats.iosFailed,
                              ),
                            if (showAndroid)
                              _PlatformStatChip(
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
                    IconButton(
                      tooltip: 'Recharger le formulaire',
                      onPressed: onReload,
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        color: adminGrey,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copier le texte',
                      onPressed: onCopy,
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: adminGrey,
                        size: 20,
                      ),
                    ),
                    if (onCancel != null)
                      IconButton(
                        tooltip: 'Annuler l’envoi',
                        onPressed: onCancel,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: adminRed,
                          size: 20,
                        ),
                      ),
                    AdminStatusChip(
                      label: _NotifsTabState.statusLabel(status),
                      color: statusColor,
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: adminGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
