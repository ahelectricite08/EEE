import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/benevole_availability.dart';
import '../models/benevole_posts.dart';
import '../models/user_role.dart';

/// Disponibilités bénévoles + brief Make + événements perso.
class BenevoleAvailabilityService {
  BenevoleAvailabilityService._();
  static final instance = BenevoleAvailabilityService._();

  static final _db = FirebaseFirestore.instance;
  static final _matches = _db.collection('matches');
  static final _customEvents = _db.collection('benevole_events');
  static final _responses = _db.collection('benevole_responses');

  static bool _isSedanSide(String name) {
    final u = name.toUpperCase();
    return u.contains('SEDAN') ||
        u.contains('CSSA') ||
        u.contains('CS SEDAN');
  }

  static String resolveBenevoleType(Map<String, dynamic> m) {
    final explicit = (m['benevoleType'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return BenevolePosts.normalizeType(explicit);
    return BenevolePosts.inferTypeFromCompetition(
      (m['competition'] ?? '').toString(),
    );
  }

  static String resolveDomicileExterieur(Map<String, dynamic> m) {
    final explicit = (m['domicileExterieur'] ?? m['domicile_exterieur'] ?? '')
        .toString()
        .trim();
    if (explicit == 'Domicile' || explicit == 'Extérieur') return explicit;
    final t1 = (m['team1'] ?? '').toString();
    if (_isSedanSide(t1)) return 'Domicile';
    return 'Extérieur';
  }

  static String resolveVille(Map<String, dynamic> m) {
    for (final k in ['ville', 'city', 'town', 'commune']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    final addr = (m['adresse'] ?? m['address'] ?? m['venueAddress'] ?? '')
        .toString();
    final mCp = RegExp(r"\b\d{5}\s+([A-Za-zÀ-ÿ\-']+)").firstMatch(addr);
    if (mCp != null) return mCp.group(1)!.trim();
    if (resolveDomicileExterieur(m) == 'Domicile') return 'Sedan';
    return '';
  }

  static String resolveLieu(Map<String, dynamic> m) {
    for (final k in [
      'lieu',
      'stadium',
      'venue',
      'stade',
      'stadiumName',
      'terrain',
      'terrainNom',
    ]) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    if (resolveDomicileExterieur(m) == 'Domicile') {
      return 'Stade Louis Dugauguez';
    }
    return '';
  }

  static String resolveAdresse(Map<String, dynamic> m) {
    for (final k in ['adresse', 'address', 'venueAddress', 'fullAddress']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    if (resolveDomicileExterieur(m) == 'Domicile') {
      return 'Route de Charleville, 08200 Sedan';
    }
    return '';
  }

  /// `null` = champ absent (legacy : tous les types).
  static List<String>? parseEventRights(Map<String, dynamic>? data) {
    if (data == null || !data.containsKey('benevoleEventRights')) return null;
    final raw = data['benevoleEventRights'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static bool isAdminUser(Map<String, dynamic>? data) {
    final roles = parseUserRolesFromDoc(data);
    return roles.contains(UserRole.admin);
  }

  BenevoleMatchCard _cardFromMap({
    required String id,
    required Map<String, dynamic> m,
    required bool isCustomEvent,
  }) {
    DateTime date = DateTime.now();
    final raw = m['date'];
    if (raw is Timestamp) date = raw.toDate();
    final brief = (m['benevoleBriefUrl'] ?? '').toString().trim();
    var team1 = (m['team1'] ?? '').toString();
    var team2 = (m['team2'] ?? '').toString();
    if (isCustomEvent) {
      final title = (m['title'] ?? '').toString().trim();
      if (title.isNotEmpty && team1.trim().isEmpty) team1 = title;
    }
    return BenevoleMatchCard(
      matchId: id,
      team1: team1,
      team2: team2,
      date: date,
      competition: (m['competition'] ?? '').toString(),
      benevoleType: resolveBenevoleType(m),
      lieu: resolveLieu(m),
      ville: resolveVille(m),
      adresse: resolveAdresse(m),
      domicileExterieur: isCustomEvent
          ? 'Extérieur'
          : resolveDomicileExterieur(m),
      briefUrl: brief.isEmpty ? null : brief,
      formOpen: BenevolePosts.isFormOpenFor(date),
      isCustomEvent: isCustomEvent,
    );
  }

  bool _eligibleFootballMatch(Map<String, dynamic> m) {
    if (m['benevoleOnly'] == true) return false;
    final explicit = (m['benevoleType'] ?? '').toString().trim();
    if (explicit.isNotEmpty) {
      return BenevolePosts.normalizeType(explicit) != BenevolePosts.typePerso;
    }
    final t1 = (m['team1'] ?? '').toString();
    final t2 = (m['team2'] ?? '').toString();
    if (_isSedanSide(t1) || _isSedanSide(t2)) return true;
    final blob = '$t1 $t2 ${m['competition']}'.toLowerCase();
    return blob.contains('flammes') || blob.contains('carolo');
  }

  List<BenevoleMatchCard> _filterCards({
    required List<BenevoleMatchCard> cards,
    required List<String>? rights,
    required bool isAdmin,
  }) {
    final out = <BenevoleMatchCard>[];
    for (final card in cards) {
      if (!BenevolePosts.isVisibleFor(card.date)) continue;
      if (!BenevolePosts.canSeeEventType(
        type: card.benevoleType,
        rights: rights,
        isAdmin: isAdmin,
      )) {
        continue;
      }
      out.add(card);
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Query<Map<String, dynamic>> _windowQuery(
    CollectionReference<Map<String, dynamic>> col,
  ) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 21));
    return col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date');
  }

  /// Matchs + événements perso dans J-20 → J-3 12:00, filtrés par droits.
  Stream<List<BenevoleMatchCard>> watchEligibleMatches() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final controller = StreamController<List<BenevoleMatchCard>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? matchSnap;
    QuerySnapshot<Map<String, dynamic>>? customSnap;
    DocumentSnapshot<Map<String, dynamic>>? userSnap;

    void emit() {
      if (controller.isClosed) return;
      final cards = <BenevoleMatchCard>[];
      if (matchSnap != null) {
        for (final doc in matchSnap!.docs) {
          if (!_eligibleFootballMatch(doc.data())) continue;
          cards.add(_cardFromMap(
            id: doc.id,
            m: doc.data(),
            isCustomEvent: false,
          ));
        }
      }
      if (customSnap != null) {
        for (final doc in customSnap!.docs) {
          cards.add(_cardFromMap(
            id: doc.id,
            m: doc.data(),
            isCustomEvent: true,
          ));
        }
      }
      final data = userSnap?.data();
      controller.add(_filterCards(
        cards: cards,
        rights: parseEventRights(data),
        isAdmin: isAdminUser(data),
      ));
    }

    final subs = <StreamSubscription<dynamic>>[
      _windowQuery(_matches).snapshots().listen((s) {
        matchSnap = s;
        emit();
      }),
      _windowQuery(_customEvents).snapshots().listen((s) {
        customSnap = s;
        emit();
      }),
    ];
    if (uid != null) {
      subs.add(_db.collection('users').doc(uid).snapshots().listen((s) {
        userSnap = s;
        emit();
      }));
    } else {
      emit();
    }

    controller.onCancel = () {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    };
    return controller.stream;
  }

  /// Tous les événements de la fenêtre (admin staffing) — pas de filtre droits.
  Stream<List<BenevoleMatchCard>> watchAdminWindowEvents() {
    final controller = StreamController<List<BenevoleMatchCard>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? matchSnap;
    QuerySnapshot<Map<String, dynamic>>? customSnap;

    void emit() {
      if (controller.isClosed) return;
      final cards = <BenevoleMatchCard>[];
      if (matchSnap != null) {
        for (final doc in matchSnap!.docs) {
          if (!_eligibleFootballMatch(doc.data()) &&
              doc.data()['benevoleOnly'] != true) {
            continue;
          }
          cards.add(_cardFromMap(
            id: doc.id,
            m: doc.data(),
            isCustomEvent: false,
          ));
        }
      }
      if (customSnap != null) {
        for (final doc in customSnap!.docs) {
          cards.add(_cardFromMap(
            id: doc.id,
            m: doc.data(),
            isCustomEvent: true,
          ));
        }
      }
      controller.add(_filterCards(
        cards: cards,
        rights: null,
        isAdmin: true,
      ));
    }

    final subs = <StreamSubscription<dynamic>>[
      _windowQuery(_matches).snapshots().listen((s) {
        matchSnap = s;
        emit();
      }),
      _windowQuery(_customEvents).snapshots().listen((s) {
        customSnap = s;
        emit();
      }),
    ];
    controller.onCancel = () {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    };
    return controller.stream;
  }

  Stream<List<BenevoleMatchCard>> watchUpcomingCustomEvents() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    return _customEvents
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('date')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (d) => _cardFromMap(id: d.id, m: d.data(), isCustomEvent: true),
          )
          .toList();
    });
  }

