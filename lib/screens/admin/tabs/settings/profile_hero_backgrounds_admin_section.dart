import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/app_settings_service.dart';
import '../../../../utils/remote_image_url.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import 'settings_card.dart';

/// Trois fonds du carrousel bandeau profil (`app_config/profile_hero`).
class ProfileHeroBackgroundsAdminSection extends StatefulWidget {
  const ProfileHeroBackgroundsAdminSection({super.key});

  @override
  State<ProfileHeroBackgroundsAdminSection> createState() =>
      _ProfileHeroBackgroundsAdminSectionState();
}

class _ProfileHeroBackgroundsAdminSectionState
    extends State<ProfileHeroBackgroundsAdminSection> {
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
                    'par défaut. Wix : URL directe static.wixstatic.com (fichier .jpg / .webp). '
                    'Pas de liens Canva — uploadez sur Storage.',
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
                              final warn = firstRemoteImageAdminWarning([
                                u1,
                                u2,
                                u3,
                              ]);
                              if (warn != null && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      warn,
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
