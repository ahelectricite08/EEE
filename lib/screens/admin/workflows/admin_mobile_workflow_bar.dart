import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_nav_model.dart';
import '../admin_palette.dart';
import 'admin_workflow_model.dart';

/// Bottom bar mobile : 4 flux + accès « Outils ».
class AdminMobileWorkflowBar extends StatelessWidget {
  final AdminWorkflowId currentWorkflow;
  final AdminNavSurface navSurface;
  final int currentTab;
  final ValueChanged<AdminWorkflowId> onWorkflowSelected;
  final VoidCallback onOpenAllTools;

  const AdminMobileWorkflowBar({
    super.key,
    required this.currentWorkflow,
    required this.navSurface,
    required this.currentTab,
    required this.onWorkflowSelected,
    required this.onOpenAllTools,
  });

  bool _selected(AdminWorkflowId id) {
    if (id == AdminWorkflowId.live) {
      return navSurface == AdminNavSurface.tab &&
          currentTab == AdminTabIndex.direct;
    }
    if (navSurface == AdminNavSurface.workflowHub) {
      return currentWorkflow == id;
    }
    return currentWorkflow == id;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: adminCard,
        border: Border(top: BorderSide(color: adminBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final w in AdminWorkflows.all)
                Expanded(
                  child: _BarItem(
                    label: w.shortLabel,
                    icon: w.icon,
                    selected: _selected(w.id),
                    accent: w.color,
                    onTap: () => onWorkflowSelected(w.id),
                  ),
                ),
              Expanded(
                child: _BarItem(
                  label: 'Outils',
                  icon: Icons.grid_view_rounded,
                  selected: false,
                  accent: adminGrey,
                  onTap: onOpenAllTools,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _BarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 2,
            color: selected ? accent : Colors.transparent,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? accent : adminGrey),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? adminTextPrimary : adminGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
