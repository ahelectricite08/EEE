import 'package:video_player/video_player.dart';

/// Lecteur HLS / Icecast (audio) pour les fans — partagé web + native.
class LiveRadioHlsPlayer {
  VideoPlayerController? _controller;
  void Function()? onEnded;

  bool get isPlaying => _controller?.value.isPlaying ?? false;

  Future<void> play(String url) async {
    await stop();
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw StateError('URL radio invalide');
    }
    final ctrl = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = ctrl;
    ctrl.addListener(_onValue);
    await ctrl.initialize();
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
