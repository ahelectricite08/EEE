import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

class _HeroField {
  const _HeroField(this.slot, this.group, this.label, this.hint);
  final HubHeroSlot slot;
  final String group;
  final String label;
  final String hint;
}

const _kHeroFields = <_HeroField>[
  _HeroField(
    HubHeroSlot.reseaux,
    'Page Nos réseaux',
    'Nos réseaux',
    'Photo du bandeau (globe). Vide = IMG_0842',
  ),
  _HeroField(HubHeroSlot.home, 'Onglets', 'Accueil', 'Vide = bannière actuelle'),
  _HeroField(HubHeroSlot.tv, 'Onglets', 'DVCR TV', 'Vide = JOURDEMATCH.jpg'),
  _HeroField(
    HubHeroSlot.calendar,
    'Onglets',
    'Calendrier',
    'Vide = photo actuelle',
  ),
  _HeroField(HubHeroSlot.articles, 'Onglets', 'Actus', 'Vide = photo actuelle'),
  _HeroField(
    HubHeroSlot.profile,
    'Onglets',
    'Profil',
    'Vide = carrousel 3 fonds / photo locale',
  ),
  _HeroField(
    HubHeroSlot.community,
    'Onglets',
    'Communauté',
    'Vide = photo actuelle du chat',
  ),
  _HeroField(
    HubHeroSlot.auth,
    'Connexion',
    'Login / espace membres',
    'Vide = photo actuelle',
  ),
  _HeroField(
    HubHeroSlot.guest,
    'Connexion',
    'Écran invité (onglet verrouillé)',
    'Vide = photo actuelle',
  ),
  _HeroField(
    HubHeroSlot.matchDetail,
    'Match',
    'Fiche match (si pas de photo stade)',
    'Vide = photo stade par défaut',
  ),
  _HeroField(
    HubHeroSlot.emission,
    'Match',
    'Émission en direct (accueil)',
    'Vide = IMG_0377',
  ),
];

/// Admin — photos hero de l’app (`app_config/hub_heroes`).
class HubHeroesAdminSection extends StatefulWidget {
  const HubHeroesAdminSection({super.key});

  @override
  State<HubHeroesAdminSection> createState() => _HubHeroesAdminSectionState();
}

class _HubHeroesAdminSectionState extends State<HubHeroesAdminSection> {
  late final Map<HubHeroSlot, TextEditingController> _ctrls;
  bool _loading = true;
  bool _saving = false;
  int _revisionMillis = 0;
  StreamSubscription<HubHeroBannersSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in _kHeroFields) f.slot: TextEditingController(),
    };
    void bump() => setState(() {});
    for (final c in _ctrls.values) {
      c.addListener(bump);
    }
    _sub = AppSettingsService.hubHeroBannersStream().listen((s) {
      if (!mounted) return;
      for (final f in _kHeroFields) {
        final c = _ctrls[f.slot]!;
        final v = s.urlForSlot(f.slot);
        if (c.text != v) c.text = v;
      }
      setState(() {
        _revisionMillis = s.revisionMillis;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final urls = {
      for (final e in _ctrls.entries) e.key: e.value.text.trim(),
    };
    final warn = firstRemoteImageAdminWarning(urls.values);
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
    await AppSettingsService.saveHubHeroBanners(
      HubHeroBannersSettings(
        homeHeroUrl: urls[HubHeroSlot.home] ?? '',
        tvHeroUrl: urls[HubHeroSlot.tv] ?? '',
        calendarHeroUrl: urls[HubHeroSlot.calendar] ?? '',
        articlesHeroUrl: urls[HubHeroSlot.articles] ?? '',
        communityHeroUrl: urls[HubHeroSlot.community] ?? '',
        authHeroUrl: urls[HubHeroSlot.auth] ?? '',
        guestHeroUrl: urls[HubHeroSlot.guest] ?? '',
        matchDetailHeroUrl: urls[HubHeroSlot.matchDetail] ?? '',
        emissionHeroUrl: urls[HubHeroSlot.emission] ?? '',
        profileHeroUrl: urls[HubHeroSlot.profile] ?? '',
        reseauxHeroUrl: urls[HubHeroSlot.reseaux] ?? '',
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _groupTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
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

  Widget _urlRow(_HeroField field) {
    final ctrl = _ctrls[field.slot]!;
    final url = ctrl.text.trim();
    final warn = remoteImageAdminWarning(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminField(ctrl: ctrl, label: field.label, hint: field.hint),
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
      title: 'PHOTOS HERO',
      icon: Icons.photo_size_select_actual_rounded,
      color: AdminUniverse.contenuDiffusion.color,
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
                    'Toutes les grandes photos de l’app. '
                    'Page globe / liens : premier champ « Nos réseaux ». '
                    'Champ vide = image actuelle. Wix : URL directe '
                    'static.wixstatic.com (.jpg / .webp). Pas de liens Canva '
                    '(403 / expiration). Uploadez sur Storage. Pronos → Pronos / '
                    'Visibilité. Profil : photo unique ici + carrousel 3 fonds '
                    'plus bas (les URL carrousel priment si remplies).',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'app_config/${HubHeroBannersSettings.firestoreDocId}',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _kHeroFields.length; i++) ...[
                    if (i == 0 ||
                        _kHeroFields[i].group != _kHeroFields[i - 1].group)
                      _groupTitle(_kHeroFields[i].group),
                    _urlRow(_kHeroFields[i]),
                    const SizedBox(height: 12),
                  ],
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
