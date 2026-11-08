import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_nav_model.dart';
import '../admin_palette.dart';
import '../workflows/admin_workflow_model.dart';

/// Sidebar : jour de match (compact) + pages triées par métier, filtrables.
class AdminSidebarWorkflowNav extends StatefulWidget {
  final AdminWorkflowId currentWorkflow;
  final AdminNavSurface navSurface;
  final int currentTab;
  final bool toolsExpanded;
  final bool collapsed;
  final List<AdminTabDef> visibleTabs;
  final ValueChanged<AdminWorkflowId> onWorkflowSelected;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onToggleTools;

  const AdminSidebarWorkflowNav({
    super.key,
    required this.currentWorkflow,
    required this.navSurface,
    required this.currentTab,
    required this.toolsExpanded,
    required this.collapsed,
    required this.visibleTabs,
    required this.onWorkflowSelected,
    required this.onTabSelected,
    required this.onToggleTools,
  });

  @override
  State<AdminSidebarWorkflowNav> createState() =>
      _AdminSidebarWorkflowNavState();
}

class _AdminSidebarWorkflowNavState extends State<AdminSidebarWorkflowNav> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return Column(
        children: [
          for (final w in AdminWorkflows.all)
            _CollapsedWorkflowTile(
              def: w,
              selected: _isWorkflowSelected(w.id),
              onTap: () => widget.onWorkflowSelected(w.id),
            ),
        ],
      );
    }

    final q = _filter.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.visibleTabs
        : widget.visibleTabs
            .where((t) =>
                t.label.toLowerCase().contains(q) ||
                t.universe.label.toLowerCase().contains(q))
            .toList();
    final groups = groupAdminTabsByUniverse(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'JOUR DE MATCH',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: adminSidebarMuted,
              letterSpacing: 1.0,
            ),
          ),
        ),
        for (final w in AdminWorkflows.all)
          _WorkflowTile(
            def: w,
            selected: _isWorkflowSelected(w.id),
            onTap: () => widget.onWorkflowSelected(w.id),
          ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: adminBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrer les pages…',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 32),
              filled: true,
              fillColor: adminSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: adminHairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: adminHairline),
              ),
            ),
          ),
        ),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              group.$1.label.toUpperCase(),
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: group.$1.color,
                letterSpacing: 1.0,
              ),
            ),
          ),
          for (final def in group.$2)
            _ToolTile(
              def: def,
              selected: widget.navSurface == AdminNavSurface.tab &&
                  widget.currentTab == def.index,
              onTap: () => widget.onTabSelected(def.index),
            ),
        ],
      ],
    );
  }

  bool _isWorkflowSelected(AdminWorkflowId id) {
    if (id == AdminWorkflowId.live) {
      return widget.navSurface == AdminNavSurface.tab &&
          widget.currentTab == AdminTabIndex.direct;
    }
    if (widget.navSurface == AdminNavSurface.workflowHub) {
      return widget.currentWorkflow == id;
    }
    return widget.currentWorkflow == id &&
        AdminWorkflows.inferFromTab(widget.currentTab) == id;
  }
}

class _WorkflowTile extends StatelessWidget {
  final AdminWorkflowDef def;
  final bool selected;
  final VoidCallback onTap;

  const _WorkflowTile({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = def.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: adminSidebarHover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? adminSidebarSelected : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                def.icon,
                size: 18,
                color: selected ? accent : adminGrey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  def.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? adminTextPrimary : adminGrey,
                  ),
                ),
              ),
              if (def.id == AdminWorkflowId.live)
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: adminRed,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final AdminTabDef def;
  final bool selected;
  final VoidCallback onTap;

  const _ToolTile({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: selected ? adminSidebarSelected : Colors.transparent,
          child: Row(
            children: [
              Icon(
                def.icon,
                size: 15,
                color: selected ? def.universe.color : adminGrey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  def.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? adminTextPrimary : adminGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedWorkflowTile extends StatelessWidget {
  final AdminWorkflowDef def;
  final bool selected;
  final VoidCallback onTap;

  const _CollapsedWorkflowTile({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = def.color;

    return Tooltip(
      message: def.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 44,
          child: Center(
            child: Icon(
              def.icon,
              size: 20,
              color: selected ? accent : adminGrey,
            ),
          ),
        ),
      ),
    );
  }
}
