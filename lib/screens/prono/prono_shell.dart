import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/prono/presentation/theme/prono_theme.dart';
import 'prono_palette.dart';

/// Accents page social : [stripeAccent] = barre / filets extérieurs ;
/// [innerAccent] non null = léger voile sur fond des cartes.
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

/// Hub prono (après l'Arène) : AppBar simple + **NavigationBar fixe en bas** + contenu stable.
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
                color: pronoSocialPurple,
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
                indicatorColor: pronoSocialPurple.withAlpha(70),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? pronoSocialPurple : pronoMutedText,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? pronoSocialPurple : pronoMutedText,
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

  const PronoSectionCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    const radius = PronoArenaTheme.cardRadius;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: PronoTheme.cardDecoration(radius: radius),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(PronoArenaTheme.cardPadding),
        child: child,
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
                  fontWeight: FontWeight.w700,
                  color: pronoMutedText,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: pronoText,
                  height: 1.05,
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
