/// Champs d’une ligue privée (`private_leagues/{id}`).
///
/// Le créateur est `ownerUid` (schéma actuel). Anciens docs : `ownerId`,
/// `createdBy`, `createdByUid`, ou simplement le premier `memberIds`.
String _uidToken(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw.trim();
  if (raw is Map) {
    for (final key in const ['uid', 'id', 'userId']) {
      final v = (raw[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
  }
  return raw.toString().trim();
}

bool _roleIsAdmin(dynamic raw) {
  if (raw == null) return false;
  if (raw is String) {
    final v = raw.trim().toLowerCase();
    return v == 'admin' || v == 'owner' || v == 'creator';
  }
  if (raw is List) {
    return raw.any(_roleIsAdmin);
  }
  return false;
}

void _addUid(Set<String> out, dynamic raw) {
  final uid = _uidToken(raw);
  if (uid.isNotEmpty) out.add(uid);
}

/// `memberIds` (liste) + clés / `uid` de `members` (map ou liste, ligues old).
List<String> leagueMemberIdsFromData(Map<String, dynamic>? data) {
  final out = <String>{};
  final rawIds = data?['memberIds'];
  if (rawIds is List) {
    for (final e in rawIds) {
      _addUid(out, e);
    }
  }
  final members = data?['members'];
  if (members is Map) {
    for (final e in members.entries) {
      _addUid(out, e.key);
      _addUid(out, e.value);
    }
  } else if (members is List) {
    for (final e in members) {
      _addUid(out, e);
    }
  }
  return out.toList();
}

const _leagueOwnerKeys = ['ownerUid', 'ownerId', 'createdBy', 'createdByUid'];

/// UIDs créateur déclarés (champs non vides uniquement — pas le 1er membre).
Set<String> leagueDeclaredOwnerUids(Map<String, dynamic>? data) {
  final out = <String>{};
  if (data == null) return out;
  for (final key in _leagueOwnerKeys) {
    _addUid(out, data[key]);
  }
  return out;
}

String leagueOwnerUidFromData(Map<String, dynamic>? data) {
  if (data == null) return '';
  for (final key in _leagueOwnerKeys) {
    final v = (data[key] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  final members = leagueMemberIdsFromData(data);
  return members.isEmpty ? '' : members.first;
}

bool isPrivateLeagueOwner(Map<String, dynamic>? data, String uid) {
  final me = uid.trim();
  if (me.isEmpty) return false;
  return leagueOwnerUidFromData(data) == me;
}

/// Alias UI / service (`ownerUid == currentUid` était trop étroit).
bool isLeagueOwnerUid(Map<String, dynamic>? data, String uid) =>
    isPrivateLeagueOwner(data, uid);

/// Membre actuel **ou** créateur (même s’il manque dans `memberIds`).
bool isPrivateLeagueMember(Map<String, dynamic>? data, String uid) {
  final me = uid.trim();
  if (me.isEmpty) return false;
  if (leagueMemberIdsFromData(data).contains(me)) return true;
  return isPrivateLeagueOwner(data, me);
}

bool isLeagueMemberUid(Map<String, dynamic>? data, String uid) =>
    isPrivateLeagueMember(data, uid);

List<String> leagueAdminUidsFromData(Map<String, dynamic>? data) {
  final out = <String>{};
  if (data == null) return const [];
  final rawAdmins = data['adminUids'];
  if (rawAdmins is List) {
    for (final e in rawAdmins) {
      _addUid(out, e);
    }
  }
  final members = data['members'];
  if (members is Map) {
    for (final e in members.entries) {
      final rec = e.value;
      if (rec is Map &&
          (_roleIsAdmin(rec['role']) || _roleIsAdmin(rec['roles']))) {
        _addUid(out, e.key);
        _addUid(out, rec);
      }
    }
  } else if (members is List) {
    for (final e in members) {
      if (e is Map && (_roleIsAdmin(e['role']) || _roleIsAdmin(e['roles']))) {
        _addUid(out, e);
      }
    }
  }
  return out.toList();
}

/// Un créateur ou admin **encore dans** la ligue.
bool leagueHasUsableOwnerOrAdmin(Map<String, dynamic>? data) {
  final members = leagueMemberIdsFromData(data);
  if (members.isEmpty) {
    return leagueDeclaredOwnerUids(data).isNotEmpty ||
        leagueAdminUidsFromData(data).isNotEmpty;
  }
  final memberSet = members.toSet();
  if (leagueDeclaredOwnerUids(data).any(memberSet.contains)) return true;
  return leagueAdminUidsFromData(data).any(memberSet.contains);
}

/// `ownerUid` vide, ou UID qui n’est plus membre — à rattraper.
bool leagueOwnerUidNeedsBackfill(Map<String, dynamic>? data) {
  final stored = (data?['ownerUid'] ?? '').toString().trim();
  if (stored.isEmpty) return true;
  final members = leagueMemberIdsFromData(data);
  if (members.isEmpty) return false;
  return !members.contains(stored);
}

/// Créateur, admin de ligue, ou tout membre si aucun owner / admin utilisable
/// (ligue old : champs vides, faux UID, compte plus dans l’effectif).
bool canEditPrivateLeagueEmblem(Map<String, dynamic>? data, String uid) {
  final me = uid.trim();
  if (me.isEmpty || data == null) return false;
  if (!isPrivateLeagueMember(data, me)) return false;
  if (leagueDeclaredOwnerUids(data).contains(me)) return true;
  if (leagueAdminUidsFromData(data).contains(me)) return true;
  return !leagueHasUsableOwnerOrAdmin(data);
}

/// Code salon : secret `join` en priorité, sinon l’id du doc `league_join_codes`.
/// Jamais le champ `code` du parent (lisible par tout user auth).
String pickLeagueInviteCode({String? secret, String? joinCodeId}) {
  final fromSecret = (secret ?? '').trim();
  if (fromSecret.isNotEmpty) return fromSecret.toUpperCase();
  return (joinCodeId ?? '').trim().toUpperCase();
}
