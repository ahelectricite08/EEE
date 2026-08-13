import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../firebase_options.dart';
import '../../../../services/helloasso_adhesion_service.dart';
import '../../../../widgets/adhesion_banner.dart';
import '../../../../widgets/adhesion_splash.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../../admin_module_colors.dart';

/// Admin — bandeau adhésion, URL HelloAsso, tracking UTM, stats clics.
class AdhesionBannerAdminSection extends StatefulWidget {
  const AdhesionBannerAdminSection({super.key});

  @override
  State<AdhesionBannerAdminSection> createState() =>
      _AdhesionBannerAdminSectionState();
}

class _AdhesionBannerAdminSectionState extends State<AdhesionBannerAdminSection> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController();
  final _bgUrlCtrl = TextEditingController();
  final _utmSourceCtrl = TextEditingController();
  final _utmMediumCtrl = TextEditingController();
  final _utmCampaignCtrl = TextEditingController();

  bool _bannerEnabled = false;
  bool _useCustomBackground = false;
  bool _trackingEnabled = true;
  bool _loading = true;
  bool _saving = false;
  HelloAssoAdhesionConfig _current = HelloAssoAdhesionConfig.defaults;

  @override
  void initState() {
    super.initState();
    HelloAssoAdhesionService.instance.configStream().listen((cfg) {
      if (!mounted) return;
      setState(() {
        _current = cfg;
        _applyConfig(cfg);
        _loading = false;
      });
    });
  }

  void _applyConfig(HelloAssoAdhesionConfig cfg) {
    _bannerEnabled = cfg.bannerEnabled;
    _useCustomBackground = cfg.useCustomBackground;
    _trackingEnabled = cfg.trackingEnabled;
    _syncCtrl(_urlCtrl, cfg.helloAssoUrl);
    _syncCtrl(_titleCtrl, cfg.title);
    _syncCtrl(_subtitleCtrl, cfg.subtitle);
    _syncCtrl(_ctaCtrl, cfg.ctaLabel);
    _syncCtrl(_bgUrlCtrl, cfg.backgroundUrl);
    _syncCtrl(_utmSourceCtrl, cfg.utmSource);
    _syncCtrl(_utmMediumCtrl, cfg.utmMedium);
    _syncCtrl(_utmCampaignCtrl, cfg.utmCampaign);
  }

  void _syncCtrl(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  HelloAssoAdhesionConfig _buildFromForm() {
    return _current.copyWith(
      bannerEnabled: _bannerEnabled,
      helloAssoUrl: _urlCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      ctaLabel: _ctaCtrl.text.trim(),
      useCustomBackground: _useCustomBackground,
      backgroundUrl: _bgUrlCtrl.text.trim(),
      trackingEnabled: _trackingEnabled,
      utmSource: _utmSourceCtrl.text.trim(),
      utmMedium: _utmMediumCtrl.text.trim(),
      utmCampaign: _utmCampaignCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final next = _buildFromForm();
      await HelloAssoAdhesionService.instance.saveConfig(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configuration adhésion enregistrée',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminGreenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: adminRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _ctaCtrl.dispose();
    _bgUrlCtrl.dispose();
    _utmSourceCtrl.dispose();
    _utmMediumCtrl.dispose();
    _utmCampaignCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AdminModuleColors.communaute),
        ),
      );
    }

    final preview = _buildFromForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                'Bandeau adhésion (accueil)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entre le hero et « Prochain match ». Désactiver pendant la review App Store.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Afficher le bandeau adhésion',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                value: _bannerEnabled,
                activeThumbColor: AdminModuleColors.communaute,
                onChanged: (v) => setState(() => _bannerEnabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                'Textes & lien HelloAsso',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AdminField(ctrl: _urlCtrl, label: 'URL formulaire HelloAsso'),
              const SizedBox(height: 8),
              AdminField(ctrl: _titleCtrl, label: 'Titre'),
              const SizedBox(height: 8),
              AdminField(ctrl: _subtitleCtrl, label: 'Sous-titre'),
              const SizedBox(height: 8),
              AdminField(ctrl: _ctaCtrl, label: 'Libellé CTA'),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Image de fond personnalisée (Storage URL)',
                  style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
                ),
                value: _useCustomBackground,
                activeThumbColor: AdminModuleColors.communaute,
                onChanged: (v) => setState(() => _useCustomBackground = v),
              ),
              if (_useCustomBackground) ...[
                const SizedBox(height: 8),
                AdminField(ctrl: _bgUrlCtrl, label: 'URL image (Storage)'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                'Tracking UTM',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Ajouter les paramètres UTM à l’URL',
                  style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
                ),
                value: _trackingEnabled,
                activeThumbColor: AdminModuleColors.communaute,
                onChanged: (v) => setState(() => _trackingEnabled = v),
              ),
              const SizedBox(height: 8),
              AdminField(ctrl: _utmSourceCtrl, label: 'utm_source'),
              const SizedBox(height: 8),
              AdminField(ctrl: _utmMediumCtrl, label: 'utm_medium'),
              const SizedBox(height: 8),
              AdminField(ctrl: _utmCampaignCtrl, label: 'utm_campaign'),
              if (preview.buildTrackedUrl().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'URL générée',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: adminGrey,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  preview.buildTrackedUrl(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AdminModuleColors.communaute,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'APERÇU',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: adminGrey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        AdhesionBanner(preview: preview),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AdminModuleColors.communaute,
              foregroundColor: Colors.black,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Enregistrer la configuration',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Admin — écran plein écran à l’ouverture (indépendant du bandeau).
class AdhesionSplashAdminSection extends StatefulWidget {
  const AdhesionSplashAdminSection({super.key});

  @override
  State<AdhesionSplashAdminSection> createState() =>
      _AdhesionSplashAdminSectionState();
}

class _AdhesionSplashAdminSectionState extends State<AdhesionSplashAdminSection> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _countLabelCtrl = TextEditingController();

  bool _splashEnabled = false;
  bool _loading = true;
  bool _saving = false;
  HelloAssoAdhesionConfig _current = HelloAssoAdhesionConfig.defaults;

  @override
  void initState() {
    super.initState();
    HelloAssoAdhesionService.instance.configStream().listen((cfg) {
      if (!mounted) return;
      setState(() {
        _current = cfg;
        _applyConfig(cfg);
        _loading = false;
      });
    });
  }

  void _applyConfig(HelloAssoAdhesionConfig cfg) {
    _splashEnabled = cfg.splashEnabled;
    _syncCtrl(_titleCtrl, cfg.splashTitle);
    _syncCtrl(_subtitleCtrl, cfg.splashSubtitle);
    _syncCtrl(_ctaCtrl, cfg.splashCtaLabel);
    _syncCtrl(_imageUrlCtrl, cfg.splashImageUrl);
    _syncCtrl(_countCtrl, cfg.memberCount.toString());
    _syncCtrl(_countLabelCtrl, cfg.memberCountLabel);
  }

  void _syncCtrl(TextEditingController c, String v) {
    if (c.text != v) c.text = v;
  }

  HelloAssoAdhesionConfig _buildFromForm() {
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    return _current.copyWith(
      splashEnabled: _splashEnabled,
      splashTitle: _titleCtrl.text.trim(),
      splashSubtitle: _subtitleCtrl.text.trim(),
      splashCtaLabel: _ctaCtrl.text.trim(),
      splashImageUrl: _imageUrlCtrl.text.trim(),
      memberCount: count < 0 ? 0 : count,
      memberCountLabel: _countLabelCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final next = _buildFromForm();
      await HelloAssoAdhesionService.instance.saveConfig(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Écran d’ouverture enregistré',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminGreenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: adminRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _ctaCtrl.dispose();
    _imageUrlCtrl.dispose();
    _countCtrl.dispose();
    _countLabelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AdminModuleColors.communaute),
        ),
      );
    }

    final preview = _buildFromForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                'Écran d’ouverture',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Plein écran à chaque ouverture d’app. Indépendant du bandeau. '
                'Les utilisateurs peuvent seulement « Plus tard » (jamais « ne plus afficher »).',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Afficher l’écran d’ouverture aujourd’hui',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adminTextPrimary,
                  ),
                ),
                value: _splashEnabled,
                activeThumbColor: AdminModuleColors.communaute,
                onChanged: (v) => setState(() => _splashEnabled = v),
              ),
              if (_splashEnabled && _current.helloAssoUrl.trim().isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Renseigne l’URL HelloAsso dans la section bandeau (lien partagé).',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: adminRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                'Contenu de l’écran',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              AdminField(ctrl: _titleCtrl, label: 'Titre'),
              const SizedBox(height: 8),
              AdminField(ctrl: _subtitleCtrl, label: 'Sous-titre', maxLines: 2),
              const SizedBox(height: 8),
              AdminField(ctrl: _ctaCtrl, label: 'Libellé CTA'),
              const SizedBox(height: 8),
              AdminField(
                ctrl: _imageUrlCtrl,
                label: 'URL photo plein écran (Storage)',
                hint: 'Vide = image du bandeau / asset par défaut',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminField(
                      ctrl: _countCtrl,
                      label: 'Compteur (manuel)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AdminField(
                      ctrl: _countLabelCtrl,
                      label: 'Libellé compteur',
                      hint: 'personnes ont rejoint',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Le compteur n’apparaît que s’il est > 0.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'APERÇU ÉCRAN',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: adminGrey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 420,
            width: double.infinity,
            child: IgnorePointer(
              child: AdhesionSplashOverlay(preview: preview),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AdminModuleColors.communaute,
              foregroundColor: Colors.black,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Enregistrer l’écran d’ouverture',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Stats clics bandeau + paiements HelloAsso.
class AdhesionStatsAdminSection extends StatelessWidget {
  const AdhesionStatsAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HelloAssoAdhesionService.instance.clicksStream(limit: 1000),
      builder: (context, clickSnap) {
        final clicks = clickSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: HelloAssoAdhesionService.instance.donationsStream(limit: 500),
          builder: (context, donSnap) {
            final donations = donSnap.data?.docs ?? [];
            final appPaid = donations
                .where((d) =>
                    HelloAssoAdhesionService.isAppAttributedPayment(d.data()))
                .length;
            final homeClicks =
                clicks.where((c) => (c.data()['slot'] ?? '') == 'home').length;
            final splashClicks =
                clicks.where((c) => (c.data()['slot'] ?? '') == 'splash').length;

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
                    'Statistiques',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Clics bandeau (accueil)',
                    value: '$homeClicks',
                  ),
                  _StatRow(
                    label: 'Clics écran d’ouverture',
                    value: '$splashClicks',
                  ),
                  _StatRow(
                    label: 'Clics total (tous emplacements)',
                    value: '${clicks.length}',
                  ),
                  _StatRow(
                    label: 'Paiements HelloAsso (total)',
                    value: '${donations.length}',
                  ),
                  _StatRow(
                    label: 'Paiements via app (metadata.source = dvcr_app)',
                    value: '$appPaid',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phase 2 : lier automatiquement userId au checkout HelloAsso.',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AdminModuleColors.communaute,
            ),
          ),
        ],
      ),
    );
  }
}

