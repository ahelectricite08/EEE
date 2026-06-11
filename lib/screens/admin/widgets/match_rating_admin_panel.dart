import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/match_rating_service.dart';
import '../../../widgets/match_rating_summary.dart';
import '../admin_palette.dart';

/// Admin direct : suivi de la note du match (live ou après fin).
class MatchRatingAdminPanel extends StatelessWidget {
  final Map<String, dynamic> data;

  const MatchRatingAdminPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = (data['matchRatingStatus'] as String? ?? '').trim();
    final active = status == 'active';
    final fulltime = MatchRatingService.isFulltimeDeclared(data);
    final rating = MatchRatingSnapshot.fromDoc(data);
    if (!active && !fulltime && rating == null) {
      return const SizedBox.shrink();
    }

    final title = (data['matchRatingTitle'] as String? ?? '').trim();
    final counts = MatchRatingSnapshot.countsFromDoc(data);
    final total = rating?.total ??
        ((data['matchRatingTotal'] as num?)?.toInt() ?? 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rate_rounded, color: adminGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NOTE DU MATCH',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? adminGreen.withValues(alpha: 0.2)
                      : adminGrey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active ? 'OUVERT' : 'CLOS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active ? adminGreen : adminGrey,
                  ),
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: adminTextPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (rating != null)
            Text(
              'Moyenne ${rating.averageLabel}/10 · $total vote${total > 1 ? 's' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: adminGold,
              ),
            )
          else
            Text(
              active
                  ? 'En attente des premiers votes sur l’accueil.'
                  : 'Aucune note enregistrée.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ...List.generate(10, (index) {
              final note = 10 - index;
              final count = counts['$note'] ?? 0;
              final ratio = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$note',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: adminGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: adminSurface,
                          color: adminGold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: adminGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (active) ...[
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('live')
                  .doc('current')
                  .collection('matchRatings')
                  .snapshots(),
              builder: (context, snap) {
                final n = snap.data?.docs.length ?? 0;
                return Text(
                  '$n utilisateur${n > 1 ? 's' : ''} ont voté (temps réel)',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
