import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/donation_banner.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

/// Admin — bannières « Soutenez DVCR » / sponsors (`app_config/soutenez_dvcr_banners`).
class SoutenezDvcrBannersAdminSection extends StatefulWidget {
  const SoutenezDvcrBannersAdminSection({super.key});

  @override
  State<SoutenezDvcrBannersAdminSection> createState() =>
      _SoutenezDvcrBannersAdminSectionState();
}

class _SlotEditors {
  bool enabled;
  final TextEditingController imageUrl;
  final TextEditingController badgeLabel;
  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController ctaLabel;
  final TextEditingController ctaUrl;
  final TextEditingController sponsorName;

  _SlotEditors({
    required this.enabled,
    required this.imageUrl,
    required this.badgeLabel,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.ctaUrl,
    required this.sponsorName,
  });

  SoutenezDvcrBannerSlotConfig toConfig() => SoutenezDvcrBannerSlotConfig(
        enabled: enabled,
        imageUrl: imageUrl.text.trim(),
        badgeLabel: badgeLabel.text.trim(),
        title: title.text.trim(),
        subtitle: subtitle.text.trim(),
        ctaLabel: ctaLabel.text.trim(),
        ctaUrl: ctaUrl.text.trim(),
        sponsorName: sponsorName.text.trim(),
      );

  void dispose() {
    imageUrl.dispose();
    badgeLabel.dispose();
    title.dispose();
    subtitle.dispose();
    ctaLabel.dispose();
    ctaUrl.dispose();
    sponsorName.dispose();
  }
}

