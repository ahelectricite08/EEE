import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Pronos DVCR — surfaces douces, texte foncé ; or + vert sur les cadres ; barres d’accent = vert seul.
const pronoBg = AppColorsLight.scaffold;
const pronoSurface = AppColorsLight.card;
const pronoSurfaceMuted = AppColorsLight.cardMuted;
const pronoBorder = AppColorsLight.border;
const pronoText = AppColorsLight.textPrimary;
const pronoMutedText = AppColorsLight.textSecondary;
const pronoGold = AppColors.gold;
const pronoGreen = AppColors.green;
/// Dégradés hero / bandeaux (sur photo), pas pour les cartes liste.
const pronoGreenDeep = Color(0xFF062921);
const pronoRed = AppColors.red;
const pronoGrey = AppColors.grey;
/// Accent discret (live) — vert institutionnel, pas de néon.
const pronoMint = AppColors.green;
const pronoGlass = Color(0xE8FFFFFF);

/// Accents écrans social prono (moins d’or, lecture par contexte).
const pronoSocialLeague = Color(0xFF6B4F9A);
const pronoSocialDuel = Color(0xFFD94A5D);
const pronoSocialFriend = Color(0xFF1E8A8A);
/// Top ligues : barre / AppBar « extérieur » bleu (intérieur cartes = vert prono).
const pronoSocialTopLeaguesBlue = Color(0xFF2563EB);
/// XP / récompenses duel — touche « jeu » sans saturer en or.
const pronoReward = Color(0xFFE07800);

/// Dégradé barre verticale (cartes social, AppBar) : couleur thème → or DVCR.
List<Color> pronoAccentStripeColors(Color accent) {
  final deep = Color.lerp(accent, const Color(0xFF121814), 0.44)!;
  final tip = Color.lerp(accent, pronoGold, 0.40)!;
  return [deep, accent, tip];
}
