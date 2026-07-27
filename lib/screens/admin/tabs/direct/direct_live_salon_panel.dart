import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';

/// Salon chat marqué live (extrait de [DirectTab] pour alléger le fichier).
class DirectLiveSalonPanel extends StatelessWidget {
  const DirectLiveSalonPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .where('isLive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final allLive = snap.data?.docs ?? [];
        final liveDocs =
            allLive.where((d) => d.data()['archived'] != true).toList();
        final archivedDocs =
            allLive.where((d) => d.data()['archived'] == true).toList();

        return Container(
          decoration: BoxDecoration(
            color: adminSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: liveDocs.isNotEmpty ? adminRed : adminBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        liveDocs.isNotEmpty
                            ? 'Actif : ${(liveDocs.first.data()['name'] as String? ?? 'Live')}'
                            : 'Aucun salon live actif',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (liveDocs.isNotEmpty) ...[
                const Divider(height: 1, color: adminBorder),
                DirectLiveSalonMessages(
                  salonId: liveDocs.first.id,
                  embedded: true,
                ),
              ],
              if (archivedDocs.isNotEmpty) ...[
                const Divider(height: 1, color: adminBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text(
                    'ARCHIVÉS (7j)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: adminGold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...archivedDocs.map((doc) {
                  final data = doc.data();
                  final name = data['name'] as String? ?? doc.id;
                  final archivedAt =
                      (data['archivedAt'] as Timestamp?)?.toDate();
                  final expiresAt =
                      archivedAt?.add(const Duration(days: 7));
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.archive_rounded,
                      color: adminGold,
                      size: 16,
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: adminTextPrimary,
                      ),
                    ),
                    subtitle: expiresAt != null
                        ? Text(
                            'Expire le ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminGrey,
                            ),
                          )
                        : null,
                    trailing: TextButton(
                      onPressed: () => DirectLiveSalonMessages.show(
                        context,
                        doc.id,
                        salonName: name,
                      ),
                      child: Text(
                        'Voir',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Lecture admin des messages d’un salon (live, archivé ou permanent).
class DirectLiveSalonMessages extends StatelessWidget {
  static const _messageLimit = 300;

  final String salonId;
  final String? salonName;
  final ScrollController? scrollController;
  final bool embedded;

  const DirectLiveSalonMessages({
    super.key,
    required this.salonId,
    this.salonName,
    this.scrollController,
    this.embedded = false,
  });

  static void show(
    BuildContext context,
    String salonId, {
    String? salonName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: adminCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => DirectLiveSalonMessages(
          salonId: salonId,
          salonName: salonName,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chat_salons')
          .doc(salonId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(_messageLimit)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Aucun message dans ce salon',
              style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
            ),
          );
        }
        final capped = docs.length >= _messageLimit;
        return Column(
          children: [
            if (capped)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Text(
                  'Affichage des $_messageLimit messages les plus récents.',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final name =
                      (data['firstName'] as String? ?? 'Membre').trim();
                  final text = (data['text'] as String? ?? '').trim();
                  final ts = (data['sentAt'] as Timestamp?)?.toDate();
                  final time = ts != null
                      ? '${ts.day.toString().padLeft(2, '0')}/'
                          '${ts.month.toString().padLeft(2, '0')} '
                          '${ts.hour.toString().padLeft(2, '0')}:'
                          '${ts.minute.toString().padLeft(2, '0')}'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            time,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: adminGrey,
                            ),
                          ),
                        ),
                        Text(
                          '$name  ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: adminGold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            text.isEmpty ? '—' : text,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: adminTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (embedded) {
      return SizedBox(height: 280, child: list);
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    salonName != null ? '# $salonName' : 'Messages du salon',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: adminTextPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: adminGrey),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: adminBorder),
          Expanded(child: list),
        ],
      ),
    );
  }
}
