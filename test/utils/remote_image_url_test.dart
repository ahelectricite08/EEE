import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/utils/remote_image_url.dart';

void main() {
  const canva =
      'https://media.canva.com/v2/image-resize/format:JPG/height:1066/'
      'quality:92/uri:ifs%3A%2F%2FM%2F227de293-b635-4435-aa66-077be2aec7a5/'
      'watermark:F/width:1600?exp=1786940777&sig=abc';

  test('Canva media URLs are skipped (no NetworkImage)', () {
    expect(looksLikeCanvaHotlinkUrl(canva), isTrue);
    expect(shouldSkipNetworkImageUrl(canva), isTrue);
    expect(remoteImageAdminWarning(canva), contains('Canva'));
  });

  test('expired exp= is skipped even without Canva host', () {
    const expired = 'https://cdn.example.com/img.jpg?exp=1000000000';
    expect(isExpiredSignedImageUrl(expired), isTrue);
    expect(shouldSkipNetworkImageUrl(expired), isTrue);
  });

  test('cache-bust does not mutate signed Canva query', () {
    expect(cacheBustedImageUrl(canva, 1787358957694), canva);
  });

  test('stable Wix still gets dvcr_rev', () {
    const wix = 'https://static.wixstatic.com/media/foo.jpg';
    expect(cacheBustedImageUrl(wix, 99), '$wix?dvcr_rev=99');
    expect(shouldSkipNetworkImageUrl(wix), isFalse);
  });

  test('tiny Wix fill (90×90) is upgraded to original media file', () {
    const tiny =
        'https://static.wixstatic.com/media/e91e00_abc~mv2.jpeg/v1/fill/w_90,h_90/e91e00_abc~mv2.jpeg';
    expect(isTinyWixFillUrl(tiny), isTrue);
    expect(
      upgradeWixStaticMediaUrl(tiny),
      'https://static.wixstatic.com/media/e91e00_abc~mv2.jpeg',
    );
    expect(remoteImageAdminWarning(tiny), contains('miniature'));
  });

  test('large Wix fill is left unchanged', () {
    const ok =
        'https://static.wixstatic.com/media/e91e00_abc~mv2.jpeg/v1/fill/w_1600,h_800,al_c,q_85,enc_jpg/e91e00_abc~mv2.jpeg';
    expect(isTinyWixFillUrl(ok), isFalse);
    expect(upgradeWixStaticMediaUrl(ok), ok);
  });

  test('403 / Canva messages are benign', () {
    expect(
      isBenignRemoteImageFailureMessage(
        'HTTP request failed, statusCode: 403, $canva',
      ),
      isTrue,
    );
  });
}
