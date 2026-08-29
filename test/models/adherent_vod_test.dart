import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/adherent_vod.dart';
import 'package:dvcr/models/user_role.dart';
import 'package:dvcr/services/helloasso_adhesion_service.dart';
import 'package:dvcr/utils/youtube_parser.dart';

void main() {
  test('AdherentVodConfig hidden by default', () {
    expect(AdherentVodConfig.firestoreDocId, 'adherent_vod');
    expect(AdherentVodConfig.defaults.enabled, isFalse);
    expect(AdherentVodConfig.defaults.showInApp, isFalse);
    expect(AdherentVodConfig.defaults.hasPlaylist, isFalse);
  });

  test('showInApp follows enabled even without playlist', () {
    expect(
      AdherentVodConfig.fromMap({
        'enabled': true,
        'playlistId': '',
      }).showInApp,
      isTrue,
    );
    expect(
      AdherentVodConfig.fromMap({
        'enabled': false,
        'playlistId': 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD',
      }).showInApp,
      isFalse,
    );
  });

  test('playlist URL is normalized to ID', () {
    final cfg = AdherentVodConfig.fromMap({
      'enabled': true,
      'playlistId':
          'https://www.youtube.com/playlist?list=PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD',
    });
    expect(cfg.playlistId, 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD');
    expect(cfg.hasPlaylist, isTrue);
  });

  test('YoutubeParser extracts playlist id from URL or bare id', () {
    expect(
      YoutubeParser.extractPlaylistId(
        'https://www.youtube.com/playlist?list=PLabcDEF1234567890xxxx',
      ),
      'PLabcDEF1234567890xxxx',
    );
    expect(
      YoutubeParser.extractPlaylistId(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabcDEF1234567890xxxx',
      ),
      'PLabcDEF1234567890xxxx',
    );
    expect(
      YoutubeParser.extractPlaylistId('PLabcDEF1234567890xxxx'),
      'PLabcDEF1234567890xxxx',
    );
    expect(
      YoutubeParser.extractPlaylistId(
        'https://studio.youtube.com/playlist/PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22/edit',
      ),
      'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22',
    );
    expect(
      YoutubeParser.extractPlaylistId(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&amp;list=PLabcDEF1234567890xxxx',
      ),
      'PLabcDEF1234567890xxxx',
    );
    expect(
      YoutubeParser.extractPlaylistId(
        'https://www.youtube.com/feeds/videos.xml?playlist_id=PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22',
      ),
      'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22',
    );
    expect(YoutubeParser.extractPlaylistId('not-a-playlist'), isNull);
  });

  test('staff preview is admin or CM, not editor', () {
    expect(canPreviewAdherentVod({UserRole.admin}), isTrue);
    expect(canPreviewAdherentVod({UserRole.communityManager}), isTrue);
    expect(canPreviewAdherentVod({UserRole.editor}), isFalse);
    expect(canPreviewAdherentVod({UserRole.supporter}), isFalse);
  });

  test('forceLockedPreview is off by default and read from map', () {
    expect(AdherentVodConfig.defaults.forceLockedPreview, isFalse);
    expect(
      AdherentVodConfig.fromMap({
        'enabled': true,
        'forceLockedPreview': true,
      }).forceLockedPreview,
      isTrue,
    );
  });

  test('saison foot FR : juillet N = N-(N+1), juin = (N-1)-N', () {
    expect(AdherentSeason.idFor(DateTime(2026, 8, 28)), '2026-2027');
    expect(AdherentSeason.idFor(DateTime(2027, 6, 1)), '2026-2027');
    expect(AdherentSeason.idFor(DateTime(2027, 7, 1)), '2027-2028');
    expect(AdherentSeason.isValidId('2026-2027'), isTrue);
    expect(AdherentSeason.isValidId('2026-2028'), isFalse);
  });

  test('playlists par saison, plus récente d’abord', () {
    final cfg = AdherentVodConfig.fromMap({
      'enabled': true,
      'seasons': [
        {'id': '2026-2027', 'playlistId': 'PLHZuIRHxEd8xMgonAb9tHsGd1Mi19eFJD'},
        {'id': '2027-2028', 'playlistId': 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22'},
      ],
    });
    expect(cfg.visibleSeasons.map((s) => s.id).toList(), [
      '2027-2028',
      '2026-2027',
    ]);
    expect(cfg.visibleSeasons.first.playlistId, 'PLHZuIRHxEd8zo9LkqpYoBgs6fLpw6xD22');
  });

  test('payé 2027-2028 n’ouvre pas 2026-2027', () {
    const access = AdherentVodAccess(paidSeasons: {'2027-2028'});
    expect(access.canWatch('2027-2028'), isTrue);
    expect(access.canWatch('2026-2027'), isFalse);
    expect(AdherentVodAccess.locked.canWatch('2026-2027'), isFalse);
    expect(
      const AdherentVodAccess(staffPreview: true).canWatch('2026-2027'),
      isTrue,
    );
  });

  test('legacy adhérent actif sans tableau = saison de la date de fin', () {
    expect(
      HelloAssoAdhesionService.paidSeasons({
        'helloAsso': {
          'isAdherentActive': true,
          'adherentExpiresAt': Timestamp.fromDate(DateTime(2027, 6, 1)),
        },
      }),
      {'2026-2027'},
    );
    expect(
      HelloAssoAdhesionService.paidSeasons({
        'helloAsso': {
          'isAdherentActive': false,
          'adherentSeasons': ['2027-2028'],
        },
      }).contains('2026-2027'),
      isFalse,
    );
  });
}
