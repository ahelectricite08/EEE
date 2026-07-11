import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import 'admin_palette.dart';
import 'admin_nav_model.dart';
import 'admin_shared_widgets.dart';
import 'widgets/admin_global_search.dart';

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
    AdminUniverse.competition,
    AdminUniverse.live,
    AdminUniverse.contenu,
    AdminUniverse.diffusion,
    AdminUniverse.communaute,
    AdminUniverse.jeux,
    AdminUniverse.system,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 72 : 260,
      decoration: BoxDecoration(
        color: adminSidebarBg,
        border: Border(
          right: BorderSide(color: adminSidebarBorder.withAlpha(180)),
        ),
        boxShadow: adminShellShadow,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (!collapsed) _buildNavLabel(),
            Expanded(child: SingleChildScrollView(child: _buildNavItems())),
            if (!collapsed && userRoles.isNotEmpty) _buildRolesFooter(),
            if (showStandaloneLogout) _buildLogout(),
            _buildCollapseToggle(),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: adminGoldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: adminGlowShadow(adminGold),
            ),
            child: Center(
              child: Text(
                'D',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminOnAccent,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: adminGoldGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: adminGlowShadow(adminGold),
                ),
                child: Center(
                  child: Text(
                    'D',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: adminOnAccent,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DVCR',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: adminRed,
                        letterSpacing: 0.5,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Administration',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: adminSidebarMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rechercher',
                onPressed: () => showAdminGlobalSearch(context),
                icon: const Icon(Icons.search_rounded, color: adminGrey, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  backgroundColor: adminSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: adminBorder),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: currentUniverse.color.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: currentUniverse.color.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(
                  currentUniverse.icon,
                  size: 14,
                  color: currentUniverse.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentTabLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: adminTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Text(
        'Navigation',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: adminSidebarMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
          child: Text(
            u.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: u.color.withAlpha(200),
              letterSpacing: 0.4,
            ),
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
          width: 72,
          height: 46,
          margin: const EdgeInsets.symmetric(vertical: 1),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sel ? adminSidebarSelected : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: sel ? ac.withAlpha(100) : Colors.transparent,
                ),
              ),
              child: Icon(
                def.icon,
                size: 18,
                color: sel ? ac : adminGrey,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTabSelected(def.index),
          borderRadius: BorderRadius.circular(10),
          hoverColor: adminSidebarHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? adminSidebarSelected : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: sel
                  ? Border.all(color: ac.withAlpha(60))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: sel ? ac.withAlpha(20) : adminSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? ac.withAlpha(70) : adminBorder,
                    ),
                  ),
                  child: Icon(
                    def.icon,
                    size: 15,
                    color: sel ? ac : adminGrey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    def.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? adminTextPrimary : adminGrey,
                    ),
                  ),
                ),
                if (sel)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: ac,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRolesFooter() {
    final orderedRoles = userRoles.toList()
      ..sort(
        (a, b) => UserService.rolePriority
            .indexOf(a)
            .compareTo(UserService.rolePriority.indexOf(b)),
      );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: adminBorder.withAlpha(180)),
          const SizedBox(height: 10),
          Text(
            'Vos rôles',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: adminSidebarMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: orderedRoles
                .map(
                  (role) => AdminRoleChip(
                    label: role.displayName,
                    color: role.color,
                    icon: roleIcon(role),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogout() {
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 10 : 12, 8, collapsed ? 10 : 12, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FirebaseAuth.instance.signOut(),
          borderRadius: BorderRadius.circular(10),
          hoverColor: adminRed.withAlpha(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminBorder),
            ),
            child: collapsed
                ? const Center(
                    child: Icon(Icons.logout_rounded, size: 16, color: adminGrey),
                  )
                : Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 16, color: adminGrey),
                      const SizedBox(width: 10),
                      Text(
                        'Déconnexion',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: adminGrey,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseToggle() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleCollapse,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          alignment: collapsed ? Alignment.center : Alignment.centerRight,
          padding: EdgeInsets.only(right: collapsed ? 0 : 14),
          child: Icon(
            collapsed
                ? Icons.chevron_right_rounded
                : Icons.chevron_left_rounded,
            color: adminSidebarMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}
