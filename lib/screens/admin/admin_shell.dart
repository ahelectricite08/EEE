import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/admin/presentation/routing/admin_routes.dart';
import 'admin_content_top_bar.dart';
import 'admin_palette.dart';
import 'admin_theme.dart';
import 'admin_nav_model.dart';
import 'admin_controller.dart';
import 'admin_lazy_tab_stack.dart';
import 'admin_sidebar.dart';
import 'widgets/admin_global_search.dart';
import 'admin_tab_registry.dart';
import 'workflows/admin_mobile_workflow_bar.dart';
import 'workflows/admin_workflow_hub.dart';

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
  const AdminShell({
    super.key,
    this.toolbarMode = AdminToolbarMode.embeddedFromApp,
  });

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
      if (idx == AdminTabIndex.matchReminder) {
        _controller.navigateToDiffusion(subTab: 1, syncBrowserUrl: false);
      } else if (idx == AdminTabIndex.estiDvcr ||
          idx == AdminTabIndex.tournament) {
        _controller.navigateToPronos(
          subTab: AdminTabIndex.pronosSubChampionnat,
          syncBrowserUrl: false,
        );
      } else if (idx == AdminTabIndex.badges) {
        if (_controller.allowedIndices.contains(AdminTabIndex.staff)) {
          _controller.navigateTo(AdminTabIndex.staff, syncBrowserUrl: false);
        }
      } else {
        _controller.navigateTo(idx, syncBrowserUrl: false);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tryApplyDeepLink);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminControllerProvider(
      controller: _controller,
      child: Theme(
        data: AdminTheme.wrap(Theme.of(context)),
        child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isWide = MediaQuery.of(context).size.width > 800;
          final visibleTabs = adminTabDefs
              .where((d) => _controller.allowedIndices.contains(d.index))
              .toList();
          final surfaceTitle = adminSurfaceTitle(
            surface: _controller.navSurface,
            workflow: _controller.workflow,
            tab: _controller.tab,
          );
          final body = Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: _controller.showingWorkflowHub,
                child: AdminLazyTabStack(
                  currentIndex: _controller.tab,
                  tabs: visibleTabs,
                ),
              ),
              if (_controller.showingWorkflowHub)
                AdminWorkflowHubPage(workflowId: _controller.workflow),
            ],
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
                    currentTabLabel: surfaceTitle,
                    currentWorkflow: _controller.workflow,
                    navSurface: _controller.navSurface,
                    toolsExpanded: _controller.toolsExpanded,
                    showStandaloneLogout:
                        widget.toolbarMode == AdminToolbarMode.standaloneWeb,
                    collapsed: _sidebarCollapsed,
                    onTabSelected: _controller.navigateTo,
                    onWorkflowSelected: _controller.selectWorkflow,
                    onToggleTools: _controller.toggleToolsExpanded,
                    onToggleCollapse: () => setState(
                      () => _sidebarCollapsed = !_sidebarCollapsed,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminContentTopBar(
                          tabLabel: surfaceTitle,
                          showBackToProfile: widget.toolbarMode ==
                              AdminToolbarMode.embeddedFromApp,
                        ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: adminBg,
            appBar: _buildAppBar(surfaceTitle),
            body: body,
            bottomNavigationBar: AdminMobileWorkflowBar(
              currentWorkflow: _controller.workflow,
              navSurface: _controller.navSurface,
              currentTab: _controller.tab,
              onWorkflowSelected: _controller.selectWorkflow,
              onOpenAllTools: () => showAdminAllToolsSheet(
                context: context,
                tabs: visibleTabs,
                onSelected: _controller.navigateTo,
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  AppBar _buildAppBar(String tabLabel) {
    final canPop = Navigator.canPop(context);
    final embedded = widget.toolbarMode == AdminToolbarMode.embeddedFromApp;

    Widget? leading;
    if (embedded) {
      leading = IconButton(
        tooltip: 'Retour au profil',
        icon: const Icon(
          Icons.person_rounded,
          color: adminTextPrimary,
          size: 22,
        ),
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

    final showLogoutMenu = embedded ||
        (widget.toolbarMode == AdminToolbarMode.standaloneWeb && canPop);

    return AppBar(
      backgroundColor: adminCard,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: leading,
      actions: [
        IconButton(
          tooltip: 'Rechercher',
          icon: const Icon(Icons.search_rounded, color: adminGrey, size: 22),
          onPressed: () => showAdminGlobalSearch(context),
        ),
        if (showLogoutMenu)
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
      ],
      title: Text(
        tabLabel,
        style: GoogleFonts.barlowCondensed(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: adminTextPrimary,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: adminBorder),
      ),
    );
  }
}
