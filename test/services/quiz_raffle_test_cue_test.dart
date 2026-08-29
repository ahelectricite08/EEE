import 'package:dvcr/services/quiz_raffle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TEST cue doc id is stable and not a quiz_raffles path', () {
    expect(QuizRaffleService.testDocId, 'quiz_raffle_test');
  });

  test('testQuizFromCue is off unless force and enough fake names', () {
    expect(QuizRaffleService.testQuizFromCue(null), isNull);
    expect(QuizRaffleService.testQuizFromCue({'force': false}), isNull);
    expect(
      QuizRaffleService.testQuizFromCue({
        'force': true,
        'winnerName': 'Léa',
        'eligibleNames': ['Léa'],
      }),
      isNull,
    );
    final quiz = QuizRaffleService.testQuizFromCue({
      'force': true,
      'winnerName': 'Camille',
      'eligibleNames': ['Léa', 'Hugo', 'Camille'],
      'playNonce': 42,
    });
    expect(quiz, isNotNull);
    expect(quiz!['id'], QuizRaffleService.testDocId);
    expect(quiz['status'], 'drawn');
    expect(quiz['winnerUid'], 'test_preview');
    expect(quiz['winnerName'], 'Camille');
    expect(quiz['playNonce'], 42);
    expect(quiz['title'], 'Quiz');
    expect(quiz['question'], isNot(contains('tombola')));
  });
}
