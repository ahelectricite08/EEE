import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/adherent_vod.dart';
import '../models/user_role.dart';
import '../models/video_model.dart';
import '../utils/youtube_parser.dart';
import 'helloasso_adhesion_service.dart';
import 'user_service.dart';
import 'youtube_playlist_service.dart';

/// Config + accès VOD adhérents — `app_config/adherent_vod`.
class AdherentVodService {
  AdherentVodService._();
  static final instance = AdherentVodService._();

  final _db = FirebaseFirestore.instance;

  AdherentVodConfig _last = AdherentVodConfig.defaults;

  AdherentVodConfig get lastKnown => _last;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('app_config').doc(AdherentVodConfig.firestoreDocId);

  Stream<AdherentVodConfig> watch() {
    return _doc.snapshots().map((snap) {
      _last = AdherentVodConfig.fromMap(snap.data());
      return _last;
    });
  }

  Future<AdherentVodConfig> getOnce() async {
    final snap = await _doc.get();
    _last = AdherentVodConfig.fromMap(snap.data());
    return _last;
  }

  Future<void> setEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await _doc.set({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> setForceLockedPreview(bool locked) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    await _doc.set({
      'forceLockedPreview': locked,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> setSeasons(List<AdherentVodSeason> seasons) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final cleaned = <AdherentVodSeason>[];
    final seen = <String>{};
    for (final s in seasons) {
      final id = s.id.trim();
      if (!AdherentSeason.isValidId(id) || !seen.add(id)) continue;
      cleaned.add(
        AdherentVodSeason(
          id: id,
          playlistId: YoutubeParser.extractPlaylistId(s.playlistId) ??
              s.playlistId.trim(),
        ),
      );
    }
    cleaned.sort((a, b) => AdherentSeason.compareNewestFirst(a.id, b.id));
    var legacyPlaylist = '';
    for (final s in cleaned) {
      if (s.id == AdherentSeason.currentId && s.hasPlaylist) {
        legacyPlaylist = s.playlistId;
        break;
      }
    }
    if (legacyPlaylist.isEmpty && cleaned.isNotEmpty) {
      legacyPlaylist = cleaned.first.playlistId;
    }
    await _doc.set({
      'seasons': cleaned.map((s) => s.toMap()).toList(),
      'playlistId': legacyPlaylist.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> setPlaylistInput(String raw) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) throw StateError('not_authenticated');
    final id = YoutubeParser.extractPlaylistId(raw) ?? '';
    final current = AdherentSeason.currentId;
    final seasons = [...lastKnown.seasons];
    final i = seasons.indexWhere((s) => s.id == current);
    if (i >= 0) {
      seasons[i] = AdherentVodSeason(id: current, playlistId: id);
    } else {
      seasons.add(AdherentVodSeason(id: current, playlistId: id));
    }
    await setSeasons(seasons);
  }

  Stream<AdherentVodAccess> watchAccess() {
    return watch().asyncExpand((config) {
      if (config.forceLockedPreview) {
        return Stream<AdherentVodAccess>.value(AdherentVodAccess.locked);
      }
      return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
        if (user == null) {
          return Stream<AdherentVodAccess>.value(AdherentVodAccess.locked);
        }
        return _db.collection('users').doc(user.uid).snapshots().map((snap) {
          final data = snap.data();
          final roles = UserService.parseRolesFromData(data);
          return AdherentVodAccess(
            staffPreview: canPreviewAdherentVod(roles),
            paidSeasons: HelloAssoAdhesionService.paidSeasons(data),
          );
        });
      });
    });
  }

  Future<List<VideoModel>> loadPlaylist(String playlistId) {
    return YoutubePlaylistService.forPublicPlaylist(playlistId);
  }
}
