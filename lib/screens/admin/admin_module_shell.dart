import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_palette.dart';

export 'admin_segmented_control.dart';

/// En-tête de page module — typo + barre d’accent (aligné hubs, anti-GPT).
class AdminModuleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const AdminModuleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.dashboard_rounded,
    this.accent = adminGold,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: adminTextPrimary,
                          height: 1.05,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Bloc section : en-tête de rubrique + contenu.
///
/// [wrapInCard] : false quand le [child] contient déjà ses propres cartes
/// (ex. live, salon) pour éviter l’empilement visuel.
class AdminModuleSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? accent;
  final bool wrapInCard;

  const AdminModuleSection({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.child,
    this.accent,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final ac = accent ?? adminGold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: ac,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: ac,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: adminTextPrimary,
                      height: 1.05,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: adminGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (wrapInCard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: adminPaper(),
            child: child,
          )
        else
          child,
      ],
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Page scrollable avec en-tête module unifié.
class AdminTabPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final Future<void> Function()? onRefresh;

  const AdminTabPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = adminGold,
    this.trailing,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 28),
    this.physics,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: padding,
      physics: physics ??
          const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
      children: [
        AdminModuleHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          accent: accent,
          trailing: trailing,
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
    if (onRefresh == null) return body;
    return RefreshIndicator(color: adminGreen, onRefresh: onRefresh!, child: body);
  }
}

/// Page avec sous-onglets (Réglages, XP, etc.).
class AdminTabPageWithSubTabs extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final TabController controller;
  final List<Widget> tabs;
  final List<Widget> tabViews;
  final Widget? headerPrefix;
  final Widget? headerSuffix;

  const AdminTabPageWithSubTabs({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.controller,
    required this.tabs,
    required this.tabViews,
    this.accent = adminGold,
    this.headerPrefix,
    this.headerSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headerPrefix != null) headerPrefix!,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accent: accent,
          ),
        ),
        if (headerSuffix != null) headerSuffix!,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AdminSubTabBar(
            controller: controller,
            tabs: tabs,
            accent: accent,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: tabViews,
          ),
        ),
      ],
    );
  }
}

/// Barre de sous-onglets cohérente.
class AdminSubTabBar extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  final Color accent;
  final ValueChanged<int>? onTap;

  const AdminSubTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.accent = adminGold,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: adminPaper(),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        isScrollable: tabs.length > 4,
        tabAlignment: tabs.length > 4 ? TabAlignment.start : TabAlignment.fill,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: accent.withAlpha(20),
          borderRadius: BorderRadius.circular(adminPaperRadius - 2),
          border: Border.all(color: accent.withAlpha(70), width: 1),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        labelColor: accent,
        unselectedLabelColor: adminGrey,
        tabs: tabs,
      ),
    );
  }
}

/// Alias sémantiques (nouveaux écrans).
typedef AdminPageHeader = AdminModuleHeader;
typedef AdminSection = AdminModuleSection;

