import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArticleCommentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _commentsCol(
    String articleId,
  ) {
    return _db.collection('articles').doc(articleId).collection('comments');
  }

  static Stream<List<Map<String, dynamic>>> watchComments(String articleId) {
    return _commentsCol(articleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  static Future<void> addComment({
    required String articleId,
    required String message,
    required String displayName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté pour commenter.');
    }
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw StateError('Ecris un commentaire avant de valider.');
    }

    final articleRef = _db.collection('articles').doc(articleId);
    final commentRef = _commentsCol(articleId).doc();

    final batch = _db.batch();
    batch.set(commentRef, {
      'uid': user.uid,
      'displayName': displayName.trim().isEmpty
          ? 'Supporter DVCR'
          : displayName.trim(),
      'message': cleanMessage,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(articleRef, {
      'commentsCount': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> deleteComment({
    required String articleId,
    required String commentId,
  }) async {
    final articleRef = _db.collection('articles').doc(articleId);
    final commentRef = _commentsCol(articleId).doc(commentId);

    final batch = _db.batch();
    batch.delete(commentRef);
    batch.set(articleRef, {
      'commentsCount': FieldValue.increment(-1),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
