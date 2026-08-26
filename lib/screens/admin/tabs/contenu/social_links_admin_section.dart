import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../screens/social/social_links_catalog.dart';
import '../../../../screens/social/social_links_settings.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Page « Nos réseaux » — `app_config/social_links`.
class SocialLinksAdminSection extends StatefulWidget {
  const SocialLinksAdminSection({super.key});

  @override
  State<SocialLinksAdminSection> createState() =>
      _SocialLinksAdminSectionState();
}

class _SocialLinksAdminSectionState extends State<SocialLinksAdminSection> {
  final Map<String, TextEditingController> _urls = {};
  final Map<String, TextEditingController> _handles = {};
  final Map<String, bool> _enabled = {};
  StreamSubscription<List<SocialNetworkSpec>>? _sub;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final spec in kSocialCatalogDefaults) {
      _urls[spec.id] = TextEditingController();
      _handles[spec.id] = TextEditingController();
      _enabled[spec.id] = spec.enabled;
    }
    _sub = SocialLinksSettings.watchAll().listen((list) {
      if (!mounted) return;
      for (final spec in list) {
        final u = _urls[spec.id];
        final h = _handles[spec.id];
        if (u != null && u.text != spec.url) u.text = spec.url;
        if (h != null && h.text != spec.handle) h.text = spec.handle;
        _enabled[spec.id] = spec.enabled;
      }
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _urls.values) {
      c.dispose();
    }
    for (final c in _handles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final specs = [
      for (final spec in kSocialCatalogDefaults)
        spec.copyWith(
          url: _urls[spec.id]?.text.trim() ?? '',
          handle: _handles[spec.id]?.text.trim() ?? '',
          enabled: _enabled[spec.id] ?? spec.enabled,
        ),
    ];
    try {
      await SocialLinksSettings.saveOverlay(specs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e', style: GoogleFonts.inter()),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'LIENS « NOS RÉSEAUX »',
      icon: Icons.public_rounded,
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
                    'Page globe de l’app. URL vide = lien catalogue par défaut '
                    '(sauf si tu désactives le réseau). '
                    'app_config/${SocialLinksSettings.configDocId}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final spec in kSocialCatalogDefaults) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spec.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: adminTextPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _enabled[spec.id] ?? spec.enabled,
                          activeThumbColor: adminGold,
                          onChanged: (v) =>
                              setState(() => _enabled[spec.id] = v),
                        ),
                      ],
                    ),
                    AdminField(
                      ctrl: _urls[spec.id]!,
                      label: 'URL ${spec.title}',
                    ),
                    const SizedBox(height: 8),
                    AdminField(
                      ctrl: _handles[spec.id]!,
                      label: 'Handle / libellé',
                    ),
                    const SizedBox(height: 14),
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
