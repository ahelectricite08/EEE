import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/constants/notification_channels.dart';
import 'package:dvcr/services/notification_service.dart';

void main() {
  test('live_start and score events use live channels, not alerts', () {
    expect(
      DvcrNotificationChannels.fromMessageType('live_start'),
      DvcrNotificationChannels.live,
    );
    expect(
      DvcrNotificationChannels.fromMessageType('kickoff'),
      DvcrNotificationChannels.live,
    );
    expect(
      DvcrNotificationChannels.fromMessageType('halftime'),
      DvcrNotificationChannels.live,
    );
    expect(
      DvcrNotificationChannels.fromMessageType('goal'),
      DvcrNotificationChannels.liveEvents,
    );
    expect(
      DvcrNotificationChannels.fromMessageType('goal_cancelled'),
      DvcrNotificationChannels.liveEvents,
    );
    expect(
      DvcrNotificationChannels.fromMessageType('yellow'),
      DvcrNotificationChannels.liveEvents,
    );
  });

  test('live heads-up types share one Android tag identity', () {
    expect(NotificationService.isLiveHeadsUpType('live_start'), isTrue);
    expect(NotificationService.isLiveHeadsUpType('goal'), isTrue);
    expect(NotificationService.isLiveHeadsUpType('article'), isFalse);
    expect(NotificationService.liveAndroidTag, 'dvcr_live');
  });

  test('duplicate live banners in a short window are skipped', () {
    NotificationService.resetLiveDedupeForTest();
    const key = 'live_start|Nous sommes en live|CSSA vs Test';
    expect(NotificationService.consumeLiveBannerDedupe(key), isFalse);
    expect(NotificationService.consumeLiveBannerDedupe(key), isTrue);
    expect(
      NotificationService.consumeLiveBannerDedupe('goal|BUT|1-0'),
      isFalse,
    );
  });
}
