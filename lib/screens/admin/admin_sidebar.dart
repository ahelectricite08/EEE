import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import 'admin_palette.dart';
import 'admin_nav_model.dart';
import 'admin_shared_widgets.dart';

/// Sidebar web collapsible pour le panel admin.
class AdminSidebar extends StatelessWidget {
  final int currentTab;
  /// Onglets visibles (déjà filtrés par permissions).
  final List<AdminTabDef> visibleTabs;
  final Set<UserRole> userRoles;
  final AdminUniverse currentUniverse;
  final String currentTabLabel;
  /// Affiche le bloc déconnexion en bas (principalement web standalone).
  final bool showStandaloneLogout;
  final bool collapsed;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.currentTab,
    required this.visibleTabs,
    required this.userRoles,
    required this.currentUniverse,
    required this.currentTabLabel,
    required this.showStandaloneLogout,
    required this.collapsed,
    required this.onTabSelected,
    this.onToggleCollapse,
  });

  static const List<AdminUniverse> _universeOrder = [
    AdminUniverse.pilotage,
    AdminUniverse.live,
    AdminUniverse.contenu,
    AdminUniverse.diffusion,
    AdminUniverse.communaute,
    AdminUniverse.system,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: collapsed ? 64 : 270,
      decoration: const BoxDecoration(
        color: adminCard,
        border: Border(right: BorderSide(color: adminBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (!collapsed) _buildNavLabel(),
            Expanded(child: SingleChildScrollView(child: _buildNavItems())),
            const SizedBox(height: 8),
            Container(height: 1, color: adminBorder),
            if (!collapsed) _buildFooterNote(),
            if (showStandaloneLogout) _buildLogout(),
            _buildCollapseToggle(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (collapsed) {
      return Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: currentUniverse.color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: currentUniverse.color.withAlpha(80)),
          ),
          child: Center(
            child: Text(
              'A',
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: currentUniverse.color,
              ),
            ),
          ),
        ),
      );
    }

    final orderedRoles = userRoles.toList()
      ..sort(
        (a, b) => UserService.rolePriority
            .indexOf(a)
            .compareTo(UserService.rolePriority.indexOf(b)),
      );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [currentUniverse.color.withAlpha(46), adminBg],
        ),
        border: Border.all(color: currentUniverse.color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ADMIN',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: adminTextPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: adminGold.withAlpha(30),
                  border: Border.all(color: adminGold, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DVCR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currentUniverse.label == currentTabLabel
                ? currentTabLabel
                : '${currentUniverse.label} · $currentTabLabel',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminMiniInfoPill(
                icon: Icons.cloud_done_rounded,
                label: 'Synchro live',
              ),
              AdminMiniInfoPill(
                icon: Icons.offline_bolt_rounded,
                label: 'Cache Firestore',
              ),
            ],
          ),
          if (orderedRoles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Roles actifs',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: adminGreyLight,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: orderedRoles
                  .map(
                    (role) => AdminRoleChip(
                      label: role.displayName.toUpperCase(),
                      color: role.color,
                      icon: roleIcon(role),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Text(
        'Sections',
        style: GoogleFonts.barlowCondensed(
          fontSize: 11,
          color: adminGreyLight,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  Widget _buildNavItems() {
    final children = <Widget>[];
    if (collapsed) {
      for (final u in _universeOrder) {
        for (final def in visibleTabs.where((d) => d.universe == u)) {
          children.add(_navTileCollapsed(def));
        }
      }
      return Column(children: children);
    }
    for (final u in _universeOrder) {
      final group = visibleTabs.where((d) => d.universe == u).toList();
      if (group.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: u.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                u.label,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: adminGreyLight,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      );
      for (final def in group) {
        children.add(_navTileExpanded(def));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _navTileCollapsed(AdminTabDef def) {
    final sel = currentTab == def.index;
    final ac = def.universe.color;
    return Tooltip(
      message: def.label,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onTabSelected(def.index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 64,
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sel ? ac.withAlpha(30) : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: sel ? ac.withAlpha(90) : Colors.transparent,
                ),
              ),
              child: Icon(
                def.icon,
                size: 18,
                color: sel ? adminTextPrimary : adminGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTileExpanded(AdminTabDef def) {
    final sel = currentTab == def.index;
    final ac = def.universe.color;
    return GestureDetector(
      onTap: () => onTabSelected(def.index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  colors: [
                    ac.withAlpha(30),
                    adminGold.withAlpha(18),
                  ],
                )
              : null,
          color: sel ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? ac.withAlpha(90) : adminBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: sel
                    ? adminBorder.withAlpha(120)
                    : adminBorder.withAlpha(40),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                def.icon,
                size: 18,
                color: sel ? adminTextPrimary : adminGrey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                def.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? adminTextPrimary : adminGrey,
                ),
              ),
            ),
            if (sel)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ac,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ac.withAlpha(130),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: adminBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: adminBorder),
        ),
        child: Text(
          'Les droits d\'accès suivent les rôles et permissions en temps réel.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: adminGrey,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildLogout() {
    return GestureDetector(
      onTap: () => FirebaseAuth.instance.signOut(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: adminBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: collapsed
            ? const Center(
                child: Icon(Icons.logout_rounded, size: 16, color: adminGrey),
              )
            : Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 16, color: adminGrey),
                  const SizedBox(width: 10),
                  Text(
                    'Déconnexion',
                    style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCollapseToggle() {
    return GestureDetector(
      onTap: onToggleCollapse,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: collapsed ? Alignment.center : Alignment.centerRight,
        padding: EdgeInsets.only(right: collapsed ? 0 : 16),
        child: Icon(
          collapsed
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded,
          color: adminGrey,
          size: 20,
        ),
      ),
    );
  }
}
