import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../navigation/app_store_safe_mode.dart';
import '../../../../services/feature_flags_service.dart';
import '../../admin_palette.dart';

/// Un switch — passage App Store / tout remettre après, sans effacer HelloAsso / VOD / partenaires.
class AppStoreSafeModeAdminSection extends StatelessWidget {
  const AppStoreSafeModeAdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        final hiding = AppStoreSafeMode.hidesUserMonetization(snap.data?.data());
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          decoration: BoxDecoration(
            color: hiding
                ? adminOrange.withValues(alpha: 0.10)
                : adminCard,
            borderRadius: BorderRadius.circular(adminPaperRadius),
            border: Border.all(
              color: hiding ? adminOrange : adminHairline,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASSAGE APP STORE',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: hiding ? adminOrange : adminGreen,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hiding
                    ? 'Mode review ON — l’app utilisateur ne montre plus adhésion, VOD adhérents ni bannières partenaire. '
                        'La config HelloAsso / VOD / partenaires reste en base. Coupe le switch pour tout remettre, sans nouveau build iOS.'
                    : 'Avant d’archiver pour Apple : active ce switch. Après validation Store : désactive-le — tout revient (dates HelloAsso, VOD, partenaires inchangés).',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: adminGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hiding
                              ? 'Masquer adhésion / VOD / partenaires'
                              : 'App normale (tout visible)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStoreSafeMode.flagKey,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: adminGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Splash adhésion · bandeaux adhérer / Rejoins la famille / soutien · VOD adhérents · bannières partenaire. '
                          'Admin, radio et billeterie restent.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: adminGrey,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: hiding,
                    onChanged: snap.hasData
                        ? (v) => FeatureFlagsService.setFlag(
                              AppStoreSafeMode.flagKey,
                              v,
                            )
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
