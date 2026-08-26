import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../../../services/sponsor_service.dart';

/// Catalogue sponsors — Association → Marque (ou Staff si non embarqué).
class StaffSponsorsSection extends StatelessWidget {
  const StaffSponsorsSection({super.key, this.embedded = false});

  /// true : pas de ListView (déjà dans une page scrollable).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SponsorService.stream(),
      builder: (context, snap) {
        final sponsors = snap.data ?? const <Map<String, dynamic>>[];
        final body = <Widget>[
            Row(
              children: [
                Text(
                  'SPONSORS',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _openSponsorEditor(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: adminGold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AJOUTER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Enregistre une fois tes sponsors et réutilise-les dans les votes, émissions et cartes.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (sponsors.isEmpty)
              Text(
                'Aucun sponsor enregistré pour le moment.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              )
            else
              ...sponsors.map((sponsor) {
                final color = adminColorFromHex(
                  (sponsor['colorHex'] as String? ?? '').trim(),
                );
                final active = sponsor['active'] != false;
                final logo = (sponsor['logoUrl'] as String? ?? '').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: logo.isEmpty
                              ? Icon(Icons.campaign_rounded,
                                  color: color, size: 18)
                              : Image.network(
                                  logo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_rounded,
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (sponsor['name'] as String? ?? '').trim(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: adminTextPrimary,
                                ),
                              ),
                              Text(
                                active ? 'Actif' : 'Inactif',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: active ? color : adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openSponsorEditor(
                            context,
                            sponsor: sponsor,
                          ),
                          icon: const Icon(Icons.edit_rounded,
                              color: adminGold, size: 18),
                        ),
                        IconButton(
                          onPressed: () async {
                            await SponsorService.deleteSponsor(
                              (sponsor['id'] as String? ?? '').trim(),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sponsor supprimé.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: adminRed, size: 18),
                        ),
                      ],
                    ),
                  ),
                );
              }),
        ];
        if (embedded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: body,
        );
      },
    );
  }

  Future<void> _openSponsorEditor(
    BuildContext context, {
    Map<String, dynamic>? sponsor,
  }) async {
    final id = (sponsor?['id'] as String? ?? '').trim();
    final nameCtrl = TextEditingController(
      text: (sponsor?['name'] as String? ?? '').trim(),
    );
    final logoCtrl = TextEditingController(
      text: (sponsor?['logoUrl'] as String? ?? '').trim(),
    );
    final colorCtrl = TextEditingController(
      text: (sponsor?['colorHex'] as String? ?? '').trim(),
    );
    final linkCtrl = TextEditingController(
      text: (sponsor?['linkUrl'] as String? ?? '').trim(),
    );
    var active = sponsor?['active'] != false;
    var saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: adminCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id.isEmpty ? 'NOUVEAU SPONSOR' : 'MODIFIER LE SPONSOR',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: adminGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                AdminField(ctrl: nameCtrl, label: 'Nom du sponsor'),
                const SizedBox(height: 10),
                AdminField(ctrl: logoCtrl, label: 'Logo (URL)'),
                const SizedBox(height: 10),
                AdminField(
                  ctrl: colorCtrl,
                  label: 'Couleur (hex, ex: #C8A436)',
                ),
                const SizedBox(height: 10),
                AdminField(ctrl: linkCtrl, label: 'Lien (optionnel)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        active ? 'Sponsor actif' : 'Sponsor inactif',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: active,
                      onChanged: (value) =>
                          setModalState(() => active = value),
                      activeThumbColor: adminGold,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
                      child: Text(
                        'Annuler',
                        style: GoogleFonts.inter(color: adminGrey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                await SponsorService.saveSponsor(
                                  id: id,
                                  name: nameCtrl.text.trim(),
                                  logoUrl: logoCtrl.text.trim(),
                                  colorHex: colorCtrl.text.trim(),
                                  linkUrl: linkCtrl.text.trim(),
                                  active: active,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } on StateError catch (error) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(error.message.toString()),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: adminGreen,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        'Enregistrer',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    logoCtrl.dispose();
    colorCtrl.dispose();
    linkCtrl.dispose();
  }
}
