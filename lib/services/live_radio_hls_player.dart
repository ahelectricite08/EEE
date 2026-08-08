import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'podcast_controller.dart';

/// Lecteur HLS / Icecast (audio) pour les fans.
///
/// - Native : [PodcastController] / `audio_service` (fond + notif, style podcast)
/// - Web : [VideoPlayerController] (pas de background OS)
class LiveRadioHlsPlayer {
  VideoPlayerController? _controller;
  bool _usingAudioService = false;
  void Function()? onEnded;

  bool get isPlaying {
    if (_usingAudioService) {
      return PodcastController.instance.isPlaying &&
          PodcastController.instance.isLiveRadioMode;
    }
    return _controller?.value.isPlaying ?? false;
  }

  Future<void> play(String url) async {
    await stop();
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw StateError('URL radio invalide');
    }

    if (!kIsWeb) {
      try {
        await PodcastController.instance.playLiveRadio(uri.toString());
        _usingAudioService = true;
        return;
      } catch (e) {
        debugPrint('LiveRadio audio_service fallback: $e');
        // Fallback video_player ci-dessous.
      }
    }

    final ctrl = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = ctrl;
    ctrl.addListener(_onValue);
    try {
      await ctrl.initialize();
    } catch (e) {
      await stop();
      final s = e.toString().toLowerCase();
      if (s.contains('404') ||
          s.contains('not found') ||
          s.contains('-12938')) {
        throw StateError(
          'Le commentaire audio n’est pas encore disponible. '
          'Réessaie dans un instant.',
        );
      }
      throw StateError('Impossible de rejoindre la radio pour le moment.');
    }
    await ctrl.setLooping(true);
    await ctrl.setVolume(1.0);
    await ctrl.play();
  }

  void _onValue() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      onEnded?.call();
    }
  }

  Future<void> stop() async {
    if (_usingAudioService) {
      _usingAudioService = false;
      try {
        await PodcastController.instance.stopLiveRadio();
      } catch (_) {}
    }

    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      c.removeListener(_onValue);
      await c.pause();
      await c.dispose();
    } catch (_) {}
  }
}
