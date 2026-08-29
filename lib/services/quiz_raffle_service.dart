import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/quiz_raffle.dart';

class QuizRaffleService {
  QuizRaffleService._();

  /// Switch TEST tombola — `app_config/quiz_raffle_test` (pas un vrai quiz).
  static const testDocId = 'quiz_raffle_test';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get testRef =>
      _db.collection('app_config').doc(testDocId);
  static final CollectionReference<Map<String, dynamic>> col = _db.collection(
    'quiz_raffles',
  );

  static DocumentReference<Map<String, dynamic>> doc(String id) => col.doc(id);

  static DocumentReference<Map<String, dynamic>> secretRef(String id) =>
      doc(id).collection('admin').doc('secret');

  static CollectionReference<Map<String, dynamic>> votesCol(String id) =>
      doc(id).collection('votes');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchActive() {
    return col.where('active', isEqualTo: true).limit(4).snapshots();
  }

  /// Tous les quiz tirés (y compris masqués). Tri côté client — pas d’index composite.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchDrawnHistory() {
    return col.where('status', isEqualTo: 'drawn').limit(80).snapshots();
  }

  static DateTime? timestampOf(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  static DateTime? drawnAtOf(Map<String, dynamic> data) {
    return timestampOf(data, 'drawnAt') ??
        timestampOf(data, 'closedAt') ??
        timestampOf(data, 'startsAt');
  }

  static List<QuizRaffleHistoryItem> historyFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = <QuizRaffleHistoryItem>[];
    for (final d in docs) {
      if (d.id == testDocId) continue;
      final data = d.data();
      if (statusOf(data) != 'drawn') continue;
      items.add(
        QuizRaffleHistoryItem(
          id: d.id,
          title: titleOf(data),
          question: questionOf(data),
          winnerUid: winnerUidOf(data),
          winnerName: winnerNameOf(data),
          drawnAt: drawnAtOf(data),
        ),
      );
    }
    return QuizRaffleLogic.sortDrawnHistory(items);
  }

  static Map<String, dynamic>? pickNewest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;
    QueryDocumentSnapshot<Map<String, dynamic>> best = docs.first;
    DateTime bestAt = _startsAt(best.data());
    for (final d in docs.skip(1)) {
      final at = _startsAt(d.data());
      if (at.isAfter(bestAt)) {
        best = d;
        bestAt = at;
      }
    }
    return {'id': best.id, ...best.data()};
  }

  static DateTime _startsAt(Map<String, dynamic> data) {
    final raw = data['startsAt'];
    if (raw is Timestamp) return raw.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String statusOf(Map<String, dynamic> data) =>
      (data['status'] as String? ?? '').trim();

  static String questionOf(Map<String, dynamic> data) =>
      (data['question'] as String? ?? '').trim();

  static String titleOf(Map<String, dynamic> data) =>
      QuizRaffleLogic.displayTitle(data['title'] as String?);

  static List<String> choicesOf(Map<String, dynamic> data) {
    final raw = data['choices'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static DateTime? endsAtOf(Map<String, dynamic> data) {
    final raw = data['endsAt'];
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  static bool isOpen(Map<String, dynamic> data, DateTime now) {
    return QuizRaffleLogic.isVoteWindowOpen(
      status: statusOf(data),
      endsAt: endsAtOf(data),
      now: now,
    );
  }

  static bool isDrawn(Map<String, dynamic> data) => statusOf(data) == 'drawn';

  static String winnerNameOf(Map<String, dynamic> data) =>
      (data['winnerName'] as String? ?? '').trim();

  static String winnerUidOf(Map<String, dynamic> data) =>
      (data['winnerUid'] as String? ?? '').trim();

  static int? correctIndexPublicOf(Map<String, dynamic> data) {
    final v = data['correctIndexPublic'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  static List<String> eligibleNamesOf(Map<String, dynamic> data) {
    final raw = data['eligibleNames'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static int eligibleCountOf(Map<String, dynamic> data) {
    final n = data['eligibleCount'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return eligibleNamesOf(data).length;
  }

  static String correctLabelOf(Map<String, dynamic> data) {
    final label = (data['correctLabelPublic'] as String? ?? '').trim();
    if (label.isNotEmpty) return label;
    final idx = correctIndexPublicOf(data);
    final choices = choicesOf(data);
    if (idx == null || idx < 0 || idx >= choices.length) return '';
    return choices[idx];
  }

  static String fanDisplayName(Map<String, dynamic>? userData, User user) {
    final firstName = (userData?['firstName'] ?? '').toString().trim();
    final lastName = (userData?['lastName'] ?? '').toString().trim();
    final displayName = (userData?['displayName'] ?? '').toString().trim();
    if (firstName.isNotEmpty) {
      if (lastName.isNotEmpty) return '$firstName ${lastName[0]}.';
      return firstName;
    }
    if (displayName.isNotEmpty) return displayName;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Membre';
  }

  static Future<String> startQuiz({
    String title = '',
    required String question,
    required List<String> choices,
    required int correctIndex,
    required int durationSeconds,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté.');
    }
    final q = question.trim();
    final clean = choices.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (q.isEmpty) {
      throw StateError('Écris une question.');
    }
    if (clean.length < 2 || clean.length > 4) {
      throw StateError('Il faut 2 à 4 choix.');
    }
    if (correctIndex < 0 || correctIndex >= clean.length) {
      throw StateError('Coche la bonne réponse.');
    }
    final dur = durationSeconds.clamp(10, 3600);

    final open = await col.where('status', isEqualTo: 'open').limit(8).get();
    if (open.docs.isNotEmpty) {
      throw StateError(
        'Un quiz est déjà ouvert. Tire au sort ou annule-le avant d’en lancer un autre.',
      );
    }

    final previous = await col.where('active', isEqualTo: true).limit(8).get();
    final ref = col.doc();
    final now = DateTime.now();
    final ends = now.add(Duration(seconds: dur));

    final batch = _db.batch();
    for (final d in previous.docs) {
      batch.set(d.reference, {'active': false}, SetOptions(merge: true));
    }
    batch.set(ref, {
      'title': title.trim(),
      'question': q,
      'choices': clean,
      'durationSeconds': dur,
      'startsAt': Timestamp.fromDate(now),
      'endsAt': Timestamp.fromDate(ends),
      'status': 'open',
      'active': true,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'winnerUid': '',
      'winnerName': '',
      'eligibleCount': 0,
      'eligibleNames': <String>[],
    });
    batch.set(secretRef(ref.id), {
      'correctIndex': correctIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ref.id;
  }

  static Future<void> cancelQuiz(String quizId) async {
    final id = quizId.trim();
    if (id.isEmpty) return;
    await doc(id).set({
      'status': 'closed',
      'active': false,
      'closedAt': FieldValue.serverTimestamp(),
      'endedReason': 'cancel',
    }, SetOptions(merge: true));
  }

  static Future<void> hideResult(String quizId) async {
    final id = quizId.trim();
    if (id.isEmpty) return;
    await doc(id).set({'active': false}, SetOptions(merge: true));
  }

  static Future<void> castVote({
    required String quizId,
    required int choiceIndex,
    required Map<String, dynamic> quiz,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Tu dois être connecté pour répondre.');
    }
    if (!isOpen(quiz, DateTime.now())) {
      throw StateError('Le quiz est clos.');
    }
    final choices = choicesOf(quiz);
    if (choiceIndex < 0 || choiceIndex >= choices.length) {
      throw StateError('Ce choix n’est plus disponible.');
    }

    var displayName = 'Membre';
    try {
      final u = await _db.collection('users').doc(user.uid).get();
      displayName = fanDisplayName(u.data(), user);
    } catch (_) {
      displayName = fanDisplayName(null, user);
    }

    final voteRef = votesCol(quizId).doc(user.uid);
    await _db.runTransaction((tx) async {
      final qSnap = await tx.get(doc(quizId));
      if (!qSnap.exists) {
        throw StateError('Quiz introuvable.');
      }
      final data = qSnap.data() ?? <String, dynamic>{};
      if (!isOpen(data, DateTime.now())) {
        throw StateError('Le quiz est clos.');
      }
      final prev = await tx.get(voteRef);
      tx.set(voteRef, {
        'uid': user.uid,
        'choiceIndex': choiceIndex,
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!prev.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<Map<String, dynamic>> drawNow(String quizId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('drawQuizRaffle');
    final result = await callable.call(<String, dynamic>{'quizId': quizId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> closeAndDraw(String quizId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('closeQuizRaffle');
    final result = await callable.call(<String, dynamic>{'quizId': quizId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static bool isForceTest(Map<String, dynamic>? data) => data?['force'] == true;

  static int playNonceOf(Map<String, dynamic> data) {
    final v = data['playNonce'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Carte Live fictive (status drawn). Aucun doc `quiz_raffles`.
  static Map<String, dynamic>? testQuizFromCue(Map<String, dynamic>? data) {
    if (!isForceTest(data) || data == null) return null;
    final names = eligibleNamesOf(data);
    final winnerName = winnerNameOf(data);
    if (names.length < 2 || winnerName.isEmpty) return null;
    final question = questionOf(data);
    final choices = choicesOf(data);
    final label = (data['correctLabelPublic'] as String? ?? '').trim();
    return {
      'id': testDocId,
      'status': 'drawn',
      'active': false,
      'title': titleOf(data),
      'question': question,
      'choices': choices.isEmpty ? const ['Vert', 'Rouge'] : choices,
      'correctLabelPublic': label.isEmpty ? 'Vert' : label,
      'winnerUid': 'test_preview',
      'winnerName': winnerName,
      'eligibleNames': names,
      'eligibleCount': names.length,
      'playNonce': playNonceOf(data),
    };
  }

  /// Allume le TEST : prénoms inventés, gagnant local, pas de tirage Firestore.
  /// [title] = libellé Live (Axel le choisit). Vide → « Quiz ».
  static Future<void> setForceTest(
    bool on, {
    String title = '',
    Random? random,
  }) async {
    if (!on) {
      await testRef.set({
        'force': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }
    final rng = random ?? Random();
    final count = 12 + rng.nextInt(9);
    final names = QuizRaffleLogic.shuffledFakeNames(
      nextInt: rng.nextInt,
      count: count,
    );
    final winner = names[rng.nextInt(names.length)];
    await testRef.set({
      'force': true,
      'playNonce': DateTime.now().millisecondsSinceEpoch,
      'winnerUid': 'test_preview',
      'winnerName': winner,
      'eligibleNames': names,
      'eligibleCount': names.length,
      'title': title.trim(),
      'question': '',
      'choices': ['Vert', 'Rouge'],
      'correctLabelPublic': 'Vert',
      'status': 'drawn',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Change le titre Live du TEST sans relancer les noms.
  static Future<void> updateTestTitle(String title) async {
    await testRef.set({
      'title': title.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
