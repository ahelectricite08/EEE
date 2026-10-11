import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/league_avatars.dart';

void main() {
  test('pack : 5 ids stables, défaut sanglier', () {
    expect(LeagueAvatarPack.all.length, 5);
    expect(LeagueAvatarPack.ids, [
      'sanglier',
      'supporter',
      'tacticien',
      'arbitre',
      'commentateur',
    ]);
    expect(LeagueAvatarPack.defaultId, 'sanglier');
    expect(LeagueAvatarPack.defaultAvatar.id, 'sanglier');
    expect(
      LeagueAvatarPack.byId('tacticien')?.assetPath,
      'assets/league_avatars/tacticien.png',
    );
    expect(LeagueAvatarPack.resolve('inconnu').id, 'sanglier');
    expect(LeagueAvatarPack.isKnownId('arbitre'), isTrue);
    expect(LeagueAvatarPack.isKnownId('nope'), isFalse);
    for (final a in LeagueAvatarPack.all) {
      expect(a.assetPath.startsWith('assets/league_avatars/'), isTrue);
      expect(isProfileAvatarSource(a.assetPath), isFalse);
    }
  });

  test('src depuis private_leagues : pack prioritaire, sinon url', () {
    expect(leagueAvatarIdFromData(null), '');
    expect(leagueAvatarSrcFromData(null), isNull);
    expect(
      leagueAvatarSrcFromData({'avatarId': ' supporter '}),
      'assets/league_avatars/supporter.png',
    );
    expect(
      leagueAvatarSrcFromData({
        'avatarId': 'inconnu',
        'avatarUrl': ' https://x.test/l.png ',
      }),
      'https://x.test/l.png',
    );
    expect(isBundledAssetKey('assets/league_avatars/sanglier.png'), isTrue);
    expect(isBundledAssetKey('https://x.test/a.png'), isFalse);
  });

  test('ids Storage / Firestore catalogue stables', () {
    expect(LeagueCatalogAvatar.firestoreDocId, 'league_avatars');
    expect(LeagueCatalogAvatar.storageFolder, 'league_avatars');
    expect(LeagueCatalogAvatar.maxFileBytes, 500 * 1024);
    expect(
      LeagueCatalogAvatar.specCopy,
      'Carré 512×512, PNG ou WebP, 500 Ko max. Ces emblèmes apparaissent '
      'dans Créer ma ligue (créateur seulement).',
    );
  });

  test('catalogue lit avatars[] et ignore les entrées vides', () {
    final c = LeagueAvatarCatalog.fromMap({
      'avatars': [
        {
          'id': 'lg_1',
          'url': ' https://x.test/league_avatars/a.webp ',
          'storagePath': 'league_avatars/lg_1.webp',
          'createdAtMillis': 20,
        },
        {'id': 'skip', 'url': '  '},
        {
          'id': 'lg_0',
          'url': 'https://x.test/league_avatars/b.png',
          'storagePath': 'league_avatars/lg_0.png',
          'createdAtMillis': 10,
        },
      ],
    });
    expect(c.avatars.length, 2);
    expect(c.avatars.first.id, 'lg_1');
    expect(c.byId('lg_0')?.url, 'https://x.test/league_avatars/b.png');
    expect(c.byId('skip'), isNull);
  });

  test('id catalogue conservé (pas recalé sur le pack)', () {
    expect(
      leagueAvatarIdFromData({
        'avatarId': 'lg_abc',
        'avatarUrl': 'https://x.test/league_avatars/a.png',
      }),
      'lg_abc',
    );
    expect(
      leagueAvatarSrcFromData({
        'avatarId': 'lg_abc',
        'avatarUrl': 'https://x.test/league_avatars/a.png',
      }),
      'https://x.test/league_avatars/a.png',
    );
  });

  test('picker : stream KO / catalogue vide → [], jamais le pack mascottes', () {
    expect(
      resolveLeagueEmblemPickerOptions(catalog: null, streamFailed: true),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemPickerOptions(catalog: LeagueAvatarCatalog.empty),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemPickerOptions(catalog: const LeagueAvatarCatalog()),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemPickerOptions(
        catalog: LeagueAvatarCatalog.empty,
        streamFailed: true,
      ),
      isEmpty,
    );
    for (final id in LeagueAvatarPack.ids) {
      expect(
        resolveLeagueEmblemPickerOptions(catalog: LeagueAvatarCatalog.empty)
            .any((o) => o.id == id),
        isFalse,
      );
    }
  });

  test('picker : catalogue admin seulement, pas le pack bundlé', () {
    expect(leagueEmblemPickerOptions(LeagueAvatarCatalog.empty), isEmpty);
    final catalog = LeagueAvatarCatalog(
      avatars: const [
        LeagueCatalogAvatar(
          id: 'lg_1',
          url: 'https://x.test/league_avatars/a.png',
          storagePath: 'league_avatars/lg_1.png',
        ),
      ],
    );
    final opts = leagueEmblemPickerOptions(catalog);
    expect(opts.length, 1);
    expect(opts.first.id, 'lg_1');
    expect(opts.first.src, 'https://x.test/league_avatars/a.png');
    expect(opts.any((o) => LeagueAvatarPack.isKnownId(o.id)), isFalse);
  });

  test('picker : ignore avatars profil même s’ils trainent dans le catalogue',
      () {
    expect(isProfileAvatarSource('assets/avatars/avatar_01_sanglier.png'),
        isTrue);
    expect(
      isProfileAvatarSource(
        'https://x.test/o/profile_avatars%2Fav_1.png',
        storagePath: 'profile_avatars/av_1.png',
      ),
      isTrue,
    );
    expect(
      isLeagueEmblemSource('assets/league_avatars/sanglier.png'),
      isTrue,
    );
    expect(
      isLeagueEmblemSource('assets/avatars/avatar_04_camera.png'),
      isFalse,
    );

    final mixed = LeagueAvatarCatalog(
      avatars: const [
        LeagueCatalogAvatar(
          id: 'lg_ok',
          url: 'https://x.test/league_avatars/ok.png',
          storagePath: 'league_avatars/lg_ok.png',
        ),
        LeagueCatalogAvatar(
          id: 'av_profile',
          url: 'https://x.test/profile_avatars/face.png',
          storagePath: 'profile_avatars/av_1.png',
        ),
        LeagueCatalogAvatar(
          id: 'asset_profile',
          url: 'assets/avatars/avatar_04_camera.png',
          storagePath: 'assets/avatars/avatar_04_camera.png',
        ),
      ],
    );
    final opts = resolveLeagueEmblemPickerOptions(catalog: mixed);
    expect(opts.map((o) => o.id).toList(), ['lg_ok']);
    expect(opts.every(isLeagueEmblemPickerOption), isTrue);
    expect(
      opts.any((o) => isProfileAvatarSource(o.src)),
      isFalse,
    );
    expect(opts.any((o) => LeagueAvatarPack.isKnownId(o.id)), isFalse);

    final onlyProfile = LeagueAvatarCatalog(
      avatars: const [
        LeagueCatalogAvatar(
          id: 'av_profile',
          url: 'https://x.test/profile_avatars/face.png',
          storagePath: 'profile_avatars/av_1.png',
        ),
      ],
    );
    expect(
      resolveLeagueEmblemPickerOptions(catalog: onlyProfile),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: 'av_profile',
        catalog: mixed,
      ),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: 'av_profile',
        catalog: onlyProfile,
      ),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemUpdateFields(
        avatarId: 'av_profile',
        catalog: mixed,
      ),
      isNull,
    );
  });

  test('création : catalogue admin, pack ignoré, pas de défaut sanglier', () {
    const catalog = LeagueAvatarCatalog(
      avatars: [
        LeagueCatalogAvatar(
          id: 'lg_1',
          url: 'https://x.test/league_avatars/a.png',
          storagePath: 'league_avatars/lg_1.png',
        ),
        LeagueCatalogAvatar(
          id: 'lg_2',
          url: 'https://x.test/league_avatars/b.png',
          storagePath: 'league_avatars/lg_2.png',
        ),
      ],
    );
    expect(
      resolveLeagueEmblemFields(
          avatarId: 'lg_2', catalog: catalog)['avatarUrl'],
      'https://x.test/league_avatars/b.png',
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: 'sanglier',
        catalog: catalog,
      )['avatarId'],
      'lg_1',
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: '',
        catalog: catalog,
      )['avatarId'],
      'lg_1',
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: 'sanglier',
        catalog: LeagueAvatarCatalog.empty,
      ),
      isEmpty,
    );
    expect(
      resolveLeagueEmblemFields(
        avatarId: 'inconnu',
        catalog: catalog,
      ),
      isEmpty,
    );
  });

  test('update : catalogue admin seulement, pack refusé', () {
    const catalog = LeagueAvatarCatalog(
      avatars: [
        LeagueCatalogAvatar(
          id: 'lg_1',
          url: 'https://x.test/league_avatars/a.png',
          storagePath: 'league_avatars/lg_1.png',
        ),
      ],
    );
    expect(
      resolveLeagueEmblemUpdateFields(avatarId: 'lg_1', catalog: catalog),
      isNotNull,
    );
    expect(
      resolveLeagueEmblemUpdateFields(avatarId: 'tacticien', catalog: catalog),
      isNull,
    );
    expect(
      resolveLeagueEmblemUpdateFields(avatarId: 'inconnu', catalog: catalog),
      isNull,
    );
  });

  test('persist conserve catalogue ou ancien pack, vide si rien', () {
    expect(
      leagueEmblemPersistFields({
        'avatarId': 'lg_1',
        'avatarUrl': 'https://x.test/league_avatars/a.png',
      })['avatarUrl'],
      'https://x.test/league_avatars/a.png',
    );
    expect(
      leagueEmblemPersistFields({
        'avatarId': 'sanglier',
        'avatarUrl': 'assets/league_avatars/sanglier.png',
      })['avatarId'],
      'sanglier',
    );
    expect(leagueEmblemPersistFields({}), isEmpty);
  });

  test('picker : ignore un asset pack même s’il trainait dans le catalogue', () {
    const sneaky = LeagueAvatarCatalog(
      avatars: [
        LeagueCatalogAvatar(
          id: 'sanglier',
          url: 'assets/league_avatars/sanglier.png',
          storagePath: 'assets/league_avatars/sanglier.png',
        ),
        LeagueCatalogAvatar(
          id: 'lg_ok',
          url: 'https://x.test/league_avatars/ok.png',
          storagePath: 'league_avatars/lg_ok.png',
        ),
      ],
    );
    expect(
      leagueEmblemPickerOptions(sneaky).map((o) => o.id).toList(),
      ['lg_ok'],
    );
  });
}
