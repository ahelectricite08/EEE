import 'package:dvcr/services/live_broadcast_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit streamBroadcast false is live non retransmis', () {
    expect(
      LiveBroadcastMode.isRetransmitted({
        'streamBroadcast': false,
        'url': 'https://youtube.com/watch?v=abc',
      }),
      isFalse,
    );
  });

  test('streamBroadcast true is retransmitted', () {
    expect(
      LiveBroadcastMode.isRetransmitted({'streamBroadcast': true}),
      isTrue,
    );
  });

  test('missing flag falls back to stream URL', () {
    expect(
      LiveBroadcastMode.isRetransmitted({'url': 'https://youtu.be/x'}),
      isTrue,
    );
    expect(LiveBroadcastMode.isRetransmitted({'url': ''}), isFalse);
  });
}
