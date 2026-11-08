import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_module_shell.dart';
import 'admin_palette.dart';

/// Une rubrique d’une page admin — un job, pas un dump.
class AdminInteriorItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String group;
  final Widget child;

  /// Si true, [child] occupe tout l’espace (déjà un ListView / Stream).
  final bool fill;

  const AdminInteriorItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.group = '',
    this.fill = false,
  });
}

/// Intérieur de page : sommaire → une rubrique. Plus de mur de formulaires.
class AdminInteriorHub extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget? trailing;
  final Widget? indexHeader;
  final List<AdminInteriorItem> items;
  final bool showPageHeader;
  final int? initialIndex;
  final ValueChanged<int>? onOpen;

  const AdminInteriorHub({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.accent = adminGold,
    this.trailing,
    this.indexHeader,
    this.showPageHeader = true,
    this.initialIndex,
    this.onOpen,
  });

  @override
  State<AdminInteriorHub> createState() => _AdminInteriorHubState();
}

class _AdminInteriorHubState extends State<AdminInteriorHub> {
  int? _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant AdminInteriorHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != null &&
        _open == null) {
      _open = widget.initialIndex;
    }
  }

  void _go(int? index) {
    setState(() => _open = index);
    if (index != null) widget.onOpen?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null && open >= 0 && open < widget.items.length) {
      return _OpenPane(
        item: widget.items[open],
        accent: widget.accent,
        showPageHeader: widget.showPageHeader,
        pageTitle: widget.title,
        pageIcon: widget.icon,
        onBack: () => _go(null),
      );
    }

    final groups = <String, List<(int, AdminInteriorItem)>>{};
    for (var i = 0; i < widget.items.length; i++) {
      final g = widget.items[i].group.trim().isEmpty
          ? widget.title
          : widget.items[i].group;
      groups.putIfAbsent(g, () => []).add((i, widget.items[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPageHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AdminModuleHeader(
              title: widget.title,
              subtitle: widget.subtitle,
              icon: widget.icon,
              accent: widget.accent,
              trailing: widget.trailing,
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (widget.indexHeader != null) ...[
                widget.indexHeader!,
                const SizedBox(height: 18),
              ],
              for (final entry in groups.entries) ...[
                if (groups.length > 1) ...[
                  Text(
                    entry.key.toUpperCase(),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.accent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final pair in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HubCard(
                      item: pair.$2,
                      accent: widget.accent,
                      onTap: () => _go(pair.$1),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OpenPane extends StatelessWidget {
  final AdminInteriorItem item;
  final Color accent;
  final bool showPageHeader;
  final String pageTitle;
  final IconData pageIcon;
  final VoidCallback onBack;

  const _OpenPane({
    required this.item,
    required this.accent,
    required this.showPageHeader,
    required this.pageTitle,
    required this.pageIcon,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final back = TextButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 16),
      label: Text(
        'Toutes les rubriques',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AdminModuleHeader(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            accent: accent,
            trailing: back,
          ),
        ),
        Expanded(
          child: item.fill
              ? item.child
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [item.child],
                ),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  final AdminInteriorItem item;
  final Color accent;
  final VoidCallback onTap;

  const _HubCard({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adminCard,
      borderRadius: BorderRadius.circular(adminPaperRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(adminPaperRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adminPaperRadius),
            border: Border.all(color: adminHairline),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.3,
                        color: adminGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: adminGrey),
            ],
          ),
        ),
      ),
    );
  }
}
