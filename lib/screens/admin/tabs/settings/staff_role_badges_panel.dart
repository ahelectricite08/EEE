import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../../../services/app_settings_service.dart';
import 'settings_card.dart';

/// Badges visuels des rôles (chat + profil).
class StaffRoleBadgesPanel extends StatefulWidget {
  const StaffRoleBadgesPanel({super.key});

  @override
  State<StaffRoleBadgesPanel> createState() => _StaffRoleBadgesPanelState();
}

class _StaffRoleBadgesPanelState extends State<StaffRoleBadgesPanel> {
  static const _memberRoles = [
    ('supporter', 'Membre', Color(0xFF9E9E9E)),
    ('team_dvcr', 'Team DVCR', Color(0xFFC8A436)),
  ];

  static const _staffRoles = [
    ('admin', 'Admin', Color(0xFFEF5350)),
    ('community_manager', 'Community Manager', Color(0xFF2979FF)),
    ('editor', 'Éditeur', Color(0xFF00BCD4)),
    ('statisticien', 'Statisticien', Color(0xFF9C27B0)),
  ];

  final Map<String, TextEditingController> _urlCtrls = {};
  final Map<String, TextEditingController> _labelCtrls = {};
  bool _loading = true;
  bool _saving = false;
  StreamSubscription<RoleBadgeSettings>? _sub;

  @override
  void initState() {
    super.initState();
    for (final r in [..._memberRoles, ..._staffRoles]) {
      _urlCtrls[r.$1] = TextEditingController();
    }
    for (final r in _memberRoles) {
      _labelCtrls[r.$1] = TextEditingController();
    }
    _sub = AppSettingsService.roleBadgesStream().listen((settings) {
      if (!mounted) return;
      for (final r in [..._memberRoles, ..._staffRoles]) {
        final v = settings.badges[r.$1]?.trim() ?? '';
        if (_urlCtrls[r.$1]!.text != v) _urlCtrls[r.$1]!.text = v;
      }
      for (final r in _memberRoles) {
        final fallback = r.$2;
        final v = settings.labelForKey(r.$1, fallback);
        if (_labelCtrls[r.$1]!.text != v) _labelCtrls[r.$1]!.text = v;
      }
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _urlCtrls.values) c.dispose();
    for (final c in _labelCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppSettingsService.saveRoleBadges(
      {
        for (final r in [..._memberRoles, ..._staffRoles])
          r.$1: _urlCtrls[r.$1]!.text.trim(),
      },
      labels: {
        for (final r in _memberRoles) r.$1: _labelCtrls[r.$1]!.text.trim(),
      },
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _roleRow((String, String, Color) r, {required bool withLabel}) {
    final url = _urlCtrls[r.$1]!.text.trim();
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
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image,
                            size: 16, color: adminGrey),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (withLabel)
            AdminField(
              ctrl: _labelCtrls[r.$1]!,
              label: 'Libellé affiché (chat, profil)',
            ),
          if (withLabel) const SizedBox(height: 6),
          AdminField(
            ctrl: _urlCtrls[r.$1]!,
            label: 'URL image badge',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SettingsCard(
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
                                'Badges membres (libellé + image) et badges staff (image seule).',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: adminGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'BADGES MEMBRES',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._memberRoles.map((r) => _roleRow(r, withLabel: true)),
                      const SizedBox(height: 8),
                      Text(
                        'BADGES ÉQUIPE (staff)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._staffRoles.map((r) => _roleRow(r, withLabel: false)),
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
