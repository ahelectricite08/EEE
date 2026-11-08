import 'package:flutter_test/flutter_test.dart';
import 'package:dvcr/models/radio_config.dart';

void main() {
  test('OBS RTSP / RTMP dérivés du HLS MediaMTX', () {
    const hls =
        'https://radio.example.com:8888/dvcr-radio/index.m3u8';
    expect(
      RadioConfig.obsRtspFromHls(hls),
      'rtsp://radio.example.com:8554/dvcr-radio',
    );
    expect(
      RadioConfig.obsRtmpFromHls(hls),
      'rtmp://radio.example.com:1935/dvcr-radio',
    );
    expect(RadioConfig.obsRtspFromHls(''), '');
  });
}
