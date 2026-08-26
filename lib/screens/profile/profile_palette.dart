import 'package:flutter/material.dart';

/// Presse club — mêmes hex que Actus / Calendrier / Communauté.
const profileBg = Color(0xFFF4F0E6);
const profileSurface = Color(0xFFFFFDF8);
const profileSurfaceMuted = Color(0xFFEDE7D9);
const profileHairline = Color(0xFFE6E0D1);
const profileBorder = Color(0xFFDDD6C6);
const profileText = Color(0xFF14181A);
const profileMutedText = Color(0xFF5E6662);
const profileGreen = Color(0xFF0A4438);
const profileGreenDeep = Color(0xFF062921);
const profileGreenBright = Color(0xFF167A5F);
const profileInk = Color(0xFF0A1C18);
const profileGold = Color(0xFFC8A436);
const profileGoldDeep = Color(0xFF8A6A18);
const profileRed = Color(0xFFBA203C);

const double profilePaperRadius = 6;

int profileImageCacheWidth(BuildContext context, double logicalPx) {
  return (logicalPx * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

BoxDecoration profilePaper({Color? edge, Color? fill}) {
  return BoxDecoration(
    color: fill ?? profileSurface,
    borderRadius: BorderRadius.circular(profilePaperRadius),
    border: Border.all(color: edge ?? profileHairline, width: 1),
  );
}
