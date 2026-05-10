import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

export '../models/user_role.dart'
    show UserRole, UserRoleExtension, kUserRolePriority;

/// Service de gestion des utilisateurs et rôles
class UserService {
  /// Compat : même ordre que [kUserRolePriority].
  static const List<UserRole> rolePriority = kUserRolePriority;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 📝 Créer un nouveau document utilisateur
  static Future<void> createUser({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    UserRole role = UserRole.supporter,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'emailLower': email.toLowerCase(),
      'firstName': firstName,
      'lastName': lastName,
      'role': role.firestoreRole,
      'roles': [role.firestoreRole],
      'displayName': '$firstName $lastName',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'isActive': true,
      'totalDonations': 0.0,
      'canAccessChat': true,
    });
  }

  /// Récupérer les données utilisateur
  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Récupérer les données utilisateur par UID
  static Future<Map<String, dynamic>?> getUserDataByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Rôle principal d'un ensemble de rôles
  static UserRole primaryRole(Set<UserRole> roles) => primaryUserRole(roles);

  /// Parser les rôles depuis un document Firestore (supporte l'ancien champ 'role' et le nouveau 'roles')
  static Set<UserRole> parseRolesFromData(Map<String, dynamic>? data) {
    return parseUserRolesFromDoc(data);
  }

  /// Récupérer tous les rôles actuels
  static Future<Set<UserRole>> getCurrentRoles() async {
    final userData = await getUserData();
    return parseRolesFromData(userData);
  }

  /// Récupérer le rôle principal actuel
  static Future<UserRole> getCurrentRole() async {
    return primaryRole(await getCurrentRoles());
  }

  /// Vérifier si l'utilisateur peut accéder au chat
  static Future<bool> canAccessChatAsync() async {
    final roles = await getCurrentRoles();
    return roles.isNotEmpty;
  }

  /// Vérifier si l'utilisateur peut modérer (matchs, replay, vidéos) — admin only
  static Future<bool> canModerate() async {
    final roles = await getCurrentRoles();
    return roles.contains(UserRole.admin);
  }

  /// Vérifier si l'utilisateur peut éditer les articles — admin + éditeur
  static Future<bool> canEditArticles() async {
    final roles = await getCurrentRoles();
    return roles.contains(UserRole.admin) || roles.contains(UserRole.editor);
  }

  /// ✅ Vérifier si l'utilisateur est admin
  static Future<bool> isAdmin() async {
    final roles = await getCurrentRoles();
    return roles.contains(UserRole.admin);
  }

  /// 🔄 Mettre à jour le rôle (avec vérification des donations)
  static Future<void> updateRoleBasedOnDonations(double totalDonations) async {
    final user = _auth.currentUser;
    if (user == null) return;

    UserRole newRole = UserRole.supporter;

    if (totalDonations >= 500) {
      newRole = UserRole.partenaire;
    } else if (totalDonations >= 100) {
      newRole = UserRole.donateur;
    }

    await _firestore.collection('users').doc(user.uid).update({
      'role': newRole.firestoreRole,
      'roles': [newRole.firestoreRole],
      'totalDonations': totalDonations,
      'canAccessChat': true,
    });
  }

  /// 📝 Mettre à jour la dernière connexion
  static Future<void> updateLastLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  static const String kProfileHeroBackgroundIndexField =
      'profileHeroBackgroundIndex';

  /// Index 0..2 : fond d’écran choisi pour le bandeau profil.
  static int profileHeroBackgroundIndexFromData(Map<String, dynamic>? data) {
    final v = data?[kProfileHeroBackgroundIndexField];
    if (v is int) return v.clamp(0, 2);
    if (v is num) return v.toInt().clamp(0, 2);
    return 0;
  }

  static Future<void> setProfileHeroBackgroundIndex(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      kProfileHeroBackgroundIndexField: index.clamp(0, 2),
    });
  }

  /// 🔥 Récupérer tous les utilisateurs (admin only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// 🔒 Désactiver un utilisateur (admin only)
  static Future<void> deactivateUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({'isActive': false});
  }

  /// 🔓 Activer un utilisateur (admin only)
  static Future<void> activateUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({'isActive': true});
  }

  /// 👤 Attribuer plusieurs rôles (admin only)
  static Future<void> setUserRoles(String uid, Set<UserRole> roles) async {
    final primary = primaryRole(roles);
    await _firestore.collection('users').doc(uid).update({
      'role': primary.firestoreRole,
      'roles': roles.map((r) => r.firestoreRole).toList(),
      'canAccessChat': true,
    });
  }

  /// 👤 Promouvoir un utilisateur (admin only) — rôle unique
  static Future<void> setUserRole(String uid, UserRole role) async {
    await setUserRoles(uid, {role});
  }

  /// 📊 Enregistrer une donation
  static Future<void> recordDonation(double amount, String method) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Enregistrer la donation
    await _firestore.collection('donations').add({
      'userId': user.uid,
      'amount': amount,
      'method': method,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
    });

    // Mettre à jour le total
    final userData = await getUserData();
    final currentTotal = (userData?['totalDonations'] ?? 0.0) as double;
    final newTotal = currentTotal + amount;

    await updateRoleBasedOnDonations(newTotal);
  }

  /// 🎭 Obtenir le display name
  static Future<String> getDisplayName() async {
    final userData = await getUserData();
    return userData?['displayName'] ?? 'Anonymous';
  }

  /// Obtenir les initiales pour l'avatar
  static Future<String> getInitials() async {
    final userData = await getUserData();
    final firstName = userData?['firstName'] ?? '';
    final lastName = userData?['lastName'] ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    return '?';
  }

  /// 📝 Créer ou mettre à jour un utilisateur (pour login/register)
  static Future<void> createOrUpdateUser(
    User user,
    String firstName,
    String lastName,
  ) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // Mettre à jour la dernière connexion
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
        'email': user.email,
        'emailLower': user.email?.toLowerCase(),
      });
    } else {
      // Créer le nouvel utilisateur
      await createUser(
        uid: user.uid,
        email: user.email!,
        firstName: firstName,
        lastName: lastName,
      );
    }
  }

  /// ✅ Vérifier si un rôle peut accéder au chat
  static bool canAccessChat(UserRole? role) {
    return role != null;
  }

  /// ✅ Vérifier si un rôle peut modérer le chat (ban, avertir, épingler) — admin + CM
  static bool canModerateChat(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.admin || role == UserRole.communityManager;
  }

  /// ✅ Vérifier si un rôle peut signaler/supprimer un message — admin + CM + Team DVCR
  static bool canReportMessage(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.admin ||
        role == UserRole.communityManager ||
        role == UserRole.teamDvcr;
  }

  /// ✅ Accès à l'onglet stats de l'admin — admin + statisticien
  static bool canAccessStats(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) ||
        roles.contains(UserRole.statisticien);
  }

  /// ✅ Accès à l'admin panel — admin + editor + CM + statisticien
  static bool canAccessAdminPanel(Set<UserRole> roles) {
    return roles.any(
      (r) => const {
        UserRole.admin,
        UserRole.editor,
        UserRole.communityManager,
        UserRole.statisticien,
      }.contains(r),
    );
  }

  static bool canManageArticles(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) || roles.contains(UserRole.editor);
  }

  static bool canManageMatches(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) ||
        roles.contains(UserRole.communityManager);
  }

  static bool canManageCommunity(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) ||
        roles.contains(UserRole.communityManager);
  }

  static bool canManageDirect(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) ||
        roles.contains(UserRole.statisticien);
  }

  static bool canManageNotifications(Set<UserRole> roles) {
    return roles.contains(UserRole.admin);
  }

  static bool canManageUsers(Set<UserRole> roles) {
    return roles.contains(UserRole.admin);
  }

  static bool canModerateArticleComments(Set<UserRole> roles) {
    return roles.contains(UserRole.admin) ||
        roles.contains(UserRole.editor) ||
        roles.contains(UserRole.communityManager);
  }
}
