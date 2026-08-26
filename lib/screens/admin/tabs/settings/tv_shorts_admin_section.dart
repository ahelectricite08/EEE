import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/youtube_playlist_service.dart';
import '../../admin_palette.dart';

/// Sync + masque / épingle des Shorts YouTube (playlist UUSH de la chaîne).
class TvShortsAdminSection extends StatefulWidget {
  const TvShortsAdminSection({super.key});

  @override
  State<TvShortsAdminSection> createState() => _TvShortsAdminSectionState();
}

class _TvShortsAdminSectionState extends State<TvShortsAdminSection> {
  bool _syncing = false;
  String? _status;

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _status = null;
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('syncYoutubeVideosManual')
          .call();
      YoutubePlaylistService.clearCache();
      if (mounted) {
        setState(() => _status = 'Synchro OK — Shorts + playlists mis à jour.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Erreur sync : $e');
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _toggle(
    DocumentReference<Map<String, dynamic>> ref,
    String field,
    bool value,
  ) async {
    await ref.set({field: value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHORTS YOUTUBE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Source : playlist Shorts de @drapeauvertcartonrouge '
          '(UUSHt5uHMCEz9w1BhE0D-ZerKg). Sync quotidienne 4h + bouton. '
          'Masquer retire le Short de l’app. Épingler le place en tête.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _syncing ? null : _sync,
          style: ElevatedButton.styleFrom(
            backgroundColor: adminGreen,
            foregroundColor: Colors.black,
          ),
          child: Text(_syncing ? 'Synchronisation…' : 'Synchroniser YouTube (Shorts inclus)'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _status!.startsWith('Erreur') ? adminRed : adminGreenAccent,
            ),
          ),
        ],
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('videos')
              .where('category', isEqualTo: 'shorts')
              .orderBy('created_at', descending: true)
              .limit(80)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(
                    color: adminGold,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Text(
                'Impossible de lire les Shorts. Lance une synchro.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Text(
                'Aucun Short en base — lance la synchro (admin).',
                style: GoogleFonts.inter(fontSize: 12, color: adminOrange),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final title = (d['title'] ?? 'Sans titre').toString();
                final hidden = d['hidden'] == true;
                final pinned = d['pinned'] == true;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hidden ? adminBg : adminCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: pinned ? adminGold.withAlpha(100) : adminBorder,
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
                            Text(
                              [
                                if (pinned) 'Épinglé',
                                if (hidden) 'Masqué',
                                (d['duration'] ?? '').toString(),
                              ].where((e) => e.isNotEmpty).join(' · '),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: pinned ? 'Retirer l’épingle' : 'Épingler',
                        onPressed: () => _toggle(doc.reference, 'pinned', !pinned),
                        icon: Icon(
                          pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: pinned ? adminGold : adminGrey,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: hidden ? 'Afficher' : 'Masquer',
                        onPressed: () => _toggle(doc.reference, 'hidden', !hidden),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: hidden ? adminOrange : adminGrey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
