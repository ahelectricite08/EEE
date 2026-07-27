import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../services/vote_history_service.dart';

/// Historique des votes MOTM / émissions — affiché dans Jeux → Visibilité.
class VoteHistorySection extends StatelessWidget {
  const VoteHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: VoteHistoryService.streamRecent(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HISTORIQUE DES VOTES',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: adminTextPrimary,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Derniers votes clos : gagnant, sponsor et participation.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Text(
                  'Aucun vote archivé pour le moment.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                )
              else
                ...docs.take(12).map((doc) {
                  final data = doc.data();
                  final sponsorColor = adminColorFromHex(
                    (data['sponsorColorHex'] as String? ?? '').trim(),
                  );
                  final closedAt = data['closedAt'];
                  final date = closedAt is Timestamp
                      ? closedAt.toDate()
                      : DateTime.now();
                  final type = (data['type'] as String? ?? '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: adminBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: adminBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: sponsorColor.withAlpha(18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: sponsorColor.withAlpha(90),
                                  ),
                                ),
                                child: Text(
                                  type == 'motm_matchday'
                                      ? 'HOMME DU MATCH'
                                      : 'SONDAGE ÉMISSION',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: sponsorColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (data['title'] as String? ?? '').trim(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: adminTextPrimary,
                            ),
                          ),
                          if ((data['subtitle'] as String? ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              (data['subtitle'] as String).trim(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if ((data['sponsorName'] as String? ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _VoteInfoPill(
                                  icon: Icons.campaign_rounded,
                                  label:
                                      (data['sponsorName'] as String).trim(),
                                ),
                              _VoteInfoPill(
                                icon: Icons.how_to_vote_rounded,
                                label:
                                    '${(data['totalVotes'] as num?)?.toInt() ?? 0} votes',
                              ),
                              if ((data['winnerName'] as String? ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _VoteInfoPill(
                                  icon: Icons.emoji_events_rounded,
                                  label:
                                      (data['winnerName'] as String).trim(),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _VoteInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VoteInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: adminBorder.withAlpha(45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: adminBorder.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: adminGold),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminGrey,
            ),
          ),
        ],
      ),
    );
  }
}
