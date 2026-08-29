import 'package:dvcr/models/quiz_raffle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final ends = DateTime(2026, 8, 29, 12, 0);

  test('vote window open only while status open and now < endsAt', () {
    expect(
      QuizRaffleLogic.isVoteWindowOpen(
        status: 'open',
        endsAt: ends,
        now: DateTime(2026, 8, 29, 11, 59, 59),
      ),
      isTrue,
    );
    expect(
      QuizRaffleLogic.isVoteWindowOpen(
        status: 'open',
        endsAt: ends,
        now: ends,
      ),
      isFalse,
    );
    expect(
      QuizRaffleLogic.isVoteWindowOpen(
        status: 'drawn',
        endsAt: ends,
        now: DateTime(2026, 8, 29, 11, 50),
      ),
      isFalse,
    );
  });

  test('cannot vote after end', () {
    expect(
      QuizRaffleLogic.isVoteWindowOpen(
        status: 'open',
        endsAt: ends,
        now: DateTime(2026, 8, 29, 12, 0, 1),
      ),
      isFalse,
    );
  });

  test('draw picks only among correct answers', () {
    const votes = [
      QuizRaffleVote(uid: 'a', choiceIndex: 0, displayName: 'Ada'),
      QuizRaffleVote(uid: 'b', choiceIndex: 1, displayName: 'Bix'),
      QuizRaffleVote(uid: 'c', choiceIndex: 1, displayName: 'Coco'),
    ];
    final first = QuizRaffleLogic.pickWinner(
      votes: votes,
      correctIndex: 1,
      pickIndex: (_) => 0,
    );
    expect(first.winnerUid, 'b');
    expect(first.winnerName, 'Bix');
    expect(first.eligibleCount, 2);

    final second = QuizRaffleLogic.pickWinner(
      votes: votes,
      correctIndex: 1,
      pickIndex: (_) => 1,
    );
    expect(second.winnerUid, 'c');
  });

  test('empty correct set → no winner', () {
    const votes = [
      QuizRaffleVote(uid: 'a', choiceIndex: 0, displayName: 'Ada'),
    ];
    final draw = QuizRaffleLogic.pickWinner(
      votes: votes,
      correctIndex: 2,
      pickIndex: (_) => 0,
    );
    expect(draw.hasWinner, isFalse);
    expect(draw.winnerUid, isEmpty);
    expect(draw.eligibleCount, 0);
  });

  test('tombola rolls only with 2+ named correct voters', () {
    expect(
      QuizRaffleLogic.shouldRollTombola(
        winnerUid: 'b',
        eligibleNames: const ['Ada'],
      ),
      isFalse,
    );
    expect(
      QuizRaffleLogic.shouldRollTombola(
        winnerUid: '',
        eligibleNames: const ['Ada', 'Bix'],
      ),
      isFalse,
    );
    expect(
      QuizRaffleLogic.shouldRollTombola(
        winnerUid: 'b',
        eligibleNames: const ['Ada', 'Bix'],
      ),
      isTrue,
    );
  });

  test('tombola reel always ends on the server winner name', () {
    final reel = QuizRaffleLogic.buildTombolaReel(
      eligibleNames: const ['Ada', 'Bix', 'Coco'],
      winnerName: 'Bix',
      cycles: 3,
    );
    expect(reel.last, 'Bix');
    expect(reel.where((n) => n == 'Ada').length, 3);
    expect(reel.length, 10);
  });

  test('empty title falls back to Quiz, never Tombola', () {
    expect(QuizRaffleLogic.displayTitle(''), 'Quiz');
    expect(QuizRaffleLogic.displayTitle('   '), 'Quiz');
    expect(QuizRaffleLogic.displayTitle(null), 'Quiz');
    expect(QuizRaffleLogic.displayTitle('Tirage écharpe'), 'Tirage écharpe');
    expect(QuizRaffleLogic.displayTitle('Tombola'), 'Tombola');
  });

  test('drawn history newest first; empty winner has no profile uid', () {
    final items = QuizRaffleLogic.sortDrawnHistory([
      QuizRaffleHistoryItem(
        id: 'old',
        title: 'Quiz antenne',
        question: 'Quelle couleur ?',
        winnerUid: 'u1',
        winnerName: 'Ada',
        drawnAt: DateTime.utc(2026, 8, 28, 18),
      ),
      QuizRaffleHistoryItem(
        id: 'new',
        title: 'Tirage écharpe',
        question: 'Qui marque ?',
        winnerUid: '',
        winnerName: '',
        drawnAt: DateTime.utc(2026, 8, 29, 19, 4),
      ),
      const QuizRaffleHistoryItem(
        id: 'undated',
        question: 'Sans date',
        winnerUid: 'u2',
        winnerName: 'Bix',
      ),
    ]);
    expect(items.map((e) => e.id).toList(), ['new', 'old', 'undated']);
    expect(items.first.hasWinner, isFalse);
    expect(items[1].hasWinner, isTrue);
    expect(
      QuizRaffleLogic.formatDrawnAtParis(DateTime.utc(2026, 8, 29, 19, 4)),
      '29 août 2026 · 21:04',
    );
  });

  test('fake tombola names are 12–20 invented first names', () {
    var i = 0;
    final names = QuizRaffleLogic.shuffledFakeNames(
      nextInt: (max) {
        final v = i % max;
        i++;
        return v;
      },
      count: 16,
    );
    expect(names, hasLength(16));
    expect(names.toSet().length, 16);
    expect(
      names.every(QuizRaffleLogic.kFakePreviewFirstNames.contains),
      isTrue,
    );
  });

  test('fan title is whatever Axel typed, Quiz if empty, never a hardcoded Tombola', () {
    expect(QuizRaffleLogic.displayTitle(''), 'Quiz');
    expect(QuizRaffleLogic.displayTitle('  '), 'Quiz');
    expect(QuizRaffleLogic.displayTitle('Tirage écharpe'), 'Tirage écharpe');
    expect(QuizRaffleLogic.displayTitle('Tombola'), 'Tombola');
  });
}
