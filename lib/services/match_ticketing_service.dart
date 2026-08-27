import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/match_ticketing.dart';

/// CTA billet Accueil — `app_config/match_ticketing`.
class MatchTicketingService {
  MatchTicketingService._();
  static final instance = MatchTicketingService._();

  final _db = FirebaseFirestore.instance;

  MatchTicketing _last = MatchTicketing.defaults;

  MatchTicketing get lastKnown => _last;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('app_config').doc(MatchTicketing.firestoreDocId);

  Stream<MatchTicketing> watch() {
    return _doc.snapshots().map((snap) {
      _last = MatchTicketing.fromMap(snap.data());
      return _last;
    });
  }

  Future<MatchTicketing> getOnce() async {
    final snap = await _doc.get();
    _last = MatchTicketing.fromMap(snap.data());
    return _last;
  }

  Future<void> setEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await _doc.set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> setUrl(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await _doc.set({
      'url': url.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> save({required bool enabled, required String url}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await _doc.set({
      'enabled': enabled,
      'url': url.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
