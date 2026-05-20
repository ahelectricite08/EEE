import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/role_permissions_service.dart';
import '../../services/user_service.dart';
import '../../features/admin/presentation/routing/admin_browser_history.dart';
import '../../features/admin/presentation/routing/admin_routes.dart';
import 'admin_nav_model.dart';
import 'admin_palette.dart';

/// État central du panel admin.
/// Exposé via InheritedNotifier ou directement passé aux widgets.
class AdminController extends ChangeNotifier {
  int _tab = 0;
  Set<UserRole> _userRoles = {};
  Map<String, List<String>> _permissionsConfig =
      RolePermissionsService.defaultPermissions;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rolesSub;
  StreamSubscription<Map<String, List<String>>>? _permissionsSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  int get tab => _tab;
  Set<UserRole> get userRoles => _userRoles;
  Map<String, List<String>> get permissionsConfig => _permissionsConfig;

  List<int> get allowedIndices =>
      allowedTabIndices(_userRoles, _permissionsConfig);

  AdminUniverse get currentUniverse => universeForTab(_tab);

  // ── Initialisation ─────────────────────────────────────────────────────────
  void init() {
    RolePermissionsService.ensureDefaults();
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
          // Si l'onglet actuel n'est plus accessible, aller au premier dispo
          if (!allowedIndices.contains(_tab)) {
            _tab = allowedIndices.isNotEmpty ? allowedIndices.first : 0;
          }
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
    final provider = context
        .dependOnInheritedWidgetOfExactType<AdminControllerProvider>();
    assert(provider != null, 'AdminControllerProvider introuvable');
    return provider!.notifier!;
  }
}
