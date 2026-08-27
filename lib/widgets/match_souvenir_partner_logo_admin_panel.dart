import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/souvenir_branding.dart';
import '../screens/admin/admin_module_colors.dart';
import '../screens/admin/admin_palette.dart';
import '../services/match_souvenir_branding_service.dart';
import '../utils/pick_image_bytes.dart';
import 'square_partner_logo_admin_slot.dart';

/// Après-match — logo partenaire optionnel sur le cadre souvenir fan.
class MatchSouvenirPartnerLogoAdminPanel extends StatefulWidget {
  const MatchSouvenirPartnerLogoAdminPanel({super.key});

  @override
  State<MatchSouvenirPartnerLogoAdminPanel> createState() =>
      _MatchSouvenirPartnerLogoAdminPanelState();
}

class _MatchSouvenirPartnerLogoAdminPanelState
    extends State<MatchSouvenirPartnerLogoAdminPanel> {
  StreamSubscription<SouvenirBranding>? _sub;
  SouvenirBranding _branding = SouvenirBranding.defaults;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = MatchSouvenirBrandingService.instance.watch().listen((b) {
      if (!mounted) return;
      setState(() {
        _branding = b;
        _loading = false;
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _setFeatureEnabled(bool v) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MatchSouvenirBrandingService.instance.setFeatureEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’enregistrer : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool v) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MatchSouvenirBrandingService.instance.setEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’enregistrer : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(PickedImageBytes picked) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (picked.bytes.length > MatchSouvenirBrandingService.maxFileBytes) {
        throw StateError('Fichier trop lourd (max 2 Mo).');
      }
      await MatchSouvenirBrandingService.instance.uploadPartnerLogo(
        bytes: picked.bytes,
        extension: picked.extension,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Upload échoué : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveUrl(String url) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await MatchSouvenirBrandingService.instance.setLogoUrl(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'URL : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Retirer le logo partenaire ?',
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Le logo disparaîtra du souvenir. Tu pourras en uploader un autre '
          'plus tard.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Retirer',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await MatchSouvenirBrandingService.instance.clearPartnerLogo(
        deleteStorageFile: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Suppression échouée : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AdminModuleColors.contenu;
    final hasLogo = _branding.hasLogo;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_camera_rounded, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CRÉER MON SOUVENIR',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: adminTextPrimary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _branding.featureEnabled
                            ? adminGreenAccent.withAlpha(25)
                            : adminGrey.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _branding.featureEnabled
                              ? adminGreenAccent.withAlpha(80)
                              : adminGrey.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        _branding.featureEnabled ? 'Actif' : 'Désactivé',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _branding.featureEnabled
                              ? adminGreenAccent
                              : adminGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Activer Créer mon souvenir',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: adminTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _branding.featureEnabled
                        ? 'CTA visible sur la fiche match (apps à jour)'
                        : 'CTA et entrée partage masqués pour les fans',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  value: _branding.featureEnabled,
                  activeThumbColor: adminGold,
                  onChanged: _busy ? null : _setFeatureEnabled,
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: adminBorder.withAlpha(180)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.handshake_rounded, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LOGO PARTENAIRE',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: adminTextPrimary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _branding.showOnFrame
                            ? adminGreenAccent.withAlpha(25)
                            : adminGrey.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _branding.showOnFrame
                              ? adminGreenAccent.withAlpha(80)
                              : adminGrey.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        _branding.showOnFrame ? 'Visible' : 'Masqué',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _branding.showOnFrame
                              ? adminGreenAccent
                              : adminGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Logo sponsor / partenaire (ex. marque) en haut à droite '
                  'du cadre souvenir. Pas le blason DVCR. '
                  'La photo du fan reste 100 % locale.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Afficher le logo partenaire',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: adminTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    hasLogo
                        ? (_branding.enabled
                            ? 'Visible sur la fiche match et le cadre souvenir'
                            : 'Masqué partout — la fiche ne montre rien')
                        : 'Uploade un logo puis active l’affichage',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  value: _branding.enabled,
                  activeThumbColor: adminGold,
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v && !hasLogo) {
                            setState(() {
                              _error =
                                  'Uploade d’abord un logo partenaire.';
                            });
                            return;
                          }
                          _setEnabled(v);
                        },
                ),
                const SizedBox(height: 8),
                SquarePartnerLogoAdminSlot(
                  title: '',
                  hint:
                      'PNG / JPG / WebP, idéalement carré. Max ~2 Mo. '
                      'app_config/${SouvenirBranding.firestoreDocId}',
                  logoUrl: _branding.logoUrl,
                  revisionMillis: _branding.revisionMillis,
                  busy: _busy,
                  error: _error,
                  framed: false,
                  onUpload: _upload,
                  onSaveUrl: _saveUrl,
                  onRemove: _removeLogo,
                ),
              ],
            ),
    );
  }
}
