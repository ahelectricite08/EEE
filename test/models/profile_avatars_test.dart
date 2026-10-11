import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/profile_avatars.dart';

void main() {
  test('ids Storage / Firestore stables', () {
    expect(ProfileAvatar.firestoreDocId, 'profile_avatars');
    expect(ProfileAvatar.storageFolder, 'profile_avatars');
    expect(ProfileAvatar.publicCollection, 'user_avatars');
    expect(ProfileAvatar.maxFileBytes, 500 * 1024);
    expect(ProfileAvatar.specCopy, 'Carré 512×512, PNG ou WebP, 500 Ko max.');
  });

  test('catalogue lit avatars[] et ignore les entrées vides', () {
    final c = ProfileAvatarCatalog.fromMap({
      'avatars': [
        {
          'id': 'av_1',
          'url': ' https://x.test/a.webp ',
          'storagePath': 'profile_avatars/av_1.webp',
          'createdAtMillis': 20,
        },
        {'id': 'skip', 'url': '  '},
        {
          'id': 'av_0',
          'url': 'https://x.test/b.png',
          'storagePath': 'profile_avatars/av_0.png',
          'createdAtMillis': 10,
        },
      ],
    });
    expect(c.avatars.length, 2);
    expect(c.avatars.first.id, 'av_1');
    expect(c.byId('av_0')?.url, 'https://x.test/b.png');
    expect(c.byId('skip'), isNull);
  });

  test('url / id depuis users/{uid}', () {
    expect(profileAvatarUrlFromData(null), isNull);
    expect(profileAvatarUrlFromData({'avatarUrl': '  '}), isNull);
    expect(
      profileAvatarUrlFromData({'avatarUrl': ' https://x.test/a.png '}),
      'https://x.test/a.png',
    );
    expect(profileAvatarIdFromData({'avatarId': ' av_1 '}), 'av_1');
  });
}
