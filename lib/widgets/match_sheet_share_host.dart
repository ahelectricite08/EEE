import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../screens/profile/match_sheet_share_visual.dart';
import '../services/live_state_service.dart';
import '../services/match_rating_service.dart';
import '../services/match_sheet_share_service.dart';
import '../services/user_service.dart';

/// Mobile : pop le visuel score + buteurs à la fin de match (bénévoles / admin).
class MatchSheetShareHost extends StatefulWidget {
  const MatchSheetShareHost({super.key});

  @override
  State<MatchSheetShareHost> createState() => _MatchSheetShareHostState();
}

class _MatchSheetShareHostState extends State<MatchSheetShareHost>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  Set<UserRole> _roles = {UserRole.supporter};
  bool _rolesReady = false;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    _onAuth(FirebaseAuth.instance.currentUser);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSub?.cancel());
    unawaited(_userSub?.cancel());
    unawaited(_liveSub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_evaluate());
    }
  }

  void _onAuth(User? user) {
    unawaited(_userSub?.cancel());
    unawaited(_liveSub?.cancel());
    _liveSub = null;
    _roles = {UserRole.supporter};
    _rolesReady = false;
    if (user == null) return;
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      _roles = UserService.parseRolesFromData(snap.data());
      _rolesReady = true;
      if (!UserService.canSeeMatchSheetShare(_roles)) {
        unawaited(_liveSub?.cancel());
        _liveSub = null;
        return;
      }
      _ensureLiveWatch();
      unawaited(_evaluate());
    });
  }

  void _ensureLiveWatch() {
    if (_liveSub != null) return;
    _liveSub = LiveStateService.watchCurrentSnapshots().listen((_) {
      unawaited(_evaluate());
    });
  }

  Future<void> _evaluate() async {
    if (!mounted || _presenting || !_rolesReady) return;
    if (!canSeeMatchSheetShare(_roles)) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('live')
          .doc('current')
          .get();
      if (!mounted || _presenting) return;
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null || data.isEmpty) return;
      if (!MatchRatingService.isFulltimeDeclared(data)) return;
      if (!MatchSheetShareService.isPremiereLiveMatch(data)) return;
      final matchId = (data['matchId'] as String? ?? '').trim();
      if (matchId.isEmpty) return;
      if (await MatchSheetShareService.instance.hasSeenMatch(matchId)) {
        return;
      }
      if (!mounted || _presenting) return;
      _presenting = true;
      await presentMatchSheetShareAfterFulltime(context, data);
      _presenting = false;
    } catch (_) {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
