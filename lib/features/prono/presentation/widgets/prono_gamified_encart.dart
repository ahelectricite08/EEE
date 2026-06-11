import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/prono_tokens.dart';

/// Encart type « quête / bonus XP » — bordure dégradée, ruban, pastilles.
class PronoGamifiedTipCard extends StatelessWidget {
  final String headline;
  final String body;
  final List<String> chips;
  final IconData icon;
  final PronoIconAccent accent;
  final String cornerBadge;

  const PronoGamifiedTipCard({
    super.key,
    required this.headline,
    required this.body,
    this.chips = const [],
    this.icon = Icons.auto_awesome_rounded,
    this.accent = PronoIconAccent.energy,
    this.cornerBadge = 'XP',
  });

  /// Texte détaillé (ex-astuce progression).
  factory PronoGamifiedTipCard.xpRules() {
    return const PronoGamifiedTipCard(
      headline: 'MÊME BARÈME PARTOUT',
      icon: Icons.bolt_rounded,
      accent: PronoIconAccent.primary,
      chips: ['7 J AVANT', 'SCORE EXACT', 'DUELS', 'CLASSEMENT'],
      cornerBadge: 'LVL+',
      body:
          'Les pronos s’ouvrent en général 7 jours avant le coup d’envoi. '
          'Régularité, bons résultats, scores exacts et duels alimentent le même XP — '
          'pas de « progression réseau » à part.',
    );
  }

  /// Accueil prono — rappel court.
  factory PronoGamifiedTipCard.homeBoost() {
    return const PronoGamifiedTipCard(
      headline: 'ENCHAÎNE LES BONS PLANS',
      icon: Icons.stars_rounded,
      accent: PronoIconAccent.primary,
      chips: ['MATCHS', 'TOP 50', 'SOCIAL'],
      cornerBadge: 'GO',
      body:
          'Chaque prono compte pour ton XP et ton niveau. Ouvre l’onglet Matchs '
          'dès que la fenêtre à 7 jours est verte, et enchaîne classement & duels pour monter plus vite.',
    );
  }

  /// Onglet matchs — focus calendrier.
  factory PronoGamifiedTipCard.matchWindow() {
    return const PronoGamifiedTipCard(
      headline: 'FENÊTRE DE PRONO',
      icon: Icons.schedule_rounded,
      accent: PronoIconAccent.matches,
      chips: ['−7 J', 'OUVERT', 'LOCK'],
      cornerBadge: '+PTS',
      body:
          'Tant que le badge n’est pas « Pronostiquer », le match est encore fermé ou trop tôt. '
          'Les cartes avec barre verte + icône tactile sont prêtes : tape pour placer ton score.',
    );
  }

  /// Bandeau social — remplace un simple gris.
  factory PronoGamifiedTipCard.socialArena() {
    return const PronoGamifiedTipCard(
      headline: 'ARÈNE SOCIALE',
      icon: Icons.celebration_rounded,
      accent: PronoIconAccent.social,
      chips: ['LIGUES', 'DUELS', 'POTES'],
      cornerBadge: 'PVP',
      body:
          'Ligues privées, duels sur un match et fil d’amis : tout ça pilote la même XP '
          'que tes pronos — idéal pour défier la tribu avant le coup d’envoi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentCol = PronoTokens.iconAccentColors(accent).$3;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 2),
        boxShadow: [
          BoxShadow(
            color: PronoTokens.accentDeep.withAlpha(22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PronoTokens.radiusLg + 2),
            color: PronoTokens.accent,
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PronoTokens.radiusLg),
              color: PronoTokens.surface,
              border: Border.all(
                color: PronoTokens.border.withAlpha(100),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: PronoTokens.iconBadgeDecoration(
                        radius: 15,
                        accent: accent,
                      ),
                      child: Icon(
                        icon,
                        color: accentCol,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: PronoTokens.text,
                              letterSpacing: 0.6,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (chips.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: chips
                                  .map(
                                    (c) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentCol.withAlpha(22),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: accentCol.withAlpha(70),
                                        ),
                                      ),
                                      child: Text(
                                        c,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: accentCol,
                                          letterSpacing: 0.45,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.rotate(
                      angle: 0.35,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: PronoTokens.accentGold,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withAlpha(90),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          cornerBadge,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: PronoTokens.accentDeep,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: PronoTokens.barStripeColors(active: true),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PronoTokens.text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
