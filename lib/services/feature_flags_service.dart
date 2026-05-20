import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Feature flags lecture/écriture dans `app_config/feature_flags`.
/// L’app mobile peut écouter [notifier] ou [stream] pour activer/désactiver des modules sans release.
class FeatureFlagsService {
  static const String docId = 'feature_flags';

  static DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection('app_config').doc(docId);

  /// Dernière valeur connue (mise à jour par [ensureListener]).
  static final ValueNotifier<Map<String, dynamic>> notifier =
      ValueNotifier<Map<String, dynamic>>(const {});

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static Stream<Map<String, dynamic>> stream() => ref
      .snapshots(includeMetadataChanges: true)
      .map((s) => Map<String, dynamic>.from(s.data() ?? const {}));

  /// À appeler une fois après Firebase init (ex. depuis [main] déferred).
  static void ensureListener() {
    _sub ??= ref.snapshots().listen((snap) {
      notifier.value = Map<String, dynamic>.from(snap.data() ?? const {});
    });
  }

  static bool isEnabled(Map<String, dynamic>? data, String key) {
    if (data == null) return false;
    return data[key] == true;
  }

  static bool flagOn(String key) => isEnabled(notifier.value, key);

  static Future<void> setFlag(String key, bool value) async {
    await ref.set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
