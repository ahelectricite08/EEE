import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

/// URL de don / support (fallback CTA Soutenez DVCR).
class SupportUrlAdminSection extends StatefulWidget {
  const SupportUrlAdminSection({super.key});

  @override
  State<SupportUrlAdminSection> createState() => _SupportUrlAdminSectionState();
}

class _SupportUrlAdminSectionState extends State<SupportUrlAdminSection> {
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
                    'URL de fallback pour le CTA des bannières Soutenez DVCR '
                    '(si le lien CTA d’un emplacement est vide).',
                    style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _urlCtrl,
                    label: 'URL de don (HelloAsso, PayPal…)',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await AppSettingsService.saveSupport(
                                SupportSettings(
                                  supportUrl: _urlCtrl.text.trim(),
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
