import 'package:flutter_test/flutter_test.dart';

import 'package:dvcr/models/media_resume.dart';

MediaResumeItem _video({
  int positionMs = 120000,
  int durationMs = 600000,
  String id = 'abc123xyz',
}) {
  return MediaResumeItem(
    kind: MediaResumeKind.video,
    id: id,
    title: 'Résumé CSSA',
    positionMs: positionMs,
    durationMs: durationMs,
    updatedAtMs: 1,
  );
}

MediaResumeItem _podcast({
  int positionMs = 180000,
  int durationMs = 3600000,
}) {
  return MediaResumeItem(
    kind: MediaResumeKind.podcast,
    id: 'https://example.com/a.mp3',
    title: 'Émission du dimanche',
    positionMs: positionMs,
    durationMs: durationMs,
    updatedAtMs: 2,
  );
}

void main() {
  test('ignore les 15 premières secondes', () {
    expect(MediaResumeRules.shouldKeep(_video(positionMs: 14000)), isFalse);
    expect(MediaResumeRules.shouldKeep(_video(positionMs: 15000)), isTrue);
  });

  test('un média fini ou quasi fini disparaît de Reprendre', () {
    expect(
      MediaResumeRules.shouldKeep(_video(positionMs: 589000, durationMs: 600000)),
      isFalse,
    );
    expect(
      MediaResumeRules.shouldKeep(_video(positionMs: 570001, durationMs: 600000)),
      isFalse,
    );
  });

  test('pas de reprise sur un Short', () {
    expect(
      MediaResumeRules.shouldKeep(_video(durationMs: 45000), isShort: true),
      isFalse,
    );
    expect(
      MediaResumeRules.eligibleDuration(durationMs: 45000),
      isFalse,
    );
  });

  test('upsert met l’item en tête et plafonne à 20', () {
    var list = <MediaResumeItem>[];
    for (var i = 0; i < 22; i++) {
      list = MediaResumeRules.upsert(
        list,
        _video(id: 'id$i', positionMs: 30000 + i),
      );
    }
    expect(list.length, MediaResumeRules.maxItems);
    expect(list.first.id, 'id21');
  });

  test('upsert d’un item trop tôt le retire', () {
    final kept = MediaResumeRules.upsert(const [], _video(positionMs: 200000));
    final after = MediaResumeRules.upsert(kept, _video(positionMs: 5000));
    expect(after, isEmpty);
  });

  test('libellés de reprise', () {
    expect(
      MediaResumeLabels.remaining(120000, 600000),
      'Plus que 8 min',
    );
    expect(
      MediaResumeLabels.remaining(0, 5400000),
      'Plus que 1 h 30 min',
    );
    expect(MediaResumeLabels.resumeAt(125000), 'Reprendre à 02:05');
    expect(MediaResumeLabels.clock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03');
  });

  test('json aller-retour', () {
    final item = _podcast();
    final copy = MediaResumeItem.fromJson(item.toJson());
    expect(copy.kind, MediaResumeKind.podcast);
    expect(copy.id, item.id);
    expect(copy.positionMs, item.positionMs);
    expect(copy.fraction, closeTo(0.05, 0.0001));
  });

  test('asVideo reconstruit un VideoModel lisible', () {
    final video = _video().asVideo;
    expect(video, isNotNull);
    expect(video!.youtubeId, 'abc123xyz');
    expect(video.title, 'Résumé CSSA');
  });
}
