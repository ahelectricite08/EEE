import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

/// Voix admin — même famille que Home / TV / Profil.
abstract final class AdminType {
  static TextStyle get kicker => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        height: 1.1,
        color: adminGrey,
      );

  static TextStyle get title => GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        height: 1.05,
        letterSpacing: 0.4,
        color: adminTextPrimary,
      );

  static TextStyle get section => GoogleFonts.barlowCondensed(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: 0.3,
        color: adminTextPrimary,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: adminTextPrimary,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: adminGrey,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: adminOnAccent,
      );
}
