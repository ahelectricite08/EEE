import 'package:flutter/material.dart';

import '../../features/prono/presentation/theme/prono_theme.dart';
import '../../theme/app_colors.dart';

/// Pronos DVCR — palette « White Minimal Gaming ».
const pronoBg = PronoArenaTheme.scaffoldTop;
const pronoSurface = PronoArenaTheme.surface;
const pronoSurfaceMuted = PronoArenaTheme.surfaceMuted;
const pronoBorder = PronoArenaTheme.border;
const pronoText = PronoArenaTheme.text;
const pronoMutedText = PronoArenaTheme.textMuted;
const pronoGold = AppColors.gold;
const pronoGreen = AppColors.green;
/// Alias historique — même vert CSSA (plus de fluo).
const pronoGreenBright = AppColors.green;
const pronoGreenDeep = PronoArenaTheme.accentDeep;
const pronoRed = AppColors.red;
const pronoGrey = PronoArenaTheme.textMuted;
const pronoMint = AppColors.green;

/// Accent social unifié (onglet Communauté).
const pronoSocialPurple = Color(0xFF7C3AED);

/// Accents écrans social prono — teinte violette cohérente.
const pronoSocialLeague = pronoSocialPurple;
const pronoSocialDuel = pronoSocialPurple;
const pronoSocialFriend = pronoSocialPurple;
const pronoSocialTopLeaguesBlue = pronoSocialPurple;
const pronoReward = pronoGold;

/// Barre latérale cartes social — bande unie (pas de mélange vert).
List<Color> pronoAccentStripeColors(Color accent) {
  final deep = Color.lerp(accent, const Color(0xFF1A1A1F), 0.22)!;
  return [deep, accent];
}
