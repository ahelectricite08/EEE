import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';



import '../theme/prono_theme.dart';

import '../theme/prono_tokens.dart';



/// Encart informatif — panneau arène discret.

class PronoGamifiedTipCard extends StatelessWidget {

  final String headline;

  final String body;

  final IconData icon;



  const PronoGamifiedTipCard({

    super.key,

    required this.headline,

    required this.body,

    this.icon = Icons.info_outline_rounded,

  });



  factory PronoGamifiedTipCard.xpRules() {

    return const PronoGamifiedTipCard(

      headline: 'Même barème partout',

      icon: Icons.rule_rounded,

      body:

          'Les pronos s’ouvrent en général 7 jours avant le coup d’envoi. '

          'Régularité, bons résultats, scores exacts et duels alimentent le même XP.',

    );

  }



  factory PronoGamifiedTipCard.matchWindow() {

    return const PronoGamifiedTipCard(

      headline: 'Fenêtre de prono',

      icon: Icons.schedule_rounded,

      body:

          'Les matchs s’ouvrent 7 jours avant le coup d’envoi. '

          'Tape sur une carte pour placer ton score.',

    );

  }



  factory PronoGamifiedTipCard.socialArena() {

    return const PronoGamifiedTipCard(

      headline: 'Communauté',

      icon: Icons.groups_rounded,

      body:

          'Ligues privées, duels et amis : tout alimente la même XP que tes pronos.',

    );

  }



  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: PronoTheme.cardDecoration(

        radius: PronoTokens.radiusMd,

        background: PronoTokens.surfaceElevated,

      ),

      padding: const EdgeInsets.all(14),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Container(

            padding: const EdgeInsets.all(8),

            decoration: PronoTokens.iconBadgeDecoration(radius: 8),

            child: Icon(icon, size: 18, color: PronoTokens.textMuted),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  headline,

                  style: GoogleFonts.barlowCondensed(

                    fontSize: 15,

                    fontWeight: FontWeight.w800,

                    color: PronoTokens.text,

                    letterSpacing: 0.2,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  body,

                  style: GoogleFonts.inter(

                    fontSize: 12,

                    fontWeight: FontWeight.w500,

                    color: PronoTokens.textMuted,

                    height: 1.45,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}


