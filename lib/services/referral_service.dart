import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  static FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: 'europe-west1');

  static String _generateCode(String uid) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    final suffix = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'DVCR${suffix}';
  }

  /// Ensures the user has a referral code. Creates one if missing (for legacy accounts).
  static Future<String> ensureCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final existing = snap.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    // Generate and write
    final code = _generateCode(uid);
    await ref.set({'referralCode': code}, SetOptions(merge: true));
    return code;
  }

  /// Returns the current user's referral code, or null if not yet generated.
  static Future<String?> getMyCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['referralCode'] as String?;
  }

  /// Returns a live stream of the current user's referral code.
  static Stream<String?> watchMyCode() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['referralCode'] as String?);
  }

  /// Returns stats: { code, referralCount, xpEarned }.
  static Future<Map<String, dynamic>> getStats() async {
    final result = await _fn.httpsCallable('getReferralStats').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Applies a referral code. Throws if invalid, already used, or self-referral.
  static Future<void> useCode(String code) async {
    await _fn.httpsCallable('useReferralCode').call({'code': code.trim().toUpperCase()});
  }

  /// Returns true if the current user has already been referred (has referredBy field).
  static Future<bool> hasBeenReferred() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['referredBy'] != null;
  }
}
