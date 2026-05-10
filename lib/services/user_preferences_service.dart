import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserPreferencesService extends ChangeNotifier {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  bool _initialized = false;
  String? _favoriteTeam;

  String? get favoriteTeam => _favoriteTeam;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    FirebaseAuth.instance.authStateChanges().listen(_bindUser);
    await _bindUser(FirebaseAuth.instance.currentUser);
  }

  Future<void> _bindUser(User? user) async {
    await _userDocSub?.cancel();
    _userDocSub = null;

    if (user == null) {
      _setFavoriteTeam(null);
      return;
    }

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final next = (snapshot.data()?['favoriteTeam'] as String?)?.trim();
          _setFavoriteTeam(next == null || next.isEmpty ? null : next);
        });
  }

  void _setFavoriteTeam(String? next) {
    if (_favoriteTeam == next) {
      return;
    }
    _favoriteTeam = next;
    notifyListeners();
  }
}
