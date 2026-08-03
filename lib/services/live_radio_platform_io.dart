import 'package:cloud_functions/cloud_functions.dart';
import 'package:livekit_client/livekit_client.dart';

import 'live_radio_service.dart';

/// Implémentation LiveKit (iOS / Android / desktop).
LiveRadioPlatform createLiveRadioPlatform() => LiveRadioPlatformIo();

abstract class LiveRadioPlatform {
  void Function()? onDisconnected;

  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  });

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> disconnect();
}

class LiveRadioPlatformIo implements LiveRadioPlatform {
  Room? _room;

  @override
  void Function()? onDisconnected;

  Future<Map<String, dynamic>> _fetchToken(LiveRadioRole role) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('getLiveRadioToken');
    final result = await callable.call(<String, dynamic>{
      'role': role == LiveRadioRole.publisher ? 'publisher' : 'subscriber',
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final token = (data['token'] ?? '').toString().trim();
    final url = (data['url'] ?? '').toString().trim();
    if (token.isEmpty || url.isEmpty) {
      throw StateError('Token LiveKit invalide');
    }
    return data;
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    if (msg.contains('LiveKit non configuré') ||
        (e.code == 'failed-precondition' &&
            msg.toLowerCase().contains('livekit'))) {
      return 'LiveKit non configuré';
    }
    if (msg.isNotEmpty) return msg;
    return 'Connexion radio impossible (${e.code})';
  }

  void _onRoomChanged() {
    final room = _room;
    if (room == null) return;
    if (room.connectionState == ConnectionState.disconnected) {
      disconnect().then((_) => onDisconnected?.call());
    }
  }

  @override
  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  }) async {
    await disconnect();
    try {
      final data = await _fetchToken(role);
      final token = (data['token'] ?? '').toString();
      final url = (data['url'] ?? '').toString();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'radio-mic',
          ),
        ),
      );
      room.addListener(_onRoomChanged);
      await room.connect(url, token);
      _room = room;
      await room.localParticipant?.setMicrophoneEnabled(enableMic);
    } on FirebaseFunctionsException catch (e) {
      await disconnect();
      throw StateError(_mapFunctionsError(e));
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    if (room == null) return;
    try {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    } catch (_) {}
  }
}
