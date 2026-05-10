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
  late final TextEditingController _contentHtml;
  late final TextEditingController _imageUrl;
  final List<TextEditingController> _imageControllers = [];
  late String _category;
  late String _status;
  late bool _featured;
  bool _saving = false;
  /// Au moins un `contentHtml` était présent à l’ouverture (pour savoir si on efface Firestore quand vide).
  late final bool _hadContentHtmlOnOpen;
  /// Article sync Wix ou déjà enrichi en HTML — afficher l’éditeur HTML.
  late final bool _showContentHtmlEditor;

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
    final html0 = (d?['contentHtml'] as String?)?.trim() ?? '';
    _contentHtml = TextEditingController(text: d?['contentHtml'] as String? ?? '');
    _hadContentHtmlOnOpen = html0.isNotEmpty;
    final wu = (d?['wixUrl'] as String?)?.trim() ?? '';
    final src = d?['source'] as String?;
    _showContentHtmlEditor =
        wu.isNotEmpty || src == 'wix_automation' || _hadContentHtmlOnOpen;
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
    _contentHtml.dispose();
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

      final htmlTrim = _contentHtml.text.trim();
      if (htmlTrim.isNotEmpty) {
        final plainLen = htmlTrim.replaceAll(RegExp('<[^>]*>'), '').length;
        payload['contentHtml'] = htmlTrim;
        payload['contentHtmlTextLen'] = plainLen > 0 ? plainLen : htmlTrim.length;
        payload['contentHtmlFetchedAt'] = FieldValue.serverTimestamp();
      } else if (_hadContentHtmlOnOpen) {
        payload['contentHtml'] = FieldValue.delete();
        payload['contentHtmlTextLen'] = FieldValue.delete();
        payload['contentHtmlFetchedAt'] = FieldValue.delete();
      }

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
          icon: const Icon(Icons.close_rounded, color: adminTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.doc == null ? 'NOUVEL ARTICLE' : 'MODIFIER',
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
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
          Builder(
            builder: (ctx) {
              final style = GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: adminTextPrimary,
              );
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final box = ctx.findRenderObject()! as RenderBox;
                    final overlay =
                        Navigator.of(ctx).overlay!.context.findRenderObject()!
                            as RenderBox;
                    final position = RelativeRect.fromRect(
                      Rect.fromPoints(
                        box.localToGlobal(Offset.zero, ancestor: overlay),
                        box.localToGlobal(
                          box.size.bottomRight(Offset.zero),
                          ancestor: overlay,
                        ),
                      ),
                      Offset.zero & overlay.size,
                    );
                    final chosen = await showMenu<String>(
                      context: ctx,
                      position: position,
                      color: adminCard,
                      surfaceTintColor: Colors.transparent,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: adminBorder),
                      ),
                      constraints: BoxConstraints(minWidth: box.size.width),
                      items: [
                        for (final c in _categories)
                          PopupMenuItem<String>(
                            value: c,
                            child: Text(c, style: style),
                          ),
                      ],
                    );
                    if (chosen != null && mounted) {
                      setState(() => _category = chosen);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_category, style: style),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: adminTextPrimary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
                        color: adminGrey,
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
                  color: adminGrey,
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
                              color: adminTextPrimary,
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
                              color: adminGrey,
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
          if (_showContentHtmlEditor) ...[
            Text(
              'CORPS HTML (AFFICHAGE DANS L’APP)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: adminGold,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pour les articles Wix : c’est ce bloc que lit l’app. Tu peux corriger le HTML ici '
              '(images, paragraphes). Laisser vide puis enregistrer réactive une prochaine synchro auto depuis le site.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentHtml,
              maxLines: 18,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                height: 1.45,
                color: adminTextPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'HTML du corps',
                hintText: '<p>...</p>',
                hintStyle: GoogleFonts.robotoMono(fontSize: 11, color: adminGrey),
                labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                filled: true,
                fillColor: adminCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: adminBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: adminGold),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'TEXTE / EXTRAIT (RECHERCHE, RÉSUMÉ)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: adminGold,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _content,
            maxLines: 16,
            style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
            decoration: InputDecoration(
              labelText: 'Contenu (texte ou markdown interne)',
              hintText: 'Résumé, repères [PHOTO:url]…',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              labelStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              filled: true,
              fillColor: adminCard,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: adminBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: adminGold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
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
