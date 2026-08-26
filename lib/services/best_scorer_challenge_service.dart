import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/best_scorer_challenge_config.dart';

/// Défi « meilleur buteur » — config admin + réponses fans (picked | ignored).
class BestScorerChallengeService {
  BestScorerChallengeService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get configRef =>
      _db.collection('app_config').doc(BestScorerChallengeConfig.firestoreDocId);

  static CollectionReference<Map<String, dynamic>> get picksCol =>
      _db.collection('prono_best_scorer_picks');

  static DocumentReference<Map<String, dynamic>> pickRef(String uid) =>
      picksCol.doc(uid);

  static Stream<BestScorerChallengeConfig> watchConfig() {
    return configRef.snapshots().map(
          (snap) => BestScorerChallengeConfig.fromMap(snap.data()),
        );
  }

  static String userFacingWriteError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.code == 'PERMISSION_DENIED')) {
      return 'Enregistrement refusé. Vérifie que tu es connecté et que le défi '
          'est encore ouvert. Le nom du joueur ne doit pas dépasser 80 caractères.';
    }
    return 'Impossible d’enregistrer. Réessaie dans un instant.';
  }

  static String _clip(String value, int max) {
    final t = value.trim();
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  static Future<BestScorerChallengeConfig> getConfig() async {
    final snap = await configRef.get();
    return BestScorerChallengeConfig.fromMap(snap.data());
  }

  static Future<void> saveAdminConfig(BestScorerChallengeConfig config) async {
    await configRef.set(config.toAdminSaveMap(), SetOptions(merge: true));
  }

  static Stream<BestScorerPick?> watchPick(String uid) {
    return pickRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BestScorerPick.fromMap(snap.data(), uid: uid);
    });
  }

  static Future<BestScorerPick?> getPick(String uid) async {
    final snap = await pickRef(uid).get();
    if (!snap.exists) return null;
    return BestScorerPick.fromMap(snap.data(), uid: uid);
  }

  /// Réponse pour la saison courante (ignore un vieux doc d’une autre saison).
  static BestScorerPick? responseForSeason(
    BestScorerPick? pick,
    BestScorerChallengeConfig config,
  ) {
    if (pick == null) return null;
    if (pick.seasonId != config.seasonId) return null;
    if (!pick.hasClearedGate) return null;
    return pick;
  }

  /// true si le portail doit bloquer l’accès Prono.
  static bool mustGateAccess({
    required BestScorerChallengeConfig config,
    required BestScorerPick? pick,
  }) {
    if (!config.isGateActive) return false;
    return responseForSeason(pick, config) == null;
  }

  static Future<void> savePick({
    required String uid,
    required String seasonId,
    required BestScorerPlayer player,
  }) async {
    final id = _clip(player.id, 120);
    final name = _clip(player.name, 80);
    if (id.isEmpty || name.isEmpty) {
      throw StateError('Choisis un joueur valide.');
    }
    await pickRef(uid).set({
      'uid': uid,
      'seasonId': _clip(seasonId, 40),
      'status': BestScorerPick.statusPicked,
      'playerId': id,
      'playerName': name,
      'pickedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'awarded': false,
    });
  }

  static Future<void> saveIgnored({
    required String uid,
    required String seasonId,
  }) async {
    await pickRef(uid).set({
      'uid': uid,
      'seasonId': _clip(seasonId, 40),
      'status': BestScorerPick.statusIgnored,
      'playerId': '',
      'playerName': '',
      'ignoredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'awarded': false,
    });
  }

  static String newPlayerId(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9àâäéèêëïîôùûüç]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = slug.isEmpty ? 'player' : slug;
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${base}_$suffix';
  }

  /// Admin — déclare le vainqueur et attribue +10 pts (idempotent côté Functions).
  static Future<Map<String, dynamic>> resolveWinner({
    required String playerId,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('resolveBestScorerChallenge');
    final result = await callable.call({'playerId': playerId});
    return Map<String, dynamic>.from(result.data as Map? ?? const {});
  }
}
