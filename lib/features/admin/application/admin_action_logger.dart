import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Journal d’audit append-only (`admin_audit_logs`).
/// Les entrées sont enrichies côté client ; les champs sensibles ne doivent pas
/// contenir de secrets en clair.
abstract final class AdminActionLogger {
  static final _col = FirebaseFirestore.instance.collection('admin_audit_logs');

  static Future<void> log({
    required String action,
    String? resourceType,
    String? resourceId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _col.add({
        'uid': user.uid,
        'email': user.email,
        'action': action,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'metadata': metadata ?? const <String, dynamic>{},
        'before': before,
        'after': after,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('AdminActionLogger: $e\n$st');
    }
  }
}
