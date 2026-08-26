import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Encart « Propulsé par » du hub Pronos (`app_config/powered_by_partner`).
class PoweredByPartnerAdminSection extends StatefulWidget {
  const PoweredByPartnerAdminSection({super.key});

  @override
  State<PoweredByPartnerAdminSection> createState() =>
      _PoweredByPartnerAdminSectionState();
}

class _PoweredByPartnerAdminSectionState
    extends State<PoweredByPartnerAdminSection> {
  final _imageUrlCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _poweredByTitleCtrl = TextEditingController();
  final _pronoPrizeCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _pronoEncartEnabled = true;
  int _pbRevisionMillis = 0;
  StreamSubscription<PoweredByPartnerSettings>? _sub;

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void initState() {
    super.initState();
    void bump() => setState(() {});
    _imageUrlCtrl.addListener(bump);
    _sub = AppSettingsService.poweredByPartnerStream().listen((s) {
      if (!mounted) return;
      _sync(_imageUrlCtrl, s.imageUrl);
      _sync(_taglineCtrl, s.tagline);
      _sync(_badgeCtrl, s.badgeLabel);
      _sync(_sectionCtrl, s.sectionLabel);
      _sync(_poweredByTitleCtrl, s.poweredByTitle);
      _sync(_pronoPrizeCtrl, s.pronoPrizeHint);
      setState(() {
        _loading = false;
        _pbRevisionMillis = s.revisionMillis;
        _pronoEncartEnabled = s.pronoPartnerEncartEnabled;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _imageUrlCtrl.dispose();
    _taglineCtrl.dispose();
    _badgeCtrl.dispose();
    _sectionCtrl.dispose();
    _poweredByTitleCtrl.dispose();
    _pronoPrizeCtrl.dispose();
    super.dispose();
  }

  String _d(String v, String fallback) =>
      v.trim().isEmpty ? fallback : v.trim();

  Widget _imagePreview(String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    final warn = remoteImageAdminWarning(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warn != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warn,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.orange.shade900,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        adminBoundedImagePreview(
          url: url,
          revisionMillis: _pbRevisionMillis,
          aspectRatio: 3 / 2,
          maxWidth: 280,
          maxHeight: 132,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'ENCART « PROPULSÉ PAR » (PRONO)',
      icon: Icons.electric_bolt_rounded,
      color: adminGreen,
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: adminBlue.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminBlue.withAlpha(60)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.aspect_ratio_rounded,
                          size: 16,
                          color: adminBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Encart en bas de l’onglet Pronos championnat dans l’app. '
                            'URL directe image (static.wixstatic.com/…). '
                            'Pas de lien Canva.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminGrey,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'PRONO',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: adminGreen,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Afficher l’encart partenaire (Pronos)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _pronoEncartEnabled
                          ? 'Visible chez les membres'
                          : 'Masqué chez les membres',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    value: _pronoEncartEnabled,
                    activeThumbColor: adminGold,
                    onChanged: (v) => setState(() => _pronoEncartEnabled = v),
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _badgeCtrl,
                    label: 'Pastille (ex. PARTENAIRE OFFICIEL)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _sectionCtrl,
                    label: 'Surtitre (ex. PRONOSTIC)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _poweredByTitleCtrl,
                    label: 'Titre (ex. PROPULSÉ PAR)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _taglineCtrl,
                    label: 'Sous-titre / ligne partenaire',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _pronoPrizeCtrl,
                    label: 'Texte lot classement (optionnel, sous l’encart prono)',
                    maxLines: 3,
                    hint: 'Ex. Le 1er du classement remporte …',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _imageUrlCtrl,
                    label: 'URL image partenaire',
                  ),
                  if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _imagePreview(_imageUrlCtrl.text),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await AppSettingsService.savePoweredByPartner(
                                PoweredByPartnerSettings(
                                  imageUrl: _imageUrlCtrl.text.trim(),
                                  tagline: _d(
                                    _taglineCtrl.text,
                                    PoweredByPartnerSettings.defaultTagline,
                                  ),
                                  badgeLabel: _d(
                                    _badgeCtrl.text,
                                    PoweredByPartnerSettings.defaultBadgeLabel,
                                  ),
                                  sectionLabel: _d(
                                    _sectionCtrl.text,
                                    PoweredByPartnerSettings.defaultSectionLabel,
                                  ),
                                  poweredByTitle: _d(
                                    _poweredByTitleCtrl.text,
                                    PoweredByPartnerSettings.defaultPoweredByTitle,
                                  ),
                                  pronoPrizeHint: _pronoPrizeCtrl.text.trim(),
                                  pronoPartnerEncartEnabled: _pronoEncartEnabled,
                                ),
                              );
                              if (mounted) {
                                setState(() => _saving = false);
                              }
                            },
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
