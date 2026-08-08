import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'podcast_controller.dart';

/// Lecteur HLS / Icecast (audio) pour les fans.
///
/// - Native non-HLS : [PodcastController] / `audio_service` (fond + notif)
/// - HLS (.m3u8) et web : [VideoPlayerController] (support HLS fiable)
///
/// MediaMTX renvoie souvent **404** tant qu’aucun publisher WHIP n’a produit
/// de segments — sonde + retries avant lecture.
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
    final playUrl = uri.toString();
    final isHls = playUrl.toLowerCase().contains('.m3u8');

    // Attendre que le m3u8 / flux existe (404 → démarrage MediaMTX).
    await _waitUntilHlsReady(playUrl);

    // Flux non-HLS (Icecast mp3…) : audio_service pour fond / notif.
    if (!kIsWeb && !isHls) {
      try {
        await PodcastController.instance.playLiveRadio(playUrl);
        _usingAudioService = true;
        return;
      } catch (e) {
        debugPrint('LiveRadio audio_service fallback: $e');
      }
    }

    // HLS : video_player (AVPlayer / ExoPlayer) — UIBackgroundModes audio iOS.
    await _playWithVideoPlayer(uri);
  }

  /// Sonde GET : MediaMTX → 404 tant que le WHIP n’a pas de segments HLS.
  /// Distingue 404 (pas de stream) vs échec réseau / ATS (http bloqué iOS).
  Future<void> _waitUntilHlsReady(String url) async {
    const attempts = 8;
    final client = http.Client();
    var sawHttp404 = false;
    var sawTransportError = false;
    Object? lastTransportError;
    debugPrint('LiveRadio listen URL=$url');
    try {
      for (var i = 0; i < attempts; i++) {
        try {
          final res = await client
              .get(Uri.parse(url), headers: const {'Accept': '*/*'})
              .timeout(const Duration(seconds: 4));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final body = res.body;
            if (body.contains('#EXTINF')) {
              return;
            }
            if (body.contains('#EXTM3U')) {
              debugPrint(
                'LiveRadio HLS playlist empty try ${i + 1}/$attempts',
              );
            } else if (!url.toLowerCase().contains('.m3u8') &&
                body.trim().isNotEmpty) {
              return;
            } else {
              return;
            }
          } else if (res.statusCode == 404) {
            sawHttp404 = true;
            debugPrint(
              'LiveRadio HLS 404 try ${i + 1}/$attempts',
            );
          } else {
            debugPrint(
              'LiveRadio HLS not ready (${res.statusCode}) try ${i + 1}/$attempts',
            );
          }
        } catch (e) {
          sawTransportError = true;
          lastTransportError = e;
          debugPrint('LiveRadio HLS probe error try ${i + 1}/$attempts: $e');
        }
        if (i < attempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 800 + (i * 400)),
          );
        }
      }
    } finally {
      client.close();
    }

    // Si on n’a jamais eu de réponse HTTP : souvent ATS / cleartext iOS.
    if (sawTransportError && !sawHttp404) {
      final s = (lastTransportError ?? '').toString().toLowerCase();
      if (s.contains('failed host lookup') ||
          s.contains('connection') ||
          s.contains('socket') ||
          s.contains('timed out') ||
          s.contains('handshake') ||
          s.contains('cleartext') ||
          s.contains('ats') ||
          s.contains('operation not permitted')) {
        throw StateError(
          'Impossible d’ouvrir le flux HTTP depuis l’app '
          '(restriction iOS/Android). Vérifie ATS / cleartext — '
          'URL: $url',
        );
      }
      throw StateError(
        'Impossible de joindre la radio ($url). '
        'Vérifie le réseau ou colle la même URL dans VLC.',
      );
    }

    throw StateError(
      'Le commentaire audio n’est pas encore disponible. '
      'Attends que le micro soit « en direct », puis réessaie (5–10 s).',
    );
  }

  Future<void> _playWithVideoPlayer(Uri uri) async {
    final ctrl = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = ctrl;
    ctrl.addListener(_onValue);
    Object? lastError;
    for (var i = 0; i < 4; i++) {
      try {
        await ctrl.initialize();
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
        debugPrint('LiveRadio video_player init try ${i + 1}: $e');
        if (i < 3) {
          await Future<void>.delayed(Duration(milliseconds: 1000 + i * 500));
        }
      }
    }
    if (lastError != null) {
      await stop();
      final s = lastError.toString().toLowerCase();
      if (s.contains('404') ||
          s.contains('not found') ||
          s.contains('introuvable') ||
          s.contains('-12938') ||
          s.contains('file not found')) {
        throw StateError(
          'Le commentaire audio n’est pas encore disponible. '
          'Attends que le micro soit « en direct », puis réessaie.',
        );
      }
      if (s.contains('ats') ||
          s.contains('ssl') ||
          s.contains('secure') ||
          s.contains('cleartext') ||
          s.contains('app transport')) {
        throw StateError(
          'Lecture HTTP bloquée — utilise une URL HLS https:// '
          'dans app_config/radio.',
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
