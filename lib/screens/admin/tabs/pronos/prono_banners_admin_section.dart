import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Admin — bannières hero Pronos (`app_config/prono_banners`).
/// Accueil / Matchs / Progression / Social — URL Wix directe ou vide = asset local.
class PronoBannersAdminSection extends StatefulWidget {
  const PronoBannersAdminSection({super.key});

  @override
  State<PronoBannersAdminSection> createState() =>
      _PronoBannersAdminSectionState();
}

class _PronoBannersAdminSectionState extends State<PronoBannersAdminSection> {
  final _home = TextEditingController();
  final _matches = TextEditingController();
  final _progress = TextEditingController();
  final _social = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int _revisionMillis = 0;
  StreamSubscription<PronoBannersSettings>? _sub;

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void initState() {
    super.initState();
    void bump() => setState(() {});
    _home.addListener(bump);
    _matches.addListener(bump);
    _progress.addListener(bump);
    _social.addListener(bump);
    _sub = AppSettingsService.pronoBannersStream().listen((s) {
      if (!mounted) return;
      _sync(_home, s.homeHeroUrl);
      _sync(_matches, s.matchesHeroUrl);
      _sync(_progress, s.progressHeroUrl);
      _sync(_social, s.socialHeroUrl);
      setState(() {
        _revisionMillis = s.revisionMillis;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _home.dispose();
    _matches.dispose();
    _progress.dispose();
    _social.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final urls = [
      _home.text.trim(),
      _matches.text.trim(),
      _progress.text.trim(),
      _social.text.trim(),
    ];
    final bad = urls.where(looksLikeWixPageNotDirectImage).toList();
    if (bad.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Une URL ressemble à une page Wix, pas une image directe '
            '(utilisez static.wixstatic.com/…).',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await AppSettingsService.savePronoBanners(
      PronoBannersSettings(
        homeHeroUrl: urls[0],
        matchesHeroUrl: urls[1],
        progressHeroUrl: urls[2],
        socialHeroUrl: urls[3],
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _urlRow({
    required String label,
    required TextEditingController ctrl,
    required String hint,
  }) {
    final url = ctrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminField(ctrl: ctrl, label: label, hint: hint),
        if (looksLikeWixPageNotDirectImage(url)) ...[
          const SizedBox(height: 6),
          Text(
            'URL suspecte (page Wix ?) — utilise le lien direct '
            '`static.wixstatic.com/...`.',
            style: GoogleFonts.inter(fontSize: 11, color: adminRed, height: 1.35),
          ),
        ],
        if (url.isNotEmpty) ...[
          const SizedBox(height: 8),
          adminBoundedImagePreview(
            url: url,
            revisionMillis: _revisionMillis,
            aspectRatio: 16 / 9,
            maxWidth: 320,
            maxHeight: 120,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'BANNIÈRES PRONOS',
      icon: Icons.image_rounded,
      color: AdminUniverse.jeux.color,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photos des bandeaux hero Pronos. Champ vide = image locale '
                    'par défaut. Wix : URL directe static.wixstatic.com '
                    '(fichier .jpg / .webp), pas la page du site.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'app_config/${PronoBannersSettings.firestoreDocId}',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Accueil — homeHeroUrl',
                    ctrl: _home,
                    hint: 'https://static.wixstatic.com/media/...',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Matchs — matchesHeroUrl (optionnel)',
                    ctrl: _matches,
                    hint: 'Vide = asset local',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Progression — progressHeroUrl (optionnel)',
                    ctrl: _progress,
                    hint: 'Vide = asset local',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Social — socialHeroUrl (optionnel)',
                    ctrl: _social,
                    hint: 'Vide = asset local',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: adminGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'ENREGISTRER',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
