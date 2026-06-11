import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_cache_service.dart';

class SocialActivityItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime? createdAt;
  final String scope;
  final List<String> memberIds;

  const SocialActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.scope,
    required this.memberIds,
  });

  factory SocialActivityItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SocialActivityItem(
      id: doc.id,
      type: (data['type'] ?? 'info').toString(),
      title: (data['title'] ?? 'Activite').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      scope: (data['scope'] ?? 'global').toString(),
      memberIds:
          (data['memberIds'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }

  factory SocialActivityItem.fromJson(Map<String, dynamic> json) {
    return SocialActivityItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'info').toString(),
      title: (json['title'] ?? 'Activite').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      scope: (json['scope'] ?? 'global').toString(),
      memberIds:
          (json['memberIds'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'createdAt': createdAt?.toIso8601String(),
    'scope': scope,
    'memberIds': memberIds,
  };
}

class PronoSocialActivityService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _prefix = 'prono.social.activity';
  static const _maxAge = Duration(minutes: 20);

  static Future<List<SocialActivityItem>> readCachedForUser(String uid) async {
    final body = await AppCacheService.readBody('$_prefix.$uid');
    if (body == null || body.isEmpty) return const [];
    try {
      final raw = jsonDecode(body) as List;
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SocialActivityItem.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> cacheForUser(
    String uid,
    List<SocialActivityItem> items,
  ) async {
    await AppCacheService.upsertBody(
      '$_prefix.$uid',
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  static Future<bool> isFreshForUser(String uid) {
    return AppCacheService.isFresh('$_prefix.$uid', _maxAge);
  }

  static Stream<List<SocialActivityItem>> watchForUser(String uid) {
    return _db
        .collection('prono_social_activity')
        .where('memberIds', arrayContains: uid)
        .limit(12)
        .snapshots()
        .asyncMap((snap) async {
          final items = snap.docs.map(SocialActivityItem.fromDoc).toList()
            ..sort((a, b) {
              final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
          await cacheForUser(uid, items);
          return items;
        });
  }
}
