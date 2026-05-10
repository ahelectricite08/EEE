import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/app_settings_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_stat_widgets.dart';
import 'admin_duels_leagues_section.dart';

class CommunauteTab extends StatefulWidget {
  const CommunauteTab();

  @override
  State<CommunauteTab> createState() => _CommunauteTabState();
}

class _CommunauteTabState extends State<CommunauteTab> {
  final _createCtrl = TextEditingController();
  final _blockedWordsCtrl = TextEditingController();
  final _autoNoticeCtrl = TextEditingController();
  bool _creating = false;
  final Map<String, TextEditingController> _renameCtrl = {};
  final Map<String, bool> _renaming = {};
  final Map<String, bool> _deleting = {};
  bool _chatAutoEnabled = false;
  bool _chatConfigLoaded = false;
  bool _chatConfigSaving = false;
  List<Map<String, dynamic>> _customChatEmojis = [];

  @override
  void initState() {
    super.initState();
    _loadChatConfig();
  }

  @override
  void dispose() {
    _createCtrl.dispose();
    _blockedWordsCtrl.dispose();
    _autoNoticeCtrl.dispose();
    for (final c in _renameCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadChatConfig() async {
    final settings = ChatSettings.fromMap(
      await AppSettingsService.appConfigDoc('chat')
          .get()
          .then((doc) => doc.data()),
    );
    if (!mounted) return;
    setState(() {
      _chatAutoEnabled = settings.autoModerationEnabled;
      _blockedWordsCtrl.text = settings.blockedWords.join(', ');
      _autoNoticeCtrl.text = settings.notice;
      _customChatEmojis =
          settings.customEmojis.map((emoji) => emoji.toMap()).toList();
      _chatConfigLoaded = true;
    });
  }

  Future<void> _saveChatConfig() async {
    setState(() => _chatConfigSaving = true);
    final cleanWords = _blockedWordsCtrl.text
        .split(',')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    final cleanEmojis = _customChatEmojis
        .map((emoji) => {
              'id': (emoji['id'] ??
                      DateTime.now().millisecondsSinceEpoch.toString())
                  .toString(),
              'label': (emoji['label'] ?? '').toString().trim(),
              'value': (emoji['value'] ?? '').toString().trim(),
              'imageUrl': (emoji['imageUrl'] ?? '').toString().trim(),
              'enabled': emoji['enabled'] != false,
            })
        .where((e) => (e['value'] ?? '').toString().isNotEmpty)
        .toList();
    await AppSettingsService.saveChat(
      ChatSettings(
        autoModerationEnabled: _chatAutoEnabled,
        blockedWords: cleanWords,
        notice: _autoNoticeCtrl.text.trim(),
        customEmojis:
            cleanEmojis.map((e) => ChatEmojiSettings.fromMap(e)).toList(),
      ),
    );
    if (!mounted) return;
    setState(() => _chatConfigSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration chat mise à jour'),
        backgroundColor: adminGreen,
      ),
    );
  }

  void _addCustomEmoji() {
    setState(() {
      _customChatEmojis.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'label': 'Nouvel emoji',
        'value': ':dvcr:',
        'imageUrl': '',
        'enabled': true,
      });
    });
  }

  Future<void> _createSalon() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    final snap = await FirebaseFirestore.instance
        .collection('chat_salons')
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    final nextOrder = snap.docs.isEmpty
        ? 1
        : ((snap.docs.first.data()['order'] as int?) ?? 0) + 1;
    await FirebaseFirestore.instance.collection('chat_salons').add({
      'name': name,
      'order': nextOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _createCtrl.clear();
    if (mounted) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salon "$name" créé'),
          backgroundColor: adminGreen,
        ),
      );
    }
  }

  Future<void> _renameSalon(String docId) async {
    final ctrl = _renameCtrl[docId];
    if (ctrl == null) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _renaming[docId] = true);
    await FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(docId)
        .update({'name': name});
    if (mounted) {
      setState(() => _renaming[docId] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salon renommé "$name"'),
          backgroundColor: adminGreen,
        ),
      );
    }
  }

  Future<void> _deleteSalonMessages(
    BuildContext ctx,
    String docId,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      barrierColor: Colors.black.withAlpha(120),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: adminCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: adminBorder),
        ),
        title: Text(
          'Vider #$name ?',
          style: GoogleFonts.inter(
            color: adminTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Tous les messages seront supprimés.',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: adminTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'VIDER',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deleting[docId] = true);
    try {
      final db = FirebaseFirestore.instance;
      QuerySnapshot snap;
      int total = 0;
      do {
        snap = await db
            .collection('chat_salons')
            .doc(docId)
            .collection('messages')
            .limit(500)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = db.batch();
        for (final d in snap.docs) batch.delete(d.reference);
        await batch.commit();
        total += snap.docs.length;
      } while (snap.docs.length == 500);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$total messages supprimés de #$name'),
            backgroundColor: adminGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting[docId] = false);
    }
  }

  Future<void> _deleteSalon(
    BuildContext ctx,
    String docId,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      barrierColor: Colors.black.withAlpha(120),
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: adminCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: adminBorder),
        ),
        title: Text(
          'Supprimer #$name ?',
          style: GoogleFonts.inter(
            color: adminTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Le salon et tous ses messages seront supprimés définitivement.',
          style: GoogleFonts.inter(color: adminGrey, fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: adminTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'SUPPRIMER',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await _deleteSalonMessages(context, docId, name);
    await FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(docId)
        .delete();
  }

  Future<void> _unpin(String docId) async {
    await FirebaseFirestore.instance
        .collection('chat_salons')
        .doc(docId)
        .update({'pinned': FieldValue.delete()});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 3, height: 22,
              decoration: BoxDecoration(color: adminGreenAccent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Text(
              'COMMUNAUTÉ',
              style: GoogleFonts.barlowCondensed(
                fontSize: 22, fontWeight: FontWeight.w900, color: adminTextPrimary, letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const AdminDuelsLeaguesSection(),
        const SizedBox(height: 24),

        // ── Créer un salon ────────────────────────────────────────────────────
        const AdminSectionTitle(label: 'CRÉER UN SALON'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _createCtrl,
                  style: GoogleFonts.inter(fontSize: 14, color: adminTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nom du nouveau salon...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: adminGreyLight,
                    ),
                    filled: true,
                    fillColor: adminCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: adminBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: adminBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: adminGold),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _createSalon(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _creating ? null : _createSalon,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: adminGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Créer',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Salons existants ──────────────────────────────────────────────────
        const AdminSectionTitle(label: 'SALONS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chat_salons')
              .orderBy('order')
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: adminBorder),
                ),
                child: Text(
                  'Aucun salon. Créez-en un ci-dessus.',
                  style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? doc.id;
                final pinned = data['pinned'] as Map<String, dynamic>?;
                _renameCtrl.putIfAbsent(
                  doc.id,
                  () => TextEditingController(text: name),
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: adminBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(35), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top accent bar
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [adminGreenAccent.withAlpha(0), adminGreenAccent.withAlpha(100), adminGreenAccent.withAlpha(0)]),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '# $name',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<AggregateQuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('chat_salons')
                                .doc(doc.id)
                                .collection('messages')
                                .count()
                                .get(),
                            builder: (_, s) {
                              final n = s.data?.count ?? 0;
                              return AdminStatusChip(
                                label: '$n msg',
                                color: adminGrey,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: (_deleting[doc.id] ?? false)
                                    ? null
                                    : () => _deleteSalonMessages(
                                          context,
                                          doc.id,
                                          name,
                                        ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: adminRed.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: adminRed.withAlpha(60),
                                    ),
                                  ),
                                  child: (_deleting[doc.id] ?? false)
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: adminRed,
                                          ),
                                        )
                                      : Text(
                                          'Vider',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: adminRed,
                                          ),
                                        ),
                                ),
                              ),
                              if (doc.id != 'general') ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () =>
                                      _deleteSalon(context, doc.id, name),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 2),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: adminGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _renameCtrl[doc.id],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: adminTextPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nouveau nom...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: adminGreyLight,
                                ),
                                filled: true,
                                fillColor: adminCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: adminBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: adminBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide:
                                      const BorderSide(color: adminGold),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: (_renaming[doc.id] ?? false)
                                ? null
                                : () => _renameSalon(doc.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: adminGold.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: adminGold.withAlpha(80),
                                ),
                              ),
                              child: (_renaming[doc.id] ?? false)
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: adminGold,
                                      ),
                                    )
                                  : Text(
                                      'Renommer',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: adminGold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (pinned != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: adminGold.withAlpha(10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: adminGold.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 12,
                                color: adminGold,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${pinned['firstName'] ?? ''} : ${pinned['text'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: adminGreyLight,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _unpin(doc.id),
                                child: Text(
                                  'Désépingler',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: adminRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],     // closes if (pinned != null) [...] spread
                      ],     // closes inner Column children
                        ),   // closes inner Column
                      ),     // closes Padding
                    ],       // closes outer Column children
                  ),         // closes outer Column
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Config chat ───────────────────────────────────────────────────────
        const AdminSectionTitle(label: 'CONFIG CHAT'),
        const SizedBox(height: 10),
        if (!_chatConfigLoaded)
          const Center(child: CircularProgressIndicator(color: adminGold))
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: adminBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Auto-modération simple',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _chatAutoEnabled,
                      activeThumbColor: adminGold,
                      onChanged: (v) => setState(() => _chatAutoEnabled = v),
                    ),
                  ],
                ),
                Text(
                  'Liste de mots bloqués séparés par des virgules. Le message est refusé et un rappel poli est posté.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGreyLight),
                ),
                const SizedBox(height: 12),
                AdminField(ctrl: _blockedWordsCtrl, label: 'Mots bloqués'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: _autoNoticeCtrl,
                  label: 'Message modération',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilise {user} dans le message pour insérer le prénom.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Emojis DVCR',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _addCustomEmoji,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: adminGold.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: adminGold.withAlpha(90)),
                        ),
                        child: Text(
                          'Ajouter',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: adminGold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Code exemple : :dvcr: . Image URL optionnelle.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGreyLight),
                ),
                const SizedBox(height: 10),
                ..._customChatEmojis.asMap().entries.map((entry) {
                  final index = entry.key;
                  final emoji = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    (emoji['label'] ?? '').toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: adminTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Label',
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: adminGrey,
                                  ),
                                  filled: true,
                                  fillColor: adminBg,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: adminBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: adminGold),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) => emoji['label'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    (emoji['value'] ?? '').toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: adminTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Code',
                                  labelStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: adminGrey,
                                  ),
                                  filled: true,
                                  fillColor: adminBg,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: adminBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: adminGold),
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) => emoji['value'] = v,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: (emoji['imageUrl'] ?? '').toString(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: adminTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Image URL optionnelle',
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: adminGrey,
                            ),
                            filled: true,
                            fillColor: adminBg,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: adminBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: adminGold),
                            ),
                            isDense: true,
                          ),
                          onChanged: (v) => emoji['imageUrl'] = v,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                emoji['enabled'] == false
                                    ? 'Hors ligne'
                                    : 'En ligne',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: adminGrey,
                                ),
                              ),
                            ),
                            Switch(
                              value: emoji['enabled'] != false,
                              activeThumbColor: adminGold,
                              onChanged: (v) =>
                                  setState(() => emoji['enabled'] = v),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _customChatEmojis.removeAt(index),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: adminRed,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _chatConfigSaving ? null : _saveChatConfig,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: adminGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: _chatConfigSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              'ENREGISTRER LA CONFIG CHAT',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── Signalements ──────────────────────────────────────────────────────
        const AdminSectionTitle(label: 'SIGNALEMENTS'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: adminBorder),
                ),
                child: Text(
                  'Aucun signalement en attente',
                  style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = d['reportedName'] as String? ?? 'Membre';
                final text = d['messageText'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: Color(0xFFFFB74D),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            doc.reference.update({'status': 'resolved'}),
                        child: Text(
                          'Résoudre',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
