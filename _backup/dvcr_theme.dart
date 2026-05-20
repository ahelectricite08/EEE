import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Thème DVCR — Style OL TV / Gentle Mates
class DVCRTheme {
  // ── Couleurs principales DVCR ──────────────────────────────────────────
  static const Color primaryRed   = Color(0xFFBA203C); // Carton Rouge
  static const Color primaryGreen = Color(0xFF0A4438); // Drapeau Vert
  static const Color primaryBlue  = Color(0xFF00B0FF);

  // ── Backgrounds ────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF000000);
  static const Color navyBackground = Color(0xFF0A0A0A);
  static const Color surfaceDark    = Color(0xFF0E0E0E);
  static const Color surfaceCard    = Color(0xFF141414);
  static const Color surfaceLight   = Color(0xFF1C1C1C);
  static const Color divider        = Color(0xFF1C1C1C);

  // ── Textes ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted     = Color(0xFF546E7A);

  // ── Rôles ─────────────────────────────────────────────────────────────
  static const Color adminColor              = Color(0xFFFFD700);
  static const Color communityManagerColor   = Color(0xFF00B0FF);
  static const Color partenaireColor         = Color(0xFFAB47BC);
  static const Color donateurColor           = Color(0xFFFF7043);
  static const Color supporterColor          = Color(0xFF0A4438);

  // ── Couleurs legacy ────────────────────────────────────────────────────
  static const Color primaryPurple = Color(0xFFAB47BC);
  static const Color primaryOrange = Color(0xFFFF7043);

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF080D14), Color(0xFF0C1220)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A4438), Color(0xFF062E24)],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBA203C), Color(0xFF8A1528)],
  );

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF080D14), Color(0xFF0C1220)],
  );

  // ── TextStyle legacy (compatibilité écrans existants) ─────────────────
  static const TextStyle displayLarge = TextStyle(
      fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.0);
  static const TextStyle displayMedium = TextStyle(
      fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1);
  static const TextStyle displaySmall = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2);
  static const TextStyle headlineLarge = TextStyle(
      fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.25, height: 1.3);
  static const TextStyle headlineMedium = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle headlineSmall = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle titleLarge = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle titleMedium = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle titleSmall = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle bodyLarge = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle bodyMedium = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle bodySmall = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static const TextStyle labelLarge = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.3);
  static const TextStyle labelMedium = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.25, height: 1.3);
  static const TextStyle labelSmall = TextStyle(
      fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.25, height: 1.3);

  // ── Typography — Barlow Condensed ──────────────────────────────────────
  /// Titres de section : condensed bold italic rouge/vert — le "look OL TV"
  static TextStyle sectionTitle({Color color = primaryGreen}) =>
      GoogleFonts.barlowCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
        color: color,
        height: 1.1,
      );

  static TextStyle heroTitle() => GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
        color: textPrimary,
        height: 1.0,
      );

  static TextStyle displayHero() => GoogleFonts.barlowCondensed(
        fontSize: 42,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.5,
        color: textPrimary,
        height: 1.0,
      );

  static TextStyle label({
    double size = 11,
    Color color = textMuted,
    double spacing = 1.5,
  }) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: spacing,
        color: color,
      );

  static TextStyle body({double size = 13, Color color = textSecondary}) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyBold({double size = 13, Color color = textPrimary}) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── ThemeData ──────────────────────────────────────────────────────────
  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primaryGreen,
        onPrimary: Colors.black,
        secondary: primaryRed,
        onSecondary: Colors.white,
        error: primaryRed,
        surface: surfaceDark,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: 1,
        ),
      ),
      textTheme: GoogleFonts.barlowTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: divider,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),
    );
  }

  // ── Widgets réutilisables ──────────────────────────────────────────────

  /// Titre de section style OL TV — condensed bold italic
  static Widget sectionHeader(String title,
      {Color color = primaryGreen,
      VoidCallback? onSeeAll,
      String seeAllLabel = 'VOIR TOUT'}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(title, style: sectionTitle(color: color)),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                seeAllLabel,
                style: label(color: textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ── RoleBadge ──────────────────────────────────────────────────────────────
class RoleBadge extends StatelessWidget {
  final String role;
  final double size;

  const RoleBadge({super.key, required this.role, this.size = 28});

  Color get _color {
    switch (role.toLowerCase()) {
      case 'admin':
        return DVCRTheme.adminColor;
      case 'community_manager':
        return DVCRTheme.communityManagerColor;
      case 'partenaire':
        return DVCRTheme.partenaireColor;
      case 'donateur':
        return DVCRTheme.donateurColor;
      default:
        return DVCRTheme.supporterColor;
    }
  }

  String get _icon {
    switch (role.toLowerCase()) {
      case 'admin':           return '👑';
      case 'community_manager': return '🛡️';
      case 'partenaire':       return '🤝';
      case 'donateur':         return '💰';
      default:                 return '❤️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: size * 0.45, vertical: size * 0.2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_icon, style: TextStyle(fontSize: size * 0.45)),
          const SizedBox(width: 5),
          Text(
            role.toUpperCase(),
            style: GoogleFonts.barlowCondensed(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── LiveBadge ─────────────────────────────────────────────────────────────
class LiveBadge extends StatelessWidget {
  final int viewers;
  const LiveBadge({super.key, required this.viewers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DVCRTheme.primaryRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EN DIRECT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          if (viewers > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$viewers',
              style: GoogleFonts.barlow(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── DVCRCard ──────────────────────────────────────────────────────────────
class DVCRCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const DVCRCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DVCRTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor!.withOpacity(0.3), width: 1)
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ── SectionHeader (legacy compat) ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.color = DVCRTheme.primaryGreen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: DVCRTheme.sectionTitle(color: color)),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text('VOIR TOUT', style: DVCRTheme.label()),
          ),
      ],
    );
  }
}
