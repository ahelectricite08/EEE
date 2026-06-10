import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';

/// Encart partenaire & bandeau lot — écran Esti'DVCR / Coupe du monde.
/// [sectionTitle] : titre affiché dans l'admin (ex: "PARTENAIRE & BANDEAU ESTI'DVCR").
/// [buttonLabel]  : texte du bouton sauvegarder.
/// [bannerLabel]  : libellé du switch bandeau lot.
class WorldCupPartnerAdminSection extends StatefulWidget {
  final String sectionTitle;
  final String buttonLabel;
  final String bannerLabel;

  const WorldCupPartnerAdminSection({
    super.key,
    this.sectionTitle = "PARTENAIRE & BANDEAU CDM",
    this.buttonLabel = 'ENREGISTRER CDM',
    this.bannerLabel = 'Bandeau lot au-dessus des matchs CdM',
  });

  @override
  State<WorldCupPartnerAdminSection> createState() =>
      _WorldCupPartnerAdminSectionState();
}

class _WorldCupPartnerAdminSectionState extends State<WorldCupPartnerAdminSection> {
  final _wcSectionCtrl = TextEditingController();
  final _wcPoweredCtrl = TextEditingController();
  final _wcTaglineCtrl = TextEditingController();
  final _wcImageCtrl = TextEditingController();
  final _wcBadgeCtrl = TextEditingController();
  final _wcPrizeBannerCtrl = TextEditingController();
  final _wcHeroSubtitleCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _wcBannerEnabled = true;
  int _pbRevisionMillis = 0;
  PoweredByPartnerSettings _base = PoweredByPartnerSettings.defaults;
  StreamSubscription<PoweredByPartnerSettings>? _sub;

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void initState() {
    super.initState();
    _sub = AppSettingsService.poweredByPartnerStream().listen((s) {
      if (!mounted) return;
      _base = s;
      _sync(_wcSectionCtrl, s.worldCupSectionLabel);
      _sync(_wcPoweredCtrl, s.worldCupPoweredByTitle);
      _sync(_wcTaglineCtrl, s.worldCupTagline);
      _sync(_wcImageCtrl, s.worldCupImageUrl);
      _sync(_wcBadgeCtrl, s.worldCupBadgeLabel);
      _sync(_wcPrizeBannerCtrl, s.worldCupPrizeBannerText);
      _sync(_wcHeroSubtitleCtrl, s.worldCupHeroSubtitle);
      setState(() {
        _loading = false;
        _pbRevisionMillis = s.revisionMillis;
        _wcBannerEnabled = s.worldCupPrizeBannerEnabled;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _wcSectionCtrl.dispose();
    _wcPoweredCtrl.dispose();
    _wcTaglineCtrl.dispose();
    _wcImageCtrl.dispose();
    _wcBadgeCtrl.dispose();
    _wcPrizeBannerCtrl.dispose();
    _wcHeroSubtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.sectionTitle,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminGold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Champs vides = reprendre les textes / image de l’encart Pronos (Réglages → Application).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            widget.bannerLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: adminTextPrimary,
            ),
          ),
          value: _wcBannerEnabled,
          activeThumbColor: adminGold,
          onChanged: (v) => setState(() => _wcBannerEnabled = v),
        ),
        AdminField(
          ctrl: _wcPrizeBannerCtrl,
          label: 'Texte bandeau lot (vide = défaut app)',
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        AdminField(
          ctrl: _wcHeroSubtitleCtrl,
          label: 'Sous-titre hero CdM (vide = défaut)',
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        AdminField(ctrl: _wcBadgeCtrl, label: 'Pastille (vide = idem prono)'),
        const SizedBox(height: 8),
        AdminField(ctrl: _wcSectionCtrl, label: 'Surtitre (vide = idem prono)'),
        const SizedBox(height: 8),
        AdminField(
          ctrl: _wcPoweredCtrl,
          label: 'Titre « propulsé par » (vide = idem prono)',
        ),
        const SizedBox(height: 8),
        AdminField(ctrl: _wcTaglineCtrl, label: 'Sous-titre (vide = idem prono)'),
        const SizedBox(height: 8),
        AdminField(ctrl: _wcImageCtrl, label: 'URL image (vide = idem prono)'),
        if (_wcImageCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          adminBoundedImagePreview(
            url: _wcImageCtrl.text,
            revisionMillis: _pbRevisionMillis,
            aspectRatio: 3 / 2,
            maxWidth: 260,
            maxHeight: 120,
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: adminGold),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.buttonLabel,
                    style: GoogleFonts.barlowCondensed(
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppSettingsService.savePoweredByPartner(
      PoweredByPartnerSettings(
        imageUrl: _base.imageUrl,
        tagline: _base.tagline,
        badgeLabel: _base.badgeLabel,
        sectionLabel: _base.sectionLabel,
        poweredByTitle: _base.poweredByTitle,
        pronoPrizeHint: _base.pronoPrizeHint,
        worldCupSectionLabel: _wcSectionCtrl.text.trim(),
        worldCupPoweredByTitle: _wcPoweredCtrl.text.trim(),
        worldCupTagline: _wcTaglineCtrl.text.trim(),
        worldCupImageUrl: _wcImageCtrl.text.trim(),
        worldCupBadgeLabel: _wcBadgeCtrl.text.trim(),
        worldCupPrizeBannerText: _wcPrizeBannerCtrl.text.trim(),
        worldCupPrizeBannerEnabled: _wcBannerEnabled,
        worldCupHeroSubtitle: _wcHeroSubtitleCtrl.text.trim(),
      ),
    );
    if (mounted) setState(() => _saving = false);
  }
}
