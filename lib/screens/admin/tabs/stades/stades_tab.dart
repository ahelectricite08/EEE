import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_components.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../admin_dialogs.dart';
import 'sedan_squad_admin_section.dart';

class StadesTab extends StatelessWidget {
  const StadesTab();

  static final _col = FirebaseFirestore.instance.collection('teams');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: 'Équipes & stades',
            subtitle:
                'Effectif Sedan, logos et fiches stades utilisés dans l\'app.',
            icon: Icons.stadium_rounded,
            accent: AdminModuleColors.preparation,
            trailing: AdminPrimaryButton(
              label: 'Ajouter',
              icon: Icons.add_rounded,
              height: 38,
              onTap: () => _showEditor(context, null, null),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _col.orderBy('name').snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final waiting = snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const SedanSquadAdminSection(),
                  const SizedBox(height: 20),
                  Text(
                    'STADES & LOGOS',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: adminGold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (waiting)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AdminModuleColors.preparation,
                        ),
                      ),
                    )
                  else if (docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(Icons.stadium_rounded,
                              color: adminGrey, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun stade configuré',
                            style: GoogleFonts.inter(
                                color: adminGrey, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showEditor(context, null, null),
                            child: Text(
                              'Ajouter une équipe →',
                              style: GoogleFonts.inter(
                                color: AdminModuleColors.preparation,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? doc.id).toString();
                      final url = (data['stadiumImageUrl'] ?? '').toString();
                      final hasImage = url.isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: adminCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: adminBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(35),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasImage)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: Image.network(
                                  url,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: adminBorder,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded,
                                          color: adminGrey, size: 28),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 80,
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(14)),
                                  color: adminCardHigh,
                                ),
                                child: const Center(
                                  child: Icon(Icons.stadium_rounded,
                                      color: adminGrey, size: 36),
                                ),
                              ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: adminTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          hasImage
                                              ? 'Image configurée'
                                              : 'Aucune image',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: hasImage
                                                ? adminGreenAccent
                                                : adminGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 18, color: adminGold),
                                    onPressed: () =>
                                        _showEditor(context, doc.id, data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded,
                                        size: 18, color: adminRed),
                                    onPressed: () async {
                                      final ok = await adminConfirm(context,
                                          'Supprimer le stade de "$name" ?');
                                      if (ok) await _col.doc(doc.id).delete();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditor(BuildContext context, String? docId, Map<String, dynamic>? data) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final urlCtrl = TextEditingController(text: data?['stadiumImageUrl'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: adminCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  docId == null ? 'NOUVEAU STADE' : 'MODIFIER LE STADE',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20, fontWeight: FontWeight.w900, color: adminGold, letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded, color: adminGrey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminField(ctrl: nameCtrl, label: 'Nom de l\'équipe (ex: SEDAN ARDENNES CS)'),
            const SizedBox(height: 12),
            AdminField(ctrl: urlCtrl, label: 'URL de la photo du stade'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  final url = urlCtrl.text.trim();
                  if (name.isEmpty) return;
                  final id = docId ?? name.toUpperCase().replaceAll(' ', '_');
                  await _col.doc(id).set({
                    'name': name,
                    'stadiumImageUrl': url.isEmpty ? null : url,
                  }, SetOptions(merge: true));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminModuleColors.preparation,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'ENREGISTRER',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
