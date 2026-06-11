import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../navigation/esti_dvcr_rollout.dart';
import '../../../../services/feature_flags_service.dart';
import '../tournament/tournament_tab.dart';

const _kEstiRed = Color(0xFFBA203C);

/// Section admin ESTI'DVCR : toggle visibilité + gestion des matchs.
class EstiDvcrAdminSection extends StatelessWidget {
  const EstiDvcrAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Visibilité ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FeatureFlagsService.ref.snapshots(),
            builder: (context, snap) {
              return _VisibilityCard(snap: snap);
            },
          ),
        ),
        const SizedBox(height: 4),

        // ── Gestion des matchs ─────────────────────────────────────────────────
        const Expanded(child: TournamentTab()),
      ],
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  final AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snap;
  const _VisibilityCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final isVisible = EstiDvcrRollout.isTabVisible;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVisible ? _kEstiRed.withAlpha(80) : adminBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: _kEstiRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "ESTI'DVCR",
                style: GoogleFonts.barlowCondensed(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _kEstiRed,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Switch(
                value: isVisible,
                activeThumbColor: _kEstiRed,
                onChanged: snap.hasData
                    ? (v) => FeatureFlagsService.setFlag(
                          EstiDvcrRollout.tabFlagKey,
                          v,
                        )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Active ou désactive l\'onglet Esti\'DVCR dans l\'app. '
            'Les pronos et classements sont conservés même si l\'onglet est masqué.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: adminGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            EstiDvcrRollout.tabFlagKey,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: adminGrey.withAlpha(160),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
