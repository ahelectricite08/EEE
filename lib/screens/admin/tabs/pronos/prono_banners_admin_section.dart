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
  final _leaguesSlab = TextEditingController();
  final _standingSlab = TextEditingController();
  final _predictSlab = TextEditingController();
  final _xiSlab = TextEditingController();
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
    _leaguesSlab.addListener(bump);
    _standingSlab.addListener(bump);
    _predictSlab.addListener(bump);
    _xiSlab.addListener(bump);
    _sub = AppSettingsService.pronoBannersStream().listen((s) {
      if (!mounted) return;
      _sync(_home, s.homeHeroUrl);
      _sync(_matches, s.matchesHeroUrl);
      _sync(_progress, s.progressHeroUrl);
      _sync(_social, s.socialHeroUrl);
      _sync(_leaguesSlab, s.leaguesSlabUrl);
      _sync(_standingSlab, s.standingSlabUrl);
      _sync(_predictSlab, s.predictSlabUrl);
      _sync(_xiSlab, s.xiSlabUrl);
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
    _leaguesSlab.dispose();
    _standingSlab.dispose();
    _predictSlab.dispose();
    _xiSlab.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final urls = [
      _home.text.trim(),
      _matches.text.trim(),
      _progress.text.trim(),
      _social.text.trim(),
      _leaguesSlab.text.trim(),
      _standingSlab.text.trim(),
      _predictSlab.text.trim(),
      _xiSlab.text.trim(),
    ];
    final warn = firstRemoteImageAdminWarning(urls);
    if (warn != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warn, style: GoogleFonts.inter()),
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
        leaguesSlabUrl: urls[4],
        standingSlabUrl: urls[5],
        predictSlabUrl: urls[6],
        xiSlabUrl: urls[7],
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _groupTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: adminGold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _urlRow({
    required String label,
    required TextEditingController ctrl,
    required String hint,
  }) {
    final url = ctrl.text.trim();
    final warn = remoteImageAdminWarning(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminField(ctrl: ctrl, label: label, hint: hint),
        if (warn != null) ...[
          const SizedBox(height: 6),
          Text(
            warn,
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
                    'Photos du module Pronos : les bandeaux hero en haut de '
                    'page, et les fonds des blocs sombres. Champ vide = visuel '
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
                  _groupTitle('Bandeaux hero (haut de page)'),
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
                  const SizedBox(height: 18),
                  _groupTitle('Fonds des blocs sombres'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Ces trois photos remplacent le fond vert / bordeaux des '
                      'blocs. Un voile sombre est appliqué automatiquement pour '
                      'garder les chiffres lisibles : choisis des images plutôt '
                      'larges, le sujet au centre. Champ vide = matière d’encre '
                      'par défaut (aucun rectangle vide).',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _urlRow(
                    label: 'Ligues privées — leaguesSlabUrl',
                    ctrl: _leaguesSlab,
                    hint: 'Comptoir « Rejoindre un salon » + en-tête de ligue',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Ta place dans le classement — standingSlabUrl',
                    ctrl: _standingSlab,
                    hint: 'Bandeau de rang du classement global',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'Feuille de prono — predictSlabUrl',
                    ctrl: _predictSlab,
                    hint: 'Plateau de score d’un match (saisie du prono)',
                  ),
                  const SizedBox(height: 12),
                  _urlRow(
                    label: 'XI probable · Ta sélection — xiSlabUrl',
                    ctrl: _xiSlab,
                    hint: 'Tableau d’affichage du XI (fiche match → Composition)',
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
