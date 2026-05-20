import 'package:cloud_firestore/cloud_firestore.dart';

class SponsorService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DocumentReference<Map<String, dynamic>> _ref = _db
      .collection('config')
      .doc('sponsors');

  static Stream<List<Map<String, dynamic>>> stream() {
    return _ref.snapshots().map((snap) => normalize(snap.data()));
  }

  static Future<void> ensureDefaults() async {
    final snap = await _ref.get();
    if (snap.exists) return;
    await _ref.set({
      'items': [
        {
          'id': 'maneo',
          'name': 'MANEO',
          'logoUrl':
              'https://static.wixstatic.com/media/e91e00_40557d11e6b9461fad85eff84a34a49d~mv2.png',
          'colorHex': '#C8A436',
          'linkUrl': '',
          'active': true,
        },
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static List<Map<String, dynamic>> normalize(Map<String, dynamic>? data) {
    final raw = data?['items'];
    if (raw is! List) return const [];
    final items = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['name'] as String? ?? '').trim().isNotEmpty)
        .toList();
    items.sort((a, b) {
      final aActive = a['active'] != false;
      final bActive = b['active'] != false;
      if (aActive != bActive) return aActive ? -1 : 1;
      final aName = (a['name'] as String? ?? '').trim().toLowerCase();
      final bName = (b['name'] as String? ?? '').trim().toLowerCase();
      return aName.compareTo(bName);
    });
    return items;
  }

  static Future<void> saveSponsor({
    required String id,
    required String name,
    String logoUrl = '',
    String colorHex = '',
    String linkUrl = '',
    bool active = true,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw StateError('Renseigne au moins le nom du sponsor.');
    }

    final cleanId = id.trim().isEmpty ? _slugify(cleanName) : id.trim();
    final sponsors = await stream().first;
    final next = [...sponsors];
    final index = next.indexWhere(
      (item) => (item['id'] as String? ?? '').trim() == cleanId,
    );
    final payload = {
      'id': cleanId,
      'name': cleanName,
      'logoUrl': logoUrl.trim(),
      'colorHex': _normalizeHex(colorHex),
      'linkUrl': linkUrl.trim(),
      'active': active,
    };

    if (index >= 0) {
      next[index] = payload;
    } else {
      next.add(payload);
    }

    await _ref.set({
      'items': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteSponsor(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    final sponsors = await stream().first;
    final next = sponsors
        .where((item) => (item['id'] as String? ?? '').trim() != cleanId)
        .toList();
    await _ref.set({
      'items': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _normalizeHex(String value) {
    final clean = value.trim().toUpperCase();
    if (clean.isEmpty) return '';
    return clean.startsWith('#') ? clean : '#$clean';
  }
}
