import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_ticketing.dart';
import '../../../../services/match_ticketing_service.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Photos & réseaux — CTA billet sur la fiche match Accueil.
class MatchTicketingAdminSection extends StatefulWidget {
  const MatchTicketingAdminSection({super.key});

  @override
  State<MatchTicketingAdminSection> createState() =>
      _MatchTicketingAdminSectionState();
}

class _MatchTicketingAdminSectionState extends State<MatchTicketingAdminSection> {
  final _url = TextEditingController();
  StreamSubscription<MatchTicketing>? _sub;
  MatchTicketing _config = MatchTicketing.defaults;
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = MatchTicketingService.instance.watch().listen((v) {
      if (!mounted) return;
      if (_url.text.trim() != v.url) {
        _url.text = v.url;
      }
      setState(() {
        _config = v;
        _enabled = v.enabled;
        _loading = false;
        _error = null;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _url.dispose();
    super.dispose();
  }

  Future<void> _setEnabled(bool v) async {
    setState(() {
      _enabled = v;
      _saving = true;
      _error = null;
    });
    try {
      await MatchTicketingService.instance.setEnabled(v);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enabled = _config.enabled;
        _error = 'Impossible d’enregistrer : $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveUrl() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MatchTicketingService.instance.setUrl(_url.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lien billetterie enregistré',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'URL : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'BILLETTERIE ACCUEIL',
      icon: Icons.confirmation_number_outlined,
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
                    'Bouton « Choppe ton billet pour le match ! » sous '
                    'Partager ce match. Visible uniquement si le switch est ON, '
                    'un lien http(s) est enregistré, et le match actuel de '
                    'l’accueil est un match à domicile (CSSA / Sedan en team1). '
                    'Extérieur, pas de match, switch OFF ou URL vide = rien. '
                    'app_config/${MatchTicketing.firestoreDocId}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Afficher le bouton billet sur l’accueil',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'Actif : le bouton n’apparaît que pour un match à domicile'
                          : 'Masqué — aucun bouton extra sur l’accueil',
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                    value: _enabled,
                    activeThumbColor: adminGold,
                    onChanged: _saving ? null : _setEnabled,
                  ),
                  const SizedBox(height: 8),
                  AdminField(
                    ctrl: _url,
                    label: 'Lien billetterie',
                    hint: 'https://…',
                    keyboardType: TextInputType.url,
                    accent: AdminUniverse.contenuDiffusion.color,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 11, color: adminRed),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving ? null : _saveUrl,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: adminGold,
                          borderRadius: BorderRadius.circular(adminPaperRadius),
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
                                  'ENREGISTRER LE LIEN',
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
