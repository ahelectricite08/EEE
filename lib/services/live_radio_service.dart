import 'package:flutter/foundation.dart';

import 'live_radio_platform_stub.dart'
    if (dart.library.io) 'live_radio_platform_io.dart';

/// Radio commentaire DVCR — publish WHIP (MediaMTX) + écoute HLS.
///
/// - Fans : [startListening] / [stop] (HLS / Icecast)
/// - Staff (app téléphone) : [startPublishing] / [stop] + [setMuted] (WHIP)
/// - Web : écoute HLS OK ; publish micro = app téléphone
class LiveRadioService extends ChangeNotifier {
  LiveRadioService._();
  static final LiveRadioService instance = LiveRadioService._();

  final LiveRadioPlatform _platform = createLiveRadioPlatform();

  bool _connecting = false;
  bool _muted = false;
  String? _lastError;
  LiveRadioRole? _role;
  bool _connected = false;

  bool get isConnecting => _connecting;
  bool get isConnected => _connected;
  bool get isListening => isConnected && _role == LiveRadioRole.subscriber;
  bool get isPublishing => isConnected && _role == LiveRadioRole.publisher;
  bool get isMuted => _muted;
  String? get lastError => _lastError;
  LiveRadioRole? get role => _role;

  Future<void> startListening() async {
    await _connect(LiveRadioRole.subscriber, enableMic: false);
  }

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
      await _platform.connect(role: role, enableMic: enableMic);
      _connected = true;
      _role = role;
      _muted = false;
      _platform.onDisconnected = () {
        _connected = false;
        _role = null;
        _muted = false;
        notifyListeners();
      };
    } catch (e) {
      _lastError = e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
      _connected = false;
      _role = null;
      rethrow;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> setMuted(bool muted) async {
    if (!isPublishing) return;
    await _platform.setMicrophoneEnabled(!muted);
    _muted = muted;
    notifyListeners();
  }

  Future<void> toggleMute() => setMuted(!_muted);

  Future<void> stop({bool silent = false}) async {
    await _platform.disconnect();
    _connected = false;
    _role = null;
    _muted = false;
    if (!silent) notifyListeners();
  }
}

enum LiveRadioRole { publisher, subscriber }
