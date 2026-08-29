import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Une ligne d’historique Reward (doc `quiz_raffles` déjà `drawn`).
class QuizRaffleHistoryItem {
  final String id;
  final String title;
  final String question;
  final String winnerUid;
  final String winnerName;
  final DateTime? drawnAt;

  const QuizRaffleHistoryItem({
    required this.id,
    this.title = '',
    required this.question,
    required this.winnerUid,
    required this.winnerName,
    this.drawnAt,
  });

  /// Profil ouvrable : vrai uid membre, pas le TEST local.
  bool get hasWinner {
    final uid = winnerUid.trim();
    return uid.isNotEmpty && uid != 'test_preview';
  }
}

/// Logique quiz-sondage + tirage (sans Firestore) — tests unitaires.
class QuizRaffleVote {
  final String uid;
  final int choiceIndex;
  final String displayName;

  const QuizRaffleVote({
    required this.uid,
    required this.choiceIndex,
    this.displayName = '',
  });
}

class QuizRaffleDraw {
  final String winnerUid;
  final String winnerName;
  final int eligibleCount;

  const QuizRaffleDraw({
    required this.winnerUid,
    required this.winnerName,
    required this.eligibleCount,
  });

  bool get hasWinner => winnerUid.isNotEmpty;
}

class QuizRaffleLogic {
  QuizRaffleLogic._();

  static bool isVoteWindowOpen({
    required String status,
    required DateTime? endsAt,
    required DateTime now,
  }) {
    if (status.trim() != 'open') return false;
    if (endsAt == null) return false;
    return now.isBefore(endsAt);
  }

  /// [pickIndex] reçoit `eligible.length` et doit renvoyer un index dans `[0, length)`.
  static QuizRaffleDraw pickWinner({
    required List<QuizRaffleVote> votes,
    required int correctIndex,
    required int Function(int length) pickIndex,
  }) {
    final eligible = votes
        .where((v) => v.choiceIndex == correctIndex)
        .toList(growable: false);
    if (eligible.isEmpty) {
      return const QuizRaffleDraw(
        winnerUid: '',
        winnerName: '',
        eligibleCount: 0,
      );
    }
    var i = pickIndex(eligible.length);
    if (i < 0) i = 0;
    if (i >= eligible.length) i = eligible.length - 1;
    final w = eligible[i];
    final name = w.displayName.trim();
    return QuizRaffleDraw(
      winnerUid: w.uid,
      winnerName: name.isEmpty ? 'Membre' : name,
      eligibleCount: eligible.length,
    );
  }

  /// Tombola publique : 0 = vide, 1 = révélation sèche, 2+ = défilement.
  /// [eligibleNames] vient du doc public après le tirage serveur.
  static bool shouldRollTombola({
    required String winnerUid,
    required List<String> eligibleNames,
  }) {
    return winnerUid.trim().isNotEmpty && eligibleNames.length >= 2;
  }

  /// Bandeau de noms. Le **dernier** item est toujours [winnerName] (tirage serveur).
  static List<String> buildTombolaReel({
    required List<String> eligibleNames,
    required String winnerName,
    int cycles = 4,
  }) {
    final winner = winnerName.trim().isEmpty ? 'Membre' : winnerName.trim();
    final names = eligibleNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return [winner];
    final n = cycles.clamp(2, 8);
    final reel = <String>[];
    for (var i = 0; i < n; i++) {
      reel.addAll(names);
    }
    reel.add(winner);
    return reel;
  }

  /// Prénoms fictifs pour le TEST tombola (pas de vrais membres).
  static const List<String> kFakePreviewFirstNames = [
    'Léa',
    'Hugo',
    'Camille',
    'Inès',
    'Jules',
    'Manon',
    'Louis',
    'Chloé',
    'Nathan',
    'Emma',
    'Léo',
    'Jade',
    'Raphaël',
    'Louise',
    'Adam',
    'Alice',
    'Noah',
    'Rose',
    'Gabriel',
    'Sarah',
  ];

  /// Mélange déterministe via [nextInt] (0 ≤ r < max). [count] entre 12 et 20.
  static List<String> shuffledFakeNames({
    required int Function(int max) nextInt,
    int count = 16,
  }) {
    final pool = List<String>.from(kFakePreviewFirstNames);
    for (var i = pool.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    final n = count.clamp(12, pool.length);
    return pool.take(n).toList();
  }

  /// Plus récent d’abord (`drawnAt`). Sans date → tout en bas.
  static List<QuizRaffleHistoryItem> sortDrawnHistory(
    List<QuizRaffleHistoryItem> items,
  ) {
    final copy = List<QuizRaffleHistoryItem>.from(items);
    copy.sort((a, b) {
      final at = a.drawnAt;
      final bt = b.drawnAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return copy;
  }

  /// Titre Live. Vide → « Quiz » (jamais « Tombola » tout seul).
  static const fallbackFanTitle = 'Quiz';

  static String displayTitle(String? raw) {
    final t = (raw ?? '').trim();
    return t.isEmpty ? fallbackFanTitle : t;
  }

  static String shortQuestion(String question, {int maxChars = 72}) {
    final q = question.trim();
    if (q.length <= maxChars) return q;
    if (maxChars < 2) return '…';
    return '${q.substring(0, maxChars - 1).trimRight()}…';
  }

  static bool _tzReady = false;

  static void _ensureParisTz() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  /// Date + heure du tirage, Europe/Paris, ex. `29 août 2026 · 21:04`.
  static String formatDrawnAtParis(DateTime? at) {
    if (at == null) return '';
    _ensureParisTz();
    final paris = tz.TZDateTime.from(at, tz.getLocation('Europe/Paris'));
    return DateFormat('d MMMM yyyy · HH:mm', 'fr_FR').format(paris);
  }
}
