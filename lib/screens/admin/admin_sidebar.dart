import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import 'admin_palette.dart';
import 'admin_nav_model.dart';
import 'admin_shared_widgets.dart';
import 'widgets/admin_global_search.dart';
import 'workflows/admin_sidebar_workflow_nav.dart';
import 'workflows/admin_workflow_model.dart';

/// Sidebar web collapsible pour le panel admin.
class AdminSidebar extends StatelessWidget {
  final int currentTab;
  final List<AdminTabDef> visibleTabs;
  final Set<UserRole> userRoles;
  final String currentTabLabel;
  final AdminWorkflowId currentWorkflow;
  final AdminNavSurface navSurface;
  final bool toolsExpanded;
  final bool showStandaloneLogout;
  final bool collapsed;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<AdminWorkflowId> onWorkflowSelected;
  final VoidCallback onToggleTools;
  final VoidCallback? onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.currentTab,
    required this.visibleTabs,
    required this.userRoles,
    required this.currentTabLabel,
    required this.currentWorkflow,
    required this.navSurface,
    required this.toolsExpanded,
    required this.showStandaloneLogout,
    required this.collapsed,
    required this.onTabSelected,
    required this.onWorkflowSelected,
    required this.onToggleTools,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 72 : 248,
      decoration: const BoxDecoration(
        color: adminSidebarBg,
        border: Border(right: BorderSide(color: adminSidebarBorder)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: AdminSidebarWorkflowNav(
                  currentWorkflow: currentWorkflow,
                  navSurface: navSurface,
                  currentTab: currentTab,
                  toolsExpanded: toolsExpanded,
                  collapsed: collapsed,
                  visibleTabs: visibleTabs,
                  onWorkflowSelected: onWorkflowSelected,
                  onTabSelected: onTabSelected,
                  onToggleTools: onToggleTools,
                ),
              ),
            ),
            if (!collapsed && userRoles.isNotEmpty) _buildRolesFooter(),
            if (showStandaloneLogout) _buildLogout(),
            _buildCollapseToggle(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'D',
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: adminRed,
              height: 1,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DVCR ADMIN',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: adminRed,
                        letterSpacing: 0.4,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTabLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: adminSidebarMuted,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rechercher',
                onPressed: () => showAdminGlobalSearch(context),
                icon: const Icon(
                  Icons.search_rounded,
                  color: adminGrey,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: adminBorder),
          const SizedBox(height: 8),
          Text(
            'Rôles',
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
      padding: EdgeInsets.fromLTRB(collapsed ? 8 : 12, 8, collapsed ? 8 : 12, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FirebaseAuth.instance.signOut(),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: collapsed
                ? const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: adminGrey,
                    ),
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: adminGrey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Déconnexion',
                        style: GoogleFonts.inter(
                          fontSize: 12,
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
    return InkWell(
      onTap: onToggleCollapse,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Icon(
            collapsed
                ? Icons.chevron_right_rounded
                : Icons.chevron_left_rounded,
            color: adminGrey,
            size: 20,
          ),
        ),
      ),
    );
  }
}