class _SoutenezDvcrBannersAdminSectionState
    extends State<SoutenezDvcrBannersAdminSection> {
  final Map<SoutenezDvcrBannerSlot, _SlotEditors> _editors = {};
  bool _loading = true;
  bool _saving = false;
  int _revisionMillis = 0;
  String _supportUrlFallback = '';
  StreamSubscription<SoutenezDvcrBannersSettings>? _sub;
  StreamSubscription<SupportSettings>? _supportSub;
  SoutenezDvcrBannerSlot? _expanded = SoutenezDvcrBannerSlot.home;

  static const _slotMeta = <SoutenezDvcrBannerSlot, (String, String)>{
    SoutenezDvcrBannerSlot.home: ('Accueil', 'home'),
    SoutenezDvcrBannerSlot.profile: ('Profil', 'profile'),
    SoutenezDvcrBannerSlot.live: ('DVCR TV / Live', 'live'),
    SoutenezDvcrBannerSlot.articles: ('Actus', 'articles'),
  };

  void _syncCtrl(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  _SlotEditors _createEditor({required bool enabled}) {
    return _SlotEditors(
      enabled: enabled,
      imageUrl: TextEditingController()..addListener(_bump),
      badgeLabel: TextEditingController()..addListener(_bump),
      title: TextEditingController()..addListener(_bump),
      subtitle: TextEditingController()..addListener(_bump),
      ctaLabel: TextEditingController()..addListener(_bump),
      ctaUrl: TextEditingController()..addListener(_bump),
      sponsorName: TextEditingController()..addListener(_bump),
    );
  }

  void _applySettings(SoutenezDvcrBannersSettings s) {
    for (final slot in SoutenezDvcrBannerSlot.values) {
      final raw = s.forSlot(slot);
      final d = SoutenezDvcrBannerSlotConfig.defaultsFor(slot);
      final e = _editors.putIfAbsent(
        slot,
        () => _createEditor(enabled: raw.enabled),
      );
      e.enabled = raw.enabled;
      _syncCtrl(e.imageUrl, raw.imageUrl);
      _syncCtrl(
        e.badgeLabel,
        raw.badgeLabel.isNotEmpty ? raw.badgeLabel : d.badgeLabel,
      );
      _syncCtrl(e.title, raw.title.isNotEmpty ? raw.title : d.title);
      _syncCtrl(
        e.subtitle,
        raw.subtitle.isNotEmpty ? raw.subtitle : d.subtitle,
      );
      _syncCtrl(e.ctaLabel, raw.ctaLabel);
      _syncCtrl(e.ctaUrl, raw.ctaUrl);
      _syncCtrl(e.sponsorName, raw.sponsorName);
    }
    _revisionMillis = s.revisionMillis;
  }

  @override
  void initState() {
    super.initState();
    for (final slot in SoutenezDvcrBannerSlot.values) {
      _editors[slot] = _createEditor(enabled: true);
    }
    _sub = AppSettingsService.soutenezDvcrBannersStream().listen((s) {
      if (!mounted) return;
      setState(() {
        _applySettings(s);
        _loading = false;
      });
    });
    _supportSub = AppSettingsService.supportStream().listen((s) {
      if (!mounted) return;
      setState(() => _supportUrlFallback = s.supportUrl);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _supportSub?.cancel();
    for (final e in _editors.values) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final imageUrls =
        _editors.values.map((e) => e.imageUrl.text.trim()).toList();
    final bad = imageUrls.where(looksLikeWixPageNotDirectImage).toList();
    if (bad.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Une URL image ressemble à une page Wix, pas une image directe '
            '(utilisez static.wixstatic.com/…).',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final settings = SoutenezDvcrBannersSettings(
      home: _editors[SoutenezDvcrBannerSlot.home]!.toConfig(),
      profile: _editors[SoutenezDvcrBannerSlot.profile]!.toConfig(),
      live: _editors[SoutenezDvcrBannerSlot.live]!.toConfig(),
      articles: _editors[SoutenezDvcrBannerSlot.articles]!.toConfig(),
    );
    await AppSettingsService.saveSoutenezDvcrBanners(settings);
    if (mounted) setState(() => _saving = false);
  }

  Widget _slotPanel(SoutenezDvcrBannerSlot slot) {
    final meta = _slotMeta[slot]!;
    final e = _editors[slot]!;
    final open = _expanded == slot;
    final imageUrl = e.imageUrl.text.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expanded = open ? null : slot;
            }),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Switch(
                    value: e.enabled,
                    activeThumbColor: adminGold,
                    onChanged: (v) => setState(() => e.enabled = v),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.$1.toUpperCase(),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'slot: ${meta.$2}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: adminGrey,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonationBanner(
                    slot: slot,
                    compact: slot == SoutenezDvcrBannerSlot.live,
                    preview: e.toConfig(),
                    previewRevisionMillis: _revisionMillis,
                    previewSupportUrlFallback: _supportUrlFallback,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: e.imageUrl,
                    label: 'URL photo (Wix static…)',
                    hint: 'Vide = image locale par défaut',
                  ),
                  if (looksLikeWixPageNotDirectImage(imageUrl)) ...[
                    const SizedBox(height: 6),
                    Text(
                      'URL suspecte (page Wix ?) — utilise le lien direct '
                      '`static.wixstatic.com/...`.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminRed,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  AdminField(ctrl: e.badgeLabel, label: 'Badge (ex. DVCR)'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: e.title, label: 'Titre'),
                  const SizedBox(height: 10),
                  AdminField(ctrl: e.subtitle, label: 'Sous-titre'),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: e.sponsorName,
                    label: 'Nom sponsor (optionnel)',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: e.ctaLabel,
                    label: 'Texte CTA (optionnel)',
                    hint: 'Ex. Faire un don',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: e.ctaUrl,
                    label: 'Lien CTA (optionnel)',
                    hint: 'Vide = lien Support global (HelloAsso…)',
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
    return SettingsCard(
      title: 'BANNIÈRES SOUTENEZ DVCR',
      icon: Icons.favorite_rounded,
      color: adminRed,
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
                    'Adapte chaque bannière (photo, titres, CTA) pour un '
                    'emplacement. Prêt pour des sponsors payants. '
                    'Wix : URL directe static.wixstatic.com '
                    '(fichier .jpg / .webp), pas la page du site.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'app_config/${SoutenezDvcrBannersSettings.firestoreDocId}',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  const SizedBox(height: 12),
                  ...SoutenezDvcrBannerSlot.values.map(_slotPanel),
                  const SizedBox(height: 4),
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
