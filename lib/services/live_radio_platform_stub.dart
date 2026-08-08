import 'package:cloud_firestore/cloud_firestore.dart';

import 'live_radio_hls_player.dart';
import 'live_radio_service.dart';

/// Abstraction plateforme (web : HLS écoute ; publish = téléphone).
abstract class LiveRadioPlatform {
  void Function()? onDisconnected;

  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  /// Retour casque local (sidetone). No-op hors publish native.
  Future<void> setMonitorEnabled(bool enabled);

  /// Volume du retour uniquement (0–1) — n’altère pas le gain WHIP.
  Future<void> setMonitorVolume(double volume);

  Future<void> disconnect();
}

LiveRadioPlatform createLiveRadioPlatform() => _WebLiveRadioPlatform();

class _WebLiveRadioPlatform implements LiveRadioPlatform {
  final LiveRadioHlsPlayer _hls = LiveRadioHlsPlayer();

  @override
  void Function()? onDisconnected;

  Future<String> _resolveHlsUrl() async {
    final snap =
        await FirebaseFirestore.instance.collection('live').doc('current').get();
    if (!snap.exists) {
      throw StateError('Aucun match en direct');
    }
    final data = snap.data() ?? {};
    if (data['radioLive'] != true) {
      throw StateError('Radio commentaire éteinte');
    }
    final url = (data['radioHlsUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError('URL HLS radio manquante');
    }
    return url;
  }

  @override
  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  }) async {
    if (role == LiveRadioRole.publisher) {
      throw StateError(
        'Utilise l’app téléphone pour parler à la radio',
      );
    }
    await disconnect();
    final url = await _resolveHlsUrl();
    _hls.onEnded = () {
      disconnect().then((_) => onDisconnected?.call());
    };
    await _hls.play(url);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setMonitorEnabled(bool enabled) async {}

  @override
  Future<void> setMonitorVolume(double volume) async {}

  @override
  Future<void> disconnect() async {
    await _hls.stop();
    _hls.onEnded = null;
  }
}
