import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/private_league.dart';

void main() {
  test('créateur : ownerUid, sinon ownerId / createdBy / createdByUid, sinon 1er membre', () {
    expect(leagueOwnerUidFromData(null), '');
    expect(leagueOwnerUidFromData({'ownerUid': ' a1 '}), 'a1');
    expect(
      leagueOwnerUidFromData({'ownerId': 'legacy', 'memberIds': ['x']}),
      'legacy',
    );
    expect(
      leagueOwnerUidFromData({'createdBy': 'cb', 'memberIds': ['x']}),
      'cb',
    );
    expect(
      leagueOwnerUidFromData({'createdByUid': 'cbu', 'memberIds': ['x']}),
      'cbu',
    );
    expect(
      leagueOwnerUidFromData({
        'ownerUid': '',
        'memberIds': ['first', 'second'],
      }),
      'first',
    );
    expect(
      leagueOwnerUidFromData({
        'ownerUid': 'stored',
        'ownerId': 'other',
        'memberIds': ['first'],
      }),
      'stored',
    );
  });

  test('membre : memberIds (stringifiés) ou créateur', () {
    expect(isPrivateLeagueMember(null, 'u1'), isFalse);
    expect(
      isPrivateLeagueMember({
        'memberIds': ['u1', 'u2'],
      }, 'u1'),
      isTrue,
    );
    expect(
      isPrivateLeagueMember({
        'ownerUid': 'boss',
        'memberIds': ['u2'],
      }, 'boss'),
      isTrue,
    );
    expect(
      isPrivateLeagueMember({
        'memberIds': ['u2'],
      }, 'u1'),
      isFalse,
    );
    expect(isPrivateLeagueOwner({'ownerUid': 'boss'}, 'boss'), isTrue);
    expect(isLeagueOwnerUid({'ownerUid': 'boss'}, 'boss'), isTrue);
    expect(isPrivateLeagueOwner({'ownerUid': 'boss'}, 'u2'), isFalse);
    expect(isLeagueMemberUid({'memberIds': ['u1']}, 'u1'), isTrue);
    expect(
      isPrivateLeagueOwner({
        'memberIds': ['boss', 'u2'],
      }, 'boss'),
      isTrue,
    );
  });

  test('emblème : créateur, admin, ou membre si owner inexploitable', () {
    expect(
      canEditPrivateLeagueEmblem({'ownerUid': 'boss', 'memberIds': ['boss']}, 'boss'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'createdByUid': 'axel',
        'memberIds': ['axel', 'u2'],
      }, 'axel'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'adminUids': ['mod'],
        'memberIds': ['mod', 'u2'],
        'ownerUid': 'boss',
      }, 'mod'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'members': {
          'mod': {'role': 'admin'},
        },
        'memberIds': ['mod', 'u2'],
        'ownerUid': 'boss',
      }, 'mod'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'ownerUid': 'boss',
        'memberIds': ['boss', 'u2'],
      }, 'u2'),
      isFalse,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'ownerUid': 'boss',
        'memberIds': ['u2'],
      }, 'u2'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'memberIds': ['axel', 'u2'],
      }, 'axel'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'memberIds': ['first', 'axel'],
      }, 'axel'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'ownerUid': 'ghost',
        'memberIds': ['axel', 'u2'],
      }, 'axel'),
      isTrue,
    );
    expect(
      canEditPrivateLeagueEmblem({
        'members': {
          'axel': {'uid': 'axel'},
          'u2': {'uid': 'u2'},
        },
      }, 'axel'),
      isTrue,
    );
    expect(canEditPrivateLeagueEmblem({'memberIds': ['u2']}, 'axel'), isFalse);
    expect(leagueOwnerUidNeedsBackfill({'memberIds': ['axel']}), isTrue);
    expect(
      leagueOwnerUidNeedsBackfill({
        'ownerUid': 'ghost',
        'memberIds': ['axel'],
      }),
      isTrue,
    );
    expect(
      leagueOwnerUidNeedsBackfill({
        'ownerUid': 'axel',
        'memberIds': ['axel'],
      }),
      isFalse,
    );
  });

  test('code salon : secret puis id league_join_codes, jamais vide collé', () {
    expect(pickLeagueInviteCode(), '');
    expect(
      pickLeagueInviteCode(secret: ' ab12 ', joinCodeId: 'ZZZZ'),
      'AB12',
    );
    expect(
      pickLeagueInviteCode(secret: '  ', joinCodeId: 'xy9k'),
      'XY9K',
    );
    expect(pickLeagueInviteCode(secret: '', joinCodeId: ''), '');
  });
}
