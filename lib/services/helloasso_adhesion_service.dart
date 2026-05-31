import 'package:cloud_firestore/cloud_firestore.dart';

/// Config HelloAsso / adhérents — admin uniquement (`app_config/helloasso_adhesion`).
class HelloAssoAdhesionConfig {
  final DateTime adherentExpiresAt;

  const HelloAssoAdhesionConfig({required this.adherentExpiresAt});

  static final DateTime defaultExpiresAt =
      DateTime.utc(2027, 6, 1, 21, 59, 59);

  factory HelloAssoAdhesionConfig.fromMap(Map<String, dynamic>? data) {
    final raw = data?['adherentExpiresAt'] ?? data?['expiresAt'];
    if (raw is Timestamp) {
      return HelloAssoAdhesionConfig(adherentExpiresAt: raw.toDate());
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) {
        return HelloAssoAdhesionConfig(adherentExpiresAt: parsed);
      }
    }
    return HelloAssoAdhesionConfig(adherentExpiresAt: defaultExpiresAt);
  }

  Map<String, dynamic> toMap() {
    return {
      'adherentExpiresAt': Timestamp.fromDate(adherentExpiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class HelloAssoAdhesionService {
  HelloAssoAdhesionService._();
  static final HelloAssoAdhesionService instance = HelloAssoAdhesionService._();

  static const _configPath = 'app_config/helloasso_adhesion';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      FirebaseFirestore.instance.doc(_configPath);

  Stream<HelloAssoAdhesionConfig> configStream() {
    return _configRef.snapshots().map(
          (s) => HelloAssoAdhesionConfig.fromMap(s.data()),
        );
  }

  Future<void> saveConfig(HelloAssoAdhesionConfig config) async {
    await _configRef.set(config.toMap(), SetOptions(merge: true));
  }

  /// Enregistre la date de fin et la propage aux adhérents actuellement actifs.
  Future<void> saveConfigAndRefreshActiveAdherents(
    HelloAssoAdhesionConfig config,
  ) async {
    await saveConfig(config);
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('helloAsso.isAdherentActive', isEqualTo: true)
        .limit(500)
        .get();
    if (snap.docs.isEmpty) return;

    final ts = Timestamp.fromDate(config.adherentExpiresAt);
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = snap.docs.skip(i).take(400);
      for (final doc in chunk) {
        batch.update(doc.reference, {
          'helloAsso.adherentExpiresAt': ts,
          'helloAsso.lastSyncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> donationsStream({int limit = 300}) {
    return FirebaseFirestore.instance
        .collection('donations')
        .where('source', isEqualTo: 'helloasso')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingMatchesStream() {
    return FirebaseFirestore.instance
        .collection('helloasso_pending_matches')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static bool isAdherentActive(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is! Map) return false;
    final now = DateTime.now();
    if (ha['isAdherentActive'] == true) {
      final exp = ha['adherentExpiresAt'];
      if (exp is Timestamp && exp.toDate().isBefore(now)) return false;
      return true;
    }
    return false;
  }

  static double adherentTotalPaid(Map<String, dynamic>? userData) {
    final ha = userData?['helloAsso'];
    if (ha is Map) {
      final v = ha['adherentTotalPaid'] ?? ha['totalPaid'];
      if (v is num) return v.toDouble();
    }
    final legacy = userData?['totalDonations'];
    if (legacy is num) return legacy.toDouble();
    return 0;
  }
}
