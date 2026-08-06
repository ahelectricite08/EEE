import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/benevole_availability.dart';
import '../models/benevole_posts.dart';

/// Disponibilités bénévoles + brief Make.
class BenevoleAvailabilityService {
  BenevoleAvailabilityService._();
  static final instance = BenevoleAvailabilityService._();

  static final _db = FirebaseFirestore.instance;
  static final _matches = _db.collection('matches');
  static final _responses = _db.collection('benevole_responses');

  static bool _isSedanSide(String name) {
    final u = name.toUpperCase();
    return u.contains('SEDAN') ||
        u.contains('CSSA') ||
        u.contains('CS SEDAN');
  }

  static String resolveBenevoleType(Map<String, dynamic> m) {
    final explicit = (m['benevoleType'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    final comp = (m['competition'] ?? '').toString().toLowerCase();
    if (comp.contains('réserve') ||
        comp.contains('reserve') ||
        comp.contains('b team') ||
        RegExp(r'\bb\b').hasMatch(comp)) {
      return BenevolePosts.typeReserve;
    }
    return BenevolePosts.typePremiere;
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
    for (final k in ['ville', 'city', 'town']) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    final addr = (m['adresse'] ?? m['address'] ?? m['venueAddress'] ?? '')
        .toString();
    final mCp = RegExp(r'\b\d{5}\s+([A-Za-zÀ-ÿ\- ]+)').firstMatch(addr);
    if (mCp != null) return mCp.group(1)!.trim();
    if (resolveDomicileExterieur(m) == 'Domicile') return 'Sedan';
    return '';
  }

  static String resolveLieu(Map<String, dynamic> m) {
    for (final k in ['lieu', 'stadium', 'venue', 'stade', 'stadiumName']) {
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

  BenevoleMatchCard _cardFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    DateTime date = DateTime.now();
    final raw = m['date'];
    if (raw is Timestamp) date = raw.toDate();
    final brief = (m['benevoleBriefUrl'] ?? '').toString().trim();
    return BenevoleMatchCard(
      matchId: doc.id,
      team1: (m['team1'] ?? '').toString(),
      team2: (m['team2'] ?? '').toString(),
      date: date,
      competition: (m['competition'] ?? '').toString(),
      benevoleType: resolveBenevoleType(m),
      lieu: resolveLieu(m),
      ville: resolveVille(m),
      adresse: resolveAdresse(m),
      domicileExterieur: resolveDomicileExterieur(m),
      briefUrl: brief.isEmpty ? null : brief,
      formOpen: BenevoleMatchCard.isFormOpenFor(date),
    );
  }

  /// Matchs Sedan visibles (J-20 → jour J), triés par date.
  Stream<List<BenevoleMatchCard>> watchEligibleMatches() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 21));
    return _matches
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date')
        .snapshots()
        .map((snap) {
      final list = <BenevoleMatchCard>[];
      for (final doc in snap.docs) {
        final m = doc.data();
        final t1 = (m['team1'] ?? '').toString();
        final t2 = (m['team2'] ?? '').toString();
        if (!_isSedanSide(t1) && !_isSedanSide(t2)) continue;
        final date = (m['date'] is Timestamp)
            ? (m['date'] as Timestamp).toDate()
            : DateTime.now();
        if (!BenevoleMatchCard.isVisibleFor(date)) continue;
        list.add(_cardFromDoc(doc));
      }
      return list;
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

  /// Postes proposés = intersection postes autorisés user ∩ postes du type match.
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

  static String formatHeure(DateTime d) => DateFormat('HH:mm').format(d);
  static String formatDateIso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String formatDateFr(DateTime d) =>
      DateFormat('dd/MM/yyyy HH:mm').format(d);
}
