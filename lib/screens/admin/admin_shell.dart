import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/admin/presentation/routing/admin_routes.dart';
import 'admin_palette.dart';
import 'admin_nav_model.dart';
import 'admin_controller.dart';
import 'admin_sidebar.dart';
import 'admin_tab_registry.dart';

/// Barre d’outils : retour app vs déconnexion web.
enum AdminToolbarMode {
  /// Depuis le profil (push) : icône retour profil + déconnexion dans le menu.
  embeddedFromApp,
  /// Web / plein écran : déconnexion si pas d’historique de navigation.
  standaloneWeb,
}

// ── AdminShell ─────────────────────────────────────────────────────────────────
class AdminShell extends StatefulWidget {
  final AdminToolbarMode toolbarMode;
  const AdminShell({super.key, this.toolbarMode = AdminToolbarMode.embeddedFromApp});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final AdminController _controller;
  bool _sidebarCollapsed = false;
  bool _deepLinkApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AdminController();
    _controller.init();
    _controller.addListener(_tryApplyDeepLink);
  }

  void _tryApplyDeepLink() {
    if (_deepLinkApplied || !kIsWeb) return;
    if (_controller.allowedIndices.isEmpty) return;
    final idx = AdminRoutes.tabIndexFromLocation(Uri.base.toString());
    if (idx != null && _controller.allowedIndices.contains(idx)) {
      _deepLinkApplied = true;
      _controller.removeListener(_tryApplyDeepLink);
      _controller.navigateTo(idx, syncBrowserUrl: false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tryApplyDeepLink);
    _controller.dispose();
    super.dispose();
  }

  String _tabLabel(int tab) {
    for (final def in adminTabDefs) {
      if (def.index == tab) return def.label;
    }
    return 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    return AdminControllerProvider(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isWide = MediaQuery.of(context).size.width > 800;
          final visibleTabs = adminTabDefs
              .where((d) => _controller.allowedIndices.contains(d.index))
              .toList();
          final body = _LazyTabStack(
            currentIndex: _controller.tab,
            tabs: visibleTabs,
          );

          if (isWide) {
            return Scaffold(
              backgroundColor: adminBg,
              body: Row(
                children: [
                  AdminSidebar(
                    currentTab: _controller.tab,
                    visibleTabs: visibleTabs,
                    userRoles: _controller.userRoles,
                    currentUniverse: _controller.currentUniverse,
                    currentTabLabel: _tabLabel(_controller.tab),
                    showStandaloneLogout:
                        widget.toolbarMode == AdminToolbarMode.standaloneWeb,
                    collapsed: _sidebarCollapsed,
                    onTabSelected: _controller.navigateTo,
                    onToggleCollapse: () => setState(
                      () => _sidebarCollapsed = !_sidebarCollapsed,
                    ),
                  ),
                  Container(width: 1, color: adminBorder),
                  Expanded(child: body),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: adminBg,
            appBar: _buildAppBar(),
            body: body,
            bottomNavigationBar: _buildTabBar(),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    final universe = _controller.currentUniverse;
    final tabLabel = _tabLabel(_controller.tab);
    final canPop = Navigator.canPop(context);
    final embedded = widget.toolbarMode == AdminToolbarMode.embeddedFromApp;

    Widget? leading;
    if (embedded) {
      leading = IconButton(
        tooltip: 'Retour au profil',
        icon: const Icon(Icons.person_rounded, color: adminTextPrimary, size: 22),
        onPressed: () => Navigator.maybePop(context),
      );
    } else if (canPop) {
      leading = IconButton(
        tooltip: 'Retour',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: adminTextPrimary,
          size: 18,
        ),
        onPressed: () => Navigator.maybePop(context),
      );
    } else {
      leading = IconButton(
        tooltip: 'Déconnexion',
        icon: const Icon(Icons.logout_rounded, color: adminGrey, size: 20),
        onPressed: () => FirebaseAuth.instance.signOut(),
      );
    }

    final showLogoutMenu =
        embedded || (widget.toolbarMode == AdminToolbarMode.standaloneWeb && canPop);

    return AppBar(
      backgroundColor: adminBg,
      elevation: 0,
      leading: leading,
      actions: showLogoutMenu
          ? [
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (v) {
                  if (v == 'logout') FirebaseAuth.instance.signOut();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded, size: 20),
                      title: Text('Déconnexion'),
                      dense: true,
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.more_vert_rounded, color: adminGrey, size: 22),
                ),
              ),
            ]
          : const <Widget>[],
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ADMIN',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 26,
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
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: universe.color.withAlpha(18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: universe.color.withAlpha(80)),
            ),
            child: Text(
              universe.label == tabLabel
                  ? tabLabel
                  : '${universe.label} · $tabLabel',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: adminBorder),
      ),
    );
  }

  Widget _buildTabBar() {
    final allTabs = adminTabDefs
        .where((d) => _controller.allowedIndices.contains(d.index))
        .toList(); // keep order from registry

    const maxVisible = 5;
    final bool hasOverflow = allTabs.length > maxVisible;

    // Visible tabs: first 4 + "Plus" if overflow, else all
    final visibleTabs = hasOverflow ? allTabs.sublist(0, maxVisible - 1) : allTabs;
    final overflowTabs = hasOverflow ? allTabs.sublist(maxVisible - 1) : <AdminTabDef>[];
    final overflowSelected = overflowTabs.any((t) => t.index == _controller.tab);

    return Container(
      decoration: BoxDecoration(
        color: adminCard,
        border: const Border(top: BorderSide(color: adminBorder, width: 1)),
        boxShadow: adminCardShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              ...visibleTabs.map((t) => Expanded(child: _buildTabItem(t))),
              if (hasOverflow)
                Expanded(child: _buildMoreItem(overflowTabs, overflowSelected)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(AdminTabDef t) {
    final selected = _controller.tab == t.index;
    return GestureDetector(
      onTap: () => _controller.navigateTo(t.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [adminGold.withAlpha(40), adminGold.withAlpha(12)])
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? adminGold.withAlpha(110) : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.icon, size: 20, color: selected ? adminTextPrimary : adminGrey),
            const SizedBox(height: 3),
            Text(
              t.label,
              style: GoogleFonts.inter(
                fontSize: 8,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? adminTextPrimary : adminGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem(List<AdminTabDef> overflowTabs, bool overflowSelected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMoreSheet(overflowTabs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          gradient: overflowSelected
              ? LinearGradient(colors: [adminGold.withAlpha(40), adminGold.withAlpha(12)])
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: overflowSelected ? adminGold.withAlpha(110) : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view_rounded, size: 20, color: overflowSelected ? adminTextPrimary : adminGrey),
            const SizedBox(height: 3),
            Text(
              'Plus',
              style: GoogleFonts.inter(
                fontSize: 7, letterSpacing: 0.2,
                fontWeight: overflowSelected ? FontWeight.w800 : FontWeight.w500,
                color: overflowSelected ? adminTextPrimary : adminGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(List<AdminTabDef> overflowTabs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: adminCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Autres sections',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16, fontWeight: FontWeight.w900,
                color: adminGold, letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: overflowTabs.map((t) {
                final selected = _controller.tab == t.index;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _controller.navigateTo(t.index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? adminGold.withAlpha(25) : adminCardHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? adminGold.withAlpha(80) : adminBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 16, color: selected ? adminGold : adminGrey),
                        const SizedBox(width: 8),
                        Text(
                          t.label,
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: selected ? adminGold : adminGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── LazyTabStack ───────────────────────────────────────────────────────────────
/// Charge un onglet seulement à la première visite, puis le garde vivant.
class _LazyTabStack extends StatefulWidget {
  final int currentIndex;
  final List<AdminTabDef> tabs;

  const _LazyTabStack({required this.currentIndex, required this.tabs});

  @override
  State<_LazyTabStack> createState() => _LazyTabStackState();
}

class _LazyTabStackState extends State<_LazyTabStack> {
  // Indices globaux déjà construits
  final Set<int> _built = {};

  @override
  void didUpdateWidget(_LazyTabStack old) {
    super.didUpdateWidget(old);
    if (!_built.contains(widget.currentIndex)) {
      setState(() => _built.add(widget.currentIndex));
    }
  }

  @override
  void initState() {
    super.initState();
    _built.add(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.tabs.map((def) {
        final isActive = def.index == widget.currentIndex;
        final wasBuilt = _built.contains(def.index);
        if (!wasBuilt) return const SizedBox.shrink();
        return Offstage(
          offstage: !isActive,
          child: TickerMode(
            enabled: isActive,
            child: _KeepAliveWrapper(child: def.builder(context)),
          ),
        );
      }).toList(),
    );
  }
}

/// Garde l'état d'un onglet vivant même quand il est offstage.
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
