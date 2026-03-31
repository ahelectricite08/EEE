import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 👥 Énumération des rôles DVCR
enum UserRole {
  supporter,
  donateur,
  partenaire,
  editor,
  communityManager,
  admin,
}

/// Extension pour obtenir le nom du rôle
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.supporter:
        return 'Supporter';
      case UserRole.donateur:
        return 'Donateur';
      case UserRole.partenaire:
        return 'Partenaire';
      case UserRole.editor:
        return 'Éditeur';
      case UserRole.communityManager:
        return 'Community Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get icon {
    switch (this) {
      case UserRole.supporter:
        return '❤️';
      case UserRole.donateur:
        return '💰';
      case UserRole.partenaire:
        return '🤝';
      case UserRole.editor:
        return '✏️';
      case UserRole.communityManager:
        return '🛡️';
      case UserRole.admin:
        return '👑';
    }
  }

  String get name {
    switch (this) {
      case UserRole.supporter:
        return 'supporter';
      case UserRole.donateur:
        return 'donateur';
      case UserRole.partenaire:
        return 'partenaire';
      case UserRole.editor:
        return 'editor';
      case UserRole.communityManager:
        return 'community_manager';
      case UserRole.admin:
        return 'admin';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.supporter:
        return Color(0xFF9E9E9E);
      case UserRole.donateur:
        return Color(0xFF0A4438);
      case UserRole.partenaire:
        return Color(0xFFFF9100);
      case UserRole.editor:
        return Color(0xFF00BCD4);
      case UserRole.communityManager:
        return Color(0xFF2979FF);
      case UserRole.admin:
        return Color(0xFFD500F9);
    }
  }
}

/// Service de gestion des utilisateurs et rôles
class UserService {
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
      'firstName': firstName,
      'lastName': lastName,
      'role': role.name,
      'roles': [role.name],
      'displayName': '$firstName $lastName',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'isActive': true,
      'totalDonations': 0.0,
      'canAccessChat': role != UserRole.supporter,
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
  
  /// Priorité des rôles (du plus élevé au plus bas)
  static const rolePriority = [
    UserRole.admin, UserRole.communityManager, UserRole.editor,
    UserRole.partenaire, UserRole.donateur, UserRole.supporter,
  ];

  /// Rôle principal d'un ensemble de rôles
  static UserRole primaryRole(Set<UserRole> roles) {
    for (final r in rolePriority) {
      if (roles.contains(r)) return r;
    }
    return UserRole.supporter;
  }

  /// Parser les rôles depuis un document Firestore (supporte l'ancien champ 'role' et le nouveau 'roles')
  static Set<UserRole> parseRolesFromData(Map<String, dynamic>? data) {
    if (data == null) return {UserRole.supporter};
    final rolesList = data['roles'];
    if (rolesList is List && rolesList.isNotEmpty) {
      final set = rolesList.whereType<String>().map(_parseRole).toSet();
      return set.isEmpty ? {UserRole.supporter} : set;
    }
    return {_parseRole(data['role'] as String?)};
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

  /// 🔄 Parser un rôle depuis string
  static UserRole _parseRole(String? roleString) {
    switch (roleString?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'communitymanager':
      case 'community_manager':
        return UserRole.communityManager;
      case 'editor':
        return UserRole.editor;
      case 'partenaire':
        return UserRole.partenaire;
      case 'donateur':
        return UserRole.donateur;
      case 'supporter':
      default:
        return UserRole.supporter;
    }
  }
  
  /// Vérifier si l'utilisateur peut accéder au chat
  static Future<bool> canAccessChatAsync() async {
    final roles = await getCurrentRoles();
    return roles.any((r) => r != UserRole.supporter);
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
      'role': newRole.name,
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
    await _firestore.collection('users').doc(uid).update({
      'isActive': false,
    });
  }
  
  /// 🔓 Activer un utilisateur (admin only)
  static Future<void> activateUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': true,
    });
  }
  
  /// 👤 Attribuer plusieurs rôles (admin only)
  static Future<void> setUserRoles(String uid, Set<UserRole> roles) async {
    final primary = primaryRole(roles);
    await _firestore.collection('users').doc(uid).update({
      'role':  primary.name,
      'roles': roles.map((r) => r.name).toList(),
      'canAccessChat': roles.any((r) => r != UserRole.supporter),
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
    if (role == null) return false;
    return role != UserRole.supporter;
  }
  
  /// ✅ Vérifier si un rôle peut modérer le chat
  /// Vérifier si le rôle peut modérer le chat — admin + CM
  static bool canModerateChat(UserRole? role) {
    if (role == null) return false;
    return role == UserRole.admin || role == UserRole.communityManager;
  }
}