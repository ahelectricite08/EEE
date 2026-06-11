import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/article_model.dart';

class ArticleService {
  static final _col = FirebaseFirestore.instance.collection('articles');

  static Stream<List<ArticleModel>> all({String? category, int limit = 20}) {
    Query<Map<String, dynamic>> q;
    if (category != null && category != 'TOUT') {
      q = _col
          .where('status', isEqualTo: 'published')
          .where('category', isEqualTo: category)
          .orderBy('created_at', descending: true)
          .limit(limit);
    } else {
      q = _col
          .where('status', isEqualTo: 'published')
          .orderBy('created_at', descending: true)
          .limit(limit);
    }
    return q.snapshots().map(
      (s) => s.docs.map(ArticleModel.fromFirestore).toList(),
    );
  }

  static Future<List<ArticleModel>> fetchAllPublished({int limit = 50}) async {
    final snap = await _col
        .where('status', isEqualTo: 'published')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(ArticleModel.fromFirestore).toList();
  }

  // Tous les articles (brouillons inclus) — pour l'admin
  static Stream<List<ArticleModel>> allWithDrafts({
    String? category,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> q;
    if (category != null && category != 'TOUT') {
      q = _col
          .where('category', isEqualTo: category)
          .orderBy('created_at', descending: true)
          .limit(limit);
    } else {
      q = _col.orderBy('created_at', descending: true).limit(limit);
    }
    return q.snapshots().map(
      (s) => s.docs.map(ArticleModel.fromFirestore).toList(),
    );
  }

  static Future<ArticleModel?> byId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ArticleModel.fromFirestore(doc);
  }

  static Stream<ArticleModel?> streamById(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ArticleModel.fromFirestore(doc);
    });
  }

  static Future<void> create({
    required String title,
    required String content,
    required String category,
    String? imageUrl,
    String? authorName,
    String status = 'published',
    List<String> images = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _col.add({
      'title': title,
      'content': content,
      'category': category,
      'imageUrl': imageUrl,
      'authorName': authorName ?? user?.displayName ?? 'Rédaction DVCR',
      'featured': false,
      'status': status,
      'images': images,
      'viewsCount': 0,
      'likesCount': 0,
      'commentsCount': 0,
      'likedBy': const <String>[],
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> update(
    String id, {
    required String title,
    required String content,
    required String category,
    String? imageUrl,
    String? authorName,
    String? status,
    List<String>? images,
  }) async {
    await _col.doc(id).update({
      'title': title,
      'content': content,
      'category': category,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (authorName != null) 'authorName': authorName,
      if (status != null) 'status': status,
      if (images != null) 'images': images,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> publish(String id) async {
    await _col.doc(id).update({
      'status': 'published',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> unpublish(String id) async {
    await _col.doc(id).update({
      'status': 'draft',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  // Met cet article à la une et retire les autres
  static Future<void> setFeatured(String id) async {
    final batch = FirebaseFirestore.instance.batch();
    final current = await _col.where('featured', isEqualTo: true).get();
    for (final doc in current.docs) {
      batch.update(doc.reference, {'featured': false});
    }
    batch.update(_col.doc(id), {'featured': true});
    await batch.commit();
  }

  static Future<void> removeFeatured(String id) async {
    await _col.doc(id).update({'featured': false});
  }

  static Future<void> incrementView(String id) async {
    await _col.doc(id).set({
      'viewsCount': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> toggleLike(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _col.doc(id);
    final snap = await ref.get();
    final data = snap.data() ?? const <String, dynamic>{};
    final likedBy = List<String>.from(data['likedBy'] ?? const <String>[]);
    final alreadyLiked = likedBy.contains(uid);
    await ref.set({
      'likedBy': alreadyLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(alreadyLiked ? -1 : 1),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
