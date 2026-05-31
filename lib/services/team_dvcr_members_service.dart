import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Team DVCR affiché dans la sélection des notifs bénévoles.
class TeamDvcrMember {
  const TeamDvcrMember({
    required this.uid,
    required this.label,
    required this.email,
  });

  final String uid;
  final String label;
  final String email;
}

/// Liste à jour des Team DVCR (mêmes critères que les Cloud Functions).
class TeamDvcrMembersService {
  TeamDvcrMembersService._();
  static final instance = TeamDvcrMembersService._();

  static final _users = FirebaseFirestore.instance.collection('users');

  static bool isTeamDvcrMember(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    final rolesRaw = data['roles'];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        final s = r.toString().trim().toLowerCase();
        if (s == 'team_dvcr' || s == 'teamdvcr') return true;
      }
    }
    final role = data['role']?.toString().trim().toLowerCase() ?? '';
    if (role == 'team_dvcr' || role == 'teamdvcr') return true;
    if (data['dvcrTeamMember'] == true) return true;
    return false;
  }

  static TeamDvcrMember fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final name = (d['displayName'] ?? d['name'] ?? '').toString().trim();
    final first = (d['firstName'] ?? '').toString().trim();
    final last = (d['lastName'] ?? '').toString().trim();
    final email = (d['email'] ?? '').toString().trim();
    var label = name;
    if (label.isEmpty) label = '$first $last'.trim();
    if (label.isEmpty) label = email;
    if (label.isEmpty) label = doc.id;
    return TeamDvcrMember(uid: doc.id, label: label, email: email);
  }

  static List<TeamDvcrMember> _mergeAndSort(
    Iterable<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final byId = <String, TeamDvcrMember>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!isTeamDvcrMember(data)) continue;
        byId[doc.id] = fromDoc(doc);
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  /// Flux fusionné : nouveaux Team DVCR apparaissent automatiquement.
  Stream<List<TeamDvcrMember>> watchMembers() {
    final controller = StreamController<List<TeamDvcrMember>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? rolesSnake;
    QuerySnapshot<Map<String, dynamic>>? rolesCamel;
    QuerySnapshot<Map<String, dynamic>>? roleFieldSnake;
    QuerySnapshot<Map<String, dynamic>>? roleFieldCamel;
    QuerySnapshot<Map<String, dynamic>>? legacyFlag;

    void emitMerged() {
      if (controller.isClosed) return;
      final snaps = [
        rolesSnake,
        rolesCamel,
        roleFieldSnake,
        roleFieldCamel,
        legacyFlag,
      ].whereType<QuerySnapshot<Map<String, dynamic>>>();
      controller.add(_mergeAndSort(snaps));
    }

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[
      _users
          .where('roles', arrayContains: 'team_dvcr')
          .snapshots()
          .listen((s) {
        rolesSnake = s;
        emitMerged();
      }),
      _users
          .where('roles', arrayContains: 'teamDvcr')
          .snapshots()
          .listen((s) {
        rolesCamel = s;
        emitMerged();
      }),
      _users
          .where('role', isEqualTo: 'team_dvcr')
          .snapshots()
          .listen((s) {
        roleFieldSnake = s;
        emitMerged();
      }),
      _users
          .where('role', isEqualTo: 'teamDvcr')
          .snapshots()
          .listen((s) {
        roleFieldCamel = s;
        emitMerged();
      }),
      _users
          .where('dvcrTeamMember', isEqualTo: true)
          .snapshots()
          .listen((s) {
        legacyFlag = s;
        emitMerged();
      }),
    ];

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }
}
