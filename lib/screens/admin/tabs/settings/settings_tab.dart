import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/dvcr_share_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../services/home_sections_service.dart';
import '../../../../services/role_permissions_service.dart';
import 'fff_season_settings_panel.dart';
import 'extra_admin_sections.dart';
import 'share_text_templates_section.dart';
import 'season_lifecycle_admin_section.dart';

/// Aperçu image réseau dans l’admin : taille plafonnée (évite un rectangle pleine largeur écran).
Widget _adminBoundedImagePreview({
  required String url,
  required int revisionMillis,
  double aspectRatio = 3 / 2,
  double maxWidth = 280,
  double maxHeight = 132,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth;
        final capW = parentW.isFinite ? min(parentW, maxWidth) : maxWidth;
        var w = capW;
        var h = w / aspectRatio;
        if (h > maxHeight) {
          h = maxHeight;
          w = h * aspectRatio;
        }
        return SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              cacheBustedImageUrl(url.trim(), revisionMillis),
              fit: BoxFit.cover,
              headers: kDvcrImageHttpHeaders,
              errorBuilder: (context, error, stackTrace) => Container(
                color: adminGrey.withAlpha(40),
                alignment: Alignment.center,
                child: Text(
                  'Aperçu indisponible',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ── SettingsTab ────────────────────────────────────────────────────────────────
class SettingsTab extends StatefulWidget {
  const SettingsTab();

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this); // APPLICATION, BADGES, PERMISSIONS, SAISON FFF
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: adminOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'PARAMÈTRES',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: TabBar(
            controller: _tc,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: adminOrange.withAlpha(25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: adminOrange.withAlpha(70)),
            ),
            labelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
            labelColor: adminOrange,
            unselectedLabelColor: adminGrey,
            tabs: const [
              Tab(text: 'APPLICATION'),
              Tab(text: 'BADGES RÔLES'),
              Tab(text: 'PERMISSIONS'),
              Tab(text: 'SAISON FFF'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _AppSettingsPanel(),
              _RoleBadgesPanel(),
              _PermissionsPanel(),
              FffSeasonSettingsPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── APPLICATION ────────────────────────────────────────────────────────────────
// Lit et écrit dans les vraies collections lues par l'app :
//   - app_config/support  → supportUrl (DonationBanner)
//   - app_config/chat     → autoModeration (ChatScreen)
//   - app_config/powered_by_partner → encart partenaire **prono** + **Coupe du monde** (textes & image)
//   - app_config/share_card → image optionnelle jointe aux partages réseaux
//   - app_config/share_text_templates → modèles de texte partage (actu/vidéo par catégorie, matchs…)
//   - app_config/profile_hero → 3 URLs de fond bandeau profil (carrousel utilisateur)
class _AppSettingsPanel extends StatelessWidget {
  const _AppSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: const [
        _SupportSection(),
        SizedBox(height: 16),
        _ProfileHeroBackgroundsSection(),
        SizedBox(height: 16),
        _PoweredByPartnerSection(),
        SizedBox(height: 16),
        _ShareCardSection(),
        SizedBox(height: 16),
        ShareTextTemplatesSection(),
        SizedBox(height: 16),
        _ChatModerationSection(),
        SizedBox(height: 16),
        _HomeLiveLayoutSection(),
        SizedBox(height: 20),
        PronoChampionshipHubAdminSection(),
        SizedBox(height: 20),
        WorldCupTabAdminSection(),
        SizedBox(height: 20),
        SeasonLifecycleAdminSection(),
        SizedBox(height: 20),
        FeatureFlagsSection(),
        SizedBox(height: 20),
        CompetitionSeasonsSection(),
      ],
    );
  }
}

class _SupportSection extends StatefulWidget {
  const _SupportSection();

  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection> {
  final _urlCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<SupportSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppSettingsService.supportStream().listen((s) {
      if (!mounted) return;
      if (_urlCtrl.text != s.supportUrl) _urlCtrl.text = s.supportUrl;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'LIEN DON / SUPPORT',
      icon: Icons.favorite_rounded,
      color: adminRed,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL affichée dans la bannière donation et le bouton de soutien.',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                  const SizedBox(height: 10),
                  AdminField(ctrl: _urlCtrl, label: 'URL de don (HelloAsso, PayPal…)'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await AppSettingsService.saveSupport(
                                SupportSettings(supportUrl: _urlCtrl.text.trim()),
                              );
                              if (mounted) setState(() => _saving = false);
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
                                      color: Colors.black, strokeWidth: 2),
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

class _ProfileHeroBackgroundsSection extends StatefulWidget {
  const _ProfileHeroBackgroundsSection();

  @override
  State<_ProfileHeroBackgroundsSection> createState() =>
      _ProfileHeroBackgroundsSectionState();
}

class _ProfileHeroBackgroundsSectionState
    extends State<_ProfileHeroBackgroundsSection> {
  final _url1 = TextEditingController();
  final _url2 = TextEditingController();
  final _url3 = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<ProfileHeroBackgroundSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppSettingsService.profileHeroBackgroundsStream().listen((s) {
      if (!mounted) return;
      void sync(TextEditingController c, String v) {
        if (c.text != v) c.text = v;
      }

      sync(_url1, s.imageUrl1);
      sync(_url2, s.imageUrl2);
      sync(_url3, s.imageUrl3);
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _url1.dispose();
    _url2.dispose();
    _url3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'FONDS PROFIL (CARROUSEL)',
      icon: Icons.photo_library_rounded,
      color: const Color(0xFF2E7D67),
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
                    'Trois images pour le bandeau profil. Champ vide = photo locale '
                    'par défaut. Wix : URL directe static.wixstatic.com (fichier .jpg / .webp).',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                  const SizedBox(height: 10),
                  AdminField(ctrl: _url1, label: 'Fond 1 — URL image'),
                  const SizedBox(height: 8),
                  AdminField(ctrl: _url2, label: 'Fond 2 — URL image'),
                  const SizedBox(height: 8),
                  AdminField(ctrl: _url3, label: 'Fond 3 — URL image'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              final u1 = _url1.text.trim();
                              final u2 = _url2.text.trim();
                              final u3 = _url3.text.trim();
                              final bad = [u1, u2, u3]
                                  .where(looksLikeWixPageNotDirectImage)
                                  .toList();
                              if (bad.isNotEmpty && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Une URL ressemble à une page Wix, pas une image directe.',
                                      style: GoogleFonts.inter(),
                                    ),
                                    backgroundColor: adminRed,
                                  ),
                                );
                                return;
                              }
                              setState(() => _saving = true);
                              await AppSettingsService.saveProfileHeroBackgrounds(
                                ProfileHeroBackgroundSettings(
                                  imageUrl1: u1,
                                  imageUrl2: u2,
                                  imageUrl3: u3,
                                ),
                              );
                              if (mounted) setState(() => _saving = false);
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

class _PoweredByPartnerSection extends StatefulWidget {
  const _PoweredByPartnerSection();

  @override
  State<_PoweredByPartnerSection> createState() =>
      _PoweredByPartnerSectionState();
}

class _PoweredByPartnerSectionState extends State<_PoweredByPartnerSection> {
  final _imageUrlCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _poweredByTitleCtrl = TextEditingController();
  final _pronoPrizeCtrl = TextEditingController();
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
  StreamSubscription<PoweredByPartnerSettings>? _sub;

  void _sync(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  @override
  void initState() {
    super.initState();
    void bump() => setState(() {});
    _imageUrlCtrl.addListener(bump);
    _wcImageCtrl.addListener(bump);
    _sub = AppSettingsService.poweredByPartnerStream().listen((s) {
      if (!mounted) return;
      _sync(_imageUrlCtrl, s.imageUrl);
      _sync(_taglineCtrl, s.tagline);
      _sync(_badgeCtrl, s.badgeLabel);
      _sync(_sectionCtrl, s.sectionLabel);
      _sync(_poweredByTitleCtrl, s.poweredByTitle);
      _sync(_pronoPrizeCtrl, s.pronoPrizeHint);
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
    _imageUrlCtrl.dispose();
    _taglineCtrl.dispose();
    _badgeCtrl.dispose();
    _sectionCtrl.dispose();
    _poweredByTitleCtrl.dispose();
    _pronoPrizeCtrl.dispose();
    _wcSectionCtrl.dispose();
    _wcPoweredCtrl.dispose();
    _wcTaglineCtrl.dispose();
    _wcImageCtrl.dispose();
    _wcBadgeCtrl.dispose();
    _wcPrizeBannerCtrl.dispose();
    _wcHeroSubtitleCtrl.dispose();
    super.dispose();
  }

  String _d(String v, String fallback) =>
      v.trim().isEmpty ? fallback : v.trim();

  Widget _imagePreview(String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (looksLikeWixPageNotDirectImage(url))
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
                    'URL suspecte (page Wix ?) — utilise le lien direct `static.wixstatic.com/...`.',
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
        _adminBoundedImagePreview(
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
    return _SettingsCard(
      title: 'ENCART « PROPULSÉ PAR » (PRONO & CDM)',
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
                            'Même encart sur **Prono** et **Coupe du monde** (bas de liste). '
                            'Hauteur = ratio de ton image. URL **directe** fichier image.\n\n'
                            'Champs **CDM vides** = reprendre texte / image **prono**.',
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
                  const SizedBox(height: 8),
                  AdminField(ctrl: _badgeCtrl, label: 'Pastille (ex. PARTENAIRE OFFICIEL)'),
                  const SizedBox(height: 8),
                  AdminField(ctrl: _sectionCtrl, label: 'Surtitre (ex. PRONOSTIC)'),
                  const SizedBox(height: 8),
                  AdminField(ctrl: _poweredByTitleCtrl, label: 'Titre (ex. PROPULSÉ PAR)'),
                  const SizedBox(height: 8),
                  AdminField(ctrl: _taglineCtrl, label: 'Sous-titre / ligne partenaire'),
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: adminBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'COUPE DU MONDE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: adminGrey,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: adminBorder)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Afficher le bandeau « lot / 1er du classement » au-dessus des matchs',
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
                    label:
                        'Texte du bandeau + ligne ballon sur le hero vert (vide = défaut app)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _wcHeroSubtitleCtrl,
                    label:
                        'Sous-titre sous « COUPE DU MONDE » sur le hero vert (vide = défaut app)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _wcBadgeCtrl,
                    label: 'CDM — pastille (vide = idem prono)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _wcSectionCtrl,
                    label: 'CDM — surtitre (vide = idem prono)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _wcPoweredCtrl,
                    label: 'CDM — titre « propulsé par » (vide = idem prono)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _wcTaglineCtrl,
                    label: 'CDM — sous-titre (vide = idem prono)',
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _wcImageCtrl,
                    label: 'CDM — URL image (vide = idem prono)',
                  ),
                  if (_wcImageCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Aperçu image CDM',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: adminGrey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _imagePreview(_wcImageCtrl.text),
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
                                  worldCupSectionLabel: _wcSectionCtrl.text.trim(),
                                  worldCupPoweredByTitle: _wcPoweredCtrl.text.trim(),
                                  worldCupTagline: _wcTaglineCtrl.text.trim(),
                                  worldCupImageUrl: _wcImageCtrl.text.trim(),
                                  worldCupBadgeLabel: _wcBadgeCtrl.text.trim(),
                                  worldCupPrizeBannerText:
                                      _wcPrizeBannerCtrl.text.trim(),
                                  worldCupPrizeBannerEnabled: _wcBannerEnabled,
                                  worldCupHeroSubtitle:
                                      _wcHeroSubtitleCtrl.text.trim(),
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

class _ShareCardSection extends StatefulWidget {
  const _ShareCardSection();

  @override
  State<_ShareCardSection> createState() => _ShareCardSectionState();
}

class _ShareCardSectionState extends State<_ShareCardSection> {
  final _imageUrlCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int _shareRevisionMillis = 0;
  StreamSubscription<ShareCardSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _imageUrlCtrl.addListener(() => setState(() {}));
    _sub = AppSettingsService.shareCardStream().listen((s) {
      if (!mounted) return;
      if (_imageUrlCtrl.text != s.imageUrl) {
        _imageUrlCtrl.text = s.imageUrl;
      }
      setState(() {
        _loading = false;
        _shareRevisionMillis = s.revisionMillis;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'IMAGE PARTAGES RÉSEAUX',
      icon: Icons.share_rounded,
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
                          Icons.info_outline_rounded,
                          size: 16,
                          color: adminBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'URL d’une image (JPEG/PNG/WebP) jointe en pièce jointe '
                            'quand un utilisateur partage un match, une actu, une vidéo, etc. '
                            'Conseillé : 1200×630 px (style réseau social). Laisser vide = texte seul. '
                            'Les apps réseaux affichent l’aperçu selon leur propre logique.\n\n'
                            'Wix : même règle — lien **direct** `static.wixstatic.com/...`, '
                            'pas l’URL d’une page.',
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
                  AdminField(
                    ctrl: _imageUrlCtrl,
                    label: 'URL image partage (https…)',
                  ),
                  if (_imageUrlCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (looksLikeWixPageNotDirectImage(_imageUrlCtrl.text))
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
                                'URL de page Wix détectée : le partage avec image '
                                'échouera tant que ce n’est pas une URL d’image directe.',
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
                    _adminBoundedImagePreview(
                      url: _imageUrlCtrl.text.trim(),
                      revisionMillis: _shareRevisionMillis,
                      aspectRatio: 1200 / 630,
                      maxWidth: 260,
                      maxHeight: 100,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await AppSettingsService.saveShareCard(
                                ShareCardSettings(
                                  imageUrl: _imageUrlCtrl.text.trim(),
                                ),
                              );
                              DvcrShare.clearSettingsCache();
                              if (mounted) setState(() => _saving = false);
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

class _ChatModerationSection extends StatefulWidget {
  const _ChatModerationSection();

  @override
  State<_ChatModerationSection> createState() => _ChatModerationSectionState();
}

class _ChatModerationSectionState extends State<_ChatModerationSection> {
  final _noticeCtrl = TextEditingController();
  final _wordsCtrl = TextEditingController();
  bool _autoEnabled = false;
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<ChatSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppSettingsService.chatStream().listen((s) {
      if (!mounted) return;
      if (_noticeCtrl.text != s.notice) _noticeCtrl.text = s.notice;
      final words = s.blockedWords.join(', ');
      if (_wordsCtrl.text != words) _wordsCtrl.text = words;
      setState(() {
        _autoEnabled = s.autoModerationEnabled;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noticeCtrl.dispose();
    _wordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final words = _wordsCtrl.text
        .split(',')
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty)
        .toList();
    await AppSettingsService.saveChat(
      ChatSettings(
        autoModerationEnabled: _autoEnabled,
        blockedWords: words,
        notice: _noticeCtrl.text.trim(),
        customEmojis: const [],
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'MODÉRATION CHAT',
      icon: Icons.shield_rounded,
      color: adminBlue,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Les avertissements manuels et les suspensions 24 h du chat se font dans l’app : compte admin ou community manager, appui long sur un message (Avertir / Suspendre). Ici tu configures seulement l’auto-modération (mots bloqués + message automatique).',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Toggle auto-modération
                  Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded,
                          size: 16, color: adminGrey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Auto-modération activée',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: adminTextPrimary),
                        ),
                      ),
                      Switch(
                        value: _autoEnabled,
                        activeColor: adminGold,
                        onChanged: (v) => setState(() => _autoEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AdminField(
                    ctrl: _wordsCtrl,
                    label: 'Mots bloqués (séparés par des virgules)',
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _noticeCtrl,
                    label: 'Message d\'avertissement ({user} = pseudo)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
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
                                      color: Colors.black, strokeWidth: 2),
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

// ── BADGES RÔLES ───────────────────────────────────────────────────────────────
// Lit et écrit dans config/role_badges (AppSettingsService.roleBadgesStream)
class _RoleBadgesPanel extends StatefulWidget {
  const _RoleBadgesPanel();

  @override
  State<_RoleBadgesPanel> createState() => _RoleBadgesPanelState();
}

class _RoleBadgesPanelState extends State<_RoleBadgesPanel> {
  static const _roles = [
    ('admin', 'Admin', Color(0xFFEF5350)),
    ('community_manager', 'Community Manager', Color(0xFF2979FF)),
    ('editor', 'Éditeur', Color(0xFF00BCD4)),
    ('statisticien', 'Statisticien', Color(0xFF9C27B0)),
    ('supporter', 'Supporter', Color(0xFF9E9E9E)),
    ('donateur', 'Fidèle Supporter', Color(0xFF4CAF50)),
    ('partenaire', 'Partenaire', Color(0xFFFF9100)),
    ('team_dvcr', 'Membre DVCR', Color(0xFFC8A436)),
  ];

  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<RoleBadgeSettings>? _sub;

  @override
  void initState() {
    super.initState();
    for (final r in _roles) _ctrls[r.$1] = TextEditingController();
    _sub = AppSettingsService.roleBadgesStream().listen((settings) {
      if (!mounted) return;
      for (final r in _roles) {
        final v = settings.badges[r.$1]?.trim() ?? '';
        if (_ctrls[r.$1]!.text != v) _ctrls[r.$1]!.text = v;
      }
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppSettingsService.saveRoleBadges({
      for (final r in _roles) r.$1: _ctrls[r.$1]!.text.trim(),
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SettingsCard(
          title: 'BADGES DES RÔLES',
          icon: Icons.workspace_premium_rounded,
          color: adminGold,
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        color: adminGold, strokeWidth: 2),
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
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: adminBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emplacement unique : configure les URLs ici (Système → Réglages). Affichage à côté du pseudo dans le chat et sur le profil.',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: adminGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._roles.map((r) {
                        final url = _ctrls[r.$1]!.text.trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: r.$3,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    r.$2.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: r.$3,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (url.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        url,
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 16,
                                                    color: adminGrey),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              AdminField(
                                ctrl: _ctrls[r.$1]!,
                                label: 'URL image badge',
                              ),
                            ],
                          ),
                        );
                      }),
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
                                          color: Colors.black, strokeWidth: 2),
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
        ),
      ],
    );
  }
}

// ── PERMISSIONS ────────────────────────────────────────────────────────────────
// Lit et écrit dans config/role_permissions (RolePermissionsService)
class _PermissionsPanel extends StatelessWidget {
  const _PermissionsPanel();

  static const _roles = [
    {'key': 'admin', 'label': 'Admin', 'emoji': '👑'},
    {'key': 'community_manager', 'label': 'Community Manager', 'emoji': '🛡️'},
    {'key': 'editor', 'label': 'Éditeur', 'emoji': '✏️'},
    {'key': 'statisticien', 'label': 'Statisticien', 'emoji': '📊'},
    {'key': 'team_dvcr', 'label': 'Équipe DVCR', 'emoji': '⚡'},
    {'key': 'partenaire', 'label': 'Partenaire', 'emoji': '🤝'},
    {'key': 'donateur', 'label': 'Donateur', 'emoji': '❤️'},
    {'key': 'supporter', 'label': 'Supporter', 'emoji': '⚽'},
  ];

  @override
  Widget build(BuildContext context) {
    // Utilise le vrai stream de RolePermissionsService → config/role_permissions
    return StreamBuilder<Map<String, List<String>>>(
      stream: RolePermissionsService.stream(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: adminGold));
        }
        final rolesData = snap.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: adminBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les permissions contrôlent l\'accès aux onglets du panel admin. Toute modification est immédiate.',
                      style:
                          GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                  ),
                ],
              ),
            ),
            ..._roles.map((role) {
              final roleKey = role['key'] as String;
              final perms = rolesData[roleKey] ?? <String>[];
              return _RolePermRow(
                roleKey: roleKey,
                label: role['label'] as String,
                emoji: role['emoji'] as String,
                currentPerms: perms,
                allPerms: RolePermissionsService.allPermissions,
              );
            }),
          ],
        );
      },
    );
  }
}

class _RolePermRow extends StatefulWidget {
  final String roleKey;
  final String label;
  final String emoji;
  final List<String> currentPerms;
  final List<String> allPerms;

  const _RolePermRow({
    required this.roleKey,
    required this.label,
    required this.emoji,
    required this.currentPerms,
    required this.allPerms,
  });

  @override
  State<_RolePermRow> createState() => _RolePermRowState();
}

class _RolePermRowState extends State<_RolePermRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.roleKey == 'admin';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _expanded ? adminOrange.withAlpha(60) : adminBorder),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(widget.emoji,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: adminTextPrimary),
                        ),
                        Text(
                          isAdmin
                              ? 'Toutes les permissions'
                              : '${widget.currentPerms.length} permission(s)',
                          style:
                              GoogleFonts.inter(fontSize: 11, color: adminGrey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: adminGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: adminBorder),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.allPerms.map((perm) {
                  final isActive = isAdmin || widget.currentPerms.contains(perm);
                  return GestureDetector(
                    onTap: isAdmin
                        ? null
                        : () async {
                            final newPerms =
                                List<String>.from(widget.currentPerms);
                            if (isActive) {
                              newPerms.remove(perm);
                            } else {
                              newPerms.add(perm);
                            }
                            // Écrit dans config/role_permissions via RolePermissionsService
                            await RolePermissionsService.setRolePermissions(
                                widget.roleKey, newPerms);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isAdmin ? adminGold : adminBlue).withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? (isAdmin ? adminGold : adminBlue).withAlpha(80)
                              : adminBorder,
                        ),
                      ),
                      child: Text(
                        perm.replaceAll('.', ' · '),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? (isAdmin ? adminGold : adminBlue)
                              : adminGrey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeLiveLayoutSection extends StatefulWidget {
  const _HomeLiveLayoutSection();

  @override
  State<_HomeLiveLayoutSection> createState() => _HomeLiveLayoutSectionState();
}

class _HomeLiveLayoutSectionState extends State<_HomeLiveLayoutSection> {
  HomeLayoutHints _hints = HomeLayoutHints.defaults;
  StreamSubscription<HomeLayoutHints>? _sub;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sub = HomeSectionsService.layoutHintsStream().listen((h) {
      if (mounted) setState(() => _hints = h);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _persist(HomeLayoutHints next) async {
    setState(() {
      _hints = next;
      _saving = true;
    });
    try {
      await HomeSectionsService.saveLayoutHints(next);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'HOME — LIVE',
      icon: Icons.live_tv_rounded,
      color: adminOrange,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(
                'Masquer bannière don si live',
                style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
              ),
              subtitle: Text(
                'Quand un match ou une émission est en direct.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              value: _hints.hideDonationBannerWhenAnyLive,
              onChanged: _saving
                  ? null
                  : (v) => _persist(
                        HomeLayoutHints(
                          hideDonationBannerWhenAnyLive: v,
                          hidePodcastBlockWhenAnyLive:
                              _hints.hidePodcastBlockWhenAnyLive,
                          hideDvcrTvBlockWhenAnyLive:
                              _hints.hideDvcrTvBlockWhenAnyLive,
                        ),
                      ),
            ),
            SwitchListTile(
              title: Text(
                'Masquer bloc Podcast si live',
                style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
              ),
              value: _hints.hidePodcastBlockWhenAnyLive,
              onChanged: _saving
                  ? null
                  : (v) => _persist(
                        HomeLayoutHints(
                          hideDonationBannerWhenAnyLive:
                              _hints.hideDonationBannerWhenAnyLive,
                          hidePodcastBlockWhenAnyLive: v,
                          hideDvcrTvBlockWhenAnyLive:
                              _hints.hideDvcrTvBlockWhenAnyLive,
                        ),
                      ),
            ),
            SwitchListTile(
              title: Text(
                'Masquer DVCR TV si live',
                style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
              ),
              value: _hints.hideDvcrTvBlockWhenAnyLive,
              onChanged: _saving
                  ? null
                  : (v) => _persist(
                        HomeLayoutHints(
                          hideDonationBannerWhenAnyLive:
                              _hints.hideDonationBannerWhenAnyLive,
                          hidePodcastBlockWhenAnyLive:
                              _hints.hidePodcastBlockWhenAnyLive,
                          hideDvcrTvBlockWhenAnyLive: v,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}
