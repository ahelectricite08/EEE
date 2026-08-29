import 'package:dvcr/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder choices are 24h, 4h and 1h — no kickoff', () {
    expect(
      MatchReminderMode.values.map((m) => m.key),
      ['24h', '4h', '1h'],
    );
    expect(
      MatchReminderMode.values.map((m) => m.offset),
      [
        const Duration(hours: 24),
        const Duration(hours: 4),
        const Duration(hours: 1),
      ],
    );
  });

  test('legacy kickoff key falls back to 1h', () {
    expect(MatchReminderMode.fromKey('kickoff'), MatchReminderMode.hourBefore);
    expect(MatchReminderMode.fromKey('4h'), MatchReminderMode.fourHoursBefore);
    expect(MatchReminderMode.fromKey('24h'), MatchReminderMode.dayBefore);
  });
}
