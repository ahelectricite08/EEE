import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_stat_widgets.dart';

class NotifsTab extends StatefulWidget {
  const NotifsTab();

  @override
  State<NotifsTab> createState() => _NotifsTabState();
}

class _NotifsTabState extends State<NotifsTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _articleIdCtrl = TextEditingController();
  final _matchIdCtrl = TextEditingController();

  String _topic = 'dvcr_alerts';
  /// none | article | match | live | actus | prono
  String _actionType = 'none';
  bool _sending = false;

  static const _maxTitle = 100;
  static const _maxBody = 360;

  static const _topics = [
    ('dvcr_alerts', 'Alertes générales', Icons.notifications_active_rounded),
    ('dvcr_live', 'Live', Icons.videocam_rounded),
    ('dvcr_articles', 'Actus', Icons.newspaper_rounded),
  ];

  static const _templates = <(String label, String title, String body, String topic)>[
    (
      'Live',
      'En direct',
      'Le live DVCR commence — ouvre l’app pour suivre le direct.',
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
      _articleIdCtrl.text = (d['articleId'] ?? '').toString();
      _matchIdCtrl.text = (d['matchId'] ?? '').toString();
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

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
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

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('notifications_queue').add({
        'title': title,
        'body': body,
        'topic': _topic,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'actionType': _actionType,
        'articleId': _articleIdCtrl.text.trim(),
        'matchId': _matchIdCtrl.text.trim(),
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _articleIdCtrl.clear();
      _matchIdCtrl.clear();
      setState(() {
        _actionType = 'none';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: adminTextPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notification mise en file — envoi FCM en cours.',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: adminGreenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: adminRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: sel ? adminCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? adminPurple.withAlpha(200) : Colors.transparent,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: adminPurple.withAlpha(45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: sel ? adminPurple : adminGrey),
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
              color: sel ? adminPurple.withAlpha(28) : adminSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? adminPurple.withAlpha(160) : adminBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: sel ? adminPurple : adminGrey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel ? adminPurple : adminTextPrimary,
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
              Icon(Icons.phone_android_rounded, size: 16, color: adminGrey),
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
              Text(
                _topicShortLabel(_topic),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: adminPurple,
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

  @override
  Widget build(BuildContext context) {
    final titleLen = _titleCtrl.text.length;
    final bodyLen = _bodyCtrl.text.length;
    final titleOk = titleLen <= _maxTitle;
    final bodyOk = bodyLen <= _maxBody;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AdminModuleHeader(
          title: 'Notifications',
          subtitle:
              'Push par topic FCM, action au tap, modèles rapides et historique.',
          icon: Icons.notifications_active_rounded,
          accent: adminPurple,
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                adminPurple.withAlpha(18),
                adminCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: adminPurple.withAlpha(55)),
            boxShadow: adminCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            adminPurple.withAlpha(40),
                            adminPurple.withAlpha(14),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: adminPurple.withAlpha(90)),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: adminPurple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOUVELLE NOTIFICATION',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: adminTextPrimary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Les abonnés au canal reçoivent la push (selon leurs réglages app).',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: adminGrey,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'CANAL D’ENVOI',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGrey,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _channelStrip(),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'MODÈLES RAPIDES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGrey,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
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
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OUVERTURE AU TAP (OPTIONNEL)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGrey,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  children: [
                    _actionChip(
                      'none',
                      'Centre notifs',
                      Icons.notifications_none_rounded,
                    ),
                    _actionChip(
                      'actus',
                      'Liste actus',
                      Icons.article_outlined,
                    ),
                    _actionChip(
                      'article',
                      'Article (id)',
                      Icons.link_rounded,
                    ),
                    _actionChip(
                      'match',
                      'Fiche match',
                      Icons.sports_soccer_rounded,
                    ),
                    _actionChip(
                      'live',
                      'Écran Live',
                      Icons.live_tv_rounded,
                    ),
                    _actionChip(
                      'prono',
                      'Prono',
                      Icons.leaderboard_rounded,
                    ),
                  ],
                ),
              ),
              if (_actionType == 'article') ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AdminField(
                    ctrl: _articleIdCtrl,
                    label: 'ID document article (Firestore)',
                    hint: 'ex. abc123…',
                  ),
                ),
              ],
              if (_actionType == 'match') ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AdminField(
                    ctrl: _matchIdCtrl,
                    label: 'ID match (Firestore)',
                    hint: 'ex. match_…',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _previewCard(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: _sending
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF9B7EFF), adminPurple],
                            ),
                      color: _sending ? adminPurple.withAlpha(80) : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _sending
                          ? null
                          : [
                              BoxShadow(
                                color: adminPurple.withAlpha(55),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: adminOnAccent,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.send_rounded,
                                  color: adminOnAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ENVOYER',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: adminOnAccent,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AdminSectionTitle(
          label: 'HISTORIQUE',
          icon: Icons.history_rounded,
          color: adminGrey,
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications_queue')
              .orderBy('sentAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Erreur : ${snap.error}',
                  style: GoogleFonts.inter(color: adminRed, fontSize: 13),
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: adminPurple),
                ),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(16),
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
                      'Aucune notification en file',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Après envoi, l’historique et le statut (envoyé / erreur) s’affichent ici.',
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
                final d = doc.data() as Map<String, dynamic>;
                final status = (d['status'] ?? 'pending').toString();
                final statusColor = status == 'sent'
                    ? adminGreenAccent
                    : status == 'error'
                    ? adminRed
                    : adminOrange;
                final ts = d['sentAt'];
                String timeStr = '';
                if (ts is Timestamp) {
                  final dt = ts.toDate().toLocal();
                  timeStr =
                      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
                final topic = (d['topic'] ?? '').toString();
                final err = (d['error'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: adminBorder),
                    boxShadow: adminCardShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _fillFromQueueDoc(d),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 48,
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
                                    d['title'] ?? '',
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
                                    d['body'] ?? '',
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
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      AdminStatusChip(
                                        label: _topicShortLabel(topic),
                                        color: adminPurple,
                                      ),
                                      AdminStatusChip(
                                        label: _actionShortLabel(
                                          d['actionType']?.toString(),
                                        ),
                                        color: adminGrey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Recharger le formulaire',
                                  onPressed: () => _fillFromQueueDoc(d),
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    color: adminGrey,
                                    size: 22,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copier le texte',
                                  onPressed: () async {
                                    final text =
                                        '${d['title'] ?? ''}\n${d['body'] ?? ''}';
                                    await Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copié',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration:
                                              const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    color: adminGrey,
                                    size: 20,
                                  ),
                                ),
                                AdminStatusChip(
                                  label: status.toUpperCase(),
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
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
