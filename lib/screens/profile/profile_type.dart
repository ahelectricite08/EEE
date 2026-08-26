import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profile_palette.dart';

/// Voix Profil — Barlow Condensed titres / chiffres, Inter corps.
abstract final class ProfileType {
  static TextStyle get nameplate => GoogleFonts.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
        color: Colors.white,
      );

  static TextStyle get kickerOnPhoto => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.85,
        color: Colors.white.withValues(alpha: 0.88),
      );

  static TextStyle get masthead => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.2,
        height: 0.95,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: profileText,
        letterSpacing: 0.1,
        height: 1.02,
      );

  static TextStyle get section => GoogleFonts.barlowCondensed(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: profileText,
        letterSpacing: 0.35,
      );

  static TextStyle get figure => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: profileText,
        height: 1.0,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: profileText,
        height: 1.25,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: profileMutedText,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: profileMutedText,
        height: 1.35,
      );

  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: profileMutedText,
      );
}
