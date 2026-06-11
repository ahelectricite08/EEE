import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/app_settings_service.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import '../../features/admin/presentation/routing/admin_browser_history.dart';
import '../../features/admin/presentation/routing/admin_routes.dart';
import 'admin_nav_model.dart';
import 'admin_palette.dart';

/// État central du panel admin.
class AdminController extends ChangeNotifier {
  int _tab = 0;
  int _diffusionSubTab = 0;
  bool _roleLandingApplied = false;
  Set<UserRole> _userRoles = {};
  Map<String, List<String>> _permissionsConfig =
      RolePermissionsService.defaultPermissions;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rolesSub;
  StreamSubscription<Map<String, List<String>>>? _permissionsSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  int get tab => _tab;
  int get diffusionSubTab => _diffusionSubTab;
  Set<UserRole> get userRoles => _userRoles;
  Map<String, List<String>> get permissionsConfig => _permissionsConfig;

  List<int> get allowedIndices =>
      allowedTabIndices(_userRoles, _permissionsConfig);

  bool can(String permission) => RolePermissionsService.hasPermission(
        _userRoles,
        permission,
        _permissionsConfig,
      );

  AdminUniverse get currentUniverse => universeForTab(_tab);

  // ── Initialisation ─────────────────────────────────────────────────────────
  void init() {
    RolePermissionsService.ensureDefaults();
    unawaited(AppSettingsService.migrateLegacyTeamDvcrBadgeLabel());
    _listenRoles();
    _listenPermissions();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void navigateTo(int index, {bool syncBrowserUrl = true}) {
    if (_tab == index) return;
    _tab = index;
    if (syncBrowserUrl && kIsWeb) {
      final seg = AdminRoutes.segmentForTab(index);
      if (seg != null) {
        syncAdminBrowserPath('#${AdminRoutes.basePath}/$seg');
      }
    }
    notifyListeners();
  }

  void navigateToDiffusion({int subTab = 0, bool syncBrowserUrl = true}) {
    _diffusionSubTab = subTab.clamp(0, 1);
    navigateTo(AdminTabIndex.notifs, syncBrowserUrl: syncBrowserUrl);
  }

  void setDiffusionSubTab(int index) {
    final v = index.clamp(0, 1);
    if (_diffusionSubTab == v) return;
    _diffusionSubTab = v;
    notifyListeners();
  }

  void _maybeApplyRoleLanding() {
    if (_roleLandingApplied) return;
    final allowed = allowedIndices;
    if (allowed.isEmpty) return;

    if (kIsWeb) {
      final deep = AdminRoutes.tabIndexFromLocation(Uri.base.toString());
      if (deep != null && allowed.contains(deep)) {
        _tab = deep;
        if (deep == AdminTabIndex.matchReminder) {
          _tab = AdminTabIndex.notifs;
          _diffusionSubTab = 1;
        }
        _roleLandingApplied = true;
        return;
      }
    }

    int? target;
    if (_userRoles.contains(UserRole.admin) &&
        allowed.contains(AdminTabIndex.dashboard)) {
      target = AdminTabIndex.dashboard;
    } else if (_userRoles.contains(UserRole.statisticien) &&
        allowed.contains(AdminTabIndex.stats)) {
      target = AdminTabIndex.stats;
    } else if (_userRoles.contains(UserRole.editor) &&
        allowed.contains(AdminTabIndex.articles)) {
      target = AdminTabIndex.articles;
    } else if (_userRoles.contains(UserRole.communityManager) &&
        allowed.contains(AdminTabIndex.communaute)) {
      target = AdminTabIndex.communaute;
    }

    if (target != null && allowed.contains(target)) {
      _tab = target;
    } else {
      _tab = allowed.first;
    }
    _roleLandingApplied = true;
  }

  // ── Streams internes ───────────────────────────────────────────────────────
  void _listenRoles() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _rolesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
          final roles = UserService.parseRolesFromData(snap.data());
          _userRoles = roles;
          if (!allowedIndices.contains(_tab)) {
            _tab = allowedIndices.isNotEmpty ? allowedIndices.first : 0;
          }
          _maybeApplyRoleLanding();
          notifyListeners();
        });
  }

  void _listenPermissions() {
    _permissionsSub?.cancel();
    _permissionsSub = RolePermissionsService.stream().listen((config) {
      _permissionsConfig = config;
      if (!allowedIndices.contains(_tab)) {
        _tab = allowedIndices.isNotEmpty ? allowedIndices.first : 0;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _rolesSub?.cancel();
    _permissionsSub?.cancel();
    super.dispose();
  }
}

/// InheritedNotifier pour accès facile dans l'arbre.
class AdminControllerProvider extends InheritedNotifier<AdminController> {
  const AdminControllerProvider({
    super.key,
    required AdminController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminController of(BuildContext context) {
    final ctrl = maybeOf(context);
    assert(ctrl != null, 'AdminControllerProvider introuvable');
    return ctrl!;
  }

  static AdminController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminControllerProvider>()
        ?.notifier;
  }
}
