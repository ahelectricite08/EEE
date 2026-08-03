import 'live_radio_service.dart';

/// Abstraction plateforme (stub web / LiveKit mobile).
abstract class LiveRadioPlatform {
  void Function()? onDisconnected;

  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> disconnect();
}

LiveRadioPlatform createLiveRadioPlatform() => _StubLiveRadioPlatform();

class _StubLiveRadioPlatform implements LiveRadioPlatform {
  @override
  void Function()? onDisconnected;

  @override
  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  }) async {
    throw StateError(
      'Radio LiveKit indisponible sur le web — utilise l’app téléphone',
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> disconnect() async {}
}
