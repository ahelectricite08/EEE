import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_settings_service.dart';
import '../models/user_role.dart';
import 'user_service.dart';

class RolePermissionsService {
  static final DocumentReference<Map<String, dynamic>> _ref =
      AppSettingsService.configDoc('role_permissions');

  static const String adminAccess = 'admin.access';
  static const String adminDashboard = 'admin.dashboard';
  static const String adminDirect = 'admin.direct';
  static const String adminArticles = 'admin.articles';
  static const String adminMatches = 'admin.matches';
  static const String adminStats = 'admin.stats';
  static const String adminNotifs = 'admin.notifs';
  static const String adminUsers = 'admin.users';
  static const String adminCommunity = 'admin.community';
  static const String adminXp = 'admin.xp';
  static const String adminBadges = 'admin.badges';
  static const String adminSettings = 'admin.settings';
  static const String adminStades = 'admin.stades';
  static const String adminLogs = 'admin.logs';
  static const String chatAccess = 'chat.access';
  static const String commentsModerate = 'comments.moderate';

  static const List<String> allPermissions = [
    adminAccess,
    adminDashboard,
    adminDirect,
    adminArticles,
    adminMatches,
    adminStats,
    adminNotifs,
    adminUsers,
    adminCommunity,
    adminXp,
    adminBadges,
    adminSettings,
    adminStades,
    adminLogs,
    chatAccess,
    commentsModerate,
  ];

  static const Map<String, List<String>> defaultPermissions = {
    'supporter': [chatAccess],
    'donateur': [chatAccess],
    'partenaire': [chatAccess],
    'team_dvcr': [chatAccess],
    'editor': [adminAccess, adminArticles, chatAccess, commentsModerate],
    'community_manager': [
      adminAccess,
      adminMatches,
      adminCommunity,
      chatAccess,
      commentsModerate,
    ],
    'statisticien': [adminAccess, adminDirect, adminStats, chatAccess],
    'admin': allPermissions,
  };

  /// N’écrit que si les règles Firestore l’autorisent (`config` : admin).
  /// Les écrans chat / appel sans droit admin reçoivent permission-denied : on ignore
  /// et on s’appuie sur [defaultPermissions] côté client.
  static Future<void> ensureDefaults() async {
    try {
      final snap = await _ref.get();
      final existing = snap.data()?['roles'] as Map<String, dynamic>? ?? {};
      // Merge : ajoute les nouvelles permissions manquantes sans écraser les perso
      final merged = <String, dynamic>{};
      for (final entry in defaultPermissions.entries) {
        final current = (existing[entry.key] as List?)?.cast<String>() ?? [];
        final merged_ = {...current, ...entry.value}.toList();
        merged[entry.key] = merged_;
      }
      await _ref.set({
        'roles': merged,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }
  }

  static Stream<Map<String, List<String>>> stream() {
    return AppSettingsService.configStream(
      'role_permissions',
    ).map((data) => normalize(data));
  }

  static Map<String, List<String>> normalize(Map<String, dynamic>? data) {
    final rawRoles = data?['roles'];
    if (rawRoles is! Map) return defaultPermissions;

    final result = <String, List<String>>{};
    for (final entry in rawRoles.entries) {
      final values = entry.value is List
          ? (entry.value as List).whereType<String>().toList()
          : <String>[];
      result[entry.key.toString()] = values;
    }
    for (final entry in defaultPermissions.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
    return result;
  }

  static Set<String> permissionsForRoles(
    Set<UserRole> roles,
    Map<String, List<String>>? config,
  ) {
    final source = config ?? defaultPermissions;
    final permissions = <String>{};
    for (final role in roles) {
      permissions.addAll(source[role.firestoreRole] ?? const <String>[]);
    }
    return permissions;
  }

  static bool hasPermission(
    Set<UserRole> roles,
    String permission,
    Map<String, List<String>>? config,
  ) {
    return permissionsForRoles(roles, config).contains(permission);
  }

  static Future<void> setRolePermissions(
    String roleKey,
    List<String> permissions,
  ) async {
    await _ref.set({
      'roles': {roleKey: permissions.toSet().toList()..sort()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
