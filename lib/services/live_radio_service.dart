import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_radio_platform_stub.dart'
    if (dart.library.io) 'live_radio_platform_io.dart';

/// Radio commentaire DVCR — publish WHIP (MediaMTX) + écoute WHEP (HLS fallback).
///
/// - Fans : [startListening] / [stop] (WHEP natif, HLS/Icecast en secours)
/// - Staff (app téléphone) : [startPublishing] explicite / [stop] + [setMuted] (WHIP)
/// - Retour casque : [setMonitorEnabled] / [setMonitorVolume] (best-effort local)
/// - Web : écoute HLS OK ; Son test = [LiveRadioTestTone] ; publish micro = téléphone
class LiveRadioService extends ChangeNotifier {
  LiveRadioService._();
  static final LiveRadioService instance = LiveRadioService._();

  static const _prefsMonitorKey = 'live_radio.monitor';
  static const _prefsMonitorVolKey = 'live_radio.monitor_volume';

  final LiveRadioPlatform _platform = createLiveRadioPlatform();

  bool _connecting = false;
  bool _muted = false;
  String? _lastError;
  LiveRadioRole? _role;
  bool _connected = false;
  bool _monitorEnabled = false;
  double _monitorVolume = 0.7;
  bool _prefsLoaded = false;

  /// Incrémenté à chaque [stop] — invalide les [_connect] encore en vol.
  int _operationId = 0;

  bool get isConnecting => _connecting;
  bool get isConnected => _connected;
  bool get isListening => isConnected && _role == LiveRadioRole.subscriber;
  bool get isPublishing => isConnected && _role == LiveRadioRole.publisher;
  bool get isMuted => _muted;
  bool get monitorEnabled => _monitorEnabled;
  double get monitorVolume => _monitorVolume;
  String? get lastError => _lastError;
  LiveRadioRole? get role => _role;

  Future<void> _ensurePrefs() async {
    if (_prefsLoaded || kIsWeb) return;
    _prefsLoaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _monitorEnabled = p.getBool(_prefsMonitorKey) ?? false;
      _monitorVolume =
          (p.getDouble(_prefsMonitorVolKey) ?? 0.7).clamp(0.0, 1.0);
    } catch (_) {}
  }

  Future<void> _persistMonitorPrefs() async {
    if (kIsWeb) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefsMonitorKey, _monitorEnabled);
      await p.setDouble(_prefsMonitorVolKey, _monitorVolume);
    } catch (_) {}
  }

  Future<void> startListening() async {
    await _connect(LiveRadioRole.subscriber, enableMic: false);
  }

  /// Message fan-friendly (évite CoreMedia / HTTP 404 bruts).
  static String userFacingMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('micro refusé') ||
        raw.contains('micro nécessaire') ||
        raw.contains('accéder au micro') ||
        raw.contains('permission') && raw.contains('micro') ||
        raw.contains('microphone')) {
      return error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
    }
    if (raw.contains('retour casque')) {
      return error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
    }
    // Pas de publisher WHIP / WHEP 404 / playlist HLS vide — pas une URL cassée.
    if (raw.contains('attente du commentateur') ||
        raw.contains('aucun commentaire en cours') ||
        raw.contains('playlist empty') ||
        raw.contains('pas encore disponible') ||
        raw.contains('no stream') ||
        raw.contains('404') ||
        raw.contains('not found') ||
        raw.contains('introuvable') ||
        raw.contains('-12938') ||
        raw.contains('file not found')) {
      return 'En attente du commentateur — active le micro sur le téléphone, '
          'puis réessaie.';
    }
    if (raw.contains('ats') ||
        raw.contains('cleartext') ||
        raw.contains('app transport') ||
        raw.contains('lecture http bloquée') ||
        raw.contains('restriction ios') ||
        raw.contains('impossible d’ouvrir le flux http')) {
      return 'Flux HTTP bloqué par iOS — installe la dernière build '
          '(ATS) ou passe l’URL HLS en https://.';
    }
    if (raw.contains('url radio invalide') ||
        raw.contains('url hls radio manquante') ||
        raw.contains('url manquante') ||
        raw.contains('url whip manquante')) {
      return 'Radio indisponible pour le moment.';
    }
    if (raw.contains('whip') ||
        raw.contains('ice') ||
        raw.contains('webrtc') ||
        raw.contains('téléphone') ||
        raw.contains('telephone') ||
        raw.contains('mediamtx')) {
      return error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
    }
    return 'Impossible de rejoindre la radio pour le moment.';
  }

  Future<void> startPublishing() async {
    if (kIsWeb) {
      throw StateError(
        'Utilise l’app téléphone pour parler à la radio',
      );
    }
    await _ensurePrefs();
    // Ne PAS auto-démarrer le retour casque (loopback) : crash natif iOS
    // fréquent juste après WHIP. L’utilisateur active le switch après.
    await _connect(LiveRadioRole.publisher, enableMic: true);
  }

  Future<void> _connect(LiveRadioRole role, {required bool enableMic}) async {
    final opId = ++_operationId;
    _connecting = true;
    _lastError = null;
    notifyListeners();

    try {
      _platform.onDisconnected = null;
      await _platform.disconnect();
      if (opId != _operationId) return;

      await _platform.connect(role: role, enableMic: enableMic);
      if (opId != _operationId) {
        await _platform.disconnect();
        return;
      }

      _connected = true;
      _role = role;
      _muted = false;
      final capturedOp = opId;
      _platform.onDisconnected = () {
        if (capturedOp != _operationId) return;
        _connected = false;
        _role = null;
        _muted = false;
        notifyListeners();
      };
    } catch (e) {
      if (opId != _operationId) return;
      _lastError = userFacingMessage(e);
      _connected = false;
      _role = null;
      throw StateError(_lastError!);
    } finally {
      if (opId == _operationId) {
        _connecting = false;
        notifyListeners();
      }
    }
  }

  Future<void> setMuted(bool muted) async {
    if (!isPublishing) return;
    await _platform.setMicrophoneEnabled(!muted);
    _muted = muted;
    notifyListeners();
  }

  Future<void> toggleMute() => setMuted(!_muted);

  Future<void> setMonitorEnabled(bool enabled) async {
    await _ensurePrefs();
    final previous = _monitorEnabled;
    _monitorEnabled = enabled;
    notifyListeners();
    if (isPublishing) {
      try {
        if (enabled) {
          await _platform.setMonitorVolume(_monitorVolume);
        }
        await _platform.setMonitorEnabled(enabled);
      } catch (e) {
        _monitorEnabled = previous;
        _lastError = userFacingMessage(e);
        notifyListeners();
        throw StateError(_lastError!);
      }
    }
    await _persistMonitorPrefs();
    notifyListeners();
  }

  Future<void> setMonitorVolume(double volume) async {
    await _ensurePrefs();
    _monitorVolume = volume.clamp(0.0, 1.0);
    if (isPublishing) {
      await _platform.setMonitorVolume(_monitorVolume);
    }
    await _persistMonitorPrefs();
    notifyListeners();
  }

  Future<void> stop({bool silent = false}) async {
    _operationId++;
    _connecting = false;
    _platform.onDisconnected = null;
    await _platform.disconnect();
    _connected = false;
    _role = null;
    _muted = false;
    if (!silent) notifyListeners();
  }
}

enum LiveRadioRole { publisher, subscriber }
