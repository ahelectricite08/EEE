import 'dart:async';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Son de test admin web : oscillateur → WHIP via proxy Cloud Functions (CORS).
///
/// Web Audio n’est pas exposé dans `dart:html` (SDK Flutter) → accès via `dart:js`.
class LiveRadioTestTone extends ChangeNotifier {
  LiveRadioTestTone._();
  static final LiveRadioTestTone instance = LiveRadioTestTone._();

  js.JsObject? _audioBundle;
  html.RtcPeerConnection? _pc;
  String? _whipLocation;
  Timer? _autoStop;
  bool _running = false;
  int _generation = 0;

  bool get isRunning => _running;

  Future<void> start({Duration duration = const Duration(seconds: 20)}) async {
    await stop();
    final gen = ++_generation;
    _running = true;
    notifyListeners();

    try {
      final stream = _startOscillatorStream();
      final pc = html.RtcPeerConnection({
        'sdpSemantics': 'unified-plan',
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });
      _pc = pc;

      for (final track in stream.getAudioTracks()) {
        pc.addTrack(track, stream);
      }

      final offer = await pc.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await pc.setLocalDescription({
        'type': offer.type,
        'sdp': offer.sdp,
      });
      await _waitIceGatheringComplete(pc);
      if (gen != _generation) return;

      final local = pc.localDescription;
      final sdp = (local?.sdp ?? '').trim();
      if (sdp.isEmpty) {
        throw StateError('Offre WebRTC vide');
      }

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('postLiveRadioWhipOffer');
      final result = await callable.call(<String, dynamic>{'sdp': sdp});
      if (gen != _generation) return;

      final data = Map<String, dynamic>.from(result.data as Map);
      final answer = (data['sdp'] ?? '').toString().trim();
      if (answer.isEmpty) {
        throw StateError('Réponse WHIP vide');
      }
      final location = (data['location'] ?? '').toString().trim();
      _whipLocation = location.isEmpty ? null : location;

      await pc.setRemoteDescription({
        'type': 'answer',
        'sdp': answer,
      });

      _autoStop?.cancel();
      _autoStop = Timer(duration, () {
        stop();
      });
    } on FirebaseFunctionsException catch (e) {
      await stop();
      final msg = (e.message ?? '').trim();
      throw StateError(
        msg.isNotEmpty ? msg : 'Son test impossible (${e.code})',
      );
    } catch (e) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _generation++;
    _autoStop?.cancel();
    _autoStop = null;

    final location = _whipLocation;
    _whipLocation = null;

    if (location != null && location.isNotEmpty) {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('deleteLiveRadioWhipSession');
        await callable.call(<String, dynamic>{'location': location});
      } catch (_) {}
    }

    final bundle = _audioBundle;
    _audioBundle = null;
    if (bundle != null) {
      try {
        bundle.callMethod('stop', []);
      } catch (_) {}
    }

    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        pc.close();
      } catch (_) {}
    }

    if (_running) {
      _running = false;
      notifyListeners();
    }
  }

  html.MediaStream _startOscillatorStream() {
    final factory = js.context.callMethod('Function', [
      r'''
      return function() {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) throw new Error('AudioContext indisponible');
        var ctx = new AC();
        var osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.value = 880;
        var gain = ctx.createGain();
        gain.gain.value = 0.18;
        var dest = ctx.createMediaStreamDestination();
        osc.connect(gain);
        gain.connect(dest);
        osc.start();
        return {
          stream: dest.stream,
          stop: function() {
            try { osc.stop(0); } catch (e) {}
            try { osc.disconnect(); } catch (e) {}
            try { gain.disconnect(); } catch (e) {}
            try { ctx.close(); } catch (e) {}
          }
        };
      }
      ''',
    ]);
    final create = (factory as js.JsFunction).apply([]);
    final bundle = (create as js.JsFunction).apply([]);
    if (bundle is! js.JsObject) {
      throw StateError('Flux audio de test indisponible');
    }
    _audioBundle = bundle;
    final stream = bundle['stream'];
    if (stream == null) {
      throw StateError('Flux audio de test indisponible');
    }
    return stream as html.MediaStream;
  }

  Future<void> _waitIceGatheringComplete(html.RtcPeerConnection pc) async {
    if (pc.iceGatheringState == 'complete') return;
    final done = Completer<void>();
    late StreamSubscription<html.RtcPeerConnectionIceEvent> sub;
    Timer? poll;
    void maybeComplete() {
      if (!done.isCompleted && pc.iceGatheringState == 'complete') {
        done.complete();
      }
    }

    sub = pc.onIceCandidate.listen((event) {
      if (event.candidate == null) maybeComplete();
      maybeComplete();
    });
    poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      maybeComplete();
    });

    try {
      await done.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // SDP partiel OK pour la plupart des MediaMTX.
    } finally {
      poll.cancel();
      await sub.cancel();
    }
  }
}
