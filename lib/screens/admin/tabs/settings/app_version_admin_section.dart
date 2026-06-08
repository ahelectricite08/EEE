import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/app_version_policy_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';

/// Admin : mises à jour store (`app_config/app_version`).
///
/// La pause des notifications est dans le **tableau de bord** (mode maintenance),
/// pas ici.
class AppVersionAdminSection extends StatefulWidget {
  const AppVersionAdminSection({super.key});

  @override
  State<AppVersionAdminSection> createState() => _AppVersionAdminSectionState();
}

class _AppVersionAdminSectionState extends State<AppVersionAdminSection> {
  bool _enabled = false;
  final _titleRequiredCtrl = TextEditingController();
  final _messageRequiredCtrl = TextEditingController();
  final _titleOptionalCtrl = TextEditingController();
  final _messageOptionalCtrl = TextEditingController();
  final _minBuildAndroidCtrl = TextEditingController();
  final _minBuildIosCtrl = TextEditingController();
  final _latestBuildAndroidCtrl = TextEditingController();
  final _latestBuildIosCtrl = TextEditingController();
  final _minVersionAndroidCtrl = TextEditingController();
  final _minVersionIosCtrl = TextEditingController();
  final _storeAndroidCtrl = TextEditingController(
    text: AppVersionPolicyService.defaultStoreAndroid,
  );
  final _storeIosCtrl = TextEditingController(
    text: AppVersionPolicyService.defaultStoreIos,
  );
  final _imageUrlCtrl = TextEditingController();
  int _imagePreviewRevision = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _imageUrlCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _titleRequiredCtrl.dispose();
    _messageRequiredCtrl.dispose();
    _titleOptionalCtrl.dispose();
    _messageOptionalCtrl.dispose();
    _minBuildAndroidCtrl.dispose();
    _minBuildIosCtrl.dispose();
    _latestBuildAndroidCtrl.dispose();
    _latestBuildIosCtrl.dispose();
    _minVersionAndroidCtrl.dispose();
    _minVersionIosCtrl.dispose();
    _storeAndroidCtrl.dispose();
    _storeIosCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await AppVersionPolicyService.ref.get();
      final d = snap.data() ?? {};
      _enabled = d['enabled'] == true;
      _titleRequiredCtrl.text =
          (d['titleRequired'] as String?) ?? (d['title'] as String?) ?? '';
      _messageRequiredCtrl.text =
          (d['messageRequired'] as String?) ?? (d['message'] as String?) ?? '';
      _titleOptionalCtrl.text = (d['titleOptional'] as String?) ?? '';
      _messageOptionalCtrl.text = (d['messageOptional'] as String?) ?? '';
      _minBuildAndroidCtrl.text = '${d['minBuildAndroid'] ?? ''}';
      _minBuildIosCtrl.text = '${d['minBuildIos'] ?? ''}';
      _latestBuildAndroidCtrl.text = '${d['latestBuildAndroid'] ?? ''}';
      _latestBuildIosCtrl.text = '${d['latestBuildIos'] ?? ''}';
      _minVersionAndroidCtrl.text = (d['minVersionAndroid'] as String?) ?? '';
      _minVersionIosCtrl.text = (d['minVersionIos'] as String?) ?? '';
      _storeAndroidCtrl.text =
          (d['storeUrlAndroid'] as String?) ??
          AppVersionPolicyService.defaultStoreAndroid;
      _storeIosCtrl.text =
          (d['storeUrlIos'] as String?) ??
          AppVersionPolicyService.defaultStoreIos;
      _imageUrlCtrl.text = (d['updateImageUrl'] as String?) ?? '';
      final updated = d['updatedAt'];
      if (updated is Timestamp) {
        _imagePreviewRevision = updated.millisecondsSinceEpoch;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final latestA = int.tryParse(_latestBuildAndroidCtrl.text.trim());
    final latestI = int.tryParse(_latestBuildIosCtrl.text.trim());
    if (_enabled && latestA == null && latestI == null) {
      final minA = int.tryParse(_minBuildAndroidCtrl.text.trim());
      if (minA != null) {
        _latestBuildAndroidCtrl.text = '${minA + 1}';
      }
    }
    final imageUrl = _imageUrlCtrl.text.trim();
    if (imageUrl.isNotEmpty && looksLikeWixPageNotDirectImage(imageUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'URL Wix invalide : colle le lien direct static.wixstatic.com/… '
              '(fichier .jpg ou .webp), pas une page du site.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: adminRed,
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await AppVersionPolicyService.savePolicy({
        'enabled': _enabled,
        'titleRequired': _titleRequiredCtrl.text.trim(),
        'messageRequired': _messageRequiredCtrl.text.trim(),
        'titleOptional': _titleOptionalCtrl.text.trim(),
        'messageOptional': _messageOptionalCtrl.text.trim(),
        'minBuildAndroid': int.tryParse(_minBuildAndroidCtrl.text.trim()),
        'minBuildIos': int.tryParse(_minBuildIosCtrl.text.trim()),
        'latestBuildAndroid': int.tryParse(_latestBuildAndroidCtrl.text.trim()),
        'latestBuildIos': int.tryParse(_latestBuildIosCtrl.text.trim()),
        'minVersionAndroid': _minVersionAndroidCtrl.text.trim(),
        'minVersionIos': _minVersionIosCtrl.text.trim(),
        'storeUrlAndroid': _storeAndroidCtrl.text.trim(),
        'storeUrlIos': _storeIosCtrl.text.trim(),
        'updateImageUrl': _imageUrlCtrl.text.trim(),
        // Champs obsolètes — désactivés pour éviter toute confusion.
        'maintenanceMode': false,
        'forceUpdate': FieldValue.delete(),
      });
      if (mounted) {
        setState(() {
          _imagePreviewRevision = DateTime.now().millisecondsSinceEpoch;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Politique de mise à jour enregistrée',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: adminGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter(fontSize: 13)),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: adminOrange, strokeWidth: 2),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MISES À JOUR APP (STORE)',
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: adminOrange,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Après chaque publication Play Store / App Store : incrémente le +N dans '
            'pubspec.yaml (ex. 1.0.1+20), puis configure les builds ci-dessous.\n\n'
            '• Build obligatoire → écran bloquant + lien store\n'
            '• Dernier build publié → bannière « Mettre à jour » avec « Plus tard »\n\n'
            'Pour couper les notifications (tests, maintenance), utilise le '
            'mode maintenance du tableau de bord — pas cette section.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.45),
          ),
          const SizedBox(height: 12),
          _switchRow('Activer le contrôle de version', _enabled, (v) {
            setState(() => _enabled = v);
          }),
          const SizedBox(height: 12),
          _sectionLabel('Visuel Wix (bannière + écran obligatoire)'),
          const SizedBox(height: 6),
          _field(
            'URL image Wix (directe)',
            _imageUrlCtrl,
            hint: 'https://static.wixstatic.com/media/….jpg',
          ),
          if (looksLikeWixPageNotDirectImage(_imageUrlCtrl.text)) ...[
            const SizedBox(height: 6),
            Text(
              '⚠ Lien page Wix détecté — utilise static.wixstatic.com (image .jpg / .webp).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: adminRed,
                height: 1.35,
              ),
            ),
          ],
          if (_imageUrlCtrl.text.trim().isNotEmpty &&
              !looksLikeWixPageNotDirectImage(_imageUrlCtrl.text)) ...[
            const SizedBox(height: 8),
            adminBoundedImagePreview(
              url: _imageUrlCtrl.text,
              revisionMillis: _imagePreviewRevision,
              maxHeight: 140,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Aucun upload : colle uniquement le lien direct Wix '
            '(static.wixstatic.com/… .jpg ou .webp), comme pour les visuels partage / accueil. '
            'Tu changes l’URL ici → l’app mobile affiche la nouvelle image sans republier.',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Obligatoire (bloque l’app)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Build min. Android (+N)',
                  _minBuildAndroidCtrl,
                  keyboard: TextInputType.number,
                  hint: 'ex. 18',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  'Build min. iOS (+N)',
                  _minBuildIosCtrl,
                  keyboard: TextInputType.number,
                  hint: 'ex. 18',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _field(
            'Titre écran obligatoire (vide = défaut)',
            _titleRequiredCtrl,
          ),
          const SizedBox(height: 8),
          _field(
            'Message écran obligatoire',
            _messageRequiredCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _sectionLabel('Recommandée (bannière, non bloquante)'),
          const SizedBox(height: 4),
          Text(
            'Obligatoire pour la bannière : renseigne un numéro strictement supérieur '
            'au build installé sur le téléphone (pubspec actuel : +20 → mets 21 ici). '
            'Sans APK récent contenant la bannière, rien ne s’affichera sur le mobile.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: adminOrange.withAlpha(220),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _field(
                  'Dernier build Android',
                  _latestBuildAndroidCtrl,
                  keyboard: TextInputType.number,
                  hint: 'ex. 20',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  'Dernier build iOS',
                  _latestBuildIosCtrl,
                  keyboard: TextInputType.number,
                  hint: 'ex. 20',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _field('Titre bannière (vide = défaut)', _titleOptionalCtrl),
          const SizedBox(height: 8),
          _field('Message bannière', _messageOptionalCtrl, maxLines: 2),
          const SizedBox(height: 14),
          _sectionLabel('Secours (si builds vides)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _field('Version min. Android', _minVersionAndroidCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _field('Version min. iOS', _minVersionIosCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          _field('URL Play Store', _storeAndroidCtrl),
          const SizedBox(height: 8),
          _field('URL App Store', _storeIosCtrl),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() {
                        final minA =
                            int.tryParse(_minBuildAndroidCtrl.text.trim());
                        final minI = int.tryParse(_minBuildIosCtrl.text.trim());
                        _latestBuildAndroidCtrl.text =
                            '${(minA ?? 19) + 1}';
                        _latestBuildIosCtrl.text = '${(minI ?? 19) + 1}';
                      });
                    },
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: Text(
                'Préremplir bannière (build +1)',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: adminOrange,
                side: BorderSide(color: adminOrange.withAlpha(100)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                'Enregistrer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: adminOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: adminTextPrimary,
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: adminGrey),
        filled: true,
        fillColor: adminBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: adminBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: adminBorder),
        ),
      ),
    );
  }
}
