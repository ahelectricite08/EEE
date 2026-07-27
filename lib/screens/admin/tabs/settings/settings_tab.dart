import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../../../widgets/admin_bounded_image_preview.dart';
import 'fff_season_settings_panel.dart';
import 'extra_admin_sections.dart';
import 'season_lifecycle_admin_section.dart';
import 'app_version_admin_section.dart';
import 'settings_card.dart';
import 'soutenez_dvcr_banners_admin_section.dart';

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
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AdminModuleColors.administration;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: 'Paramètres',
            subtitle: 'Application, bannières, saison FFF et maintenance.',
            icon: Icons.settings_rounded,
            accent: accent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AdminSubTabBar(
            controller: _tc,
            accent: accent,
            tabs: const [
              Tab(text: 'APPLICATION'),
              Tab(text: 'SAISON FFF'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _AppSettingsPanel(),
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
//   - app_config/support  → supportUrl (fallback CTA DonationBanner)
//   - app_config/soutenez_dvcr_banners → bannières Soutenez DVCR / sponsors
//   - app_config/chat     → autoModeration (ChatScreen)
//   - app_config/powered_by_partner → encart partenaire **prono championnat**
//   - app_config/profile_hero → 3 URLs de fond bandeau profil (carrousel utilisateur)
class _AppSettingsPanel extends StatelessWidget {
  const _AppSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const _SettingsGroupTitle('Maintenance & version'),
        AppVersionAdminSection(),
        const SizedBox(height: 16),
        const _SettingsGroupTitle('Support & profil'),
        const _SupportSection(),
        const SizedBox(height: 16),
        const SoutenezDvcrBannersAdminSection(),
        const SizedBox(height: 16),
        _ProfileHeroBackgroundsSection(),
        const SizedBox(height: 20),
        const _SettingsGroupTitle('Partenaire prono championnat'),
        const _PoweredByPartnerSection(),
        const SizedBox(height: 20),
        const _SettingsGroupTitle('Chat & communauté'),
        const CommunityChatRolloutAdminSection(),
        const SizedBox(height: 16),
        _ChatModerationSection(),
        const SizedBox(height: 20),
        const _SettingsGroupTitle('Saisons & fonctionnalités'),
        const SeasonLifecycleAdminSection(),
        const SizedBox(height: 20),
        const CompetitionSeasonsSection(),
      ],
    );
  }
}

class _SettingsGroupTitle extends StatelessWidget {
  final String title;

  const _SettingsGroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.barlowCondensed(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: adminOrange,
          letterSpacing: 1.1,
        ),
      ),
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
    return SettingsCard(
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
                    'URL de fallback pour le CTA des bannières Soutenez DVCR '
                    '(si le lien CTA d’un emplacement est vide).',
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
    return SettingsCard(
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
                            'Encart en bas de l’onglet **Pronos championnat** dans l’app. '
                            'URL **directe** image (static.wixstatic.com/…). '
                            'Coupe du monde : onglet admin **Pronos & jeux**.',
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
    return SettingsCard(
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
