import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/video_model.dart';

void main() {
  test('VideoModel.cleanId extrait l identifiant YouTube', () {
    const shortUrl = 'https://youtu.be/dQw4w9WgXcQ';
    const watchUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

    expect(
      VideoModel(
        id: '1',
        title: 'Test',
        youtubeId: shortUrl,
        duration: '0:00',
        date: DateTime(2026),
        category: 'resume',
      ).cleanId,
      'dQw4w9WgXcQ',
    );

    expect(
      VideoModel(
        id: '2',
        title: 'Test',
        youtubeId: watchUrl,
        duration: '0:00',
        date: DateTime(2026),
        category: 'podcast',
      ).cleanId,
      'dQw4w9WgXcQ',
    );
  });
}
