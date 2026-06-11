import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'prono_palette.dart';

/// Accents page social : [stripeAccent] = barre / filets extérieurs ;
/// [innerAccent] non null = léger voile sur fond des cartes (ex. vert à l’intérieur).
class PronoSocialPageAccent extends InheritedWidget {
  final Color stripeAccent;
  final Color? innerAccent;

  const PronoSocialPageAccent({
    super.key,
    required this.stripeAccent,
    this.innerAccent,
    required super.child,
  });

  static Color? maybeStripeAccent(BuildContext context) {
    return context
        .findAncestorWidgetOfExactType<PronoSocialPageAccent>()
        ?.stripeAccent;
  }

  static Color? maybeInnerAccent(BuildContext context) {
    return context
        .findAncestorWidgetOfExactType<PronoSocialPageAccent>()
        ?.innerAccent;
  }

  @override
  bool updateShouldNotify(PronoSocialPageAccent oldWidget) =>
      oldWidget.stripeAccent != stripeAccent ||
      oldWidget.innerAccent != innerAccent;
}

/// Hub prono (après l’Arène) : AppBar simple + **NavigationBar fixe en bas** + contenu stable.
class PronoShellScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool loading;
  final bool isAuthenticated;
  final Widget authWall;
  final List<Widget> pages;
  final VoidCallback onBack;

  const PronoShellScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.loading,
    required this.isAuthenticated,
    required this.authWall,
    required this.pages,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pronoBg,
      appBar: AppBar(
        backgroundColor: pronoSurface,
        foregroundColor: pronoText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: pronoText,
          ),
          onPressed: onBack,
        ),
        title: Text(
          'Pronos',
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: pronoText,
            letterSpacing: 0.6,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: pronoBorder),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: pronoGreen,
                strokeWidth: 2.2,
              ),
            )
          : !isAuthenticated
          ? authWall
          : IndexedStack(
              index: selectedIndex.clamp(0, pages.length - 1),
              children: pages,
            ),
      bottomNavigationBar: loading || !isAuthenticated
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: pronoGreen.withAlpha(70),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? pronoGreen : pronoMutedText,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? pronoGreen : pronoMutedText,
                    size: 22,
                  );
                }),
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: pronoSurface,
                surfaceTintColor: Colors.transparent,
                selectedIndex: selectedIndex.clamp(0, 2),
                onDestinationSelected: onDestinationSelected,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.sports_soccer_outlined),
                    selectedIcon: Icon(Icons.sports_soccer_rounded),
                    label: 'Jouer',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights_rounded),
                    label: 'Saison',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups_rounded),
                    label: 'Classement',
                  ),
                ],
              ),
            ),
    );
  }
}

class PronoSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  /// Surcharge rare ; sinon couleur = [PronoSocialPageAccent] ou vert prono.
  final Color? stripeColor;

  const PronoSectionCard({
    super.key,
    required this.child,
    this.padding,
    this.stripeColor,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    final stripeBase = stripeColor ??
        PronoSocialPageAccent.maybeStripeAccent(context) ??
        pronoGreen;
    final innerTint = PronoSocialPageAccent.maybeInnerAccent(context);
    final panelBg = innerTint != null
        ? (Color.lerp(pronoSurface, innerTint, 0.055) ?? pronoSurface)
        : pronoSurface;
    return Container(
      decoration: BoxDecoration(
        color: pronoSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pronoBorder),
        boxShadow: [
          BoxShadow(
            color: stripeBase.withAlpha(52),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        // Stack + bandeau Positioned : évite Row(stretch) sous hauteur max infinie
        // (CustomScrollView / SliverToBoxAdapter), qui provoquait h=Infinity / écran blanc.
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: pronoAccentStripeColors(stripeBase),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: ColoredBox(
                color: panelBg,
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PronoSectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PronoSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: pronoGold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: pronoText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: pronoMutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class PronoMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const PronoMetricChip({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pronoSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pronoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pronoMutedText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
