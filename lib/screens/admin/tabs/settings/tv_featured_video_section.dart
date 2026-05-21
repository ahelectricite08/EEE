import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/video_featured_service.dart';

/// Choix de la vidéo mise en avant sur l’écran Vidéos de l’app Android TV.
class TvFeaturedVideoSection extends StatelessWidget {
  const TvFeaturedVideoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VIDÉO À LA UNE (TV)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Une seule vidéo en tête de l’écran Vidéos sur Android TV. '
          'Les contenus partenaires sont exclus partout sur la TV (y compris « Autres »).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tv').doc('config').snapshots(),
          builder: (context, cfgSnap) {
            final id = (cfgSnap.data?.data()?['featuredVideoId'] ?? '').toString();
            if (id.isEmpty) {
              return Text(
                'Aucune à la une active — l’écran Vidéos TV n’affichera pas de bannière.',
                style: GoogleFonts.inter(fontSize: 11, color: adminOrange),
              );
            }
            return Text(
              'À la une active (id Firestore : $id)',
              style: GoogleFonts.inter(fontSize: 11, color: adminGreenAccent),
            );
          },
        ),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tv').doc('config').snapshots(),
          builder: (context, cfgSnap) {
            final configFeaturedId =
                (cfgSnap.data?.data()?['featuredVideoId'] ?? '').toString();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('videos')
                  .orderBy('created_at', descending: true)
                  .limit(24)
                  .snapshots(),
              builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
                ),
              );
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Text(
                'Aucune vidéo — lance une synchro YouTube depuis les fonctions.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            final docs = snap.data!.docs.where((doc) {
              final d = doc.data();
              final cat = (d['category'] ?? '').toString().toLowerCase();
              if (cat == 'partenaire') return false;
              final title = (d['title'] ?? '').toString().toLowerCase();
              return !title.contains('partenaire');
            }).toList();
            if (docs.isEmpty) {
              return Text(
                'Aucune vidéo éligible (les contenus partenaires sont exclus de la TV).',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final title = (d['title'] ?? 'Sans titre').toString();
                final featured =
                    doc.id == configFeaturedId || d['featured'] == true;
                final duration = (d['duration'] ?? '').toString();
                final category = (d['category'] ?? '').toString();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: featured ? adminGold.withAlpha(18) : adminBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: featured ? adminGold.withAlpha(100) : adminBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: adminTextPrimary,
                              ),
                            ),
                            if (duration.isNotEmpty || category.isNotEmpty)
                              Text(
                                [if (category.isNotEmpty) category, if (duration.isNotEmpty) duration]
                                    .join(' · '),
                                style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: featured ? 'Retirer de la une' : 'Mettre à la une',
                        onPressed: () async {
                          try {
                            if (featured) {
                              await VideoFeaturedService.clearFeatured(doc.id);
                            } else {
                              await VideoFeaturedService.setFeatured(doc.id);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e')),
                              );
                            }
                          }
                        },
                        icon: Icon(
                          featured ? Icons.star_rounded : Icons.star_border_rounded,
                          color: featured ? adminGold : adminGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
              },
            );
          },
        ),
      ],
    );
  }
}
