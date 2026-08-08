import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'live_radio_hls_player.dart';
import 'live_radio_service.dart';

/// Implémentation native : WHIP (publish) + HLS (écoute).
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
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _whipResourceUrl;
  Map<String, String>? _whipAuthHeaders;
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

  Future<Map<String, dynamic>> _fetchPublishConfig() async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('getLiveRadioPublishConfig');
    final result = await callable.call(<String, dynamic>{});
    return Map<String, dynamic>.from(result.data as Map);
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').trim();
    if (msg.contains('MediaMTX non configuré') ||
        msg.toLowerCase().contains('whip')) {
      return msg.isNotEmpty ? msg : 'MediaMTX non configuré';
    }
    if (msg.isNotEmpty) return msg;
    return 'Connexion radio impossible (${e.code})';
  }

  Future<void> _waitIceGatheringComplete(RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final done = Completer<void>();
    pc.onIceGatheringState = (RTCIceGatheringState? state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !done.isCompleted) {
        done.complete();
      }
    };
    try {
      await done.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // SDP partiel OK pour la plupart des MediaMTX.
    }
  }

  Future<void> _connectWhip({required bool enableMic}) async {
    await disconnect();
    Map<String, dynamic> cfg;
    try {
      cfg = await _fetchPublishConfig();
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_mapFunctionsError(e));
    }

    final whipUrl = (cfg['whipUrl'] ?? '').toString().trim();
    if (whipUrl.isEmpty) {
      throw StateError('URL WHIP manquante — configure app_config/radio');
    }

    final headers = <String, String>{
      'Content-Type': 'application/sdp',
    };
    final authorization = (cfg['authorization'] ?? '').toString().trim();
    if (authorization.isNotEmpty) {
      headers['Authorization'] = authorization;
    }
    _whipAuthHeaders = Map<String, String>.from(headers)
      ..remove('Content-Type');

    final pc = await createPeerConnection({
      'sdpSemantics': 'unified-plan',
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    _pc = pc;

    pc.onConnectionState = (RTCPeerConnectionState? state) {
      if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state ==
              RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        disconnect().then((_) => onDisconnected?.call());
      }
    };

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    _localStream = stream;
    for (final track in stream.getAudioTracks()) {
      track.enabled = enableMic;
      await pc.addTrack(track, stream);
    }

    final offer = await pc.createOffer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(offer);
    await _waitIceGatheringComplete(pc);
    final local = await pc.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null || sdp.isEmpty) {
      await disconnect();
      throw StateError('Offre WebRTC vide');
    }

    final response = await http.post(
      Uri.parse(whipUrl),
      headers: headers,
      body: sdp,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await disconnect();
      throw StateError(
        'WHIP refusé (${response.statusCode}) — vérifie MediaMTX',
      );
    }

    final location = response.headers['location'];
    if (location != null && location.trim().isNotEmpty) {
      final loc = location.trim();
      _whipResourceUrl = loc.startsWith('http')
          ? loc
          : Uri.parse(whipUrl).resolve(loc).toString();
    }

    await pc.setRemoteDescription(
      RTCSessionDescription(response.body, 'answer'),
    );
  }

  Future<void> _connectHls() async {
    await disconnect();
    final url = await _resolveHlsUrl();
    _hls.onEnded = () {
      disconnect().then((_) => onDisconnected?.call());
    };
    await _hls.play(url);
  }

  @override
  Future<void> connect({
    required LiveRadioRole role,
    required bool enableMic,
  }) async {
    if (role == LiveRadioRole.publisher) {
      await _connectWhip(enableMic: enableMic);
    } else {
      await _connectHls();
    }
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    final tracks = _localStream?.getAudioTracks() ?? const [];
    for (final t in tracks) {
      t.enabled = enabled;
    }
  }

  @override
  Future<void> disconnect() async {
    final resource = _whipResourceUrl;
    final auth = _whipAuthHeaders;
    _whipResourceUrl = null;
    _whipAuthHeaders = null;

    if (resource != null && resource.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse(resource),
          headers: auth ?? const {},
        );
      } catch (_) {}
    }

    await _hls.stop();
    _hls.onEnded = null;

    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        await t.stop();
      }
      await stream.dispose();
    }

    final pc = _pc;
    _pc = null;
    if (pc != null) {
      pc.onConnectionState = null;
      pc.onIceGatheringState = null;
      try {
        await pc.close();
      } catch (_) {}
    }
  }
}