/// Instructions webhook HelloAsso (URL publique, secret côté Firebase).
class AdhesionWebhookAdminSection extends StatelessWidget {
  const AdhesionWebhookAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final webhookUrl =
        HelloAssoAdhesionService.webhookUrlForProject(projectId);

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
          Row(
            children: [
              const Icon(Icons.webhook_rounded,
                  color: AdminModuleColors.communaute, size: 18),
              const SizedBox(width: 8),
              Text(
                'Webhook HelloAsso',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Colle cette URL dans HelloAsso → Paramètres → Webhooks. '
            'Le secret HMAC est stocké dans Firebase Secrets (HELLOASSO_WEBHOOK_SECRET) — ne jamais l’exposer dans l’app.',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: adminBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: adminBorder),
            ),
            child: SelectableText(
              webhookUrl,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: AdminModuleColors.communaute,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: webhookUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'URL webhook copiée',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: adminGreenAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(
              'Copier l’URL',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminModuleColors.communaute,
              side: BorderSide(color: AdminModuleColors.communaute.withAlpha(140)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Configuration HelloAsso',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '1. Événements : Payment (authorized / processed)\n'
            '2. Signature : header x-ha-signature (HMAC SHA-256 du corps brut)\n'
            '3. Metadata formulaire : ajouter userId (UID Firebase) et source = dvcr_app pour rattacher les paiements\n'
            '4. Vérifier les paiements non rattachés dans la section ci-dessous',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.5),
          ),
        ],
      ),
    );
  }
}
