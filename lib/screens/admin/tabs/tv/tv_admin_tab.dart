import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../settings/tv_settings_panel.dart';

/// Onglet admin dédié Android TV (sidebar → Système).
class TvAdminTab extends StatelessWidget {
  const TvAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: adminOrange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANDROID TV (DVCR)',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: adminTextPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Flux HLS, direct TV, récaps audience — visible selon la permission « admin.tv ».',
                      style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.live_tv_rounded, color: adminOrange.withAlpha(200), size: 28),
            ],
          ),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: TvSettingsPanel(),
          ),
        ),
      ],
    );
  }
}
