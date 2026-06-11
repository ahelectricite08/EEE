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
      duration: const Duration(milliseconds: 180),
      width: collapsed ? 64 : 270,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1A12),
        border: Border(right: BorderSide(color: Color(0xFF1E2E22))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (!collapsed) _buildNavLabel(),
            Expanded(child: SingleChildScrollView(child: _buildNavItems())),
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.white.withAlpha(18)),
            if (!collapsed) _buildFooterNote(),
            if (showStandaloneLogout) _buildLogout(),
            _buildCollapseToggle(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A1A12),
            const Color(0xFF111D16),
          ],
        ),
        border: Border.all(color: currentUniverse.color.withAlpha(70)),
        boxShadow: [
          BoxShadow(
            color: currentUniverse.color.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bande couleur univers en haut
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [currentUniverse.color, currentUniverse.color.withAlpha(0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.8],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo DVCR branding
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'DVCR',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: ' ADMIN',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: adminGold,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Rechercher',
                      onPressed: () => showAdminGlobalSearch(context),
                      icon: Icon(Icons.search_rounded, color: Colors.white.withAlpha(160), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: currentUniverse.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: currentUniverse.color.withAlpha(160),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        currentUniverse.label == currentTabLabel
                            ? currentTabLabel
                            : '${currentUniverse.label} · $currentTabLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withAlpha(140),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    'RÔLES ACTIFS',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(80),
                      letterSpacing: 1.2,
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
          ),
        ],
      ),
    );
  }

  Widget _buildNavLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Text(
        'NAVIGATION',
        style: GoogleFonts.barlowCondensed(
          fontSize: 10,
          color: Colors.white.withAlpha(60),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
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
                u.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withAlpha(60),
                  letterSpacing: 1.3,
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
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  colors: [ac.withAlpha(22), ac.withAlpha(8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: sel
              ? Border.all(color: ac.withAlpha(70))
              : null,
        ),
        child: Row(
          children: [
            // Barre accent gauche quand sélectionné
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: sel ? ac : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                boxShadow: sel
                    ? [BoxShadow(color: ac.withAlpha(120), blurRadius: 8)]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: sel ? ac.withAlpha(25) : adminBorder.withAlpha(30),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                def.icon,
                size: 16,
                color: sel ? ac : adminGrey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  def.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? Colors.white : Colors.white.withAlpha(130),
                  ),
                ),
              ),
            ),
            if (sel) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: ac,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: ac.withAlpha(140), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 12),
            ],
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
          color: Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: Text(
          'Les droits d\'accès suivent les rôles et permissions en temps réel.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withAlpha(80),
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
          color: Colors.white.withAlpha(6),
          border: Border.all(color: Colors.white.withAlpha(20)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: collapsed
            ? Center(
                child: Icon(Icons.logout_rounded, size: 16, color: Colors.white.withAlpha(100)),
              )
            : Row(
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: Colors.white.withAlpha(100)),
                  const SizedBox(width: 10),
                  Text(
                    'Déconnexion',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withAlpha(120)),
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
          color: Colors.white.withAlpha(80),
          size: 20,
        ),
      ),
    );
  }
}
