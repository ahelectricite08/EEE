import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FavoriteType { article, match, video }

class FavoriteEntry {
  final String docId;
  final FavoriteType type;
  final String itemId;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String routeHint;
  final DateTime? addedAt;
  final Map<String, dynamic> data;

  const FavoriteEntry({
    required this.docId,
    required this.type,
    required this.itemId,
    required this.title,
    required this.subtitle,
    required this.routeHint,
    required this.data,
    this.imageUrl,
    this.addedAt,
  });

  static FavoriteEntry fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawType = (data['type'] ?? 'match').toString();
    final type = FavoriteType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => FavoriteType.match,
    );
    return FavoriteEntry(
      docId: doc.id,
      type: type,
      itemId: (data['itemId'] ?? doc.id).toString(),
      title: (data['title'] ?? 'Favori DVCR').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      imageUrl: (data['imageUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : (data['imageUrl'] as String).trim(),
      routeHint: (data['routeHint'] ?? '').toString(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      data: Map<String, dynamic>.from(data),
    );
  }
}

class FavoritesService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = currentUid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('favorites');
  }

  static String docId(FavoriteType type, String itemId) {
    if (type == FavoriteType.match) return itemId;
    return '${type.name}__$itemId';
  }

  static DocumentReference<Map<String, dynamic>>? ref(
    FavoriteType type,
    String itemId,
  ) {
    final col = _collection();
    if (col == null) return null;
    return col.doc(docId(type, itemId));
  }

  static Stream<bool> watchIsFavorite(FavoriteType type, String itemId) {
    final reference = ref(type, itemId);
    if (reference == null) return Stream<bool>.value(false);
    return reference.snapshots().map((snap) => snap.exists);
  }

  static Stream<List<FavoriteEntry>> watchAll() {
    final col = _collection();
    if (col == null) return Stream<List<FavoriteEntry>>.value([]);
    return col
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(FavoriteEntry.fromFirestore).toList());
  }

  static Stream<FavoriteEntry?> watchEntry(FavoriteType type, String itemId) {
    final reference = ref(type, itemId);
    if (reference == null) return Stream<FavoriteEntry?>.value(null);
    return reference.snapshots().map((snap) {
      if (!snap.exists) return null;
      return FavoriteEntry.fromFirestore(snap);
    });
  }

  static Future<void> removeByDocId(String docId) async {
    final col = _collection();
    if (col == null) return;
    await col.doc(docId).delete();
  }

  static Future<void> toggle({
    required FavoriteType type,
    required String itemId,
    required String title,
    required String subtitle,
    String? imageUrl,
    String routeHint = '',
    Map<String, dynamic> extra = const {},
  }) async {
    final reference = ref(type, itemId);
    if (reference == null) return;
    final snap = await reference.get();
    if (snap.exists) {
      await reference.delete();
      return;
    }
    await reference.set({
      'type': type.name,
      'itemId': itemId,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'routeHint': routeHint,
      'addedAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }
}