  Stream<BenevoleAvailabilityResponse?> watchMyResponse(String matchId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || matchId.isEmpty) {
      return Stream.value(null);
    }
    final id = '${matchId}_$uid';
    return _responses.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BenevoleAvailabilityResponse.fromFirestore(
        snap.id,
        snap.data() ?? {},
      );
    });
  }

  Stream<List<BenevoleAvailabilityResponse>> watchAllResponses() {
    return _responses.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => BenevoleAvailabilityResponse.fromFirestore(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      return list;
    });
  }

  Future<List<String>> getMyAuthorizedPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final snap = await _db.collection('users').doc(uid).get();
    final raw = snap.data()?['benevolePostes'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Stream<List<String>> watchMyAuthorizedPosts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['benevolePostes'];
      if (raw is! List) return const <String>[];
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    });
  }

  /// Postes proposés = intersection postes autorisés user ∩ postes du type.
  static List<String> filterPostsForUser({
    required List<String> authorized,
    required String benevoleType,
  }) {
    final forType = BenevolePosts.forEventType(benevoleType);
    if (authorized.isEmpty) return forType;
    final set = authorized.toSet();
    return forType.where(set.contains).toList();
  }

  Future<Map<String, dynamic>> submit({
    required String matchId,
    required String statutPresence,
    required String voeu1,
    String voeu2 = '',
    String voeu3 = '',
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('submitBenevoleAvailability');
    final result = await callable.call({
      'matchId': matchId,
      'statut_presence': statutPresence,
      'voeu_1': voeu1,
      'voeu_2': voeu2,
      'voeu_3': voeu3,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'ok': true};
  }

  Future<Map<String, dynamic>> retryMakeSync(String responseId) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('retryBenevoleMakeSync');
    final result = await callable.call({'responseId': responseId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'ok': true};
  }

  /// Événement perso / intervention extérieure (hors calendrier football).
  Future<String> createCustomEvent({
    required String title,
    required DateTime date,
    String lieu = '',
    String ville = '',
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Titre requis');
    }
    final ref = await _customEvents.add({
      'title': trimmed,
      'team1': trimmed,
      'team2': '',
      'date': Timestamp.fromDate(date),
      'lieu': lieu.trim(),
      'ville': ville.trim(),
      'city': ville.trim(),
      'competition': BenevolePosts.typePerso,
      'benevoleType': BenevolePosts.typePerso,
      'status': 'upcoming',
      'manual': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Match réserve dans le calendrier app (pas d’import FFF réserve aujourd’hui).
  Future<String> createReserveMatch({
    required String opponent,
    required DateTime date,
    String lieu = '',
    String ville = '',
    String team1 = 'CSSA Réserve',
  }) async {
    final opp = opponent.trim();
    if (opp.isEmpty) {
      throw ArgumentError('Adversaire requis');
    }
    final ref = await _matches.add({
      'team1': team1.trim().isEmpty ? 'CSSA Réserve' : team1.trim(),
      'team2': opp,
      'date': Timestamp.fromDate(date),
      'lieu': lieu.trim(),
      'stadium': lieu.trim(),
      'ville': ville.trim(),
      'city': ville.trim(),
      'competition': 'Équipe réserve',
      'benevoleType': BenevolePosts.typeReserve,
      'status': 'upcoming',
      'manual': true,
      'streamBroadcast': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deleteCustomEvent(String id) async {
    if (id.isEmpty) return;
    await _customEvents.doc(id).delete();
  }

  static String formatHeure(DateTime d) => DateFormat('HH:mm').format(d);
  static String formatDateIso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String formatDateFr(DateTime d) =>
      DateFormat('dd/MM/yyyy HH:mm').format(d);
}
