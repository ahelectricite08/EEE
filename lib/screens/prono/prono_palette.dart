import 'package:flutter/material.dart';

import '../../features/prono/presentation/theme/prono_theme.dart';
import '../../theme/app_colors.dart';

/// Pronos DVCR — ivoire club, vert / or / rouge.
const pronoBg = PronoArenaTheme.scaffoldTop;
const pronoSurface = PronoArenaTheme.surface;
const pronoSurfaceMuted = PronoArenaTheme.surfaceMuted;
const pronoBorder = PronoArenaTheme.border;
const pronoText = PronoArenaTheme.text;
const pronoMutedText = PronoArenaTheme.textMuted;
const pronoGold = AppColors.gold;
const pronoGreen = AppColors.green;
const pronoGreenBright = Color(0xFF146B54);
const pronoGreenDeep = PronoArenaTheme.accentDeep;
const pronoRed = AppColors.red;
const pronoGrey = PronoArenaTheme.textMuted;
const pronoMint = AppColors.green;

/// Accent social — rouge club (plus de violet SaaS).
const pronoSocialPurple = AppColors.red;

const pronoSocialLeague = pronoSocialPurple;
const pronoSocialDuel = pronoSocialPurple;
const pronoSocialFriend = pronoSocialPurple;
const pronoSocialTopLeaguesBlue = pronoSocialPurple;
const pronoReward = pronoGold;

List<Color> pronoAccentStripeColors(Color accent) {
  final deep = Color.lerp(accent, const Color(0xFF14181A), 0.22)!;
  return [deep, accent];
}
