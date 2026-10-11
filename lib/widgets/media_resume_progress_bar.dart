import 'package:flutter/material.dart';

import '../models/media_resume.dart';
import '../services/media_resume_store.dart';

/// Filet de progression en bas d’une miniature — style reprise.
class MediaResumeProgressBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const MediaResumeProgressBar({
    super.key,
    required this.fraction,
    this.color = const Color(0xFF167A5F),
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    final t = fraction.clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: t,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

class MediaResumeThumbProgress extends StatelessWidget {
  final MediaResumeKind kind;
  final String id;
  final Color color;

  const MediaResumeThumbProgress({
    super.key,
    required this.kind,
    required this.id,
    this.color = const Color(0xFF167A5F),
  });

  factory MediaResumeThumbProgress.video(
    String youtubeId, {
    Color color = const Color(0xFF167A5F),
  }) {
    return MediaResumeThumbProgress(
      kind: MediaResumeKind.video,
      id: youtubeId,
      color: color,
    );
  }

  factory MediaResumeThumbProgress.podcast(
    String mp3Url, {
    Color color = const Color(0xFF167A5F),
  }) {
    return MediaResumeThumbProgress(
      kind: MediaResumeKind.podcast,
      id: mp3Url,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MediaResumeStore.instance,
      builder: (context, _) {
        final item = MediaResumeStore.instance.itemFor(kind, id);
        if (item == null) return const SizedBox.shrink();
        return MediaResumeProgressBar(fraction: item.fraction, color: color);
      },
    );
  }
}
