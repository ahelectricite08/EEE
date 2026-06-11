import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_stats_schema.dart';
import '../../admin_palette.dart';

/// Faits de jeu Sedan (buts / cartons) — alimenté par live + fiche match.
class MatchPlayerFactsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final String team1;
  final String team2;
  final bool compact;

  const MatchPlayerFactsPanel({
    super.key,
    required this.events,
    required this.team1,
    required this.team2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final facts = MatchStatsSchema.sedanPlayerFacts(events, team1, team2);
    if (facts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: adminCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: adminBorder),
        ),
        child: Text(
          'Aucun fait Sedan enregistré pour ce match. '
          'Les buts / cartons saisis au live ou dans Modifier match apparaîtront ici.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: adminGrey,
            height: 1.35,
          ),
        ),
      );
    }

    final sorted = facts.entries.toList()
      ..sort((a, b) {
        final g = (b.value['goals'] ?? 0).compareTo(a.value['goals'] ?? 0);
        if (g != 0) return g;
        return a.key.compareTo(b.key);
      });

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 16, color: adminGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'JOUEURS SEDAN — CE MATCH',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: adminGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Source : live + fiche match. Sert aux comparaisons et au suivi individuel.',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.3),
          ),
          const SizedBox(height: 10),
          ...sorted.map((e) {
            final g = e.value['goals'] ?? 0;
            final y = e.value['yellow'] ?? 0;
            final r = e.value['red'] ?? 0;
            final subs = (e.value['subsIn'] ?? 0) + (e.value['subsOut'] ?? 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                  ),
                  if (g > 0) _chip('$g but${g > 1 ? 's' : ''}', adminGold),
                  if (y > 0) ...[
                    const SizedBox(width: 4),
                    _chip('$y J', const Color(0xFFE8C82A)),
                  ],
                  if (r > 0) ...[
                    const SizedBox(width: 4),
                    _chip('$r R', adminRed),
                  ],
                  if (subs > 0) ...[
                    const SizedBox(width: 4),
                    _chip('↔', const Color(0xFF4A90D9)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
