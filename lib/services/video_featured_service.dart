import 'package:cloud_firestore/cloud_firestore.dart';

/// Une seule vidéo « à la une » TV : champ Firestore + [tv/config.featuredVideoId].
class VideoFeaturedService {
  static final _col = FirebaseFirestore.instance.collection('videos');
  static final _tvConfig =
      FirebaseFirestore.instance.collection('tv').doc('config');

  static bool _isPartner(Map<String, dynamic> data) {
    final cat = (data['category'] ?? '').toString().toLowerCase();
    if (cat == 'partenaire') return true;
    final title = (data['title'] ?? '').toString().toLowerCase();
    return title.contains('partenaire');
  }

  static Future<void> setFeatured(String videoDocId) async {
    final doc = await _col.doc(videoDocId).get();
    final data = doc.data() ?? {};
    if (_isPartner(data)) {
      throw StateError('Les vidéos partenaires ne peuvent pas être mises à la une sur la TV.');
    }
    final batch = FirebaseFirestore.instance.batch();
    final current = await _col.where('featured', isEqualTo: true).get();
    for (final doc in current.docs) {
      if (doc.id != videoDocId) {
        batch.update(doc.reference, {'featured': false});
      }
    }
    batch.set(_col.doc(videoDocId), {'featured': true}, SetOptions(merge: true));
    batch.set(
      _tvConfig,
      {'featuredVideoId': videoDocId},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<void> clearFeatured(String videoDocId) async {
    await _col.doc(videoDocId).set({'featured': false}, SetOptions(merge: true));
    final tvSnap = await _tvConfig.get();
    if (tvSnap.data()?['featuredVideoId'] == videoDocId) {
      await _tvConfig.update({'featuredVideoId': FieldValue.delete()});
    }
  }
}
