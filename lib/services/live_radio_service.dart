import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Connexion LiveKit pour la radio commentaire DVCR (audio-only).
///
/// - Fans : [startListening] / [stop]
/// - Staff (app téléphone) : [startPublishing] / [stop] + [setMuted]
class LiveRadioService extends ChangeNotifier {
  LiveRadioService._();
  static final LiveRadioService instance = LiveRadioService._();

  Room? _room;
  bool _connecting = false;
  bool _muted = false;
  String? _lastError;
  LiveRadioRole? _role;

  bool get isConnecting => _connecting;
  bool get isConnected => _room != null && _room!.connectionState == ConnectionState.connected;
  bool get isListening => isConnected && _role == LiveRadioRole.subscriber;
  bool get isPublishing => isConnected && _role == LiveRadioRole.publisher;
  bool get isMuted => _muted;
  String? get lastError => _lastError;
  LiveRadioRole? get role => _role;

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

  Future<void> startListening() async {
    await _connect(LiveRadioRole.subscriber, enableMic: false);
  }

  /// Publication micro — réservé mobile (web : message admin).
  Future<void> startPublishing() async {
    if (kIsWeb) {
      throw StateError(
        'Utilise l’app téléphone pour parler à la radio',
      );
    }
    await _connect(LiveRadioRole.publisher, enableMic: true);
  }

  Future<void> _connect(LiveRadioRole role, {required bool enableMic}) async {
    if (_connecting) return;
    _connecting = true;
    _lastError = null;
    notifyListeners();

    try {
      await stop(silent: true);

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
      _role = role;
      _muted = false;

      if (enableMic) {
        await room.localParticipant?.setMicrophoneEnabled(true);
      } else {
        await room.localParticipant?.setMicrophoneEnabled(false);
      }
    } on FirebaseFunctionsException catch (e) {
      _lastError = _mapFunctionsError(e);
      await _disposeRoom();
      rethrow;
    } catch (e) {
      _lastError = e.toString().replaceFirst('StateError: ', '');
      await _disposeRoom();
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
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

  Future<void> setMuted(bool muted) async {
    final room = _room;
    if (room == null || _role != LiveRadioRole.publisher) return;
    await room.localParticipant?.setMicrophoneEnabled(!muted);
    _muted = muted;
    notifyListeners();
  }

  Future<void> toggleMute() => setMuted(!_muted);

  Future<void> stop({bool silent = false}) async {
    await _disposeRoom();
    if (!silent) notifyListeners();
  }

  void _onRoomChanged() {
    final room = _room;
    if (room == null) return;
    if (room.connectionState == ConnectionState.disconnected) {
      _disposeRoom().then((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }

  Future<void> _disposeRoom() async {
    final room = _room;
    _room = null;
    _role = null;
    _muted = false;
    if (room == null) return;
    try {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    } catch (_) {}
  }
}

enum LiveRadioRole { publisher, subscriber }
