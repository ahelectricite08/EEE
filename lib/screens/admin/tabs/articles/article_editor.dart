import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_dialogs.dart';

class AdminArticleEditorScreen extends StatefulWidget {
  final DocumentSnapshot? doc;
  const AdminArticleEditorScreen({super.key, this.doc});

  @override
  State<AdminArticleEditorScreen> createState() =>
      _AdminArticleEditorScreenState();
}

class _AdminArticleEditorScreenState extends State<AdminArticleEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _imageUrl;
  final List<TextEditingController> _imageControllers = [];
  late String _category;
  late String _status;
  late bool _featured;
  bool _saving = false;

  static const _categories = [
    'RÉSULTATS',
    'AVANT-MATCH',
    'ANALYSE',
    'INTERVIEW',
    'COULISSES',
    'CHRONIQUES SEDANAISES',
  ];

  String _normalizeWixImageUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return '';

    url = Uri.decodeFull(url);

    if (url.startsWith('wix:image://v1/')) {
      final rest = url.substring('wix:image://v1/'.length);
      final assetId = rest.split('/').first.split('#').first.trim();
      final fileName = rest.contains('/')
          ? rest.split('/')[1].split('#').first.trim()
          : assetId.split('/').last.trim();
      if (assetId.isNotEmpty) {
        final safeName = fileName.isEmpty ? 'image.jpg' : fileName;
        return 'https://static.wixstatic.com/media/$assetId/v1/fill/w_1600,h_900,al_c,q_85,enc_jpg/$safeName';
      }
    }

    if (url.contains('static.wixstatic.com/media')) {
      url = url.replaceAll('enc_avif,quality_auto', 'enc_jpg');
      url = url.replaceAll('enc_avif', 'enc_jpg');
      if (!url.contains('/v1/')) {
        final filename = url.split('/').last.split('?').first.split('#').first;
        url = '$url/v1/fill/w_1600,h_900,al_c,q_85,enc_jpg/$filename';
      }
    }

    return url;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.doc?.data() as Map<String, dynamic>?;
    _title = TextEditingController(text: d?['title'] ?? '');
    _content = TextEditingController(text: d?['content'] ?? '');
    _imageUrl = TextEditingController(text: d?['imageUrl'] ?? '');
    for (final url in ((d?['images'] as List?) ?? const [])) {
      _imageControllers.add(TextEditingController(text: url.toString()));
    }
    _category = d?['category'] ?? _categories.first;
    _status = d?['status'] ?? 'published';
    _featured = d?['featured'] ?? false;
    _imageUrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _imageUrl.dispose();
    for (final controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _insertAtCursor(String text) {
    final sel = _content.selection;
    final cur = _content.text;
    if (!sel.isValid) {
      _content.text = cur + text;
      _content.selection = TextSelection.collapsed(
        offset: _content.text.length,
      );
      return;
    }
    final newText = cur.replaceRange(sel.start, sel.end, text);
    _content.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  Future<void> _insertLink() async {
    final textCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ok = await adminShowFormDialog(context, 'INSÉRER UN LIEN', [
      AdminField(ctrl: textCtrl, label: 'Texte affiché'),
      const SizedBox(height: 10),
      AdminField(ctrl: urlCtrl, label: 'URL (https://...)'),
    ]);
    textCtrl.dispose();
    urlCtrl.dispose();
    if (!ok || urlCtrl.text.trim().isEmpty) return;
    final label = textCtrl.text.trim();
    final url = urlCtrl.text.trim();
    _insertAtCursor(label.isNotEmpty ? '[$label]($url)' : url);
  }

  Future<void> _insertPhoto() async {
    final urlCtrl = TextEditingController();
    final ok = await adminShowFormDialog(context, 'INSÉRER UNE PHOTO', [
      AdminField(ctrl: urlCtrl, label: 'URL de l\'image'),
    ]);
    urlCtrl.dispose();
    if (!ok || urlCtrl.text.trim().isEmpty) return;
    _insertAtCursor(
      '\n![photo](${_normalizeWixImageUrl(urlCtrl.text.trim())})\n',
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final images = _imageControllers
          .map((controller) => _normalizeWixImageUrl(controller.text))
          .where((url) => url.isNotEmpty)
          .toList();
      final payload = <String, dynamic>{
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'imageUrl': _imageUrl.text.trim().isEmpty
            ? null
            : _normalizeWixImageUrl(_imageUrl.text.trim()),
        'images': images,
        'category': _category,
        'status': _status,
        'featured': _featured,
        'authorName': 'Rédaction DVCR',
      };
      if (widget.doc == null) {
        payload['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('articles').add(payload);
      } else {
        await widget.doc!.reference.update(payload);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = _normalizeWixImageUrl(_imageUrl.text);
    final canPreview = normalizedImageUrl.isNotEmpty;
    final wasNormalized =
        _imageUrl.text.trim().isNotEmpty &&
        normalizedImageUrl.trim() != _imageUrl.text.trim();

    return Scaffold(
      backgroundColor: adminBg,
      appBar: AppBar(
        backgroundColor: adminBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.doc == null ? 'NOUVEL ARTICLE' : 'MODIFIER',
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'PUBLIER',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: adminBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminField(ctrl: _title, label: 'Titre de l\'article'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                dropdownColor: const Color(0xFF1A1A1A),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AdminField(
            ctrl: _imageUrl,
            label: 'URL image principale (optionnel)',
            hint: 'Colle ici une URL directe Wix ou un lien wix:image://...',
          ),
          if (canPreview) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
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
                      Text(
                        'APERÇU IMAGE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: adminGold,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      if (wasNormalized)
                        AdminSmallButton(
                          label: 'CORRIGER WIX',
                          onTap: () => _imageUrl.text = normalizedImageUrl,
                          color: adminGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        normalizedImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: adminBg,
                          alignment: Alignment.center,
                          child: Text(
                            'Image non lisible',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: adminGrey,
                            ),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                color: adminBg,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: adminGold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (wasNormalized) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Le lien Wix collé a été converti en URL image exploitable.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'PHOTOS DANS L’ARTICLE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: adminGold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              AdminSmallButton(
                label: 'AJOUTER UNE PHOTO',
                onTap: () => setState(
                  () => _imageControllers.add(TextEditingController()),
                ),
                color: adminGold,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_imageControllers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: adminBorder),
              ),
              child: Text(
                'Ajoute ici tes URLs Wix supplementaires pour les photos de l’article.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
            )
          else
            ..._imageControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              final normalized = _normalizeWixImageUrl(controller.text);
              final canPreview = normalized.isNotEmpty;
              final wasNormalized =
                  controller.text.trim().isNotEmpty &&
                  normalized.trim() != controller.text.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
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
                          Text(
                            'PHOTO ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          AdminSmallButton(
                            label: 'SUPPRIMER',
                            onTap: () => setState(() {
                              controller.dispose();
                              _imageControllers.removeAt(index);
                            }),
                            color: adminRed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AdminField(
                        ctrl: controller,
                        label: 'URL photo Wix',
                        hint:
                            'Colle ici une URL directe Wix ou un lien wix:image://...',
                      ),
                      if (canPreview) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              normalized,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: adminBg,
                                alignment: Alignment.center,
                                child: Text(
                                  'Image non lisible',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: adminGrey,
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      color: adminBg,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: adminGold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (wasNormalized)
                              AdminSmallButton(
                                label: 'CORRIGER WIX',
                                onTap: () => controller.text = normalized,
                                color: adminGold,
                              ),
                            AdminSmallButton(
                              label: 'INSERER DANS LE CONTENU',
                              onTap: () =>
                                  _insertAtCursor('\n![photo]($normalized)\n'),
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          AdminField(ctrl: _content, label: 'Contenu', maxLines: 10),
          const SizedBox(height: 8),
          Row(
            children: [
              AdminSmallButton(label: '🔗  LIEN', onTap: _insertLink),
              const SizedBox(width: 8),
              AdminSmallButton(label: '📷  PHOTO', onTap: _insertPhoto),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AdminToggleChip(
                label: 'À LA UNE',
                icon: Icons.star_rounded,
                active: _featured,
                onTap: () => setState(() => _featured = !_featured),
              ),
              const SizedBox(width: 10),
              AdminToggleChip(
                label: _status == 'published' ? 'PUBLIÉ' : 'BROUILLON',
                icon: Icons.visibility_rounded,
                active: _status == 'published',
                onTap: () => setState(
                  () =>
                      _status = _status == 'published' ? 'draft' : 'published',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
