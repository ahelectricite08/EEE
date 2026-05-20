import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/article_model.dart';
import '../../services/article_service.dart';

const _kRed = Color(0xFFBA203C);
const _kGreen = Color(0xFF0A4438);
const _kBg = Color(0xFFF5F2E9);
const _kCard = Color(0xFFFFFFFF);
const _kCardSoft = Color(0xFFF8F6F0);
const _kBorder = Color(0xFFE5E1D6);
const _kText = Color(0xFF1A2522);
const _kMuted = Color(0xFF5C6560);

const _kCategories = ['RÉSULTATS', 'AVANT-MATCH', 'CHRONIQUES SEDANAISES', 'ANALYSE', 'COULISSES', 'CLUB', 'FOOTBALL'];

class ArticleEditorScreen extends StatefulWidget {
  final ArticleModel? article; // null = création, non-null = édition

  const ArticleEditorScreen({super.key, this.article});

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _imageUrl;
  late final TextEditingController _author;
  late String _category;
  bool _saving = false;
  late String _status;
  final List<TextEditingController> _imageControllers = [];

  bool get _isEdit => widget.article != null;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _title    = TextEditingController(text: a?.title ?? '');
    _content  = TextEditingController(text: a?.content ?? '');
    _imageUrl = TextEditingController(text: a?.imageUrl ?? '');
    _author   = TextEditingController(text: a?.authorName ?? 'Rédaction DVCR');
    _category = a?.category ?? _kCategories.first;
    _status   = a?.status ?? 'published';
    for (final url in (a?.images ?? [])) {
      _imageControllers.add(TextEditingController(text: url));
    }
  }

  @override
  void dispose() {
    _title.dispose(); _content.dispose();
    _imageUrl.dispose(); _author.dispose();
    for (final c in _imageControllers) c.dispose();
    super.dispose();
  }

  String _fixWixUrl(String url) {
    if (url.isEmpty) return url;
    if (!url.contains('static.wixstatic.com/media')) return url;
    // Remplace enc_avif par enc_jpg (Flutter ne supporte pas AVIF)
    url = url.replaceAll('enc_avif,quality_auto', 'enc_jpg');
    url = url.replaceAll('enc_avif', 'enc_jpg');
    // Si pas encore transformé, ajoute le suffixe
    if (!url.contains('/v1/')) {
      final filename = url.split('/').last;
      url = '$url/v1/fill/w_740,h_493,al_c,q_85,enc_jpg/$filename';
    }
    return url;
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final imgs = _imageControllers
          .map((c) => _fixWixUrl(c.text.trim()))
          .where((s) => s.isNotEmpty)
          .toList();
      if (_isEdit) {
        await ArticleService.update(
          widget.article!.id,
          title:      _title.text.trim(),
          content:    _content.text.trim(),
          category:   _category,
          imageUrl:   _imageUrl.text.trim().isEmpty ? null : _fixWixUrl(_imageUrl.text.trim()),
          authorName: _author.text.trim(),
          status:     status,
          images:     imgs,
        );
      } else {
        await ArticleService.create(
          title:      _title.text.trim(),
          content:    _content.text.trim(),
          category:   _category,
          imageUrl:   _imageUrl.text.trim().isEmpty ? null : _fixWixUrl(_imageUrl.text.trim()),
          authorName: _author.text.trim(),
          status:     status,
          images:     imgs,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _kGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Modifier l\'article' : 'Nouvel article',
          style: GoogleFonts.oswald(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kGreen,
          ),
        ),
        actions: _saving
            ? const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _kGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => _save('draft'),
                  child: Text(
                    'Brouillon',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kMuted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _save('published'),
                  child: Text(
                    'Publier',
                    style: GoogleFonts.oswald(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kRed,
                    ),
                  ),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Catégorie
            Text('Catégorie', style: _label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _kCategories.map((cat) {
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _kRed : _kCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? _kRed : _kBorder, width: 1),
                    ),
                    child: Text(cat,
                      style: GoogleFonts.barlow(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.white54)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Titre
            Text('Titre *', style: _label),
            const SizedBox(height: 8),
            _Field(controller: _title, hint: 'Titre de l\'article', maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 16),

            // Contenu
            Text('Contenu *', style: _label),
            const SizedBox(height: 8),
            _Field(controller: _content, hint: 'Écris ton article ici...', maxLines: 12,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 16),

            // Image URL
            Text('Image (URL)', style: _label),
            const SizedBox(height: 8),
            _Field(controller: _imageUrl, hint: 'https://...'),
            const SizedBox(height: 16),

            // Auteur
            Text('Auteur', style: _label),
            const SizedBox(height: 8),
            _Field(controller: _author, hint: 'Rédaction DVCR'),
            const SizedBox(height: 20),

            // Photos dans l'article
            Row(
              children: [
                Text('Photos (URLs Wix)', style: _label),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() =>
                    _imageControllers.add(TextEditingController())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      '+ Ajouter',
                      style: GoogleFonts.barlow(
                        fontSize: 11,
                        color: _kGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._imageControllers.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _Field(controller: e.value, hint: 'https://...')),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      e.value.dispose();
                      _imageControllers.removeAt(e.key);
                    }),
                    child: const Icon(Icons.close, color: _kMuted, size: 20),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  TextStyle get _label => GoogleFonts.barlow(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: Colors.white54, letterSpacing: 0.5);
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.barlow(fontSize: 14, color: _kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.barlow(fontSize: 14, color: _kMuted),
        filled: true,
        fillColor: _kCardSoft,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGreen, width: 1.5),
        ),
      ),
    );
  }
}
